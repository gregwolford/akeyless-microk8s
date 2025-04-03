#!/bin/bash

set -e

echo "=== Updating NGINX ConfigMap for header size limits ==="
INGRESS_NAME=$(microk8s kubectl get ingress -n ingress -o jsonpath="{.items[0].metadata.name}")
microk8s kubectl get configmap $INGRESS_NAME -n ingress -o yaml > nginx-configmap.yaml

echo "Patching nginx-configmap.yaml..."
cat <<EOL >> nginx-configmap.yaml

data:
  large-client-header-buffers: "4 64k"
  client-header-buffer-size: "64k"
  http2-max-header-size: "64k"
EOL

microk8s kubectl apply -f nginx-configmap.yaml
echo "NGINX ConfigMap updated and applied."

echo "=== Creating shared StorageClass and PersistentVolume in 'my-apps' namespace ==="
microk8s kubectl config set-context --current --namespace=my-apps

cat <<EOF | microk8s kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: shared-local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

cat <<EOF | microk8s kubectl apply -f -
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

echo "Preparing host path directory..."
sudo mkdir -p /mnt/data/shared
sudo chmod -R 777 /mnt/data/shared

echo "✅ Post-setup storage and config patches applied."
