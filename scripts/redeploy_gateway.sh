#!/bin/bash

set -euo pipefail

CYAN="\033[1;36m"
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

info() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

info "Redeploying Akeyless Gateway..."

CONFIG_FILE=~/config.properties
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  fail "Missing config.properties file"
  exit 1
fi

info "Installing cert-manager CRDs..."
microk8s kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.crds.yaml

info "Applying ClusterIssuer..."
microk8s kubectl apply -f ~/k8s/lets-encrypt-prod-issuer.yml

info "Applying Nginx ingress and volume resources..."
microk8s kubectl apply -f ~/k8s/nginx-ingress-service.yaml
microk8s kubectl apply -f ~/k8s/pv.yml
microk8s kubectl apply -f ~/k8s/storageclass.yml

info "Updating Helm repo and deploying gateway..."
microk8s helm3 repo add akeyless https://akeylesslabs.github.io/helm-charts || true
microk8s helm3 repo update
microk8s helm3 upgrade --install akeyless-gateway akeyless/gateway -f ~/k8s/gateway-values.yaml

success "Akeyless Gateway redeployment completed."
