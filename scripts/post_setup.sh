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

log "Checking if snap is installed..."
if ! command -v snap >/dev/null 2>&1; then
  log "Snap not found. Installing snapd..."
  sudo apt update && sudo apt install -y snapd
  sudo systemctl enable --now snapd.socket
fi

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
# sudo apt update && sudo apt install -y docker.io
sudo snap install docker --classic
log "Adding current user to docker..."
sudo groupadd docker
sudo usermod -aG docker $USER
sudo snap restart docker
newgrp docker

log "Ensuring snap path..."
sudo ln -s /var/lib/snapd/snap /snap || true
export PATH=$PATH:/snap/bin

log "Creating kube config..."
mkdir -p ~/.kube
microk8s config > ~/.kube/config
log "Adding current user to docker and microk8s groups..."
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
newgrp microk8s
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

# if ! groups $USER | grep -qw microk8s; then
#   warn "User $USER added to microk8s group. You must log out and back in for this to take effect."
# fi

log "Installing Kubectx and configuring..."
sudo snap install kubectx --classic
echo 'export KUBECONFIG=/var/snap/microk8s/current/credentials/client.config' >> ~/.bashrc

log "Adding kubectl aliases..."
curl -sSL https://raw.githubusercontent.com/ahmetb/kubectl-aliases/master/.kubectl_aliases -o ~/.kubectl_aliases && grep -qxF '[ -f ~/.kubectl_aliases ] && source ~/.kubectl_aliases' ~/.bashrc || echo '[ -f ~/.kubectl_aliases ] && source ~/.kubectl_aliases' >> ~/.bashrc
export KUBECONFIG=/var/snap/microk8s/current/credentials/client.config
source ~/.bashrc

log "Creating namespacess..."
k create namespace my-apps
k create namespace k8sinjector

# log "Installing cert-manager CRDs..."
# microk8s kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.crds.yaml

log "Applying Nginx ingress..."
microk8s kubectl apply -f ~/k8s/nginx-ingress-service.yaml

log "Applying Let's Encrypt Certificate issuer..."
microk8s kubectl apply -f ~/k8s/lets-encrypt-prod-issuer.yml

log "Adding helm repositories..."
helm repo add akeyless https://akeylesslabs.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

log "Verifying the public IP assignment..."
kubectl get services -n ingress

log "Patching gateway-values.yaml with domain: $DOMAIN"
sed -i "s|host:.*|host: $DOMAIN|" ~/k8s/gateway-values.yaml
sed -i "s|secretName:.*|secretName: ${DOMAIN//./-}-tls|" ~/k8s/gateway-values.yaml
sed -i "s|- .*.sslip.io|- $DOMAIN|" ~/k8s/gateway-values.yaml

log "Installing the unified gateway..."
helm install akl-gcp-gw akeyless/akeyless-gateway -n akeyless -f gateway-values.yaml

# log "Ensuring 'ingress' namespace exists..."
# if ! microk8s kubectl get namespace ingress >/dev/null 2>&1; then
#   microk8s kubectl create namespace ingress
#   log "'ingress' namespace created."
# fi

# log "Modifying the NGINX ConfigMap..."
# kubectl get ingress -A
# kubectl get configmap <ingress name> -n ingress -o yaml > nginx-configmap.yaml

# log "Creating a Persistent Volume and Storage Class..."
# microk8s kubectl apply -f ~/k8s/pv.yml
# microk8s kubectl apply -f ~/k8s/storageclass.yml


# log "Adding Helm repositories..."
# microk8s helm3 repo add akeyless https://akeylesslabs.github.io/helm-charts || true
# microk8s helm3 repo add bitnami https://charts.bitnami.com/bitnami || true
# microk8s helm3 repo update

# log "Installing Akeyless Unified Gateway with domain: $DOMAIN"
# microk8s helm3 install akl-gcp-gw akeyless/akeyless-gateway -n akeyless -f ~/k8s/gateway-values.yaml --create-namespace

log "Post-setup completed successfully."
