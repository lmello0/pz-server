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
