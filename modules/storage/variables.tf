variable "project_name" {
  type    = string
  default = "pz-server"
}

variable "availability_zone" {
  description = "Must match the instance's AZ - EBS volumes are AZ-locked and can only attach within the same AZ"
  type        = string
  default     = "sa-east-1a"
}

variable "volume_size" {
  description = "Size in GB. PZ saves grow with explored map area; 20GB is plenty for a small server."
  type        = number
  default     = 20
}

variable "instance_id" {
  description = "Comes from the compute module's output"
  type        = string
}
