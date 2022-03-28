<img src="https://camo.githubusercontent.com/5b298bf6b0596795602bd771c5bddbb963e83e0f/68747470733a2f2f692e696d6775722e636f6d2f7031527a586a512e706e67" align="left" width="144px" height="144px"/>

## GitOps + k8s Homelab

> This repo contains the code I use for deploying and managing my homelab.

[![k3s](https://img.shields.io/badge/k3s-v1.23.3-orange?style=flat-square)](https://k3s.io/)
[![GitHub issues](https://img.shields.io/github/issues/ankushg/home-cluster?style=flat-square)](https://github.com/ankushg/home-cluster/issues)
[![GitHub last commit](https://img.shields.io/github/last-commit/ankushg/home-cluster?color=purple&style=flat-square)](https://github.com/ankushg/home-cluster/commits/master)
[![GitHub Super-Linter](https://github.com/ankushg/home-cluster/workflows/Lint/badge.svg)](https://github.com/marketplace/actions/super-linter)

---

This is a _highly_ (but not necessarily _intelligently_) opinionated deployment of a single [k3s](https://k3s.io/) cluster, that is:

- deployed by [k3sup](https://github.com/alexellis/k3sup)
- backed by the [GitOps](https://www.weave.works/blog/what-is-gitops-really) tool [Flux](https://toolkit.fluxcd.io/)
- secured with help of the [Flux SOPS integration](https://toolkit.fluxcd.io/guides/mozilla-sops/),
- accessed through [traefik](https://traefik.io)

## 🙇 Thanks

Big shout out to all of the contributors to the projects that I'm using in this repository.

A lot of inspiration for this repo came from the following projects:

- [k8s-at-home/template-cluster-k3s](https://github.com/k8s-at-home/template-cluster-k3s)
- [onedr0p/home-cluster](https://github.com/onedr0p/home-cluster)
- [carpenike/k8s-gitops](https://github.com/carpenike/k8s-gitops)
- [and many more](https://github.com/k8s-at-home/awesome-home-kubernetes)

And a lot of support and advice came from the k8s-at-home Discord:
[![Discord](https://img.shields.io/badge/discord-chat-7289DA.svg?maxAge=60&style=flat-square)](https://discord.gg/Yv2gzFy)
