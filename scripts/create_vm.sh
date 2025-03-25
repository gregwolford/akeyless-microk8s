#!/bin/bash
# create_vm.sh
# Script to provision a GCP VM using gcloud CLI.
gcloud components update --quiet
gcloud auth activate-service-account --key-file "$GCLOUD_CREDENTIALS_JSON"
# It loads configuration variables from config/config.properties.

# Determine the path to the config file (assumes script is in scripts/)
CONFIG_FILE="$(dirname "$0")/../config/config.properties"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Configuration file not found at $CONFIG_FILE"
  exit 1
fi

# Load configuration variables
source "$CONFIG_FILE"

echo "Setting GCP project to: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

echo "Creating VM instance: $INSTANCE_NAME in zone: $ZONE"
gcloud compute instances create "$INSTANCE_NAME" \
  --zone="$ZONE" \
  --machine-type="$MACHINE_TYPE" \
  --image-family="$IMAGE_FAMILY" \
  --image-project="debian-cloud" \
  --metadata=startup-script='#!/bin/bash
    # Install Microk8s and add the current user to the microk8s group
    sudo snap install microk8s --classic
    sudo usermod -a -G microk8s $USER
    sudo chown -f -R $USER ~/.kube
  '

echo "VM creation initiated. Please wait for the VM to be ready before proceeding."