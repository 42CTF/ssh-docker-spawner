#!/bin/bash

# NOTE: If you are using Docker rootless, you may need to
#       change the socket path to the rootless Docker socket.
#       You can use the -s option to specify the socket path.
#       Example: ./run.sh -s /run/user/<UID>/docker.sock

function usage {
  echo "Usage: $0 [Options] [CMD]\n"
  echo "Options:"
  echo "  -a            Attach the container in foreground"
  echo "  -h            Display this help message"
  echo "  -p <port>     Port to bind the SSH server to (default: 4242)\n"
  echo "CMD: Command to run in the container"
}

while getopts "ap:s:h" opt; do
  case $opt in
    a)
      ATTACH=true
      ;;
    p)
      PORT=$OPTARG
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

shift $((OPTIND -1))



PORT=${PORT:-4242}
ATTACH=${ATTACH:false}


docker rm sshds -f

echo "Listening on Host port $PORT"

docker run \
  -v ./ssh-keys/ssh_host_rsa_key:/etc/ssh/ssh_host_rsa_key \
  -v ./:/app \
  -v ./images:/images \
  -p $PORT:4242 \
  --privileged \
  --cgroupns=host \
  --tty \
  $([ "$ATTACH" = true ] && echo "-i" || echo "-d") \
  --name sshds \
  --restart unless-stopped \
  sshds "$@"
