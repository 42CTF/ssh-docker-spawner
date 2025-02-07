import yaml
import signal
import subprocess
import os
import shutil
import time

compose_file = "services.yml"
sshd_config_dir = "/etc/ssh/sshd_config.d"

dockerd_logs = open("/var/log/dockerd.log", "w")

process_config = {
    "sshd": {
        "args": ["/usr/sbin/sshd.pam", "-DE", "/dev/pts/0"],
        "stdout": subprocess.PIPE,
        "stderr": subprocess.PIPE,
    },
    "dockerd": {
        "args": ["dockerd"],
        "stdout": dockerd_logs,
        "stderr": dockerd_logs,
    }
}

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
            ["./src/create_user.sh", username, "-p", f"{password}", "-g", "docker"],
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"Error creating user {username}: {e}")

def validate_compose_file():
    try:
        subprocess.run(
            ["docker-compose", "-f", compose_file, "config"],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error validating compose file: {e}")
        return False


def generate_sshd_config():
    with open(compose_file, "r") as f:
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
        user_conf += f"\tForceCommand /app/src/spawner_entrypoint.sh {service}\n"
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
            ["./src/PAM/build.sh"],
            check=True
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error building PAM: {e}")
        return False

if not build_PAM() or not generate_sshd_config():
    exit(1)

processes = {
    f: subprocess.Popen(
        p["args"],
        stdout=p["stdout"],
        stderr=p["stderr"]
    ) for f, p in process_config.items()
}

def sighup_handler(signum, frame):
    print("Received SIGHUP signal")
    if not build_PAM() or not validate_compose_file() or not generate_sshd_config():
        return
    processes['sshd'].send_signal(signal.SIGHUP)

def stop_all_processes(signum, frame):
    print(f"Received {signum} signal")
    for name, process in processes.items():
        print(f"Terminating {name}")
        process.terminate()  # Envoie SIGTERM aux processus enfants
    time.sleep(1)  # Donne un peu de temps aux processus pour s'arrêter
    for name, process in processes.items():
        if process.poll() is None:  # Si toujours actif, forcer l'arrêt
            print(f"Killing {name}")
            process.kill()
    exit(0)

signal.signal(signal.SIGHUP, sighup_handler)
signal.signal(signal.SIGTERM, stop_all_processes)
signal.signal(signal.SIGINT, stop_all_processes)
signal.signal(signal.SIGQUIT, stop_all_processes)
signal.signal(signal.SIGTSTP, stop_all_processes)

while True:
    time.sleep(1)
    
    # Check if the processes are still running
    # If not, try to restart them
    for name, process in processes.items():
        if process.poll() is not None:
            print(f"Process {name} exited with code {process.returncode}")
            print(f"Restarting {name}")
            processes[name] = subprocess.Popen(
                process_config[name]["args"],
                stdout=process_config[name]["stdout"],
                stderr=process_config[name]["stderr"]
            )


