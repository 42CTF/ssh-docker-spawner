#!/bin/sh

# Exit immediately if a command exits with a non-zero status
set -e

usage() {
  echo "Usage: $0 <service_name> [-P] [-l <limit per user>]"
  echo "  <service_name>        The name of the service to spawn"
  echo "  -P                    Specify if the PAM module is used for the current service"
  echo "  -l <limit per user>   Set the number of container per user"
}

PAM_AUTH=false
LIMIT=0

SERVICE_NAME=$1
shift

while getopts "Pl:" opt; do
  case ${opt} in
    P)
      PAM_AUTH=true
      ;;
    l)
      LIMIT=$OPTARG
      ;;
    \?)
      usage
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ -z "$SERVICE_NAME" ]; then
  exit 1
fi

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

# if PAM module is used
if [ "$PAM_AUTH" = true ]; then

  # Delete every non-alnum char
  TOKEN=$(echo "$TOKEN" | tr -cds '[:alnum:]')

  if [[ -z "${TOKEN// }" ]]; then
    echo "ERROR: Invalid token"
    exit 1
  fi

  # Set the working directory to the user's home directory
  mkdir -p "$HOME/$TOKEN/"
  cd "$HOME/$TOKEN/"

  ln -sf /app/services.yml "$HOME/$TOKEN/compose.yml"

  cat <<EOF > $HOME/$TOKEN/label.yml
services:
  $USER:
    labels:
      - 'TOKEN=$TOKEN'
EOF

  DOCKER_ARGS_EXT='-f label.yml'

  ALREADY_RUNNING=$(docker ps -q -f label=TOKEN="$TOKEN")

  # Compter les conteneurs déjà en cours d'exécution avec le label TOKEN
  ALREADY_RUNNING=$(docker ps -q -f label=TOKEN="$TOKEN")
  RUNNING_COUNT=$(echo "$ALREADY_RUNNING" | wc -l)

  if [ "$LIMIT" -gt 0 ] && [ "$RUNNING_COUNT" -ge "$LIMIT" ]; then
    echo "You have reached the limit of $LIMIT running container(s)."
    echo "You can stop one of your running container to start a new one."

    list=$(docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}" -f label=TOKEN="$TOKEN")
    echo "$list"

    # remove head, and get the first column
    my_containers=$(echo "$list" | awk 'NR>1 {print $1, $NF}')

    prompt="Enter the ID or name of the container to stop: "
    read -r -p "$prompt" CONTAINER_TO_STOP

    if echo "$my_containers" | grep -qw "$CONTAINER_TO_STOP"; then
        docker stop "$CONTAINER_TO_STOP"
    else
      echo "Error: No such object: '$CONTAINER_TO_STOP'"
      exit 1
    fi
  fi
else
    mkdir -p "$HOME/$SERVICE_NAME/"
    cd "$HOME/$SERVICE_NAME/"

    ln -sf /app/services.yml "$HOME/$SERVICE_NAME/compose.yml"
fi

# Use an invalid buildkit progress mode to break the build
# The spawner should never build anything (it could lead to potential leaks)
# The images should be built by the manager
export BUILDKIT_PROGRESS=break

set +e
echo "Spawning container for $USER... (This may take some time)"
temp=$(mktemp)
docker --log-level=warning compose -f compose.yml $DOCKER_ARGS_EXT run --rm $USER 2>$temp
status=$?
set -e

if grep -q "invalid progress mode break" $temp; then
  echo "This container is currently unavailable."
  echo "Please try again later."
  status=1
fi

rm -f $temp

exit $status
