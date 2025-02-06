#!/bin/sh

# Exit immediately if a command exits with a non-zero status
set -e

# Create a new group with a GID, or display the group name if the given GID is already in use
usage() {
  echo "Usage: $0 <groupname> <gid> [-h]"
  ecoh "  <groupname>   The name of the new group"
  echo "  <gid>         The GID of the new group"
  echo "  -h            Display this help message"
}

GROUPNAME=$1
GID=$2

while getopts "h" opt; do
  case ${opt} in
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

if [ $# -ne 2 ]; then
  usage
  exit 1
fi

# Check if the GID is already in use
# If it is, display the group name and exit
group=$(getent group $GID | cut -d: -f1)
if [ -n "$group" ]; then
  echo $group
  exit 0
fi

# If the GID is not in use, create the group and display its name 
addgroup -g $GID $GROUPNAME
echo $GROUPNAME
