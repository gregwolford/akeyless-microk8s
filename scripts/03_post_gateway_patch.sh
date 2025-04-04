#!/bin/bash

set -e

echo "=== Post-Gateway Patch Script ==="

# Ensure yq is installed
if ! command -v yq &> /dev/null; then
  echo "yq not found. Installing yq..."
  sudo snap install yq
else
  echo "yq is already installed."
fi

echo "=== Updating NGINX ConfigMap for header size limits ==="

# Find the ConfigMap
CONFIGMAP_NAME=$(microk8s kubectl get configmap -n ingress -o jsonpath="{.items[?(@.metadata.name=='nginx-load-balancer-microk8s-conf')].metadata.name}")
if [[ -z "$CONFIGMAP_NAME" ]]; then
  echo "Error: Could not find the NGINX ConfigMap in the ingress namespace."
  exit 1
fi

echo "Found configmap: $CONFIGMAP_NAME"

TMPFILE=$(mktemp)

# Dump current config map
microk8s kubectl get configmap "$CONFIGMAP_NAME" -n ingress -o yaml > "$TMPFILE"

# Patch `data` fields using yq
yq e '.data."large-client-header-buffers" = "4 64k"' -i "$TMPFILE"
yq e '.data."client-header-buffer-size" = "64k"' -i "$TMPFILE"
yq e '.data."http2-max-header-size" = "64k"' -i "$TMPFILE"

# Apply patched config map
microk8s kubectl apply -f "$TMPFILE"
rm "$TMPFILE"

# Restart NGINX ingress controller to pick up new config
echo "Restarting NGINX ingress controller to apply changes..."
microk8s kubectl rollout restart daemonset nginx-ingress-microk8s-controller -n ingress
