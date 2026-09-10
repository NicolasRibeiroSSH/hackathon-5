variable "project_name"          { type = string }
variable "environment"           { type = string }
variable "vpc_id"                { type = string }
variable "public_subnet_id"      { type = string }
variable "private_subnet_ids"    { type = list(string) }
variable "rds_security_group_id" { type = string }

variable "instance_type" {
  type    = string
  default = "t3.xlarge"
}

variable "key_name" {
  type    = string
  default = ""
}

variable "allowed_ssh_cidr" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
