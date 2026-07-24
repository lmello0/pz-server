# required_providers is NOT inherited from the root module. Without this
# block, Terraform assumes any provider it sees here lives in the default
# "hashicorp/" namespace - so `cloudflare_dns_record` gets resolved as
# hashicorp/cloudflare, which doesn't exist. Every child module using a
# non-HashiCorp provider needs its own declaration like this.
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}