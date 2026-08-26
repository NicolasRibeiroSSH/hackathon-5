output "ecr_repositories" {
  value = module.ecr.repository_urls
}

output "rds_endpoints" {
  value     = module.rds.db_endpoints
  sensitive = true
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}

output "sqs_queue_url" {
  value = module.sqs.queue_url
}

output "k8s_node_public_ip" {
  value = module.ec2_k8s.public_ip
}

output "k8s_node_dr_public_ip" {
  value = module.ec2_k8s_dr.public_ip
}

output "tfstate_bucket" {
  value = module.tfstate_backend.bucket_name
}
