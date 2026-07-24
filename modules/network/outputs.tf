output "vpc_id" {
  value = aws_vpc.pz.id
}

output "subnet_id" {
  value = aws_subnet.public.id
}

output "security_group_id" {
  value = aws_security_group.pz_server.id
}
