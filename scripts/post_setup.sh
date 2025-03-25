#!/bin/bash
# post_setup.sh
# This script should be run on the VM after SSH-ing into it.
# It installs Microk8s, Docker, configures kubectl, and deploys the Akeyless unified gateway.

set -euo pipefail

log() {
  echo -e "\033[1;32m[INFO]\033[0m $1"
}

error_exit() {
  echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
  exit 1
}

log "Starting Akeyless Gateway post-setup script..."

CONFIG_FILE=~/config.properties
if [ -f "$CONFIG_FILE" ]; then
  log "Sourcing configuration from $CONFIG_FILE"
  source "$CONFIG_FILE"
else
  error_exit "Configuration file $CONFIG_FILE not found."
fi

# Ensure snapd is installed
if ! command -v snap &> /dev/null; then
  log "snap not found. Installing snapd..."
  sudo apt update && sudo apt install -y snapd
  sudo systemctl start snapd
  sudo systemctl enable snapd
  sudo ln -s /var/lib/snapd/snap /snap || true
  export PATH=$PATH:/snap/bin
else
  log "snap is already installed."
fi

# Install Microk8s
if ! command -v microk8s &> /dev/null; then
  log "Installing Microk8s..."
  sudo snap install microk8s --classic || error_exit "Microk8s installation failed"
else
  log "Microk8s already installed."
fi

# Wait for Microk8s availability
log "Waiting for microk8s command to become available to sudo..."
for i in {1..20}; do
  if sudo microk8s status &> /dev/null; then
    log "microk8s is available to sudo."
    break
  fi
  log "Waiting for sudo microk8s... retrying in 5 seconds"
  sleep 5
  if [ $i -eq 20 ]; then
    error_exit "Timed out waiting for sudo microk8s to become available."
  fi
done

# Install Docker
log "Installing Docker..."
sudo snap install docker || error_exit "Failed to install Docker"
sudo groupadd docker || log "Docker group already exists"
sudo usermod -aG docker $USER || error_exit "Failed to add user to docker group"
sudo snap restart docker || log "Failed to restart docker snap"
newgrp docker || log "newgrp docker failed — may need to log out/in"

# Configure kubectl
log "Setting up kube config..."
mkdir -p ~/.kube
sudo microk8s config > ~/.kube/config || error_exit "Failed to create kube config"
sudo usermod -a -G microk8s $USER || error_exit "Failed to add user to microk8s group"
sudo chown -f -R $USER ~/.kube || error_exit "Failed to set ownership on .kube"
newgrp microk8s || log "newgrp microk8s failed — may need to log out/in"

log "Waiting for Microk8s to be fully ready..."
sudo microk8s status --wait-ready || error_exit "Microk8s is not ready"

log "Enabling Microk8s add-ons: dns, storage, and ingress..."
sudo microk8s enable dns storage ingress || error_exit "Failed to enable Microk8s add-ons"

log "Fetching static IP address..."
STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --region="$REGION" --format="value(address)") || error_exit "Failed to fetch static IP"
log "Using static IP: $STATIC_IP"

log "Updating gateway-values.yaml with sslip.io domain..."
sed -i "s/hostname: \".*\.sslip\.io\"/hostname: \"$STATIC_IP.sslip.io\"/" ~/k8s/gateway-values.yaml || error_exit "Failed to update gateway-values.yaml"

log "Creating Kubernetes secret: $GATEWAY_CREDENTIALS_SECRET"
sudo microk8s kubectl create secret generic "$GATEWAY_CREDENTIALS_SECRET" \
  --from-literal=gateway-access-key="$GATEWAY_ACCESS_KEY" || log "Secret already exists or could not be created"

log "Applying Kubernetes manifests..."
for yaml in gateway-values.yaml lets-encrypt-prod-issuer.yml nginx-ingress-service.yaml pv.yml storageclass.yml; do
  log "Applying $yaml"
  sudo microk8s kubectl apply -f ~/k8s/$yaml || error_exit "Failed to apply $yaml"
done

log "Deployment complete! Run the following to verify:"
echo "  sudo microk8s kubectl get all"
