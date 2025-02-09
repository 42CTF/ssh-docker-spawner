import yaml
import signal
import subprocess
import os
import shutil
import time

import supervisor.xmlrpc
import xmlrpc.client

# Remove docker host variable
# Else we can't use docker here
os.environ.pop("DOCKER_HOST")

compose_file = "services.yml"
sshd_config_dir = "/etc/ssh/sshd_config.d"
app_dir = "/app"

rpc = xmlrpc.client.ServerProxy("http://localhost:9001/RPC2")

base_sshd_config = \
f"""
Port 4242
UsePAM yes
PasswordAuthentication no
KbdInteractiveAuthentication yes
PermitEmptyPasswords no

Include {sshd_config_dir}/spawner.d/*.conf
"""

def create_user(username, password=""):
    print(f"Creating user '{username}' with password '{password}'")

    try:
        subprocess.run(
            [f"{app_dir}/scripts/create_user.sh", username, "-p", f"{password}", "-g", "docker"],
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"Error creating user {username}: {e}")

def validate_compose_file():
    try:
        subprocess.run(
            ["docker", "compose", "-f", f"{app_dir}/{compose_file}", "config"],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        return True
    except subprocess.CalledProcessError:
        print(f"Error validating compose file")
        return False


def generate_sshd_config():
    with open(f"{app_dir}/{compose_file}", "r") as f:
        config = yaml.safe_load(f)

    # if sshd_config_dir/spawner.d/ exists, remove it and recreate it
    if os.path.exists(f"{sshd_config_dir}/spawner.d"):
        shutil.rmtree(f"{sshd_config_dir}/spawner.d")

    os.makedirs(f"{sshd_config_dir}/spawner.d")

    services = config["services"]
    for service in services.keys():
        print(service)
        create_user(service)
        user_conf = f"Match User {service}\n"
        user_conf += f"\tForceCommand /app/scripts/spawner_entrypoint.sh {service}\n"
        user_conf += f"\tPermitTTY yes\n"
        user_conf += f"\tPAMServiceName sshd_docker\n"

        with open(f"{sshd_config_dir}/spawner.d/{service}.conf", "w") as f:
            f.write(user_conf)

    with open(f"{sshd_config_dir}/docker_ssh.conf", "w") as f:
        f.write(base_sshd_config)

    return True

def build_PAM():
    print("Building PAM")
    try:
        subprocess.run(
            [f"{app_dir}/PAM/build.sh"],
            check=True
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error building PAM: {e}")
        return False

def build_images():
    # Rebuild containers if needed
    try:
        subprocess.run(["docker", "compose", "-f", f"{app_dir}/{compose_file}", "build"], check=True)
        print("Images successfully build")
        return True
    except subprocess.CalledProcessError:
        print("Error building images")
        return False

def update():
    if not build_PAM() or not validate_compose_file() or not generate_sshd_config():
        return

    build_images()

    try:
        subprocess.run(["pkill", "-SIGHUP", "dockerd"], check=True)
        print("Sent SIGHUP to dockerd")
    except subprocess.CalledProcessError as e:
        print(f"Error sending SIGHUP to dockerd: {e}")

    # check if sshd config is still valid
    try:
        subprocess.run(["/usr/sbin/sshd.pam", "-t"], check=True)
    except subprocess.CalledProcessError:
        print(f"Error validating sshd config. Modification not applied")
        return

    print("sshd config is valid, sending SIGHUP to sshd")
    try:
        subprocess.run(["pkill", "-SIGHUP", "sshd.pam"], check=True)
        print("Sent SIGHUP to sshd")
    except subprocess.CalledProcessError as e:
        print(f"Error sending SIGHUP to sshd: {e}")

def sighup_handler(signum, frame):
    print("Received SIGHUP signal")
    update()

def wait_for_docker(timeout=30):
    print("Waiting for docker daemon")

    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            subprocess.run(["docker", "info"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            print("Docker deamon is ready")
            return True
        except subprocess.CalledProcessError:
            time.sleep(1)

    print("Failed to start docker after 30s")
    return False


signal.signal(signal.SIGHUP, sighup_handler)

def main():
    if not build_PAM() or not validate_compose_file() or not generate_sshd_config():
        exit(1)

    try:
        # run supervisord in the background
        supervisor = subprocess.Popen(
            ["supervisord", "-c", f"{app_dir}/conf/supervisord.conf"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except subprocess.CalledProcessError as e:
        print(f"Error running supervisord: {e}")
        exit(1)

    if not wait_for_docker():
        exit(1)

    build_images()

    while True:
        # Every 5 seconds, ensure that sshd and dockerd are still running
        time.sleep(5)

        try:
            sshd_state = rpc.supervisor.getProcessInfo("sshd")
            if sshd_state["statename"] in ["STOPPED", "EXITED", "FATAL"]:
                print("sshd died. Exiting")
                exit(1)
            dockerd_state = rpc.supervisor.getProcessInfo("dockerd")
            if dockerd_state["statename"] in ["STOPPED", "EXITED", "FATAL"]:
                print("Dockerd died. Exiting")
                exit(1)
        except Exception as e:
            print(f"Error getting process info: {e}")
            exit(1)

if __name__ == "__main__":
    main()
