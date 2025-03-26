#!/bin/bash

set -euo pipefail

LOG_FILE="/var/log/akeyless-post-setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a $LOG_FILE) 2>&1

log() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
fail() { echo -e "\033[1;31m[FAIL]\033[0m $1"; }

log "Logging to $LOG_FILE"
CONFIG_FILE=~/config.properties
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  fail "Configuration file not found at $CONFIG_FILE"
  exit 1
fi

if [ -z "${STATIC_IP:-}" ]; then
  fail "STATIC_IP not set in config.properties"
  exit 1
fi

DOMAIN="${STATIC_IP//./-}.sslip.io"
log "Using domain: $DOMAIN"

log "Installing Microk8s if not already present..."
if ! command -v microk8s &>/dev/null; then
  sudo snap install microk8s --classic
fi

log "Installing Docker..."
sudo apt update && sudo apt install -y docker.io

log "Ensuring snap path..."
sudo ln -s /var/lib/snapd/snap /snap || true
export PATH=$PATH:/snap/bin

log "Creating kube config..."
mkdir -p ~/.kube
microk8s config > ~/.kube/config
sudo chown -R $USER ~/.kube

log "Creating aliases for kubectl and helm3..."
sudo snap alias microk8s.kubectl kubectl || true
sudo snap alias microk8s.helm3 helm || true

log "Adding current user to docker and microk8s groups..."
sudo usermod -aG docker $USER
sudo usermod -aG microk8s $USER

if ! groups $USER | grep -qw microk8s; then
  warn "User $USER added to microk8s group. You must log out and back in for this to take effect."
fi

log "Installing cert-manager CRDs..."
microk8s kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.crds.yaml

log "Applying ClusterIssuer..."
microk8s kubectl apply -f ~/k8s/lets-encrypt-prod-issuer.yml

log "Applying Nginx ingress and storage resources..."
microk8s kubectl apply -f ~/k8s/nginx-ingress-service.yaml
microk8s kubectl apply -f ~/k8s/pv.yml
microk8s kubectl apply -f ~/k8s/storageclass.yml

log "Patching gateway-values.yaml with domain: $DOMAIN"
sed -i "s|host:.*|host: $DOMAIN|" ~/k8s/gateway-values.yaml
sed -i "s|secretName:.*|secretName: ${DOMAIN//./-}-tls|" ~/k8s/gateway-values.yaml
sed -i "s|- .*.sslip.io|- $DOMAIN|" ~/k8s/gateway-values.yaml

log "Adding Helm repositories..."
microk8s helm3 repo add akeyless https://akeylesslabs.github.io/helm-charts || true
microk8s helm3 repo add bitnami https://charts.bitnami.com/bitnami || true
microk8s helm3 repo update

log "Installing Akeyless Unified Gateway with domain: $DOMAIN"
microk8s helm3 install akl-gcp-gw akeyless/akeyless-gateway -n akeyless -f ~/k8s/gateway-values.yaml --create-namespace

log "Post-setup completed successfully."
