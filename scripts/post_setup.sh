#!/bin/bash
# post_setup.sh
# This script should be run on the VM after SSH-ing into it.
# It installs required Microk8s add-ons and deploys the Akeyless unified gateway configuration.

# Optionally, load configuration if needed
CONFIG_FILE="$(dirname "$0")/../config/config.properties"
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi

echo "Enabling necessary Microk8s add-ons: dns, storage, and ingress..."
sudo microk8s enable dns storage ingress

echo "Waiting for Microk8s to be fully ready..."
sleep 30

echo "Deploying Akeyless unified gateway and related resources..."

# Adjust the path if you copied the k8s folder into your home directory or another location
sudo microk8s kubectl apply -f ~/k8s/gateway-values.yaml
sudo microk8s kubectl apply -f ~/k8s/lets-encrypt-prod-issuer.yml
sudo microk8s kubectl apply -f ~/k8s/nginx-ingress-service.yaml
sudo microk8s kubectl apply -f ~/k8s/pv.yml
sudo microk8s kubectl apply -f ~/k8s/storageclass.yml

echo "Deployment complete. Verify with:"
echo "  sudo microk8s kubectl get all"
