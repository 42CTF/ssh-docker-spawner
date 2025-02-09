#!/bin/sh

set -e

# Check if the SSH_ORIGINAL_COMMAND is set,
# If if it is, we should just deny the request
# man ssh(1):
#   This variable contains the original command line if a forced command is executed.
if [ -n "$SSH_ORIGINAL_COMMAND" ]; then
  command=$(echo $SSH_ORIGINAL_COMMAND | cut -d' ' -f1)
  echo -n "Access denied: "
  echo "You are not allowed to run '$command' on this server."
  exit 1
fi

# Set the working directory to the user's home directory
mkdir -p $HOME/$TOKEN/
cd $HOME/$TOKEN/

ln -sf /app/services.yml $HOME/$TOKEN/compose.yml

cat <<EOF > $HOME/$TOKEN/label.yml
services:
  $USER:
    labels:
      - 'TOKEN=$TOKEN'
EOF

ALREADY_RUNNING=$(docker ps -q -f label=TOKEN=$TOKEN)

if [ -n "$ALREADY_RUNNING" ]; then
  echo "Warning: You already have one or more already running containers."

  prompt="Do you want to stop them and start a new one? [y/N] "
  read -r -p "$prompt" response

  case "$response" in
    [yY][eE][sS]|[yY])
      for CONTAINER in $ALREADY_RUNNING; do
	echo -en "Stopping container $CONTAINER \033[s... (this may take up to 10 seconds)"
        container=$(docker stop $CONTAINER &)
	# restore cursor position, clear the rest of the line and print OK
	echo -e "\033[u\033[KOK"
      done
      ;;
    *)
      echo "Exiting..."
      exit 0
      ;;
  esac
fi

# Use an invalid buildkit progress mode to break the build
# The spawner should never build anything (it could lead to potential leaks)
# The images should be built by the manager
export BUILDKIT_PROGRESS=break

echo "Spawning container for $USER... (This may take some time)"
docker --log-level=warning compose -f compose.yml -f label.yml run --rm $USER 2>/dev/null || echo "It seems like this challenge is actually unavailable. Please try again later."
