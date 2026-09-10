variable "project_name"   { type = string }
variable "environment"    { type = string }
variable "aws_account_id" { type = string }
variable "aws_region"     { type = string }
variable "github_owner"   { type = string }
variable "github_repo"    { type = string }
variable "github_connection_arn" { type = string }

variable "github_branch" {
  type    = string
  default = "main"
}

variable "services" {
  type = map(object({
    ecr_repo   = string
    build_spec = string
    port       = number
  }))
}
