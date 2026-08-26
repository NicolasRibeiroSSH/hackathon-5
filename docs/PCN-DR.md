# Plano de Continuidade de Negócios (PCN) — SolidaryTech

## Contexto

A SolidaryTech opera uma plataforma de doações para ONGs. A indisponibilidade do
`donation-service` impacta diretamente a arrecadação das ONGs parceiras.

---

## Objetivos de Recuperação

| Serviço | RTO | RPO | Justificativa |
|---|---|---|---|
| donation-service | **15 min** | **5 min** | Hot path — cada minuto = doações perdidas |
| ngo-service | 30 min | 1 hora | Cadastro — impacto menor |
| volunteer-service | 1 hora | 24 horas | DynamoDB com PITR ativo |

---

## Estratégia de DR — Warm Standby (Ativo-Passivo)

### Região Primária: us-east-1 (N. Virginia)
### Região DR: us-east-2 (Ohio)

A infraestrutura DR é provisionada via Terraform com o provider `aws.dr`.
Para ativar o ambiente espelho:

```bash
# Levantar ambiente DR completo com 1 comando
terraform apply -target=module.vpc_dr -target=module.rds_dr -target=module.ec2_k8s_dr
```

### Componentes no ambiente DR

| Componente | Estratégia |
|---|---|
| EC2 + K3s | Instância `t3.large` (menor custo em standby) |
| RDS PostgreSQL | Instância separada — restore via snapshot S3 |
| DynamoDB | Global Tables habilitado para replicação automática |
| SQS | Fila recriada via Terraform |
| Imagens Docker | ECR replicado via `aws ecr replicate-image` |

### Procedimento de Failover

1. Detectar falha na região primária (alerta Prometheus/Datadog)
2. Executar `terraform apply` no ambiente DR (~10 min)
3. Restaurar último snapshot RDS na região DR
4. Atualizar DNS/ALB para apontar para IP da EC2 DR
5. Validar health checks dos 3 serviços
6. Comunicar stakeholders

### Backup

- RDS: snapshots automáticos diários (retenção 7 dias) + exportação para S3
- DynamoDB: Point-in-Time Recovery (PITR) habilitado — RPO de segundos
- Terraform state: S3 com versionamento habilitado

---

## Comunicação de Incidentes

| Severidade | Canal | SLA de Comunicação |
|---|---|---|
| P1 (donation-service down) | Slack #incidents + Email stakeholders | 5 min |
| P2 (degradação) | Slack #incidents | 15 min |
| P3 (outros serviços) | Slack #alerts | 1 hora |
