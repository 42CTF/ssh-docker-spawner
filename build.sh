#!/bin/bash

function usage {
  echo "Usage: $0 [-f]"
  echo "  -f: Force rebuild without cache"
  echo "  -h: Show this help"
  exit 1
}

while getopts "f:h" opt; do
  case ${opt} in
    f)
      FORCE="--no-cache"
      ;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "Invalid option: $OPTARG" 1>&2
      usage
      exit 1
      ;;
  esac
done


mkdir -p ssh-keys && ssh-keygen -t rsa -b 4096 -f ssh-keys/ssh_host_rsa_key -N "" <<< n

docker build . -t sshds --progress plain $FORCE
