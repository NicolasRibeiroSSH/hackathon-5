# SLOs & SLIs — SolidaryTech

## donation-service (Hot Path)

### SLI 1 — Taxa de Sucesso

| Item | Valor |
|---|---|
| Definição | % de requisições HTTP com status 2xx ou 3xx |
| Métrica | `1 - (rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]))` |
| **SLO** | **≥ 99.5% em janela de 30 dias** |
| Error Budget | 0.5% = ~3h 36min de downtime/mês |

### SLI 2 — Latência P99

| Item | Valor |
|---|---|
| Definição | 99% das requisições respondidas em menos de 500ms |
| Métrica | `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))` |
| **SLO** | **P99 < 500ms em 99% do tempo** |
| Justificativa | Doadores não devem esperar mais de 0.5s para confirmar uma doação |

### Error Budget Policy

- **> 75% restante**: deploy normal, sem restrições
- **25–75% restante**: apenas deploys com rollback automático habilitado
- **< 25% restante**: freeze de deploys, foco em estabilidade
- **0% (esgotado)**: incidente P1, post-mortem obrigatório

### Dashboard

Grafana: `SolidaryTech — SRE Dashboard` (UID: `solidarytech-sre`)

Painéis:
- Taxa de Sucesso (gauge com threshold no SLO)
- Latência P99 (gauge com threshold em 500ms)
- Error Budget Restante (gauge 0–100%)
- Requests/s e Errors/s (timeseries)
- Latência P50/P95/P99 (timeseries)
