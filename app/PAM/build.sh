#!/bin/sh

set -e

apk add --no-cache build-base linux-pam-dev curl-dev
gcc -Wall -fPIC -shared -o /app/PAM/pam_docker.so /app/PAM/pam.c -lpam -lcurl

echo "Successfully built pam_docker.so"

# Ensure the /usr/lib/security directory exists
mkdir -p /usr/lib/security

ln -sf /app/PAM/pam_docker.so /usr/lib/security/pam_docker.so
echo "Symlink updated (/usr/lib/security/pam_docker.so -> /app/PAM/pam_docker.so)"

ln -sf /app/PAM/sshd_docker /etc/pam.d/sshd_docker
echo "Symlink updated (/etc/pam.d/sshd_docker -> /app/PAM/sshd_docker)"
