#!/bin/sh

set -e

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

#docker --log-level=warning compose -f compose.yml -f label.yml down $USER --remove-orphans
docker --log-level=warning compose -f compose.yml -f label.yml run --rm $USER

