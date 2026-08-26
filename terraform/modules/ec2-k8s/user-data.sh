#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1

apt-get update && apt-get install -y curl git jq unzip

# AWS CLI
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip && ./aws/install && rm -rf aws awscliv2.zip

# Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu

# K3s
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -
sleep 30

mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# kubectl + Helm
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

kubectl create namespace ${project_name}-${environment} || true
kubectl create namespace argocd || true
kubectl create namespace monitoring || true

# ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8080,"nodePort":30090}]}}'

# Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Prometheus
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --set server.service.type=NodePort \
  --set server.service.nodePort=30900 \
  --set server.persistentVolume.enabled=false \
  --set alertmanager.persistentVolume.enabled=false \
  --wait --timeout 5m

# Grafana
helm install grafana grafana/grafana \
  --namespace monitoring \
  --set service.type=NodePort \
  --set service.nodePort=30300 \
  --set adminPassword=admin123 \
  --set persistence.enabled=false \
  --set "datasources.datasources\\.yaml.apiVersion=1" \
  --wait --timeout 5m

# Loki + Promtail
helm install loki grafana/loki \
  --namespace monitoring \
  --set loki.auth_enabled=false \
  --set singleBinary.replicas=1 \
  --set singleBinary.persistence.enabled=false \
  --set monitoring.selfMonitoring.enabled=false \
  --set monitoring.selfMonitoring.grafanaAgent.installOperator=false \
  --set monitoring.lokiCanary.enabled=false \
  --set test.enabled=false \
  --set gateway.enabled=false \
  --set backend.replicas=0 --set read.replicas=0 --set write.replicas=0 \
  --wait --timeout 5m

helm install promtail grafana/promtail \
  --namespace monitoring \
  --set config.clients[0].url=http://loki:3100/loki/api/v1/push \
  --wait --timeout 5m

# Script de setup dos secrets da aplicação
cat > /home/ubuntu/setup-secrets.sh << 'SETUP'
#!/bin/bash
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
PROJECT="${project_name}"
ENV="${environment}"
NS="$PROJECT-$ENV"

get_secret() {
  aws secretsmanager get-secret-value --secret-id "$1" --query SecretString --output text --region $AWS_REGION
}

NGO_SECRET=$(get_secret "$PROJECT-$ENV-ngo-db")
DONATION_SECRET=$(get_secret "$PROJECT-$ENV-donation-db")

NGO_URL="postgresql://$(echo $NGO_SECRET | jq -r '.username'):$(echo $NGO_SECRET | jq -r '.password')@$(echo $NGO_SECRET | jq -r '.endpoint' | cut -d: -f1):5432/$(echo $NGO_SECRET | jq -r '.database')"
DONATION_URL="postgresql://$(echo $DONATION_SECRET | jq -r '.username'):$(echo $DONATION_SECRET | jq -r '.password')@$(echo $DONATION_SECRET | jq -r '.endpoint' | cut -d: -f1):5432/$(echo $DONATION_SECRET | jq -r '.database')"
SQS_URL=$(aws sqs get-queue-url --queue-name $PROJECT-$ENV-solidary-donations --query QueueUrl --output text --region $AWS_REGION)

kubectl create secret generic app-secrets \
  --from-literal=NGO_DATABASE_URL="$NGO_URL" \
  --from-literal=DONATION_DATABASE_URL="$DONATION_URL" \
  --from-literal=AWS_SQS_URL="$SQS_URL" \
  --from-literal=AWS_REGION="$AWS_REGION" \
  --from-literal=DYNAMODB_TABLE="SolidaryTechVolunteers" \
  --namespace $NS \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secrets configurados com sucesso."
SETUP

chmod +x /home/ubuntu/setup-secrets.sh
chown ubuntu:ubuntu /home/ubuntu/setup-secrets.sh
touch /home/ubuntu/setup-complete.txt
