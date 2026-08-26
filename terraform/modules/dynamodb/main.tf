terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

resource "aws_dynamodb_table" "volunteers" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "volunteer_id"

  attribute {
    name = "volunteer_id"
    type = "S"
  }

  attribute {
    name = "ngo_id"
    type = "N"
  }

  # GSI para evitar Scan por ngo_id (melhoria de performance)
  global_secondary_index {
    name            = "ngo_id-index"
    hash_key        = "ngo_id"
    projection_type = "ALL"
  }

  point_in_time_recovery { enabled = true }

  tags = { Name = var.table_name }
}
