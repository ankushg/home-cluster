#!/bin/bash
set -e

echo "Downloading zsh-in-docker"
curl -L -O https://raw.githubusercontent.com/deluan/zsh-in-docker/HEAD/zsh-in-docker.sh

echo "Setting permissions on zsh-in-docker.sh"
chmod +x zsh-in-docker.sh

echo "Installing oh-my-zsh..."
./zsh-in-docker.sh \
    -t robbyrussell \
    -p direnv \
    -p git \
    -p helm \
    -p kubectl \
    -p https://github.com/zsh-users/zsh-autosuggestions \
    -a 'command -v flux >/dev/null && . <(flux completion zsh) && compdef _flux flux'

echo "oh-my-zsh installed!"
