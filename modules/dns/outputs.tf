output "hostname" {
  description = "The full hostname players connect to"
  value       = cloudflare_dns_record.pz.name
}
