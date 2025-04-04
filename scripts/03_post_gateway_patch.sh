#!/bin/bash

# This is only for adding persistent storage and large header support. It hasn't been tested yet.

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
  echo "❌ Error: Could not find the NGINX ConfigMap in the ingress namespace."
  exit 1
fi

echo "✅ Found configmap: $CONFIGMAP_NAME"

TMPFILE=$(mktemp /tmp/nginx-configmap.XXXXXX.yaml)

# Dump current config map
microk8s kubectl get configmap "$CONFIGMAP_NAME" -n ingress -o yaml > "$TMPFILE"

# Patch `data` fields using yq
yq e '.data."large-client-header-buffers" = "4 64k"' -i "$TMPFILE"
yq e '.data."client-header-buffer-size" = "64k"' -i "$TMPFILE"
yq e '.data."http2-max-header-size" = "64k"' -i "$TMPFILE"

# Apply patched config map
microk8s kubectl apply -f "$TMPFILE"

# Switch to my-apps namespace or create if not exists
echo "Ensuring 'my-apps' namespace exists..."
microk8s kubectl get namespace my-apps &> /dev/null || microk8s kubectl create namespace my-apps
microk8s kubectl config set-context --current --namespace=my-apps

echo "=== Creating Storage Class ==="
cat << EOF | microk8s kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: shared-local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

echo "=== Creating Persistent Volume ==="
cat << EOF | microk8s kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-shared
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: shared-local-storage
  hostPath:
    path: /mnt/data/shared
EOF

echo "Creating shared directory on host..."
sudo mkdir -p /mnt/data/shared
sudo chmod -R 777 /mnt/data/shared

echo "Restarting NGINX ingress controller to apply changes..."
microk8s kubectl rollout restart daemonset nginx-ingress-microk8s-controller -n ingress

echo "✅ Post-gateway patch completed!"
