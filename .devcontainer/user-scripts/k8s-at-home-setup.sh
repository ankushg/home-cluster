
# Handled by template
# GnuPG	Encrypts and signs your data
# kubectl	Allows you to run commands against Kubernetes clusters
# helm	Manage Kubernetes applications
# direnv	Exports env vars based on present working directory
# kustomize	Template-free way to customize application configuration (built into kubectl)

set -e

# k3sup	Tool to install k3s on your nodes
curl -sLS https://get.k3sup.dev | sh
sudo install k3sup /usr/local/bin/


# flux	Operator that manages your k8s cluster based on your Git repository
curl -s https://fluxcd.io/install.sh | sudo bash
echo "${fpath// /\n}" | grep -i completion

# pinentry	Allows GnuPG to read passphrases and PIN numbers
# golang    required by SOPS
# python    reqyured by pre-commit
# npm       required by prettier

apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends golang pinentry-curses npm python

# SOPS	Encrypts k8s secrets with GnuPG
echo 'GOPATH=~/go' >> ~/.bashrc \
source ~/.bashrc \
mkdir $GOPATH \

go get -u go.mozilla.org/sops/cmd/sops

# pre-commit	Runs checks pre git commit
pip install pre-commit

# go-task	A task runner / simpler Make alternative written in Go
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin


# prettier	Prettier is an opinionated code formatter.
npm install prettier

# TODO: add to zshrc
echo -e "command -v flux >/dev/null && . <(flux completion zsh) && compdef _flux flux" > ${user_rc_file}
echo -e "eval \"$(direnv hook zsh)\"" > ${user_rc_file}
