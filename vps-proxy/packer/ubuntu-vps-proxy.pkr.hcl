# Provide no default. This must be set in the command line, a variable file,
# or as an environment variable. Packer build will fail otherwise.
variable "digital_ocean_api_key" {
  type        = string
  sensitive   = true
  description = "Digital ocean API key used to provision image"
}

variable "vps_private_key" {
  type        = string
  sensitive   = true
  description = "The private key to use for the wireguard interface on the VPS"
}

variable "client_public_key" {
  type        = string
  sensitive   = true
  description = "The public key of the client to use in the wireguard peer configuration"
}

variable "public_ip_endpoint" {
  type        = string
  sensitive   = true
  description = "The endpoint to use that is or points to your public IP. Ex: my-ip.duckdns.org"
}

variable "snapshot_prefix" {
  type        = string
  default     = "vps-proxy"
  description = "The prefix to prepend for the snapshot name"
}

locals {
  snapshot_prefix = "vps-proxy"
  timestamp       = formatdate("MM-DD-YYYY_hh-mm-ss", timestamp())
}

packer {
  required_plugins {
    digitalocean = {
      version = ">= 1.0.4"
      source  = "github.com/digitalocean/digitalocean"
    }
  }
}

source "digitalocean" "vps-proxy" {
  api_token     = var.digital_ocean_api_key
  image         = "ubuntu-22-04-x64"
  region        = "nyc1"
  size          = "s-1vcpu-512mb-10gb"
  snapshot_name = "${local.snapshot_prefix}-${local.timestamp}"
  ssh_username  = "root"
}

build {
  name    = "proxy-server"
  sources = ["source.digitalocean.vps-proxy"]

  # Install dependencies
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
    ]
    inline = [
      "echo 'Sleeping to allow full system boot...'",
      "sleep 80",

      "echo 'Updating apt repositories...'",
      "apt-get update",
      "echo 'Apt packages updated'",

      "echo 'Installing dependencies...'",
      # Need resolvconf for wireguard DNS
      "apt-get install -y wireguard wireguard-tools nginx iptables-persistent resolvconf",
      # Optional recommended extras
      "apt-get install -y libgd-tools fcgiwrap nginx-doc ssl-cert",
      "echo 'Dependencies installed successfully'",

      "echo 'Restarting packagekit.service'",
      "systemctl restart packagekit.service",
      "echo 'packagekit.service restarted'",

      "echo 'Restarting unattended-upgrades.service...'",
      "systemctl restart unattended-upgrades.service",
      "echo 'unattended-upgrades.service restarted'",
    ]
  }

  provisioner "shell" {
    script = "./scripts/enable_ip_forwarding.sh"
  }

  # Create wireguard directory to store configuration
  provisioner "shell" {
    inline = [
      "echo creating wireguard directory...",
      "mkdir -p /etc/wireguard",
      "chmod 700 /etc/wireguard",
      "echo Wireguard directory created: /etc/wireguard",
    ]
  }

  # Generate wireguard configuration
  provisioner "file" {
    content = templatefile("${path.root}/files/wg0.conf.tpl", {
      vps_private_key    = var.vps_private_key,
      client_public_key  = var.client_public_key,
      public_ip_endpoint = var.public_ip_endpoint,
    })
    destination = "/etc/wireguard/wg0.conf"
  }

  # Configure firewall rules
  provisioner "shell" {
    script = "./scripts/configure_firewall_rules.sh"
  }

  # Configure NGINX reverse proxy to forward traffic via wireguard.
  provisioner "shell" {
    script = "./scripts/configure_nginx_reverse_proxy.sh"
  }

  # Enable and start services
  provisioner "shell" {
    inline = [
      "echo 'Enabling services...'",
      "systemctl enable wg-quick@wg0",
      "systemctl enable nginx",
      "echo 'Services enabled'",

      "echo 'Restarting services...'",
      "systemctl restart packagekit.service",
      "systemctl restart unattended-upgrades.service",
      "echo 'Services restarted'",

      "echo 'Setup complete!'",
    ]
  }
}
