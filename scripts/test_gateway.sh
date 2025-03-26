#!/bin/bash

set -euo pipefail

log() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
fail() { echo -e "\033[1;31m[FAIL]\033[0m $1"; }

log "🔍 Checking Akeyless Gateway Deployment in 'akeyless' namespace..."

PODS=$(microk8s kubectl get pods -n akeyless --no-headers 2>/dev/null | grep akeyless-gateway || true)

if [[ -z "$PODS" ]]; then
  fail "No gateway pod found in 'akeyless' namespace"
else
  echo "$PODS"
  if echo "$PODS" | grep -q 'CreateContainerConfigError'; then
    fail "Pods exist but failed to start due to CreateContainerConfigError"
    echo
    echo "👉 To investigate the issue, try:"
    echo "   microk8s kubectl describe pod <pod-name> -n akeyless"
    echo "   microk8s kubectl logs <pod-name> -n akeyless"
    echo
    echo "⚠️  This typically means the secret or image config is incorrect. Ensure:"
    echo "- Your GATEWAY_CREDENTIALS_SECRET exists in namespace 'akeyless'"
    echo "- The access key is correctly base64 encoded and mounted"
  else
    log "Gateway pod(s) detected and appear to be running."
  fi
fi

log "Checking Services in 'akeyless' namespace..."
microk8s kubectl get svc -n akeyless || warn "No services found in 'akeyless'"

log "Checking Ingress in 'akeyless' namespace..."
microk8s kubectl get ingress -n akeyless || warn "No Ingress resources found in 'akeyless'"

log "Note: The Akeyless Gateway is installed in the 'akeyless' namespace."
