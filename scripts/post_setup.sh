#!/bin/bash
# post_setup.sh
# Run after SSH into the VM to install Microk8s, Docker, gateway, and required Kubernetes resources.

set -euo pipefail

log() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
fail() { echo -e "\033[1;31m[FAIL]\033[0m $1"; }

log "Sourcing configuration..."
CONFIG_FILE=~/config.properties
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  fail "Configuration file not found at $CONFIG_FILE"
  exit 1
fi

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
sudo snap alias microk8s.kubectl kubectl || warn "Failed to alias kubectl"
sudo snap alias microk8s.helm3 helm || warn "Failed to alias helm"

log "Adding current user to docker and microk8s groups..."
sudo usermod -aG docker $USER
sudo usermod -aG microk8s $USER

warn "Group membership updated. You may need to log out and back in for changes to take effect."

log "Installing cert-manager CRDs..."
microk8s kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.crds.yaml

log "Applying ClusterIssuer..."
microk8s kubectl apply -f ~/k8s/lets-encrypt-prod-issuer.yml

log "Applying nginx ingress service and volumes..."
microk8s kubectl apply -f ~/k8s/nginx-ingress-service.yaml
microk8s kubectl apply -f ~/k8s/pv.yml
microk8s kubectl apply -f ~/k8s/storageclass.yml

log "Installing Akeyless Gateway via Helm..."
microk8s helm3 repo add akeyless https://akeylesslabs.github.io/helm-charts
microk8s helm3 repo update
microk8s helm3 install akeyless-gateway akeyless/gateway -f ~/k8s/gateway-values.yaml

log "Post-setup completed successfully."
