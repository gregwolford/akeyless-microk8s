#!/bin/bash

set -euo pipefail

CYAN="\033[1;36m"
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

info() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo
info "🔧 Running Auto-Fix Validation for Akeyless Gateway Environment..."

# Load config file
CONFIG_FILE=~/config.properties
if [ -f "$CONFIG_FILE" ]; then
  info "Sourcing configuration from $CONFIG_FILE"
  source "$CONFIG_FILE"
  echo "GATEWAY_CREDENTIALS_SECRET is set to: $GATEWAY_CREDENTIALS_SECRET"
else
  fail "Configuration file not found at $CONFIG_FILE – cannot validate or create secrets"
  exit 1
fi

# Ensure microk8s is in the path
if [ ! -f /usr/local/bin/microk8s ]; then
  sudo ln -s /snap/bin/microk8s /usr/local/bin/microk8s || true
  info "Linked /snap/bin/microk8s to /usr/local/bin/microk8s"
fi

# Check microk8s status
if sudo microk8s status --wait-ready &>/dev/null; then
  success "Microk8s is running and ready"
else
  fail "Microk8s is not running properly"
fi

# Enable required addons
for addon in dns ingress storage; do
  if microk8s status | grep -A 100 'addons:' | grep enabled | grep -q "$addon"; then
    success "$addon addon is enabled"
  else
    info "Enabling Microk8s addon: $addon"
    sudo microk8s enable "$addon" && success "$addon enabled" || fail "Failed to enable $addon"
  fi
done

# Check Docker
info "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
  fail "Docker is not installed – please install Docker manually or re-run post_setup.sh"
else
  success "Docker is installed"
fi

# Docker socket access
if docker info &>/dev/null; then
  success "Docker socket is accessible"
else
  warn "Docker socket permission denied. Try 'newgrp docker' or log out and log back in."
fi

# kubeconfig check
if [ -f ~/.kube/config ]; then
  success "~/.kube/config found"
else
  info "Generating ~/.kube/config from microk8s..."
  mkdir -p ~/.kube
  microk8s config > ~/.kube/config && success "kube config created" || fail "Failed to generate kube config"
fi

# Cluster access check
if microk8s kubectl get nodes &>/dev/null; then
  success "kubectl can access the cluster"
else
  fail "kubectl cannot access the cluster"
fi

# Secret validation or creation
info "Checking for Kubernetes secret: $GATEWAY_CREDENTIALS_SECRET"
SECRET_OUTPUT=$(microk8s kubectl get secret "$GATEWAY_CREDENTIALS_SECRET" -o json 2>/dev/null || echo "")
if [[ "$SECRET_OUTPUT" == *"gateway-access-key"* ]]; then
  success "Akeyless gateway secret exists and is valid"
else
  warn "Secret missing or misconfigured – attempting to create it..."
  microk8s kubectl delete secret "$GATEWAY_CREDENTIALS_SECRET" 2>/dev/null || true
  microk8s kubectl create secret generic "$GATEWAY_CREDENTIALS_SECRET" \
    --from-literal=gateway-access-key="$GATEWAY_ACCESS_KEY" && success "Secret created successfully" || fail "Failed to create secret"
fi

echo
info "✅ Auto-Fix Validation Complete"
