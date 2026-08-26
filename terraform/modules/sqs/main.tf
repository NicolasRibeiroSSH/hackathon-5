terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-${var.environment}-${var.queue_name}-dlq"
  message_retention_seconds = 1209600 # 14 dias
  tags                      = { Name = "${var.project_name}-${var.environment}-${var.queue_name}-dlq" }
}

resource "aws_sqs_queue" "main" {
  name                      = "${var.project_name}-${var.environment}-${var.queue_name}"
  message_retention_seconds = 345600 # 4 dias
  receive_wait_time_seconds = 20     # long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = { Name = "${var.project_name}-${var.environment}-${var.queue_name}" }
}
