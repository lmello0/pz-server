output "group_arn" {
  value = aws_resourcegroups_group.pz.arn
}

output "console_url" {
  description = "Direct link to the group in the AWS console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/resource-groups/group/${aws_resourcegroups_group.pz.name}?region=${var.aws_region}"
}
