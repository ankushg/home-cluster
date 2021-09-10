#!/bin/bash
set -e

echo "Setting up dev tools from repo..."
direnv allow
pre-commit install-hooks
