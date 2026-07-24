## --- A record pointing at the server ---
# Skipped entirely when create_record is false. That's driven by
# use_elastic_ip upstream, not by whether elastic_ip happens to be
# non-empty right now - `count` has to be decidable at PLAN time, and on
# a fresh apply the instance doesn't exist yet, so its public IP is
# unknown until apply. A plain boolean input variable is always known;
# a computed attribute like module.compute.public_ip is not. Using the
# boolean for count and saving the (possibly still-unknown) IP for the
# resource body itself is what makes this valid.
#
# CRITICAL: proxied MUST be false. Cloudflare's proxy (the orange cloud)
# only handles HTTP/HTTPS traffic. Project Zomboid uses raw UDP on
# 16261-16262, which the proxy cannot carry - turning it on would make
# the server completely unreachable while looking like a DNS problem.
# "DNS only" (grey cloud) just answers with the IP and stays out of the
# way, which is exactly what a game server needs.
resource "cloudflare_dns_record" "pz" {
  count = var.create_record ? 1 : 0

  zone_id = var.zone_id
  name    = var.record_name
  type    = "A"
  content = var.elastic_ip
  proxied = false
  ttl     = var.ttl

  comment = "Project Zomboid server - managed by Terraform"
}