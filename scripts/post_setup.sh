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

log "Installing Docker..."
# sudo apt update && sudo apt install -y docker.io
sudo snap install docker --classic
log "Adding current user to docker group (if not already)..."
if ! getent group docker > /dev/null; then
    sudo groupadd docker
fi
sudo usermod -aG docker $USER

log "NOTE: You must log out and back in (or reboot) for Docker group changes to take effect."

