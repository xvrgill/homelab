# VPS Proxy Configuration

## Installing Packer

[Packer](https://developer.hashicorp.com/packer) is used to create the reusable 
machine image that will be provisioned via a cloud provider. These installation 
instructions are for my specific setup(s) and are likely to become outdated. 
Please reference the [official installation guide](https://developer.hashicorp.com/packer/install) 
for updated instructions for your particular setup.

### MacOS

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/packer
```

## Defining Packer Build

### Defining Digital Ocean API Key

An API key with droplet permissions must be provided to Packer via the `digital_ocean_api_key` variable. This is 
defined in the `ubuntu-vps-proxy.pkr.hcl` file:

```hcl
variable "digital_ocean_api_key" {
  type        = string
  sensitive   = true
  description = "Digital ocean API key used to provision image"
}
```

Note that there is no `default` parameter set in the variable definition. This means that you must provide the value 
for this variable in the command line or in a variable file during `packer build`. You can use a dedicated secrets file 
such as `secrets.auto.pkrvars.hcl` to store this value. The `auto` portion of the file name tells packer to 
automatically use it during build, so that you don't need to manually pass the file with the `var-file` option to the 
`build` command.

### Defining Plugins & Sources

The packer plugin is required to tell packer which plugins we want to use to perform the build. Because we are using 
Digital Ocean, we can define our plugin like so:

```hcl
packer {
  required_plugins {
    digitalocean = {
      version = ">= 1.0.4"
      source  = "github.com/digitalocean/digitalocean"
    }
  }
}
```

We also define a source named `vps-proxy` that uses the `digitalocean` plugin. It contains the information required to 
provision the droplet. 

```hcl
source "digitalocean" "vps-proxy" {
  api_token    = var.digital_ocean_api_key
  image        = "ubuntu-22-04-x64"
  region       = "nyc1"
  size         = "s-1vcpu-512mb-10gb"
  ssh_username = "root"
}
```

