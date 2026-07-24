output "server_public_ip" {
  description = "Enter this in Project Zomboid's Join server > Direct Connection"
  value       = module.compute.public_ip
}

output "admin_password" {
  description = "Retrieve with: terraform output -raw admin_password"
  value       = module.compute.admin_password
  sensitive   = true
}
