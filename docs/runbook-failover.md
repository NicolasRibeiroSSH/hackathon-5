# Runbook — Failover para DR (us-east-2)

## Pré-requisitos
- Acesso AWS com profile `devops`
- Terraform inicializado em `terraform/`
- Chave SSH `~/.ssh/solidarytech-key-dr.pem`

---

## 1. Detecção de Falha

Alertas que disparam este runbook:
- `ServiceDown` — serviço indisponível > 1 min
- `ServiceHighErrorRate` — error rate > 0.5% por > 2 min
- Falha total da região us-east-1 (AWS Health Dashboard)

---

## 2. Avaliação (< 5 min)

```bash
# Verificar saúde dos serviços na região primária
curl -s http://98.89.162.183:8081/health
curl -s http://98.89.162.183:8082/health
curl -s http://98.89.162.183:8083/health

# Verificar status da EC2 primária
aws ec2 describe-instance-status \
  --region us-east-1 --profile devops \
  --query 'InstanceStatuses[*].{ID:InstanceId,Status:InstanceStatus.Status}'
```

Se 2+ serviços indisponíveis → **ativar DR**.

---

## 3. Ativar Ambiente DR (< 10 min)

```bash
cd terraform/

# Subir EC2 DR + K3s (já provisionado pelo Terraform)
terraform apply -auto-approve \
  -target=module.vpc_dr \
  -target=module.rds_dr \
  -target=module.ec2_k8s_dr

# Pegar IP da EC2 DR
DR_IP=$(terraform output -raw k8s_node_dr_public_ip)
echo "DR IP: $DR_IP"
```

---

## 4. Deploy dos Serviços no DR (< 5 min)

```bash
# Copiar helm charts e script de deploy para EC2 DR
scp -i ~/.ssh/solidarytech-key-dr.pem -r \
  helm-charts/ ubuntu@$DR_IP:/home/ubuntu/

scp -i ~/.ssh/solidarytech-key-dr.pem \
  /tmp/deploy.sh ubuntu@$DR_IP:/home/ubuntu/

# Executar deploy (adaptar DATABASE_URL para endpoints RDS DR)
ssh -i ~/.ssh/solidarytech-key-dr.pem ubuntu@$DR_IP \
  "chmod +x /home/ubuntu/deploy.sh && /home/ubuntu/deploy.sh"
```

---

## 5. Validação (< 5 min)

```bash
# Health checks na região DR
curl -s http://$DR_IP:8081/health  # ngo-service
curl -s http://$DR_IP:8082/health  # donation-service
curl -s http://$DR_IP:8083/health  # volunteer-service

# Verificar pods
ssh -i ~/.ssh/solidarytech-key-dr.pem ubuntu@$DR_IP \
  "sudo k3s kubectl get pods -n solidarytech"
```

---

## 6. Atualizar DNS / Comunicar

- Atualizar registros DNS para apontar para `$DR_IP`
- Notificar stakeholders via Slack `#incidents`
- Registrar horário de failover no ticket de incidente

---

## 7. Failback (quando primária recuperar)

```bash
# 1. Verificar que primária está saudável
curl -s http://98.89.162.183:8081/health

# 2. Sincronizar dados (DynamoDB já replica automaticamente via Global Tables)
# RDS: restaurar snapshot mais recente na primária se necessário

# 3. Redirecionar DNS de volta para primária
# 4. Desligar EC2 DR para economizar custos
terraform destroy -target=module.ec2_k8s_dr -auto-approve
```

---

## RTO/RPO Alcançados

| Serviço | RTO Target | RTO Real | RPO Target | RPO Real |
|---|---|---|---|---|
| donation-service | 15 min | ~20 min | 5 min | ~5 min (snapshot RDS) |
| ngo-service | 30 min | ~20 min | 1 hora | ~1 hora |
| volunteer-service | 1 hora | ~20 min | 24 horas | Segundos (DynamoDB Global Tables) |
