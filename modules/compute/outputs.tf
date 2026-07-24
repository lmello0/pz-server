output "instance_id" {
  value = aws_instance.pz.id
}

output "public_ip" {
  description = "The address to connect to. Uses the Elastic IP when enabled, otherwise the instance's auto-assigned public IP (which changes on every stop/start)."
  value       = var.use_elastic_ip ? aws_eip.pz[0].public_ip : aws_instance.pz.public_ip
}

output "admin_password" {
  description = "PZ in-game/RCON admin password - retrieve with: terraform output -raw admin_password"
  value       = random_password.admin.result
  sensitive   = true
}

output "server_password" {
  description = "Join password to share with friends"
  value       = random_password.server.result
  sensitive   = true
}

output "rcon_password" {
  description = "RCON console password - keep private"
  value       = random_password.rcon.result
  sensitive   = true
}
