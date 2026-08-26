variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "dr_region" {
  type    = string
  default = "us-east-2"
}

variable "aws_profile" {
  type    = string
  default = "default"
}

variable "aws_account_id" {
  type = string
}

variable "project_name" {
  type    = string
  default = "solidarytech"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "vpc_cidr_dr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "ecr_repositories" {
  type = list(string)
  default = [
    "ngo-service",
    "donation-service",
    "volunteer-service"
  ]
}

variable "rds_instances" {
  type = map(object({
    allocated_storage = number
    engine_version    = string
    instance_class    = string
    db_name           = string
  }))
  default = {
    ngo = {
      allocated_storage = 20
      engine_version    = "16.3"
      instance_class    = "db.t3.micro"
      db_name           = "ngo_db"
    }
    donation = {
      allocated_storage = 20
      engine_version    = "16.3"
      instance_class    = "db.t3.micro"
      db_name           = "donation_db"
    }
  }
}

variable "dynamodb_table_name" {
  type    = string
  default = "SolidaryTechVolunteers"
}

variable "sqs_queue_name" {
  type    = string
  default = "solidary-donations"
}

variable "k8s_instance_type" {
  type    = string
  default = "t3.xlarge"
}

variable "k8s_instance_type_dr" {
  type    = string
  default = "t3.large"
}

variable "ssh_key_name" {
  type    = string
  default = ""
}

variable "allowed_ssh_cidr" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "budget_monthly_limit" {
  type    = number
  default = 200
}

variable "budget_alert_emails" {
  type    = list(string)
  default = []
}
