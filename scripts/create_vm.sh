#!/bin/bash

set -euo pipefail

CONFIG_FILE="./config/config.properties"
NGINX_FILE="./k8s/nginx-ingress-service.yaml"

log() { echo -e "\033[1;32m[INFO]\033[0m $1"; }

log "Loading configuration from $CONFIG_FILE..."
source "$CONFIG_FILE"

log "Authenticating with gcloud..."
gcloud auth activate-service-account --key-file="$GCLOUD_CREDENTIALS_JSON"
gcloud config set project "$PROJECT_ID"

log "Checking if static IP already exists..."
EXISTING_IP=$(gcloud compute addresses list --filter="name=($STATIC_IP_NAME)" --regions="$REGION" --format="value(address)" || true)

if [ -z "$EXISTING_IP" ]; then
  log "Creating new static IP..."
  gcloud compute addresses create "$STATIC_IP_NAME" --region="$REGION"
  STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --region="$REGION" --format="value(address)")
else
  log "Using existing static IP..."
  STATIC_IP="$EXISTING_IP"
fi

log "Saving STATIC_IP to config.properties..."
if grep -q '^STATIC_IP=' "$CONFIG_FILE"; then
  sed -i "s|^STATIC_IP=.*|STATIC_IP=$STATIC_IP|" "$CONFIG_FILE"
else
  echo "STATIC_IP=$STATIC_IP" >> "$CONFIG_FILE"
fi

log "Patching nginx-ingress-service.yaml with STATIC_IP..."
sed -i "s|externalIPs:.*|externalIPs:\n  - $STATIC_IP|" "$NGINX_FILE"

log "Creating VM instance..."
gcloud compute instances create "$INSTANCE_NAME" \
  --zone="$ZONE" \
  --machine-type="$MACHINE_TYPE" \
  --image-family="$IMAGE_FAMILY" \
  --image-project="debian-cloud" \
  --address="$STATIC_IP" \
  --network-tier=PREMIUM

log "VM creation complete."
