variable "project_name" {
  description = "Value of the Project tag to group on. Must match the provider's default_tags."
  type        = string
  default     = "pz-server"
}

variable "aws_region" {
  description = "Used only to build the console URL"
  type        = string
}
