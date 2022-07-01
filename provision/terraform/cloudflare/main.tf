terraform {

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "3.18.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.12.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "2.2.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "0.7.1"
    }
  }
}

terraform {
  cloud {
    organization = "ankushlab"

    workspaces {
      name = "home-cluster"
    }
  }
}

data "sops_file" "cloudflare_secrets" {
  source_file = "secret.sops.yaml"
}

provider "cloudflare" {
  api_token = data.sops_file.cloudflare_secrets.data["cloudflare_token"]
}

provider "kubernetes" {
  # KUBE_CONFIG_PATH environment variable is set by Taskfile
}

data "cloudflare_zones" "domain" {
  filter {
    name = data.sops_file.cloudflare_secrets.data["cloudflare_domain"]
  }
}

resource "cloudflare_zone_settings_override" "cloudflare_settings" {
  zone_id = lookup(data.cloudflare_zones.domain.zones[0], "id")
  settings {
    # /ssl-tls
    ssl = "strict"
    # /ssl-tls/edge-certificates
    always_use_https         = "on"
    min_tls_version          = "1.2"
    opportunistic_encryption = "on"
    tls_1_3                  = "zrt"
    automatic_https_rewrites = "on"
    universal_ssl            = "on"
    # /firewall/settings
    browser_check  = "on"
    challenge_ttl  = 1800
    privacy_pass   = "on"
    security_level = "medium"
    # /speed/optimization
    brotli = "on"
    minify {
      css  = "on"
      js   = "on"
      html = "on"
    }
    rocket_loader = "on"
    # /caching/configuration
    always_online    = "off"
    development_mode = "off"
    # /network
    http3               = "on"
    zero_rtt            = "on"
    ipv6                = "on"
    websockets          = "on"
    opportunistic_onion = "on"
    pseudo_ipv4         = "off"
    ip_geolocation      = "on"
    # /content-protection
    email_obfuscation   = "on"
    server_side_exclude = "on"
    hotlink_protection  = "off"
    # /workers
    security_header {
      enabled = false
    }
  }
}

data "http" "ipv4" {
  url = "http://ipv4.icanhazip.com"
}

locals {
  public_ips = [
    "${chomp(data.http.ipv4.body)}/32",
    # "${chomp(data.http.public_ipv6.body)}/128"
  ]
}

resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

resource "cloudflare_argo_tunnel" "homelab" {
  account_id = data.sops_file.cloudflare_secrets.data["cloudflare_account_id"]
  name       = "homelab"
  secret     = base64encode(random_password.tunnel_secret.result)
}

# Not proxied. Can use with external-dns for access via port forwarding.
resource "cloudflare_record" "ipv4" {
  name    = "ipv4"
  zone_id = lookup(data.cloudflare_zones.domain.zones[0], "id")
  value   = chomp(data.http.ipv4.response_body)
  proxied = true
  type    = "A"
  ttl     = 1
}

# Not proxied, not accessible. Can use with external-dns for access through the tunnel
resource "cloudflare_record" "tunnel" {
  name    = "homelab-tunnel"
  zone_id = lookup(data.cloudflare_zones.domain.zones[0], "id")
  value   = "${cloudflare_argo_tunnel.homelab.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = false
  ttl     = 1 # Auto
}

# Not proxied, not accessible. Can use with external-dns for access on the LAN
resource "cloudflare_record" "lan-gateway" {
  name    = "lan-gateway"
  zone_id = lookup(data.cloudflare_zones.domain.zones[0], "id")
  value   = chomp(data.sops_file.cloudflare_secrets.data["k8s_gateway_ip"])
  proxied = false
  type    = "A"
  ttl     = 1 # Auto
}

resource "cloudflare_record" "root" {
  name    = data.sops_file.cloudflare_secrets.data["cloudflare_domain"]
  zone_id = lookup(data.cloudflare_zones.domain.zones[0], "id")
  value   = "homelab-tunnel.${data.sops_file.cloudflare_secrets.data["cloudflare_domain"]}"
  proxied = true
  type    = "CNAME"
  ttl     = 1
}

resource "kubernetes_secret" "cloudflared_credentials" {
  metadata {
    name      = "cloudflared-credentials"
    namespace = "networking"
  }

  data = {
    "credential.json" = jsonencode({
      AccountTag   = data.sops_file.cloudflare_secrets.data["cloudflare_account_id"]
      TunnelName   = cloudflare_argo_tunnel.homelab.name
      TunnelID     = cloudflare_argo_tunnel.homelab.id
      TunnelSecret = base64encode(random_password.tunnel_secret.result)
    })
    "credentials.json" = jsonencode({
      AccountTag   = data.sops_file.cloudflare_secrets.data["cloudflare_account_id"]
      TunnelName   = cloudflare_argo_tunnel.homelab.name
      TunnelID     = cloudflare_argo_tunnel.homelab.id
      TunnelSecret = base64encode(random_password.tunnel_secret.result)
    })
  }
}
