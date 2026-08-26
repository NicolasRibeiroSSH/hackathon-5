#!/bin/bash
# Executado automaticamente pelo LocalStack ao iniciar

echo "Criando recursos AWS locais..."

awslocal sqs create-queue \
  --queue-name solidary-donations \
  --region us-east-1

awslocal sqs create-queue \
  --queue-name solidary-donations-dlq \
  --region us-east-1

awslocal dynamodb create-table \
  --table-name SolidaryTechVolunteers \
  --attribute-definitions AttributeName=volunteer_id,AttributeType=S \
  --key-schema AttributeName=volunteer_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

echo "Recursos locais criados com sucesso."
