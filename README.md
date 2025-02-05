# SSH Docker Spawner

A Docker container that provides SSH access and automatically spawns containers for each connected users.

## Description

This project creates a Docker container running an SSH server that:
- Listens on port 4242
- Automatically spawns a container when users connect
- Provides a secure and isolated environment for each SSH connection

## Prerequisites

- Docker installed on the host machine
- Docker socket accessible

## Usage

1. Build the docker image:
```bash
# You can also specify the USER and PASS args
docker build . \
  -t sshds \
  --build-arg DOCKER_GID=$(getent group docker | cut -d: -f3)
```
2. Run sshds:
```bash
# Note: If running in rootless mode, make sure to bind the correct Docker socket:  
# Instead of `/var/run/docker.sock`, use `/run/user/<uid>/docker.sock`,  
# where `<uid>` is the user ID of the rootless Docker instance.  
docker run -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ./4242-docker.conf:/etc/ssh/sshd_config.d/4242-docker.conf \
  -p 4242:4242 \
  sshds
```
3. Connect to sshds via SSH:
```bash
ssh user@localhost -p 4242
```
4. Enjoy your newly instantiated container !

