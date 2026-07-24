variable "project_name" {
  description = "Short name used to tag/name resources"
  type        = string
  default     = "pz-server"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "AZ to place the subnet in"
  type        = string
  default     = "sa-east-1a"
}

variable "admin_ip" {
  description = "Your public IP in CIDR form, e.g. \"200.10.20.30/32\""
  type        = string
}
