#!/bin/bash
# rollback_setup.sh
# Rolls back everything installed by post_setup.sh to return the system to a clean state

set -euo pipefail

log() { echo -e "\033[1;31m[ROLLBACK]\033[0m $1"; }

log "Rolling back Akeyless Gateway deployment..."

# Delete Helm release
if microk8s helm3 list -n akeyless | grep -q akl-gcp-gw; then
  microk8s helm3 uninstall akl-gcp-gw -n akeyless
fi

# Delete Kubernetes resources
log "Deleting k8s gateway-related resources..."
microk8s kubectl delete -f ~/k8s/lets-encrypt-prod-issuer.yml --ignore-not-found
microk8s kubectl delete -f ~/k8s/nginx-ingress-service.yaml --ignore-not-found
microk8s kubectl delete -f ~/k8s/pv.yml --ignore-not-found
microk8s kubectl delete -f ~/k8s/storageclass.yml --ignore-not-found
microk8s kubectl delete namespace akeyless --ignore-not-found

# Remove cert-manager CRDs
log "Removing cert-manager CRDs..."
for crd in certificaterequests.cert-manager.io certificates.cert-manager.io challenges.acme.cert-manager.io \
           clusterissuers.cert-manager.io issuers.cert-manager.io orders.acme.cert-manager.io; do
  microk8s kubectl delete crd $crd --ignore-not-found
done

# Remove Helm repos
log "Removing Helm repositories..."
microk8s helm3 repo remove akeyless || true
microk8s helm3 repo remove bitnami || true

# Remove aliases
log "Removing snap aliases..."
sudo snap unalias kubectl || true
sudo snap unalias helm || true

# Remove kube config
log "Removing kube config..."
rm -rf ~/.kube

# Optional: Remove Microk8s and Docker
log "Uninstalling Microk8s and Docker..."
sudo snap remove microk8s || true
sudo apt purge -y docker.io || true
sudo apt autoremove -y

# Remove user from docker and microk8s groups (must relogin for effect)
log "Removing user from docker and microk8s groups..."
sudo gpasswd -d $USER docker || true
sudo gpasswd -d $USER microk8s || true

log "Rollback complete. You may want to restart your shell or log out/in."
