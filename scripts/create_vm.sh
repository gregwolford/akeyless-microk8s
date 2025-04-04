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
  --network-interface=address="$STATIC_IP,network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=example-subnet" \
  --maintenance-policy="MIGRATE" \
  --provisioning-model="STANDARD" \
  --service-account="$SERVICE_ACCOUNT" \
  --scopes="https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append" \
  --tags="my-inbound-rules,allow-all-outbound,http-server,https-server,ssh-server" \
  --create-disk="auto-delete=yes,boot=yes,device-name=example-lab-base-image-disk,image=projects/ubuntu-os-cloud/global/images/ubuntu-2404-noble-amd64-v20250130,mode=rw,size=200,type=pd-balanced" \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --labels="goog-ec-src=vm_add-gcloud,always_up=false,owner=$OWNER,skip_shutdown=false,tf_created=false" \
  --reservation-affinity=any
  #--image-family="$IMAGE_FAMILY" \
  #--image-project="debian-cloud" \
  #--address="$STATIC_IP" \
  #--network-tier=PREMIUM

log "VM creation complete."

log "Uploading files to VM..."
gcloud compute scp --zone=us-central1-c --recurse k8s config/config.properties scripts/01_pre_docker_setup.sh scripts/02_post_docker_setup.sh my-microk8s-vm:~
