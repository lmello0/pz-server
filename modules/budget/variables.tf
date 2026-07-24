variable "project_name" {
  type    = string
  default = "pz-server"
}

variable "monthly_limit" {
  description = "Monthly budget in USD. A t3.large running 24/7 would be well over this - the point is to notice if you forget to stop it."
  type        = string
  default     = "20"
}

variable "alert_email" {
  description = "Where budget alerts get sent"
  type        = string
}
