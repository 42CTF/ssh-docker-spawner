#!/bin/bash

# NOTE: If you are using Docker rootless, you may need to
#       change the socket path to the rootless Docker socket.
#       You can use the -s option to specify the socket path.
#       Example: ./run.sh -s /run/user/<UID>/docker.sock

function usage {
  echo "Usage: $0 [-p <port>] [-s <socket>]"
  echo "  -p <port>    Port to bind the SSH server to (default: 4242)"
  echo "  -s <socket>  Path to the Docker socket (default: /var/run/docker.sock)"
  echo "  -h           Display this help message"
}

while getopts "p:s:h" opt; do
  case $opt in
    p)
      PORT=$OPTARG
      ;;
    s)
      SOCKET=$OPTARG
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

PORT=${PORT:-4242}
SOCKET=${SOCKET:-/var/run/docker.sock}

echo "Listening on Host port $PORT"

docker run -it \
  -v $SOCKET:/var/run/docker.sock \
  -v ./ssh-keys/ssh_host_rsa_key:/etc/ssh/ssh_host_rsa_key \
  -p $PORT:4242 \
  sshds
