#!/bin/sh

# Exit immediately if a command exits with a non-zero status
set -e

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
      GROUP=$OPTARG
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

GID=$(getent group $GROUP | cut -d: -f3)

# Check if the user already exists
if id -u $USERNAME > /dev/null 2>&1; then
  echo "User $USERNAME already exists"
  if [ -n "$GID" ]; then
    if [ $(id -g $USERNAME) -ne $GID ]; then
      echo "User $USERNAME is not in group $GID"
      exit 1
    fi
  fi
  exit 0
fi

adduser=$(echo 'adduser -D' $(if [ -n "$GID" ]; then echo "-G $GROUP"; fi) $USERNAME)
echo $adduser && $adduser

# Set the password, even if it's empty
echo "$USERNAME:$PASSWORD" | chpasswd

echo "User $USERNAME successfully created"
