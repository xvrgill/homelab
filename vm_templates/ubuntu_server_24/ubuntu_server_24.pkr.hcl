variable proxmox_api_url {
  type      = string
  sensitive = true
}

variable proxmox_api_token_id {
  type      = string
  sensitive = true
}

variable proxmox_api_token_secret {
  type      = string
  sensitive = true
}

packer {
  required_plugins {
    name = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "ubuntu-server-24" {

  # Proxmox connection settings.
  proxmox_url              = "${var.proxmox_api_url}"
  username                 = "${var.proxmox_api_token_id}"
  token                    = "${var.proxmox_api_token_secret}"
  insecure_skip_tls_verify = true

  # Boot ISO settings for starting up the VM during creation.
  boot_iso {
    type     = "scsi"
    iso_file = "local-btrfs:iso/ubuntu-24.04.3-live-server-amd64.iso"
    # iso_url          = "https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso"
    iso_checksum     = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
    unmount          = true
    iso_storage_pool = "local-btrfs"
  }

  # General VM settings.
  node                 = "proxmox"
  vm_name              = "ubuntu-server-24-packer"
  tags                 = "ubuntu-server-24;template"
  template_description = "Ubuntu Server 24 Focal"

  # Whether to install qemu guest agent.
  qemu_agent = true

  # HDD settings.
  scsi_controller = "virtio-scsi-pci"
  disks {
    type         = "sata"
    disk_size    = "20G"
    format       = "qcow2"
    storage_pool = "local-btrfs"
  }

  # CPU settings.
  cores = "4"

  # Memory settings.
  memory = "4096"

  # Networking configuration.
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = false
  }

  # Cloud init settings
  cloud_init              = true
  cloud_init_storage_pool = "local-btrfs"

  # Boot command to inject into the console window during boot.
  boot_wait = "10s"
  # boot_command = [
  #   "e<wait>",
  #   "<down><down><down>",
  #   # 27 rights
  #   "<right><right><right><right><right><right><right><right><right><right>",
  #   "<right><right><right><right><right><right><right><right><right><right>",
  #   "<right><right><right><right><right><right><right>",
  #   "<spacebar>",
  #   "autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
  #   "<esc><enter>",
  # ]
  boot_command = [
    "c",
    "linux /casper/vmlinuz autoinstall quiet ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<enter>",
    "initrd /casper/initrd<enter>",
    "boot<enter>",
  ]

  # Packer autoinstall settings
  http_directory = "auto_install_config"
  # (Optional) Bind IP address and port
  # http_bind_address = 0.0.0.0
  # http_port_min = 8000
  # http_port_max = 9000

  ssh_username = "xgill"
  # Option 1 - Add user password here
  # ssh_password = "your_password"
  # Option 2 - Add private ssh key file (local) here
  ssh_private_key_file = "~/.ssh/id_ed25519"
  # Increase SSH timeout if installation takes a while.
  ssh_timeout = "20m"
}

# Build definition to create the VM template.
build {

  name    = "ubuntu-server-24"
  sources = ["source.proxmox-iso.ubuntu-server-24"]

  provisioner "shell" {
    inline = [
      # Wait for any initial cloud-init run to finish (defensive)
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",

      # Silence interactive terminal requirement warning for apt
      "export DEBIAN_FRONTEND=noninteractive",

      # Ensure tools are present
      "sudo apt-get update",
      "sudo apt-get install -y cloud-init qemu-guest-agent",

      # Don't need `systemctl enable` for guest agent.
      # "sudo systemctl enable qemu-guest-agent",
      "sudo systemctl start qemu-guest-agent",

      # Proxmox-friendly datasource config
      "echo 'datasource_list: [ NoCloud, ConfigDrive ]' | sudo tee /etc/cloud/cloud.cfg.d/99-pve.cfg",

      # Let cloud-init manage networking (undo subiquity’s override)
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",

      # Clean cloud-init + identity so clones start fresh
      "sudo cloud-init clean --logs",
      "sudo rm -rf /var/lib/cloud/*",

      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id || true",

      # New SSH host keys per clone
      "sudo rm -f /etc/ssh/ssh_host_*",

      # (Optional) save a bit of disk space
      "sudo apt-get -y autoremove --purge",
      "sudo apt-get -y clean",
      "sudo apt-get -y autoclean",

      "sudo sync"
    ]
  }
}

