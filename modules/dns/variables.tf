variable "zone_id" {
  description = "Cloudflare Zone ID. Find it on your domain's Overview page in the Cloudflare dashboard, right sidebar."
  type        = string
}

variable "record_name" {
  description = "Subdomain to create, e.g. \"pz\" produces pz.yourdomain.com. Use \"@\" for the root domain."
  type        = string
  default     = "pz"
}

variable "elastic_ip" {
  description = "Comes from the compute module's output"
  type        = string
}

variable "ttl" {
  description = "Seconds. 300 is a good balance: short enough that a changed IP propagates quickly, long enough to avoid hammering DNS. Must be 1 (automatic) if proxied, but we're not proxying."
  type        = number
  default     = 300
}
