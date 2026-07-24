variable "project_name" {
  type    = string
  default = "pz-server"
}

variable "retain_count" {
  description = "How many daily snapshots to keep. Older ones are deleted automatically, which is what stops snapshot costs growing forever."
  type        = number
  default     = 7
}
