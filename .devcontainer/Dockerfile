FROM homebrew/brew

COPY user-scripts/*.sh /tmp/user-scripts/
RUN /bin/bash /tmp/user-scripts/install-zsh.sh

COPY Brewfile* /tmp/brew/
RUN /bin/bash /tmp/user-scripts/k8s-at-home-setup.sh

ENTRYPOINT [ "/bin/zsh" ]
