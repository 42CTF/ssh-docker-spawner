FROM docker:latest

# Don't forget to build this image specifying the host's docker gid
# --build-arg DOCKER_GID=$(getent group docker | cut -d: -f3)
ARG DOCKER_GID=999
ARG USER=user
ARG PASS=

# Add sshd and generate an ssh key to make it happy
RUN apk add openssh-server
RUN ssh-keygen -A

# Create the user
RUN adduser ${USER} -D

# Try to give it access to docker deamon
RUN if getent group ${DOCKER_GID} > /dev/null; then \
    group_name=$(getent group ${DOCKER_GID} | cut -d: -f1) && \
    adduser ${USER} "$group_name"; \
    else \
    addgroup -g ${DOCKER_GID} docker_sock && \
    adduser ${USER} docker_sock; \
    fi

# Set the user password
RUN echo "${USER}:${PASS}" | chpasswd

CMD ["/usr/sbin/sshd","-D"]

