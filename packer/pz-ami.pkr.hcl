# Builds an AMI with SteamCMD, Project Zomboid, and the JVM heap fix
# already baked in. Deploying from this AMI instead of stock Ubuntu turns
# a ~10 minute boot (mostly a 5.3GB SteamCMD download) into something
# closer to 30-60 seconds, since only the EBS mount and systemd unit
# still need to happen at instance-boot time.
#
# Usage:
#   cd packer
#   packer init pz-ami.pkr.hcl
#   packer build \
#     -var "subnet_id=$(terraform -chdir=.. output -raw subnet_id)" \
#     -var "ssh_source_cidr=YOUR_IP/32" \
#     pz-ami.pkr.hcl
#
# Note the extra `subnet_id` root output this needs - see the setup docs.

packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.3"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "sa-east-1"
}

variable "aws_profile" {
  type    = string
  default = "pz-server"
}

variable "subnet_id" {
  type        = string
  description = "Subnet to build in. Reuse the one Terraform already created: terraform output -raw subnet_id. Needs a route to the internet for the SteamCMD download."
}

variable "ssh_source_cidr" {
  type        = string
  description = "Your IP in CIDR form, e.g. 200.10.20.30/32. Packer opens a temporary security group allowing SSH from here only, for the duration of the build."
}

locals {
  # Bare timestamp, safe for use in an AMI name (no spaces/colons).
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "pz" {
  profile       = var.aws_profile
  region        = var.aws_region
  ami_name      = "pz-server-baked-${local.timestamp}"
  instance_type = "t3.medium" # only runs the installer here, doesn't need to run the game itself
  subnet_id     = var.subnet_id

  # Needed to reach GitHub/apt/Steam's CDN during the build, and for
  # Packer's SSH connection back to this instance.
  associate_public_ip_address = true

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  ssh_username = "ubuntu"

  # Packer creates a throwaway security group just for the build and
  # deletes it afterward - scoped to only your IP, same principle as the
  # SSH rule in the real security group.
  temporary_security_group_source_cidrs = [var.ssh_source_cidr]

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size            = 30
    volume_type            = "gp3"
    delete_on_termination  = true
  }

  tags = {
    Name    = "pz-server-baked-${local.timestamp}"
    Project = "pz-server"
  }
}

build {
  sources = ["source.amazon-ebs.pz"]

  provisioner "shell" {
    script = "${path.root}/bake.sh"
  }

  post-processor "manifest" {
    output = "manifest.json"
  }
}
