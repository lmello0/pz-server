variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "sa-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use (matches what you set up with `aws configure --profile`)"
  type        = string
  default     = "pz-server"
}

variable "admin_ip" {
  description = "Your public IP in CIDR form, e.g. \"200.10.20.30/32\". Used to lock down SSH and RCON to just you."
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to your generated SSH public key file, e.g. \"C:/Users/mello/.ssh/pz-server-key.pub\""
  type        = string
}
