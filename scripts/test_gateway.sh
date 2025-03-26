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
info "🔍 Checking Akeyless Gateway Deployment..."

# Check pods
PODS=$(microk8s kubectl get pods --no-headers | grep gateway || true)
if [ -n "$PODS" ]; then
  echo "$PODS"
  if echo "$PODS" | grep -q "Running"; then
    success "Gateway pod is running"
  else
    fail "Gateway pod exists but is not running. Check logs with: microk8s kubectl logs <gateway-pod-name>"
  fi
else
  fail "No gateway pod found"
fi

# Check services
info "Checking Kubernetes Services..."
microk8s kubectl get svc

# Check ingress
info "Checking Kubernetes Ingress..."
microk8s kubectl get ingress

# Show ingress URL if exists
INGRESS_URL=$(microk8s kubectl get ingress -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || true)
if [ -n "$INGRESS_URL" ]; then
  success "Gateway ingress hostname: $INGRESS_URL"
  info "Testing connectivity..."
  curl -k --max-time 10 https://$INGRESS_URL || fail "Failed to reach ingress at $INGRESS_URL"
else
  warn "No Ingress hostname configured"
fi

echo
info "✅ Gateway test completed"
