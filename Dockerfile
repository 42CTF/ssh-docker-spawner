FROM docker:latest

# Don't forget to build this image specifying the host's docker gid
# --build-arg DOCKER_GID=$(getent group docker | cut -d: -f3)
ARG DOCKER_GID=999

RUN apk add --no-cache openssh-server python3 py3-pip && pip install pyyaml --break-system-packages

RUN mkdir -p /etc/ssh/sshd_config.d

COPY setup.py /setup.py
COPY config.yml /config.yml

# Generate SSH configs and create the associated users for each challenge
RUN python3 /setup.py

# Launch SSHD
CMD ["/usr/sbin/sshd", "-D", "-E", "/dev/pts/0"]

