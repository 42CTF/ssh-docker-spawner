FROM docker:dind

WORKDIR /app

RUN apk add --no-cache openssh-server-pam python3 py3-pip && pip install pyyaml supervisor --break-system-packages

# packages to build PAM module
RUN apk add --no-cache build-base linux-pam-dev curl-dev

RUN mkdir -p /etc/ssh/sshd_config.d

COPY . /app

# Disable sftp
RUN sed -i 's/^\s*Subsystem\s*sftp\s*internal-sftp$/#&/' /etc/ssh/sshd_config

# Create dockerd log directory
RUN mkdir -p /var/log/dockerd/

CMD ["python", "/app/manager.py"]

