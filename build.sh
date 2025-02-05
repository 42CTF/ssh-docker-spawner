#!/bin/bash

function usage {
  echo "Usage: $0 [Options]"
  echo "Options:"
  echo "  -f    Force rebuild without cache"
  echo "  -h    Display this help message"
  exit 1
}

while getopts "fh" opt; do
  case ${opt} in
    f)
      FORCE="--no-cache"
      ;;
    h)
      usage
      exit 0
      ;;
    \?)
      usage
      exit 1
      ;;
  esac
done

mkdir -p ssh-keys && ssh-keygen -t rsa -b 4096 -f ssh-keys/ssh_host_rsa_key -N "" <<< n

docker build . -t sshds --progress plain $FORCE
