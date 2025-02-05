#!/bin/sh

usage() {
  echo "Usage: $0 <username> [-p <password>] [-g <group>] [-h]"
  echo "  <username>    The name of the new user"
  echo "  -p <password> The password for the new user"
  echo "  -g <group>    The group to which the new user will belong"
  echo "  -h            Display this help message"
}

USERNAME=$1
shift

while getopts "p:g:h" opt; do
  case ${opt} in
    p)
      PASSWORD=$OPTARG
      ;;
    g)
      GID=$OPTARG
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

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

adduser=$(echo 'adduser -D' $(if [ -n "$GID" ]; then echo "-G $GID"; fi) $USERNAME)
echo $adduser && $adduser

# Set the password, even if it's empty
echo "$USERNAME:$PASSWORD" | chpasswd
