output "instance_id" {
  description = "EC2 instance ID - used by pz.sh for start/stop"
  value       = module.compute.instance_id
}

output "subnet_id" {
  description = "Used by packer/pz-ami.pkr.hcl to build in the same network"
  value       = module.network.subnet_id
}

output "server_public_ip" {
  description = "Enter this in Project Zomboid's Join server > Direct Connection"
  value       = module.compute.public_ip
}

output "server_hostname" {
  description = "Friendlier address to share with friends (port is still 16261)"
  value       = module.dns.hostname
}

output "admin_password" {
  description = "Retrieve with: terraform output -raw admin_password"
  value       = module.compute.admin_password
  sensitive   = true
}

output "server_password" {
  description = "Join password for friends. Retrieve with: terraform output -raw server_password"
  value       = module.compute.server_password
  sensitive   = true
}

output "rcon_password" {
  description = "Retrieve with: terraform output -raw rcon_password"
  value       = module.compute.rcon_password
  sensitive   = true
}

output "resource_group_url" {
  description = "Console link listing every resource in this deployment"
  value       = module.resourcegroup.console_url
}
