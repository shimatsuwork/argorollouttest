#!/bin/bash

echo "=== Installing Argo Rollouts Controller ==="

# Create namespace for argo rollouts
kubectl create namespace argo-rollouts

# Install Argo Rollouts controller
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

echo "Waiting for Argo Rollouts controller to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argo-rollouts -n argo-rollouts --timeout=300s

echo "=== Installing kubectl rollouts plugin ==="

# Download and install kubectl rollouts plugin
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
    ARCH="arm64"
fi

PLUGIN_URL="https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-${PLATFORM}-${ARCH}"

echo "Downloading kubectl rollouts plugin..."
curl -LO "$PLUGIN_URL"

chmod +x kubectl-argo-rollouts-${PLATFORM}-${ARCH}
sudo mv kubectl-argo-rollouts-${PLATFORM}-${ARCH} /usr/local/bin/kubectl-argo-rollouts

echo "=== Verification ==="
echo "Checking Argo Rollouts controller status:"
kubectl get pods -n argo-rollouts

echo ""
echo "Checking kubectl rollouts plugin:"
kubectl argo rollouts version

echo ""
echo "=== Installation Complete ==="
echo "You can now deploy rollouts using:"
echo "  helm install rollouts-demo ./helm-chart/rollouts-demo"