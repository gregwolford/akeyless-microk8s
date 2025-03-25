#!/bin/bash
# post_setup.sh
# This script should be run on the VM after SSH-ing into it.
# It installs Microk8s and deploys the Akeyless unified gateway configuration.

CONFIG_FILE=~/config.properties
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi

# Ensure snapd is installed (required for Microk8s)
if ! command -v snap &> /dev/null; then
  echo "Snap not found. Installing snapd..."
  sudo apt update && sudo apt install -y snapd
  sudo systemctl start snapd
  sudo systemctl enable snapd
  sudo ln -s /var/lib/snapd/snap /snap || true
  export PATH=$PATH:/snap/bin
fi

# Install Microk8s if not already present
if ! command -v microk8s &> /dev/null; then
  echo "Installing Microk8s..."
  sudo snap install microk8s --classic
fi

# Wait until microk8s becomes available
echo "Waiting for microk8s command to become available..."
for i in {1..20}; do
  if command -v microk8s &> /dev/null; then
    echo "microk8s is ready!"
    break
  fi
  echo "microk8s not found yet... retrying in 5 seconds"
  sleep 5
done

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
