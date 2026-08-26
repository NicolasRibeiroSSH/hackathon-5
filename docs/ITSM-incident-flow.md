# ITSM — Gestão de Incidentes SolidaryTech

## Fluxo de Vida de um Incidente

```
[Datadog Watchdog / Prometheus Alert]
           │
           ▼
    1. DETECÇÃO (automática)
    Watchdog detecta anomalia comportamental no donation-service
    (ex: spike de latência, aumento de error rate)
           │
           ▼
    2. NOTIFICAÇÃO (< 2 min)
    Alerta enviado para:
    - Slack #incidents (webhook)
    - PagerDuty (on-call engineer)
    - Email stakeholders (P1 apenas)
           │
           ▼
    3. TRIAGEM (< 5 min)
    On-call engineer:
    - Confirma impacto no SLO
    - Classifica severidade (P1/P2/P3)
    - Abre ticket no JIRA/ServiceNow
           │
           ▼
    4. DIAGNÓSTICO (< 10 min)
    - Grafana SRE Dashboard → identifica serviço afetado
    - Datadog APM → distributed tracing → identifica root cause
    - Loki → logs estruturados do pod afetado
           │
           ▼
    5. MITIGAÇÃO (< 15 min para P1)
    Opções de resposta automática:
    - kubectl rollout undo (rollback de deploy)
    - HPA já escala automaticamente sob carga
    - Failover para região DR se necessário
           │
           ▼
    6. RESOLUÇÃO
    - Confirmar recovery via health checks
    - Validar SLO voltou ao verde no Grafana
    - Fechar alerta no Datadog/PagerDuty
           │
           ▼
    7. POST-MORTEM (obrigatório para P1)
    - Documento em 48h
    - Timeline do incidente
    - Root cause analysis (5 Whys)
    - Action items com owner e prazo
    - Comunicação aos stakeholders
```

## Como o AIOps reduz o MTTR

| Ferramenta | Contribuição |
|---|---|
| Datadog Watchdog | Detecta anomalias antes do usuário perceber (proativo) |
| Distributed Tracing | Identifica o serviço exato em segundos (sem grep manual) |
| Prometheus Alerts | Dispara automação de rollback via webhook |
| HPA | Escala automaticamente sob carga — evita indisponibilidade |
| Loki | Logs correlacionados com trace_id — diagnóstico em 1 clique |

**MTTR estimado com a stack**: 8–12 minutos (vs 45–60 min sem observabilidade)
