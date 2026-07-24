## --- Find the latest Ubuntu 22.04 LTS AMI in whatever region we're in ---
# Hardcoding an AMI ID would break the moment Canonical ships a new image.
# Instead we ask AWS for "the most recent official Canonical image matching
# this name pattern" every time we plan/apply.
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

## --- Admin password ---
# PZ refuses to create its built-in 'admin' account non-interactively
# without one. Generated here instead of hardcoded, so it's never sitting
# in plaintext in the config files you write.
resource "random_password" "admin" {
  length  = 20
  special = false # keep it simple to pass safely as a bare CLI argument
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
  ami                    = data.aws_ami.ubuntu.id
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
    admin_password = random_password.admin.result
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

## --- Elastic IP ---
# A static public IP, reattached to the instance regardless of stop/start.
# Without this, stopping the instance releases its public IP and you'd
# get a different one on next start.
resource "aws_eip" "pz" {
  instance = aws_instance.pz.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}
