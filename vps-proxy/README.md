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

