#!/bin/bash
set -e

echo "Downloading zsh-in-docker"
curl -L -O https://github.com/deluan/zsh-in-docker/releases/download/v1.1.1/zsh-in-docker.sh

echo "Setting permissions on zsh-in-docker.sh"
chmod +x zsh-in-docker.sh

echo "Installing oh-my-zsh..."
./zsh-in-docker.sh \
    -p direnv \
    -p git \
    -p helm \
    -p kubectl \
    -p https://github.com/zsh-users/zsh-autosuggestions \
    -p https://github.com/stocky37/zsh-flux>
echo "oh-my-zsh installed!"
