import yaml
import os
import subprocess
import re

CONFIG_FILE = "/config.yml"
SSH_CONFIG_DIR = "/etc/ssh/sshd_config.d"
BASE_SSH_CONFIG = """Port 4242
PermitUserEnvironment yes
"""

DOCKER_GID = os.getenv("DOCKER_GID", "999")
HOST_WORKDIR = os.getenv("HOST_WORKDIR", "/tmp")

def create_user(username, password=""):
    """Create a user in the container with a password"""
    try:
        # If a group with GID 999 does not exist, create it with the name "docker_socket"
        # and add the user to this group.
        # Otherwise, add the user to the existing group.

        group_name = subprocess.run(["getent", "group", DOCKER_GID], stdout=subprocess.PIPE).stdout.decode().strip()

        if not group_name:
            subprocess.run(["addgroup", "-g", DOCKER_GID, "docker_socket"], check=True)
            group_name = "docker_socket"
        else:
            group_name = re.match(r"^(.*?):.*?:.*?$", group_name).group(1)

        subprocess.run(["adduser", "-D", "-G", group_name, username], check=True)

        chpasswd = f"{username}:{password}"
        subprocess.run(["chpasswd"], input=chpasswd.encode(), check=True)

        print(f"User {username} successfully created.")
    except subprocess.CalledProcessError as e:
        print(f"Error while creating user {username}: {e}")
        exit(1)

def get_docker_command(challenge):
    image = challenge["image"]
    cmd = challenge.get("cmd", "")
    volumes = challenge.get("volumes", [])
    env = challenge.get("env", [])
    env_file = challenge.get("env_file", [])
    tty = challenge.get("tty", False)
    stdin_open = challenge.get("stdin_open", False)
    workdir = challenge.get("workdir", None)

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

    return f"{base} {image} {cmd}"


def generate_ssh_config(challenges):
    os.makedirs(SSH_CONFIG_DIR, exist_ok=True)
    ssh_config = BASE_SSH_CONFIG

    for challenge_name, challenge in challenges.items():
        username = challenge_name  # Each challenge becomes an SSH user
        password = challenge.get("password", "")

        create_user(username, password)  # Create the user in the container

        user_config = f"""
Match User {username}
    PermitEmptyPasswords yes
    PasswordAuthentication yes
    ForceCommand {get_docker_command(challenge)}
    PermitTTY yes
    X11Forwarding no
"""
        ssh_config += user_config

    with open(f"{SSH_CONFIG_DIR}/docker_ssh.conf", "w") as f:
        f.write(ssh_config)

def main():
    with open(CONFIG_FILE, "r") as f:
        config = yaml.safe_load(f)

    generate_ssh_config(config["challenges"])
    print("SSHD configuration and users successfully generated.")

if __name__ == "__main__":
    main()

