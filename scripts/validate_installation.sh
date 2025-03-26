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

# Ensure microk8s is accessible in the path
if [ ! -f /usr/local/bin/microk8s ]; then
  sudo ln -s /snap/bin/microk8s /usr/local/bin/microk8s || true
  info "Linked /snap/bin/microk8s to /usr/local/bin/microk8s"
fi

# Validate Microk8s
if sudo microk8s status --wait-ready &>/dev/null; then
  success "Microk8s is running and ready"
else
  fail "Microk8s is not running properly"
fi

# Enable required addons
REQUIRED_ADDONS=(dns ingress storage)
for addon in "${REQUIRED_ADDONS[@]}"; do
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

# Attempt Docker socket access
DOCKER_SOCKET_OK=false
if docker info &>/dev/null; then
  success "Docker socket is accessible"
  DOCKER_SOCKET_OK=true
else
  fail "Docker socket permission denied"
  info "Trying to fix Docker socket permission..."
  sudo usermod -aG docker "$USER"
  sleep 2
  if docker info &>/dev/null; then
    success "Docker socket now accessible"
    DOCKER_SOCKET_OK=true
  else
    warn "Still cannot access Docker socket – your session likely needs to be restarted"
  fi
fi

# Check if docker group is in current session
GROUPS=$(groups $USER)
info "Current groups for $USER: $GROUPS"
[[ "$GROUPS" == *docker* ]] && success "User is in docker group" || warn "User not in docker group in current session (may require logout)"
[[ "$GROUPS" == *microk8s* ]] && success "User is in microk8s group" || sudo usermod -aG microk8s $USER

if ! $DOCKER_SOCKET_OK; then
  warn "Docker socket still inaccessible. Try running:"
  echo "    newgrp docker"
  echo "    OR log out and log back in to refresh group membership"
fi

# Check kube config
if [ -f ~/.kube/config ]; then
  success "~/.kube/config found"
else
  info "Generating ~/.kube/config from microk8s..."
  mkdir -p ~/.kube
  microk8s config > ~/.kube/config && success "kube config created" || fail "Failed to generate kube config"
fi

# Check kubectl access
if microk8s kubectl get nodes &>/dev/null; then
  success "kubectl can access the cluster"
else
  fail "kubectl cannot access the cluster"
fi

# Check Kubernetes resources
info "Checking Kubernetes resources in default namespace..."
microk8s kubectl get all -n default

# Check secret
CONFIG_FILE=~/config.properties
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
  info "Checking for Kubernetes secret: $GATEWAY_CREDENTIALS_SECRET"
  SECRET=$(microk8s kubectl get secret "$GATEWAY_CREDENTIALS_SECRET" -o json 2>/dev/null || echo "")
  if [[ "$SECRET" == *"gateway-access-key"* ]]; then
    success "Akeyless gateway secret exists and is valid"
  else
    fail "Akeyless gateway secret is missing or misconfigured"
  fi
else
  fail "Configuration file not found at ~/config.properties – cannot check secret"
fi

echo
info "✅ Auto-Fix Validation Complete"
