#!/bin/bash

RELEASE_NAME="rollouts-demo"
NAMESPACE="default"

echo "=== Cleaning up Rollouts Demo ==="

echo "Uninstalling Helm release..."
helm uninstall $RELEASE_NAME -n $NAMESPACE || echo "Release not found"

echo "Cleaning up remaining resources..."
kubectl delete rollout $RELEASE_NAME -n $NAMESPACE || echo "Rollout not found"
kubectl delete svc ${RELEASE_NAME}-active ${RELEASE_NAME}-preview -n $NAMESPACE || echo "Services not found"

echo "Removing Argo Rollouts controller (optional - uncomment if needed)..."
# kubectl delete namespace argo-rollouts

echo ""
echo "=== Cleanup complete ==="
echo "To completely remove Argo Rollouts controller:"
echo "  kubectl delete namespace argo-rollouts"