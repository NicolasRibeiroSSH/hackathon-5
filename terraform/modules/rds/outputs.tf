output "db_endpoints" {
  value = { for k, v in aws_db_instance.postgres : k => v.endpoint }
}
output "security_group_id" {
  value = aws_security_group.rds.id
}
