#!/bin/bash
set -e

################################################################################
# Create git private auth
################################################################################
GIT_AUTH_FILE=scripts/gitauth/flux-git-auth.sops.yaml
if [ -f "$GIT_AUTH_FILE" ]; then
    echo "$GIT_AUTH_FILE exists."
else 
    echo "$GIT_AUTH_FILE does not exist."
    echo "Generating git credentials..."
    flux create secret git flux-git-auth \
        --url=ssh://git@github.com/ankushg/home-cluster \
        --export > $GIT_AUTH_FILE

    echo "Add as a deploy key:"
    yq eval '.stringData."identity.pub"' $GIT_AUTH_FILE

    echo "Encrypting git credentials with sops..."
    sops --encrypt --in-place $GIT_AUTH_FILE
fi

echo "Applying decrypted secret via kubectl..."
sops --decrypt $GIT_AUTH_FILE | kubectl apply -f -
