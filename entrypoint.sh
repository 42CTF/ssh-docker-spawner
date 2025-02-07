#!/bin/sh

dockerd > /var/log/dockerd.log 2>&1 &

/usr/sbin/sshd.pam -DE /dev/pts/0
