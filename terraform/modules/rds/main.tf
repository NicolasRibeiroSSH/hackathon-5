terraform {
  required_providers {
    aws    = { source = "hashicorp/aws" }
    random = { source = "hashicorp/random" }
  }
}

resource "random_password" "db" {
  for_each = var.db_instances
  length   = 16
  special  = false
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.project_name}-${var.environment}-db-subnet" }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "RDS access from K8s node"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-rds-sg" }
}

resource "aws_db_instance" "postgres" {
  for_each = var.db_instances

  identifier             = "${var.project_name}-${var.environment}-${each.key}"
  engine                 = "postgres"
  engine_version         = each.value.engine_version
  instance_class         = each.value.instance_class
  allocated_storage      = each.value.allocated_storage
  storage_type           = "gp3"
  db_name                = each.value.db_name
  username               = "dbadmin"
  password               = random_password.db[each.key].result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  deletion_protection    = false

  tags = {
    Name    = "${var.project_name}-${var.environment}-${each.key}-db"
    Service = each.key
  }
}

resource "aws_secretsmanager_secret" "db" {
  for_each = var.db_instances
  name     = "${var.project_name}-${var.environment}-${each.key}-db"
  tags     = { Name = "${var.project_name}-${var.environment}-${each.key}-db" }
}

resource "aws_secretsmanager_secret_version" "db" {
  for_each  = var.db_instances
  secret_id = aws_secretsmanager_secret.db[each.key].id
  secret_string = jsonencode({
    username = aws_db_instance.postgres[each.key].username
    password = random_password.db[each.key].result
    endpoint = aws_db_instance.postgres[each.key].endpoint
    database = aws_db_instance.postgres[each.key].db_name
  })
}
