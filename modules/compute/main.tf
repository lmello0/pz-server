## --- Find the latest Ubuntu 22.04 LTS AMI in whatever region we're in ---
# Only used as a fallback when custom_ami_id is empty. Hardcoding an AMI
# ID would break the moment Canonical ships a new image, so this always
# asks AWS for "the most recent official Canonical image matching this
# name pattern" - but it's skipped in practice once you're using the
# baked AMI from packer/, since that boots in a fraction of the time.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.custom_ami_id != "" ? var.custom_ami_id : data.aws_ami.ubuntu.id
}

## --- Admin password ---
# PZ refuses to create its built-in 'admin' account non-interactively
# without one. Generated here instead of hardcoded, so it's never sitting
# in plaintext in the config files you write.
resource "random_password" "admin" {
  length  = 20
  special = false # keep it simple to pass safely as a bare CLI argument
}

## --- Server join password ---
# What you share with friends. Separate from the admin password: leaking
# this lets someone play, leaking the admin one lets them run commands.
resource "random_password" "server" {
  length  = 12
  special = false # players have to type this by hand
}

## --- RCON password ---
# Grants full server control, so this one is long and never shared.
resource "random_password" "rcon" {
  length  = 24
  special = false
}

## --- Your SSH key, imported (not generated) ---
# public_key here is just text - AWS stores it and injects it into the
# instance's authorized_keys on first boot. Your private key never
# touches AWS or Terraform state.
resource "aws_key_pair" "pz" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key
}

## --- The instance itself ---
resource "aws_instance" "pz" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = aws_key_pair.pz.key_name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  # Runs once, automatically, on first boot only. This is what installs
  # SteamCMD, downloads the game, and wires up the systemd service.
  user_data = templatefile("${path.module}/install.sh.tpl", {
    admin_password  = random_password.admin.result
    server_password = random_password.server.result
    rcon_password   = random_password.rcon.result
    max_players     = var.max_players
    server_name     = var.server_name
    jvm_heap_mb     = var.jvm_heap_mb
    jvm_initial_mb  = var.jvm_initial_mb
  })

  # By default, changing user_data does NOT make an already-running
  # instance re-execute it - cloud-init only runs once per instance ID,
  # ever. Setting this makes Terraform destroy and recreate the instance
  # whenever the boot script changes, guaranteeing it actually reruns.
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-instance"
  }
}

## --- Elastic IP (optional) ---
# A static public IP that survives instance stop/start. AWS charges for
# an EIP whenever it's NOT attached to a running instance - including
# while the instance is stopped - so if the server sits idle for long
# stretches it's cheaper to release it and allocate a new one on the
# next apply. The DNS record follows public_ip automatically either way.
resource "aws_eip" "pz" {
  count = var.use_elastic_ip ? 1 : 0

  instance = aws_instance.pz.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}
