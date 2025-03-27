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

log "Installing Microk8s if not already present..."
if ! command -v microk8s &>/dev/null; then
  sudo snap install microk8s --classic
fi

# Ensure /snap/bin is in PATH for this script
  export PATH=$PATH:/snap/bin

# Wait for microk8s to be ready
#   log "Waiting for Microk8s to become available..."
#   until microk8s status --wait-ready >/dev/null 2>&1; do
#     sleep 2
#   done
# fi

# log "Adding Current user to microk8s groups if not already..."
# if ! getent group microk8s > /dev/null; then
#     sudo usermod -a -G microk8s $USER
# fi

log "Installing Docker..."
# sudo apt update && sudo apt install -y docker.io
sudo snap install docker --classic
log "Adding current user to docker group (if not already)..."
if ! getent group docker > /dev/null; then
    sudo groupadd docker
fi

log "NOTE: Run 'sudo usermod -a -G microk8s $USER', 'sudo chown -f -R $USER ~/.kube', and 'sudo usermod -aG docker $USER', then log out and log back in for group changes to take effect."

