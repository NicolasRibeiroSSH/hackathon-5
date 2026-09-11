#!/bin/bash
# Teste de Resiliência e Carga — SolidaryTech
# Valida: HPA, auto-recovery, SLO metrics

EC2_IP="98.89.162.183"
NAMESPACE="solidarytech"
KUBECTL="sudo k3s kubectl"

echo "============================================"
echo " SolidaryTech — Teste de Resiliência"
echo "============================================"

# 1. Health check baseline
echo ""
echo "=== 1. Health Check Baseline ==="
for svc in "30081/health" "30082/health" "30083/health"; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$EC2_IP:$svc 2>/dev/null || echo "FAIL")
  PORT=$(echo $svc | cut -d/ -f1)
  echo "  Port $PORT: HTTP $STATUS"
done

# 2. Teste de carga leve (donation-service)
echo ""
echo "=== 2. Carga no donation-service (50 requests) ==="
SUCCESS=0; FAIL=0
for i in $(seq 1 50); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST http://$EC2_IP:30082/donations \
    -H "Content-Type: application/json" \
    -d "{\"ngo_id\":1,\"amount\":10.0,\"donor_name\":\"Test $i\"}" 2>/dev/null)
  if [ "$CODE" = "201" ] || [ "$CODE" = "500" ]; then
    SUCCESS=$((SUCCESS+1))
  else
    FAIL=$((FAIL+1))
  fi
done
echo "  Sucesso: $SUCCESS | Falha: $FAIL"
RATE=$(echo "scale=1; $SUCCESS * 100 / 50" | bc)
echo "  Taxa de sucesso: $RATE%"

# 3. Teste de auto-recovery
echo ""
echo "=== 3. Teste de Auto-Recovery (delete pod) ==="
ssh -i ~/.ssh/solidarytech-key.pem -o StrictHostKeyChecking=no ubuntu@$EC2_IP "
  POD=\$($KUBECTL get pod -n $NAMESPACE -l app=ngo-service -o jsonpath='{.items[0].metadata.name}')
  echo '  Pod antes: '\$POD
  $KUBECTL delete pod \$POD -n $NAMESPACE --grace-period=0 --force 2>/dev/null
  echo '  Pod deletado. Aguardando recovery...'
  sleep 15
  NEW_POD=\$($KUBECTL get pod -n $NAMESPACE -l app=ngo-service -o jsonpath='{.items[0].metadata.name}')
  STATUS=\$($KUBECTL get pod \$NEW_POD -n $NAMESPACE -o jsonpath='{.status.phase}')
  echo '  Novo pod: '\$NEW_POD' — Status: '\$STATUS
" 2>/dev/null

# 4. Verificar HPA
echo ""
echo "=== 4. Status dos HPAs ==="
ssh -i ~/.ssh/solidarytech-key.pem -o StrictHostKeyChecking=no ubuntu@$EC2_IP \
  "$KUBECTL get hpa -n $NAMESPACE" 2>/dev/null

# 5. Verificar PDBs
echo ""
echo "=== 5. Status dos PDBs ==="
ssh -i ~/.ssh/solidarytech-key.pem -o StrictHostKeyChecking=no ubuntu@$EC2_IP \
  "$KUBECTL get pdb -n $NAMESPACE" 2>/dev/null

# 6. Verificar métricas Prometheus
echo ""
echo "=== 6. Métricas SLO no Prometheus ==="
PROM="http://$EC2_IP:30090"
UP=$(curl -s "$PROM/api/v1/query?query=up{job=~'ngo-service|donation-service|volunteer-service'}" \
  | python3 -c "import json,sys; r=json.load(sys.stdin)['data']['result']; [print('  ',x['metric']['job'],'->', x['value'][1]) for x in r]" 2>/dev/null)
echo "$UP"

echo ""
echo "============================================"
echo " Teste concluído"
echo "============================================"
