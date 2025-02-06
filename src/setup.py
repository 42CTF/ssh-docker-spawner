import yaml
import os
import subprocess
import re

CONFIG_FILE = "config.yml"
SSH_CONFIG_DIR = "/etc/ssh/sshd_config.d"
BASE_SSH_CONFIG = "Port 4242\n"

DOCKER_GID = os.getenv("DOCKER_GID", "999")
HOST_WORKDIR = os.getenv("HOST_WORKDIR", "/tmp")

def create_user(username, password=""):
    print(f"Creating user '{username}' with password '{password}'")

    group_name = subprocess.run(
        ["./src/create_group.sh", username, DOCKER_GID],
        stdout=subprocess.PIPE
    ).stdout.decode().strip()

    subprocess.run(
        ["./src/create_user.sh", username, "-p", f"{password}", "-g", group_name],
        check=True
    )

    print(f"User {username} successfully created.")

def get_docker_command(challenge):
    image = challenge["image"]
    cmd = challenge.get("cmd", "")
    volumes = challenge.get("volumes", [])
    env = challenge.get("env", [])
    env_file = challenge.get("env_file", [])
    tty = challenge.get("tty", False)
    stdin_open = challenge.get("stdin_open", False)
    workdir = challenge.get("workdir", None)
    mem_limit = challenge.get("mem_limit", None)
    cpus = challenge.get("cpus", None)
    storage_limit = challenge.get("storage_limit", None)

    base = f"docker run --rm"
    if tty:
        base += " -t"

    if stdin_open:
        base += " -i"

    if workdir:
        base += f" -w {workdir}"

    # If the volume is a relative path, we assume it is relative to the host workdir
    for volume in volumes:
        volume = volume.split(":")
        rest = ":".join(volume[1:])

        if any([volume[0].startswith(p) for p in ["./", "../", "~/"]]):
            base += f" -v {os.path.join(HOST_WORKDIR, volume[0])}:{rest}"
        else:
            base += f" -v {volume[0]}:{rest}"

    for e in env:
        base += f" -e {e}"

    for ef in env_file:
        base += f" --env-file {ef}"

    if mem_limit:
        base += f" --memory {mem_limit}"

    if cpus:
        base += f" --cpus {cpus}"

    if storage_limit:
        base += f" --storage-opt size={storage_limit}"

    base += f' --label "TOKEN=$TOKEN"'

    return f"{base} {image} {cmd}"


def generate_ssh_config(config):
    challenges = config["challenges"]
    sshd = config.get("sshd", {})

    os.makedirs(SSH_CONFIG_DIR, exist_ok=True)
    ssh_config = BASE_SSH_CONFIG
    
    if sshd.get("use_pam", False):
        ssh_config += "UsePAM yes\n"
        ssh_config += "PasswordAuthentication no\n"
        ssh_config += "KbdInteractiveAuthentication yes\n"
    else:
        ssh_config += "UsePAM no\n"
        ssh_config += "PasswordAuthentication yes\n"


    for challenge_name, challenge in challenges.items():
        username = challenge_name  # Each challenge becomes an SSH user
        password = challenge.get("password", "")

        create_user(username, password)  # Create the user in the container

        user_config = f"""
Match User {username}
    ForceCommand {get_docker_command(challenge)}
    PermitTTY yes
    X11Forwarding no
    PermitEmptyPasswords {"no" if sshd.get("use_pam", False) else "yes"}
    {"PAMServiceName sshd_docker" if sshd.get("use_pam", False) else ""}
"""
        ssh_config += user_config

    with open(f"{SSH_CONFIG_DIR}/docker_ssh.conf", "w") as f:
        f.write(ssh_config)

def main():
    with open(CONFIG_FILE, "r") as f:
        config = yaml.safe_load(f)

    try:
        if config.get("sshd", {}).get("use_pam", False):
            subprocess.run(["./src/PAM/build.sh"], check=True)

        generate_ssh_config(config)
        print("SSHD configuration and users successfully generated.")

    except subprocess.CalledProcessError as e:
        print(f"Error while generating SSHD configuration: {e}")
        exit(1)

if __name__ == "__main__":
    main()

