## --- A record pointing at the Elastic IP ---
# CRITICAL: proxied MUST be false. Cloudflare's proxy (the orange cloud)
# only handles HTTP/HTTPS traffic. Project Zomboid uses raw UDP on
# 16261-16262, which the proxy cannot carry - turning it on would make
# the server completely unreachable while looking like a DNS problem.
# "DNS only" (grey cloud) just answers with the IP and stays out of the
# way, which is exactly what a game server needs.
resource "cloudflare_dns_record" "pz" {
  zone_id = var.zone_id
  name    = var.record_name
  type    = "A"
  content = var.elastic_ip
  proxied = false
  ttl     = var.ttl

  comment = "Project Zomboid server - managed by Terraform"
}
