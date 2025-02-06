#!/bin/sh

set -e

apk add --no-cache build-base linux-pam-dev curl-dev
gcc -Wall -fPIC -shared -o /app/src/PAM/pam_docker.so /app/src/PAM/pam.c -lpam -lcurl

echo "Successfully built pam_docker.so"

# Ensure the /usr/lib/security directory exists
mkdir -p /usr/lib/security

ln -sf /app/src/PAM/pam_docker.so /usr/lib/security/pam_docker.so
echo "Symlink updated (/usr/lib/security/pam_docker.so -> /app/src/PAM/pam_docker.so)"

ln -sf /app/src/PAM/sshd_docker /etc/pam.d/sshd_docker
echo "Symlink updated (/etc/pam.d/sshd_docker -> /app/src/PAM/sshd_docker)"
