variable "project_name"       { type = string }
variable "environment"        { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "db_instances" {
  type = map(object({
    allocated_storage = number
    engine_version    = string
    instance_class    = string
    db_name           = string
  }))
}
