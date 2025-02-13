# SSH Docker Spawner

A Docker-based SSH server that dynamically spawns containers based on SSH users, providing an isolated environment per session.

## Description

This project sets up an SSH server inside a Docker container that:
- Listens on a configurable port (default: `4242`).
- Automatically creates a Unix user for each service in [app/services.yml](https://github.com/42CTF/ssh-docker-spawner/blob/main/app/services.yml).
- When a user connects via SSH, a corresponding container is started and attached to the SSH session.

## Installation

### 1. Build the Docker image
Use the provided `build.sh` script to build the `sshds` image.
```bash
./build.sh
```

**Options:**
- `-f`: Force rebuild without cache.
- `-h`: Display help message.

### 2. Run the SSH server container
Start the SSH server container using `run.sh`.
```bash
./run.sh
```

**Options:**
- `-a` : Attach to the container in foreground mode.
- `-p <port>` : Specify the SSH server port (default: `4242`).
- `-h` : Display help message.

### 3. Connect to the SSH server
Once the server is running, connect to it using SSH:
```bash
ssh <service_name>@localhost -p <port>
```
Example:
```bash
ssh nginx@localhost -p 4242
```
If the `nginx` service is defined in `services.yml`, this will start a new `nginx` container and attach your SSH session to it.

### 4. Updating Running Services
If you modify the service definitions in `services.yml` or any docker images built locally, you can apply the changes without restarting the SSH server by sending a `SIGHUP` signal to the `sshds` container:
```bash
docker kill -s SIGHUP sshds
```
This will force the SSH server to reload the `services.yml` configuration without breaking active ssh connections.
This action will also attempt to rebuild custom images (declared in the `images/` directory) used by services.

### 5. Stopping the Service
To stop and remove the running SSH server container:

```bash
docker rm sshds -f
```

## Local Images Configuration
Instead of pulling images from Docker Hub, you can define and use custom-built images stored in the `images/` directory.<br>
Local images are built:
- During the initial startup
- When the `sshds` container receives a `SIGHUP` signal

Each image should be placed in a subdirectory inside `images/`, following this structure:
```
images/
 ├── my-custom-image/
 │   ├── Dockerfile
 │   ├── script.sh
 │   └── other-files...
 ├── another-image/
 │   ├── Dockerfile
 │   └── config.json
```
In `app/services.yml`, specify the build path relative to `/images/`:
```yaml
services:
  myservice:
    build: /images/my-custom-image
  another-service:
    build: /images/another-image
```

## Future Improvements
- Support for a more generic authentication module and or additional authentication mechanisms.
- Better logging and monitoring.


