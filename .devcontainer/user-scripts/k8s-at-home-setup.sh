#!/bin/bash
set -e

echo "Installing k8s-at-home support packages from brew..."
brew analytics off
brew update
brew bundle install --file=/tmp/brew/Brewfile --no-upgrade --cleanup --verbose
echo "Packages installed from brew!"
