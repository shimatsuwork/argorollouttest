#!/bin/bash

set -e

RELEASE_NAME="rollouts-demo"
NAMESPACE="default"
CHART_PATH="./helm-chart/rollouts-demo"

echo "=== Deploying Rollouts Demo Application ==="

# Check if release already exists
if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
    echo "Release $RELEASE_NAME already exists. Upgrading..."
    helm upgrade $RELEASE_NAME $CHART_PATH -n $NAMESPACE
else
    echo "Installing new release $RELEASE_NAME..."
    helm install $RELEASE_NAME $CHART_PATH -n $NAMESPACE
fi

echo "Waiting for rollout to be ready..."
kubectl wait --for=condition=Progressing rollout/$RELEASE_NAME -n $NAMESPACE --timeout=300s

echo ""
echo "=== Deployment Status ==="
kubectl argo rollouts get rollout $RELEASE_NAME -n $NAMESPACE

echo ""
echo "=== Services ==="
kubectl get svc -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE

echo ""
echo "=== Rollout ready! ==="
echo "You can now:"
echo "1. View the rollout status: kubectl argo rollouts get rollout $RELEASE_NAME"
echo "2. Access the dashboard: http://localhost:31000 (or check setup-dashboard.sh output)"
echo "3. Test deployment: kubectl port-forward svc/$RELEASE_NAME-active 8080:80"
echo "4. Update the image: ./scripts/update-image.sh <new-tag>"