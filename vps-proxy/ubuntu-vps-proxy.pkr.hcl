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

packer {
  required_plugins {
    digitalocean = {
      version = ">= 1.0.4"
      source  = "github.com/digitalocean/digitalocean"
    }
  }
}

source "digitalocean" "vps-proxy" {
  api_token    = var.digital_ocean_api_key
  image        = "ubuntu-22-04-x64"
  region       = "nyc1"
  size         = "s-1vcpu-512mb-10gb"
  ssh_username = "root"
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
    script = "./scripts/packer/enable_ip_forwarding.sh"
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

  # Generate wireguard
  provisioner "shell" {
    environment_vars = [
      "VPS_PRIVATE_KEY=${var.vps_private_key}",
      "CLIENT_PUBLIC_KEY=${var.client_public_key}",
      "PUBLIC_IP_ENDPOINT=${var.public_ip_endpoint}",
    ]
    script = "./scripts/packer/create_wireguard_server_conf.sh"
  }

  # Configure firewall rules
  provisioner "shell" {
    script = "./scripts/packer/configure_firewall_rules.sh"
  }

  # Configure NGINX reverse proxy to forward traffic via wireguard.
  provisioner "shell" {
    script = "./scripts/packer/configure_nginx_reverse_proxy.sh"
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
