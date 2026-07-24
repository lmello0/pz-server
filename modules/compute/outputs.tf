output "instance_id" {
  value = aws_instance.pz.id
}

output "public_ip" {
  description = "The Elastic IP - this is what you and your friends connect to"
  value       = aws_eip.pz.public_ip
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
