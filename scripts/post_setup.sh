#!/bin/bash
# post_setup.sh
# This script should be run on the VM after SSH-ing into it.
# It installs required Microk8s add-ons and deploys the Akeyless unified gateway configuration.

CONFIG_FILE="$(dirname "$0")/../config/config.properties"
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi

echo "Enabling necessary Microk8s add-ons: dns, storage, and ingress..."
sudo microk8s enable dns storage ingress

echo "Waiting for Microk8s to be fully ready..."
sleep 30

# Add current user to microk8s group
echo "Adding current user to microk8s group and adjusting kube permissions..."
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
newgrp microk8s

# Update gateway-values.yaml with the actual static IP as hostname
STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --region="$REGION" --format="value(address)")
sed -i "s/hostname: \".*\.sslip\.io\"/hostname: \"$STATIC_IP.sslip.io\"/" ~/k8s/gateway-values.yaml

# Create Kubernetes secret for Akeyless gateway authentication
echo "Creating Kubernetes secret: $GATEWAY_CREDENTIALS_SECRET"
sudo microk8s kubectl create secret generic "$GATEWAY_CREDENTIALS_SECRET" \
  --from-literal=gateway-access-key="$GATEWAY_ACCESS_KEY" || true

echo "Deploying Akeyless unified gateway and related resources..."
sudo microk8s kubectl apply -f ~/k8s/gateway-values.yaml
sudo microk8s kubectl apply -f ~/k8s/lets-encrypt-prod-issuer.yml
sudo microk8s kubectl apply -f ~/k8s/nginx-ingress-service.yaml
sudo microk8s kubectl apply -f ~/k8s/pv.yml
sudo microk8s kubectl apply -f ~/k8s/storageclass.yml

echo "Deployment complete. Verify with:"
echo "  sudo microk8s kubectl get all"
