variable "project_name" {
  type    = string
  default = "pz-server"
}

variable "instance_type" {
  description = "t3.large = 2 vCPU / 8GB RAM, a good fit for 5-8 players with few mods"
  type        = string
  default     = "t3.large"
}

variable "subnet_id" {
  description = "Comes from the network module's output"
  type        = string
}

variable "security_group_id" {
  description = "Comes from the network module's output"
  type        = string
}

variable "ssh_public_key" {
  description = "Contents of your SSH public key (the actual key text, not a file path)"
  type        = string
}

variable "max_players" {
  description = "Player slot cap"
  type        = number
  default     = 8
}

variable "use_elastic_ip" {
  description = "Allocate a static Elastic IP. Set false to save the hourly charge that applies while the instance is stopped; the DNS record will follow whatever IP the instance gets on next start."
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB - holds the OS + game install, not save data"
  type        = number
  default     = 30
}
