# terraform/main.tf

terraform {
  required_version = ">= 1.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Variables
variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
}

variable "packer_image_name" {
  description = "Name of the Packer-built image"
  type        = string
  default     = "proxy-server"
}

variable "droplet_name" {
  description = "Name for the VPS droplet"
  type        = string
  default     = "vps-proxy"
}

variable "ssh_key_name" {
  description = "Name of SSH key in DigitalOcean"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc1"
}

variable "size" {
  description = "Droplet size"
  type        = string
  default     = "s-1vcpu-512mb-10gb"
}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

# Data source to get the custom image built by Packer
data "digitalocean_image" "proxy_image" {
  name = var.packer_image_name
}

# Data source to get SSH key
data "digitalocean_ssh_key" "main" {
  name = var.ssh_key_name
}

# Create the VPS droplet
resource "digitalocean_droplet" "proxy_vps" {
  image    = data.digitalocean_image.proxy_image.id
  name     = var.droplet_name
  region   = var.region
  size     = var.size
  ssh_keys = [data.digitalocean_ssh_key.main.id]

  # Enable monitoring
  monitoring = true

  # Enable backups (optional but recommended)
  backups = false

  # IPv6 support
  ipv6 = true

  # User data script to start services on boot
  user_data = <<-EOF
    #!/bin/bash
    set -e

    echo "Starting VPS proxy setup..."

    # Ensure services are running
    systemctl start wg-quick@wg0
    systemctl start nginx

    # Enable IP forwarding (should already be configured)
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.all.forwarding=1

    # Apply firewall rules
    iptables-restore < /etc/iptables/rules.v4

    echo "VPS proxy setup complete"
  EOF

  tags = ["proxy", "wireguard", "nginx"]
}

# Create a firewall for additional security
resource "digitalocean_firewall" "proxy_firewall" {
  name = "${var.droplet_name}-firewall"

  droplet_ids = [digitalocean_droplet.proxy_vps.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # HTTP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # HTTPS (commented out in your nginx config, uncomment if needed)
  # inbound_rule {
  #   protocol         = "tcp"
  #   port_range       = "443"
  #   source_addresses = ["0.0.0.0/0", "::/0"]
  # }

  # WireGuard
  inbound_rule {
    protocol         = "udp"
    port_range       = "51820"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # All outbound traffic allowed
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Outputs
output "vps_ip" {
  description = "Public IP address of the VPS"
  value       = digitalocean_droplet.proxy_vps.ipv4_address
}

output "vps_ipv6" {
  description = "IPv6 address of the VPS"
  value       = digitalocean_droplet.proxy_vps.ipv6_address
}

output "vps_id" {
  description = "Droplet ID"
  value       = digitalocean_droplet.proxy_vps.id
}

output "ssh_command" {
  description = "SSH command to connect to the VPS"
  value       = "ssh root@${digitalocean_droplet.proxy_vps.ipv4_address}"
}