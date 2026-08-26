# FinOps — Forecast de Custos SolidaryTech

## Tags Obrigatórias (implementadas via Terraform `default_tags`)

Todos os recursos AWS recebem automaticamente:

```hcl
Project     = "SolidaryTech"
Environment = "prod"
CostCenter  = "NGO-Core"
ManagedBy   = "Terraform"
Owner       = "platform-team"
```

---

## Forecast Mensal — Ambiente Produção (us-east-1)

| Recurso | Tipo | Custo/mês |
|---|---|---|
| EC2 t3.xlarge (K8s primário) | Compute | ~$120 |
| EC2 t3.large (K8s DR standby) | Compute DR | ~$60 |
| RDS db.t3.micro × 2 (ngo + donation) | Database | ~$30 |
| DynamoDB (PAY_PER_REQUEST) | NoSQL | ~$5 |
| SQS (Standard) | Mensageria | ~$1 |
| ECR (3 repos) | Registry | ~$3 |
| S3 (tfstate + artifacts) | Storage | ~$2 |
| NAT Gateway | Rede | ~$35 |
| EIP × 2 | Rede | ~$8 |
| **Total estimado** | | **~$264/mês** |

> O ambiente DR (EC2 t3.large) pode ser desligado quando não há incidente,
> reduzindo para ~$204/mês em operação normal.

---

## Recomendações de Otimização

### 1. Savings Plans (maior impacto — economia de ~30%)
Comprometer 1 ano de uso para EC2 e RDS.
- EC2 t3.xlarge: $120 → ~$84/mês
- RDS db.t3.micro × 2: $30 → ~$21/mês
- **Economia: ~$45/mês (~$540/ano)**

### 2. Desligar EC2 DR fora do horário comercial
O ambiente DR só precisa estar ativo durante testes mensais e incidentes reais.
- Usar AWS Instance Scheduler para ligar/desligar automaticamente
- **Economia: ~$45/mês**

### 3. NAT Gateway → NAT Instance (t3.nano)
Para tráfego baixo de dev/staging, substituir NAT Gateway por NAT Instance.
- NAT Gateway: $35/mês → NAT Instance t3.nano: ~$4/mês
- **Economia: ~$31/mês** (não recomendado para produção crítica)

### 4. Rightsizing dos Pods (já implementado)
Requests ajustados com base em métricas reais:
- ngo-service: 50m CPU / 96Mi RAM (vs 100m/256Mi padrão)
- donation-service: 100m CPU / 128Mi RAM
- volunteer-service: 50m CPU / 96Mi RAM
- Evita over-provisioning e reduz custo de instância EC2

---

## Budget Alert

Configurado via módulo Terraform `budget`:
- Alerta em 80% do limite ($160) → notificação por email
- Alerta em 100% forecasted ($200) → notificação por email
