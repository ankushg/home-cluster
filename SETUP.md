# Template for deploying k3s backed by Flux

Highly opinionated template for deploying a single [k3s](https://k3s.io/) cluster with [k3sup](https://github.com/alexellis/k3sup) backed by [Flux](https://toolkit.fluxcd.io/) and [SOPS](https://toolkit.fluxcd.io/guides/mozilla-sops/).

The purpose here is to showcase how you can deploy an entire Kubernetes cluster and show it off to the world using the [GitOps](https://www.weave.works/blog/what-is-gitops-really) tool [Flux](https://toolkit.fluxcd.io/). When completed, your Git repository will be driving the state of your Kubernetes cluster. In addition with the help of the [Flux SOPS integration](https://toolkit.fluxcd.io/guides/mozilla-sops/) you'll be able to commit GPG encrypted secrets to your public repo.

## Overview

- [Introduction](#-introduction)
- [Prerequisites](#-prerequisites)
- [Repository structure](#-repository-structure)
- [Lets go!](#-lets-go)
- [Post installation](#-post-installation)
- [Thanks](#-thanks)

## 👋 Introduction

The following components will be installed in your [k3s](https://k3s.io/) cluster by default. They are only included to get a minimum viable cluster up and running. You are free to add / remove components to your liking but anything outside the scope of the below components are not supported by this template.

Feel free to read up on any of these technologies before you get started to be more familiar with them.

- [flannel](https://github.com/flannel-io/flannel) - default CNI provided by k3s
- [local-path-provisioner](https://github.com/rancher/local-path-provisioner) - default storage class provided by k3s
- [flux](https://toolkit.fluxcd.io/) - GitOps tool for deploying manifests from the `cluster` directory
- [metallb](https://metallb.universe.tf/) - bare metal load balancer
- [cert-manager](https://cert-manager.io/) - SSL certificates - with Cloudflare DNS challenge
- [ingress-nginx](https://kubernetes.github.io/ingress-nginx/) - Kubernetes ingress controller used for a HTTP reverse proxy of Kubernetes ingresses
- [hajimari](https://github.com/toboshii/hajimari) - start page with ingress discovery
- [system-upgrade-controller](https://github.com/rancher/system-upgrade-controller) - upgrade k3s
- [reloader](https://github.com/stakater/Reloader) - restart pod when configmap or secret changes

## 📝 Prerequisites

### 💻 Nodes

Already provisioned Bare metal or VMs with any modern operating system like Ubuntu, Debian or CentOS.

If coming from a fresh install of Linux make sure you do the following steps.

- Enable SSH logins via certificates for all of the hosts

- Enable packet forwarding on the hosts and increase max_user_watches

```sh
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward=1
fs.inotify.max_user_watches=65536
EOF
sysctl --system
```

- Configure DNS on your nodes to use an upstream provider (e.g. `1.1.1.1`, `9.9.9.9`), or your router's IP if you have DNS configured there and it's not pointing to a local Ad-blocker DNS. Ad-blockers should only be used on devices with a web browser.

- Set a static IP on the nodes OS itself and **NOT** by using DHCP. Using DHCP to assign IPs injects a search domain into your nodes `/etc/resolv.conf` and this could potentially break DNS in containers.

- Disable swap

### 🔧 Tools

📍 You should install the below CLI tools on your workstation. Make sure you pull in the latest versions.

| Tool                                                               | Purpose                                                             |
| ------------------------------------------------------------------ | ------------------------------------------------------------------- |
| [k3sup](https://github.com/alexellis/k3sup)                        | Tool to install k3s on your nodes                                   |
| [kubectl](https://kubernetes.io/docs/tasks/tools/)                 | Allows you to run commands against Kubernetes clusters              |
| [flux](https://toolkit.fluxcd.io/)                                 | Operator that manages your k8s cluster based on your Git repository |
| [SOPS](https://github.com/mozilla/sops)                            | Encrypts k8s secrets with GnuPG                                     |
| [GnuPG](https://gnupg.org/)                                        | Encrypts and signs your data                                        |
| [pinentry](https://gnupg.org/related_software/pinentry/index.html) | Allows GnuPG to read passphrases and PIN numbers                    |
| [direnv](https://github.com/direnv/direnv)                         | Exports env vars based on present working directory                 |
| [pre-commit](https://github.com/pre-commit/pre-commit)             | Runs checks pre `git commit`                                        |
| [kustomize](https://kustomize.io/)                                 | Template-free way to customize application configuration            |
| [helm](https://helm.sh/)                                           | Manage Kubernetes applications                                      |
| [go-task](https://github.com/go-task/task)                         | A task runner / simpler Make alternative written in Go              |
| [prettier](https://github.com/prettier/prettier)                   | Prettier is an opinionated code formatter.                          |

### ⚠️ pre-commit

It is advisable to install [pre-commit](https://pre-commit.com/) and the pre-commit hooks that come with this repository.
[sops-pre-commit](https://github.com/k8s-at-home/sops-pre-commit) will check to make sure you are not by accident commiting non-encrypted Kubernetes secrets to your repostory.

After pre-commit is installed on your machine run:

```sh
pre-commit install --install-hooks
```

## 📂 Repository structure

The Git repository contains the following directories under `cluster` and are ordered below by how Flux will apply them.

```sh
📁 cluster      # k8s cluster defined as code
├─📁 flux       # flux, gitops operator, loaded before everything
├─📁 crds       # custom resources, loaded before 📁 core and 📁 apps
├─📁 charts     # helm repos, loaded before 📁 core and 📁 apps
├─📁 config     # cluster config, loaded before 📁 core and 📁 apps
├─📁 core       # crucial apps, namespaced dir tree, loaded before 📁 apps
└─📁 apps       # regular apps, namespaced dir tree, loaded last
```

## 🚀 Lets go

Very first step will be to create a new repository by clicking the **Use this template** button on this page.

📍 In these instructions you will be exporting several environment variables to your current shell env. Make sure you stay with in your current shell to not lose any exported variables.

📍 **All of the below commands** are run on your **local** workstation, **not** on any of your cluster nodes.

### 🔐 Setting up GnuPG keys

📍 Here we will create a personal and a Flux GPG key. Using SOPS with GnuPG allows us to encrypt and decrypt secrets.

1. Create a Personal GPG Key, password protected, and export the fingerprint. It's **strongly encouraged** to back up this key somewhere safe so you don't lose it.

   ```sh
   export GPG_TTY=$(tty)
   export BOOTSTRAP_PERSONAL_KEY_NAME="First name Last name (location) <email>"

   gpg --batch --full-generate-key <<EOF
   Key-Type: 1
   Key-Length: 4096
   Subkey-Type: 1
   Subkey-Length: 4096
   Expire-Date: 0
   Name-Real: ${BOOTSTRAP_PERSONAL_KEY_NAME}
   EOF

   gpg --list-secret-keys "${BOOTSTRAP_PERSONAL_KEY_NAME}"
   # pub   rsa4096 2021-03-11 [SC]
   #       772154FFF783DE317KLCA0EC77149AC618D75581
   # uid           [ultimate] k8s@home (Macbook) <k8s-at-home@gmail.com>
   # sub   rsa4096 2021-03-11 [E]

   # Add to .config.env:
   # export BOOTSTRAP_PERSONAL_KEY_FP=772154FFF783DE317KLCA0EC77149AC618D75581
   ```

2. Create a Flux GPG Key and export the fingerprint

   ```sh
   export GPG_TTY=$(tty)
   export BOOTSTRAP_FLUX_KEY_NAME="Cluster name (Flux) <email>"

   gpg --batch --full-generate-key <<EOF
   %no-protection
   Key-Type: 1
   Key-Length: 4096
   Subkey-Type: 1
   Subkey-Length: 4096
   Expire-Date: 0
   Name-Real: ${FLUX_KEY_NAME}
   EOF

   gpg --list-secret-keys "${BOOTSTRAP_FLUX_KEY_NAME}"
   # pub   rsa4096 2021-03-11 [SC]
   #       AB675CE4CC64251G3S9AE1DAA88ARRTY2C009E2D
   # uid           [ultimate] Home cluster (Flux) <k8s-at-home@gmail.com>
   # sub   rsa4096 2021-03-11 [E]

   # Add to .config.env:
   # export BOOTSTRAP_FLUX_KEY_FP=AB675CE4CC64251G3S9AE1DAA88ARRTY2C009E2D
   ```

3. You will need the Fingerprints in the configuration section below. For example, in the above steps you will need `772154FFF783DE317KLCA0EC77149AC618D75581` and `AB675CE4CC64251G3S9AE1DAA88ARRTY2C009E2D`

### ☁️ Cloudflare API Token

...Be aware you **will not** have a valid SSL cert until `cert-manager` is configured correctly

In order to use `cert-manager` with the Cloudflare DNS challenge you will need to create a API token.

1. Head over to Cloudflare and create a API token by going [here](https://dash.cloudflare.com/profile/api-tokens).
2. Click the blue `Create Token` button
3. Scroll down and create a Custom Token by choosing `Get started`
4. Give your token a name like `cert-manager`
5. Under `Permissions` give **read** access to `Zone` : `Zone` and **write** access to `Zone` : `DNS`
6. Under `Zone Resources` set it to `Include` : `All Zones`
7. Click `Continue to summary` and then `Create Token`
8. Export this token and your Cloudflare email address to an environment variable on your system to be used in the following steps

```sh
# For .config.env:
# export BOOTSTRAP_CLOUDFLARE_DOMAIN="k8s-at-home.com"
# export BOOTSTRAP_CLOUDFLARE_EMAIL="k8s-at-home@gmail.com"
# export BOOTSTRAP_CLOUDFLARE_TOKEN="kpG6iyg3FS_du_8KRShdFuwfbwu3zMltbvmJV6cD"
```

### 📄 Configuration

📍 The `.config.env` file contains necessary configuration files that are needed to set thing up.

1. Copy the `.config.sample.env` to `.config.env` and start filling out all the environment variables based on the steps above.

2. You will need to export more environment variables for application configuration **All are required** and read the comments they will explain further what is required.

3. Once that is done, verify the configuration is correct by running `./configure.sh --verify`

4. If you do not encounter any errors run `./configure.sh` to start having the script wire up the templated files and place them where they need to be.

   📍 Variables defined in `cluster-secrets.sops.yaml` and `cluster-settings.sops.yaml` will be usable anywhere in your YAML manifests under `./cluster`

5. **Verify** all the above files have the correct information present, and no secrets are committed to your repo.

6. If you verified all the secrets are encrypted, you can delete the `tmpl` directory now

7. Push your changes to git

   ```sh
   git add -A
   git commit -m "initial commit"
   git push
   ```

### ⛵ Installing k3s with k3sup

📍 Here we will be install [k3s](https://k3s.io/) with [k3sup](https://github.com/alexellis/k3sup). After completion, k3sup will drop a `kubeconfig` in your present working directory for use with interacting with your cluster with `kubectl`.

1. Ensure you are able to SSH into you nodes with using your private ssh key. This is how k3sup is able to connect to your remote node.

2. Install the master node(s)

   _We will be installing metallb instead of servicelb, ingress and metrics-server will be installed with Flux._

   ```sh
   # renovate: datasource=github-releases depName=k3s-io/k3s
   K3S_VERSION="v1.24.3+k3s1"

   k3sup install \
       --host=169.254.1.1 \
       --user=k8s-at-home \
       --k3s-extra-args="--disable servicelb --disable traefik --disable metrics-server --kubelet-arg='feature-gates=MixedProtocolLBService=true,GracefulNodeShutdown=true'" \
       --k3s-version=$K3S_VERSION
   ```

3. Join worker nodes (optional)

   ```sh
   k3sup join \
       --host=169.254.1.2 \
       --server-host=169.254.1.1 \
       --user=k8s-at-home \
       --k3s-extra-args="--kubelet-arg='feature-gates=MixedProtocolLBService=true,GracefulNodeShutdown=true'" \
      --k3s-version=$K3S_VERSION
   ```

4. Verify the nodes are online

   ```sh
   task cluster:nodes
   # NAME           STATUS   ROLES                       AGE     VERSION
   # k8s-master-a   Ready    control-plane,master      4d20h   vv1.23.3+k3s1
   # k8s-worker-a   Ready    worker                    4d20h   vv1.23.3+k3s1
   ```

### 🔹 GitOps with Flux

📍 Here we will be installing [flux](https://toolkit.fluxcd.io/) after some quick bootstrap steps.

1. Verify Flux can be installed

   ```sh
   task cluster:verify
   # ► checking prerequisites
   # ✔ kubectl v1.23.3 >=1.18.0-0
   # ✔ Kubernetes v1.23.3+k3s1 >=1.16.0-0
   # ✔ prerequisites checks passed
   ```

2. Install Flux and sync the cluster to the Git repository

   📍 Due to race conditions with the Flux CRDs you might have to run the below command twice. There should be no errors on this second run.

   ```sh
   task cluster:install
   # namespace/flux-system configured
   # customresourcedefinition.apiextensions.k8s.io/alerts.notification.toolkit.fluxcd.io created
   # ...
   # unable to recognize "./cluster/base/flux-system": no matches for kind "Kustomization" in version "kustomize.toolkit.fluxcd.io/v1beta1"
   # unable to recognize "./cluster/base/flux-system": no matches for kind "GitRepository" in version "source.toolkit.fluxcd.io/v1beta1"
   # unable to recognize "./cluster/base/flux-system": no matches for kind "HelmRepository" in version "source.toolkit.fluxcd.io/v1beta1"
   # unable to recognize "./cluster/base/flux-system": no matches for kind "HelmRepository" in version "source.toolkit.fluxcd.io/v1beta1"
   # unable to recognize "./cluster/base/flux-system": no matches for kind "HelmRepository" in version "source.toolkit.fluxcd.io/v1beta1"
   # unable to recognize "./cluster/base/flux-system": no matches for kind "HelmRepository" in version "source.toolkit.fluxcd.io/v1beta1"
   ```

3. Verify Flux components are running in the cluster

   ```sh
   task cluster:pods -- -n flux-system
   # NAME                                       READY   STATUS    RESTARTS   AGE
   # helm-controller-5bbd94c75-89sb4            1/1     Running   0          1h
   # kustomize-controller-7b67b6b77d-nqc67      1/1     Running   0          1h
   # notification-controller-7c46575844-k4bvr   1/1     Running   0          1h
   # source-controller-7d6875bcb4-zqw9f         1/1     Running   0          1h
   ```

🎉 **Congratulations** you have a Kubernetes cluster managed by Flux, your Git repository is driving the state of your cluster.

## 📣 Post installation

### Verify ingress

If your cluster is not accessible to outside world you can update your hosts file to verify the ingress controller is working.

This will only be temporary and you should set up DNS to handle these records either manually or automated with [external-dns](https://github.com/kubernetes-sigs/external-dns).

```sh
echo "${BOOTSTRAP_SVC_INGRESS_ADDR} ${BOOTSTRAP_CLOUDFLARE_DOMAIN} hajimari.${BOOTSTRAP_CLOUDFLARE_DOMAIN}" | sudo tee -a /etc/hosts
```

Head over to your browser and you _should_ be able to access `https://hajimari.${BOOTSTRAP_CLOUDFLARE_DOMAIN}`

### direnv

This is a great tool to export environment variables depending on what your present working directory is, head over to their [installation guide](https://direnv.net/docs/installation.html) and don't forget to hook it into your shell!

When this is done you no longer have to use `--kubeconfig=./kubeconfig` in your `kubectl`, `flux` or `helm` commands.

### VSCode SOPS extension

[VSCode SOPS](https://marketplace.visualstudio.com/items?itemName=signageos.signageos-vscode-sops) is a neat little plugin for those using VSCode.
It will automatically decrypt you SOPS secrets when you click on the file in the editor and encrypt them when you save and exit the file.

### 👉 Debugging

Manually sync Flux with your Git repository

```sh
flux --kubeconfig=./kubeconfig reconcile source git flux-system
# ► annotating GitRepository flux-system in flux-system namespace
# ✔ GitRepository annotated
# ◎ waiting for GitRepository reconciliation
# ✔ GitRepository reconciliation completed
# ✔ fetched revision main/943e4126e74b273ff603aedab89beb7e36be4998
```

Show the health of you kustomizations

```sh
kubectl --kubeconfig=./kubeconfig get kustomization -A
# NAMESPACE     NAME          READY   STATUS                                                             AGE
# flux-system   apps          True    Applied revision: main/943e4126e74b273ff603aedab89beb7e36be4998    3d19h
# flux-system   core          True    Applied revision: main/943e4126e74b273ff603aedab89beb7e36be4998    4d6h
# flux-system   crds          True    Applied revision: main/943e4126e74b273ff603aedab89beb7e36be4998    4d6h
# flux-system   flux-system   True    Applied revision: main/943e4126e74b273ff603aedab89beb7e36be4998    4d6h
```

Show the health of your main Flux `GitRepository`

```sh
flux --kubeconfig=./kubeconfig get sources git
# NAME           READY    MESSAGE                                                            REVISION                                         SUSPENDED
# flux-system    True     Fetched revision: main/943e4126e74b273ff603aedab89beb7e36be4998    main/943e4126e74b273ff603aedab89beb7e36be4998    False
```

Show the health of your `HelmRelease`s

```sh
flux --kubeconfig=./kubeconfig get helmrelease -A
# NAMESPACE           NAME                      READY    MESSAGE                             REVISION    SUSPENDED
# cert-manager        cert-manager              True     Release reconciliation succeeded    v1.5.2      False
# default            hajimari                True     Release reconciliation succeeded    1.1.1       False
# networking          ingress-nginx           True     Release reconciliation succeeded    3.30.0      False
```

Show the health of your `HelmRepository`s

```sh
flux --kubeconfig=./kubeconfig get sources helm -A
# NAMESPACE      NAME                 READY    MESSAGE                                                       REVISION                                    SUSPENDED
# flux-system    bitnami       True     Fetched revision: 0ec3a3335ff991c45735866feb1c0830c4ed85cf    0ec3a3335ff991c45735866feb1c0830c4ed85cf    False
# flux-system    hajimari      True     Fetched revision: 1b24af9c5a1e3da91618d597f58f46a57c70dc13    1b24af9c5a1e3da91618d597f58f46a57c70dc13    False
# flux-system    ingress-nginx True     Fetched revision: 45669a3117fc93acc09a00e9fb9b4445e8990722    45669a3117fc93acc09a00e9fb9b4445e8990722    False
# flux-system    jetstack      True     Fetched revision: 7bad937cc82a012c9ee7d7a472d7bd66b48dc471    7bad937cc82a012c9ee7d7a472d7bd66b48dc471    False
# flux-system    k8s-at-home   True     Fetched revision: 1b24af9c5a1e3da91618d597f58f46a57c70dc13    1b24af9c5a1e3da91618d597f58f46a57c70dc13    False
```

Flux has a wide range of CLI options available be sure to run `flux --help` to view more!

### 🤖 Automation

- [Renovate](https://www.mend.io/free-developer-tools/renovate) is a very useful tool that when configured will start to create PRs in your Github repository when Docker images, Helm charts or anything else that can be tracked has a newer version. The configuration for renovate is located [here](./.github/renovate.json5).

- [system-upgrade-controller](https://github.com/rancher/system-upgrade-controller) will watch for new k3s releases and upgrade your nodes when new releases are found.

## ❔ What's next

The world is your cluster, first thing you might want to do is to have storage backed by something other than local disk. If you have some sort of NAS and want storage back by that check out the helm charts for [nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner), [democratic-csi](https://github.com/democratic-csi/democratic-csi), or [csi-driver-nfs](https://github.com/kubernetes-csi/csi-driver-nfs).

Many people have shared their awesome repositories over at [awesome-home-kubernetes](https://github.com/k8s-at-home/awesome-home-kubernetes), be sure to check this out and click the `Search All Repos` icon if you are wondering how someone implemented or deployed an application.

## 🤝 Thanks

Big shout out to all the authors and contributors to the projects that we are using in this repository.
