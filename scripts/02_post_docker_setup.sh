#!/bin/bash

set -euo pipefail

LOG_FILE="/var/log/akeyless-post-setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a $LOG_FILE) 2>&1

log() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
fail() { echo -e "\033[1;31m[FAIL]\033[0m $1"; }

log "Logging to $LOG_FILE"
# CONFIG_FILE=~/config.properties
# if [ -f "$CONFIG_FILE" ]; then
#   source "$CONFIG_FILE"
# else
#   fail "Configuration file not found at $CONFIG_FILE"
#   exit 1
# fi

CONFIG_FILE=~/config.properties

if [[ -f "$CONFIG_FILE" ]]; then
  log "Loading config from $CONFIG_FILE"
  set -o allexport
  source "$CONFIG_FILE"
  set +o allexport
else
  log "ERROR: Config file $CONFIG_FILE not found."
  exit 1
fi

log "Checking if snap is installed..."
if ! command -v snap >/dev/null 2>&1; then
  log "Snap not found. Installing snapd..."
  sudo apt update && sudo apt install -y snapd
  sudo systemctl enable --now snapd.socket
fi

if [ -z "${STATIC_IP:-}" ]; then
  fail "STATIC_IP not set in config.properties"
  exit 1
fi

DOMAIN="${STATIC_IP//./-}.sslip.io"
log "Using domain: $DOMAIN"

log "Ensuring snap path..."
sudo ln -s /var/lib/snapd/snap /snap || true
export PATH=$PATH:/snap/bin

log "Creating kube config..."
mkdir -p ~/.kube
microk8s config > ~/.kube/config

microk8s status --wait-ready

log "Creating aliases for kubectl and helm3..."
sudo snap alias microk8s.kubectl kubectl || true
sudo snap alias microk8s.helm3 helm || true

log "Enable MicroK8s addons..."
microk8s enable dns
microk8s enable ingress
kubectl delete ingressclass public
microk8s enable helm3
microk8s enable cert-manager --set crds.enabled=true --set global.leaderElection.namespace=cert-manager

log "Installing Kubectx and configuring..."
sudo snap install kubectx --classic
echo 'export KUBECONFIG=/var/snap/microk8s/current/credentials/client.config' >> ~/.bashrc

log "Setting up kubectl aliases..."
curl -sSL https://raw.githubusercontent.com/ahmetb/kubectl-aliases/master/.kubectl_aliases -o ~/.kubectl_aliases

# Add to .bashrc if not already present
if ! grep -q 'source ~/.kubectl_aliases' ~/.bashrc; then
    echo '[ -f ~/.kubectl_aliases ] && source ~/.kubectl_aliases' >> ~/.bashrc
    log "Appended kubectl aliases to ~/.bashrc"
else
    log "kubectl aliases already present in ~/.bashrc"
fi

# Set KUBECONFIG for Microk8s
if ! grep -q 'KUBECONFIG=' ~/.bashrc; then
    echo 'export KUBECONFIG=/var/snap/microk8s/current/credentials/client.config' >> ~/.bashrc
    log "Appended KUBECONFIG to ~/.bashrc"
fi

log "Creating namespacess..."
microk8s kubectl create namespace my-apps
microk8s kubectl create namespace k8sinjector
microk8s kubectl create namespace akeyless

log "Applying Nginx ingress..."
microk8s kubectl apply -f ~/k8s/nginx-ingress-service.yaml

log "Applying Let's Encrypt Certificate issuer..."
microk8s kubectl apply -f ~/k8s/lets-encrypt-prod-issuer.yml

log "Adding helm repositories..."
helm repo add akeyless https://akeylesslabs.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

log "Verifying the public IP assignment..."
microk8s kubectl get services -n ingress

log "Sourcing config file...."
# source "$CONFIG_FILE"

if [[ -z "${GATEWAY_CREDENTIALS_SECRET:-}" || -z "${GATEWAY_ACCESS_ID:-}" || -z "${GATEWAY_ACCESS_KEY:-}" ]]; then
  fail "❌ One or more required variables (GATEWAY_CREDENTIALS_SECRET, GATEWAY_ACCESS_ID, GATEWAY_ACCESS_KEY) are missing or empty"
  exit 1
fi

echo "Using GATEWAY_ACCESS_ID=$GATEWAY_ACCESS_ID"

# Check for missing variables
if [[ -z "$GATEWAY_CREDENTIALS_SECRET" || -z "$GATEWAY_ACCESS_ID" || -z "$GATEWAY_ACCESS_KEY" ]]; then
  echo "❌ One or more required variables are missing in config.properties"
  exit 1
fi

echo "🔐 Creating Kubernetes secret: $GATEWAY_CREDENTIALS_SECRET in namespace 'akeyless'"

microk8s kubectl create secret generic "$GATEWAY_CREDENTIALS_SECRET" \
  --namespace akeyless \
  --from-literal=gateway-access-key="$GATEWAY_ACCESS_KEY" 

echo "✅ Secret created successfully."
microk8s kubectl get secret access-key -n akeyless -o yaml

log "Patching gateway-values.yaml with domain: $DOMAIN"

# Patch hostname inside gateway-values.yaml
sed -i "s|^\( *host:\).*|\\1 $DOMAIN|" ~/k8s/gateway-values.yaml

# Patch the TLS secret name based on domain (dots replaced with dashes)
sed -i "s|^\( *secretName:\).*|\\1 ${DOMAIN//./-}-tls|" ~/k8s/gateway-values.yaml

# Patch the hosts array if it's in the form '- something.sslip.io'
sed -i "s|^\( *- \).*\.sslip\.io|\\1$DOMAIN|" ~/k8s/gateway-values.yaml


log "Installing the unified gateway..."
helm install akl-gcp-gw akeyless/akeyless-gateway -n akeyless -f k8s/gateway-values.yaml

log "Checking pod status..."
microk8s kubectl get pods -n akeyless
microk8s kubectl describe pod -n akeyless -l app.kubernetes.io/name=akeyless-gateway

log "Post-setup completed successfully."
log "Please run 'source ~/.bashrc' or open a new shell session to apply the alias and KUBECONFIG changes."
