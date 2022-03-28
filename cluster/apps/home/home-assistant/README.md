# Home Assistant

## VS Code Server

### [Configure HTTP Component](https://github.com/k8s-at-home/charts/tree/master/charts/stable/home-assistant#http-400-bad-request-while-accessing-from-your-browser)

- open `config.yaml`
- add `http` component with `use_x_forwarded_for: true` and `trusted_proxies` set to include both Pod and Node CIDR

### Home Assistant Config VS Code Extension

- Install `Home Assistant Config` extension
- Run `Reload Window` from Command Pallete
- [Configure connection to HA](https://github.com/keesschollaart81/vscode-home-assistant/wiki/Configure-connection-to-HA)

## Home Assistant Setup

### Install HACS

- `kubectl get pods --namespace home`
- `kubectl exec --stdin --tty home-assistant-<whatever> --namespace=home -- /bin/bash`
- `wget -O - https://get.hacs.xyz | bash -`
  - (from [here](https://hacs.xyz/docs/setup/download#option-2-run-the-downloader-inside-the-container))
- Restart HASS from Web UI
