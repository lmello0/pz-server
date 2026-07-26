variable "project_name" {
  description = "Short name for this deployment. Used as the Project tag on every resource, and as the resource group name."
  type        = string
  default     = "pz-server"
}

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

variable "alert_email" {
  description = "Email address for AWS budget alerts"
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly spend threshold that triggers alerts"
  type        = string
  default     = "20"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:DNS:Edit permission. Keep this out of version control."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for your domain"
  type        = string
}

variable "dns_record_name" {
  description = "Subdomain for the server, e.g. \"pz\" -> pz.yourdomain.com"
  type        = string
  default     = "pz"
}

variable "use_elastic_ip" {
  description = "Set false before long idle periods to avoid the EIP charge that applies while the instance is stopped. The Cloudflare record updates automatically when it's re-enabled."
  type        = bool
  default     = true
}

variable "custom_ami_id" {
  description = "AMI ID built by packer/pz-ami.pkr.hcl. Leave empty to boot stock Ubuntu and do the full install at boot time instead."
  type        = string
  default     = ""
}

# --- Instance sizing ---
# These three move together. If you change instance_type, check the heap
# values still fit: jvm_heap_mb must be at least ~1000-1500MB below the
# instance's total RAM, or the server OOM-crashes on startup.
#
#   t3a.medium  4GB RAM  -> jvm_heap_mb = 2500   (~3-4 players, vanilla)
#   t3a.large   8GB RAM  -> jvm_heap_mb = 5000   (~8 players, some mods)
#
variable "instance_type" {
  description = "EC2 instance type. Must have enough RAM for jvm_heap_mb plus OS overhead."
  type        = string
  default     = "t3a.medium"
}

variable "jvm_heap_mb" {
  description = "Max JVM heap (-Xmx) in MB. Keep 1000-1500MB below the instance's total RAM."
  type        = number
  default     = 2500
}

variable "jvm_initial_mb" {
  description = "Initial JVM heap (-Xms) in MB."
  type        = number
  default     = 1024
}

variable "max_players" {
  description = "Player slot cap"
  type        = number
  default     = 8
}
