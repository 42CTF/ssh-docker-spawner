FROM docker:latest

# Don't forget to build this image specifying the host's docker gid
# --build-arg DOCKER_GID=$(getent group docker | cut -d: -f3)
ARG DOCKER_GID=999

# The host's workdir is needed if you wanna be able to bind mount the host's files
ARG HOST_WORKDIR=/tmp

WORKDIR /app

RUN apk add --no-cache openssh-server python3 py3-pip && pip install pyyaml --break-system-packages

RUN mkdir -p /etc/ssh/sshd_config.d

COPY . /app

# Generate SSH configs and create the associated users for each challenge
RUN python3 ./scripts/setup.py

# Launch SSHD
CMD ["/usr/sbin/sshd", "-D", "-E", "/dev/pts/0"]

