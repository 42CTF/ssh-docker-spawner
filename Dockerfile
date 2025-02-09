FROM docker:dind

WORKDIR /app

RUN apk add --no-cache openssh-server-pam python3 py3-pip && pip install pyyaml --break-system-packages

RUN mkdir -p /etc/ssh/sshd_config.d

COPY . /app

# Disable sftp
RUN sed -i 's/^\s*Subsystem\s*sftp\s*internal-sftp$/#&/' /etc/ssh/sshd_config

CMD ["python3", "/app/src/manager.py"]
