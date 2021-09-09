# Note: You can use any Debian/Ubuntu based image you want. 
FROM mcr.microsoft.com/vscode/devcontainers/base:debian

# Options
ARG INSTALL_ZSH="true"
ARG UPGRADE_PACKAGES="false"
ARG USE_MOBY="true"
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
# Install needed packages and setup non-root user. Use a separate RUN statement to add your own dependencies.
COPY library-scripts/*.sh /tmp/library-scripts/
RUN apt-get update && /bin/bash /tmp/library-scripts/common-debian.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" "true" "true" \
    && /bin/bash /tmp/library-scripts/docker-in-docker-debian.sh "true" "${USERNAME}" "${USE_MOBY}" \ 
    && /bin/bash /tmp/library-scripts/kubectl-helm-debian.sh "latest" "latest" "latest" \
    && mkdir -p /home/${USERNAME}/.minikube \
    && chown ${USERNAME} /home/${USERNAME}/.minikube \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

VOLUME [ "/var/lib/docker" ]

# Setting the ENTRYPOINT to docker-init.sh will start up the Docker Engine 
# inside the container "overrideCommand": false is set in devcontainer.json. 
# The script will also execute CMD if you need to alter startup behaviors.
ENTRYPOINT [ "/usr/local/share/docker-init.sh" ]
CMD [ "sleep", "infinity" ]


# Custom Setup

# Handled by template
# GnuPG	Encrypts and signs your data
# kubectl	Allows you to run commands against Kubernetes clusters
# helm	Manage Kubernetes applications
# direnv	Exports env vars based on present working directory
# kustomize	Template-free way to customize application configuration (built into kubectl)

# k3sup	Tool to install k3s on your nodes
RUN curl -sLS https://get.k3sup.dev | sh
RUN sudo install k3sup /usr/local/bin/


# flux	Operator that manages your k8s cluster based on your Git repository
RUN curl -s https://fluxcd.io/install.sh | sudo bash \
    && echo "${fpath// /\n}" | grep -i completion

# pinentry	Allows GnuPG to read passphrases and PIN numbers
# golang    required by SOPS
# python    reqyured by pre-commit
# npm       required by prettier

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends golang pinentry-curses npm python

# SOPS	Encrypts k8s secrets with GnuPG
RUN echo 'GOPATH=~/go' >> ~/.bashrc \
    && source ~/.bashrc \
    && mkdir $GOPATH \
    && go get -u go.mozilla.org/sops/cmd/sops

# pre-commit	Runs checks pre git commit
RUN pip install pre-commit


# go-task	A task runner / simpler Make alternative written in Go
RUN sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin


# prettier	Prettier is an opinionated code formatter.
RUN npm install prettier

# TODO: add to zshrc
RUN echo -e "command -v flux >/dev/null && . <(flux completion zsh) && compdef _flux flux" > ${user_rc_file}
RUN echo -e "eval \"$(direnv hook zsh)\"" > > ${user_rc_file}
