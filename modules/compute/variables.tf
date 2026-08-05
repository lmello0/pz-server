variable "project_name" {
  type    = string
  default = "pz-server"
}

variable "custom_ami_id" {
  description = "AMI ID from a baked image (see packer/). Leave empty to use stock Ubuntu 22.04 and run the full SteamCMD install at boot - slower (~10 min) but requires no separate build step."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Must have enough RAM for jvm_heap_mb plus ~1-1.5GB for the OS. t3a.medium = 4GB (fine for ~4 players vanilla), t3.large = 8GB (comfortable for 8 + mods)."
  type        = string
  default     = "t3a.medium"
}

variable "jvm_heap_mb" {
  description = "Max JVM heap (-Xmx) in MB. Keep this at least 1000-1500MB BELOW the instance's total RAM - the JVM uses memory outside the heap, and the OS needs its share. Exceeding total RAM causes an OOM crash on boot."
  type        = number
  default     = 2500
}

variable "jvm_initial_mb" {
  description = "Initial JVM heap (-Xms) in MB. Lower than jvm_heap_mb; the JVM grows toward the max as needed."
  type        = number
  default     = 1024
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

variable "server_name" {
  description = "PZ world identity. Changing this creates a brand new world on next apply and leaves the old one intact on the volume; changing it back restores the previous world. Alphanumerics and underscores only - it becomes a filename."
  type        = string
  default     = "servertest"
}
