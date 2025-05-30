# Provide no default. This must be set in the command line, a variable file,
# or as an environment variable. Packer build will fail otherwise.
variable "digital_ocean_api_key" {
  type        = string
  sensitive   = true
  description = "Digital ocean API key used to provision image"
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
      "sleep 80",
      "echo Updating apt repositories...",
      "apt-get update",
      "echo Apt packages updated",
      "sleep 10",
      "echo Installing dependencies...",
      "apt-get install -y wireguard wireguard-tools nginx iptables-persistent",
      "echo Wireguard installed successfully",
      "sleep 10",
      "echo Restarting packagekit.service",
      "systemctl restart packagekit.service",
      "echo packagekit.service restarted",
      "sleep 10",
      "echo Restarting unattended-upgrades.service...",
      "systemctl restart unattended-upgrades.service",
      "echo unattended-upgrades.service restarted",
      "sleep 5",
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
      "sleep 5",
    ]
  }
}
