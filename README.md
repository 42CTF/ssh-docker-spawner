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

### 1. Simply build the docker image:
**Note**: _If you want to force the build without cache, you can use the ``-f`` option._
```bash
./build.sh
```
### 2. Run sshds:
**Note**: _If running in rootless mode, make sure to specify the docker socket
path using the ``-s`` option (e.g. ``./run.sh -s /run/user/<UID>/docker.sock``).<br>
The Host port can be specified using the ``-p`` option, but defaults to ``4242``._
```bash
./run.sh -p 4242
```
### 3. Connect to sshds via SSH:
```bash
ssh user@localhost -p 4242
```
### 4. Enjoy your newly instantiated container !

