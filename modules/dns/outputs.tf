output "hostname" {
  description = "The full hostname players connect to, or empty if no record exists"
  value       = length(cloudflare_dns_record.pz) > 0 ? cloudflare_dns_record.pz[0].name : ""
}
