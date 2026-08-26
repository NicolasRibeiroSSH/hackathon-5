terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "k8s" {
  name        = "${var.project_name}-${var.environment}-k8s-sg"
  description = "K8s node security group"
  vpc_id      = var.vpc_id

  ingress { from_port = 22;    to_port = 22;    protocol = "tcp"; cidr_blocks = var.allowed_ssh_cidr }
  ingress { from_port = 80;    to_port = 80;    protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 443;   to_port = 443;   protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 6443;  to_port = 6443;  protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 8081;  to_port = 8083;  protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 30000; to_port = 32767; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0;     to_port = 0;     protocol = "-1";  cidr_blocks = ["0.0.0.0/0"] }

  tags = { Name = "${var.project_name}-${var.environment}-k8s-sg" }
}

resource "aws_security_group_rule" "rds_from_k8s" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.k8s.id
  security_group_id        = var.rds_security_group_id
}

resource "aws_iam_role" "k8s" {
  name = "${var.project_name}-${var.environment}-k8s-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-${var.environment}-k8s-role" }
}

resource "aws_iam_role_policy" "k8s" {
  name = "${var.project_name}-${var.environment}-k8s-policy"
  role = aws_iam_role.k8s.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}-${var.environment}-*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = "arn:aws:sqs:*:*:${var.project_name}-${var.environment}-*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]
        Resource = "arn:aws:dynamodb:*:*:table/SolidaryTech*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "k8s" {
  name = "${var.project_name}-${var.environment}-k8s-profile"
  role = aws_iam_role.k8s.name
}

resource "aws_instance" "k8s" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.k8s.id]
  iam_instance_profile   = aws_iam_instance_profile.k8s.name
  key_name               = var.key_name != "" ? var.key_name : null

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    project_name = var.project_name
    environment  = var.environment
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-k8s-node"
    Role = "k8s-node"
  }
}

resource "aws_eip" "k8s" {
  instance = aws_instance.k8s.id
  domain   = "vpc"
  tags     = { Name = "${var.project_name}-${var.environment}-k8s-eip" }
}
