#!/bin/bash

set -e

RELEASE_NAME="rollouts-demo"
NAMESPACE="default"
CHART_PATH="./helm-chart/rollouts-demo"

if [ -z "$1" ]; then
    echo "Usage: $0 <new-image-tag>"
    echo "Example: $0 1.26"
    exit 1
fi

NEW_TAG="$1"

echo "=== Updating Rollout to nginx:$NEW_TAG ==="

# Update the image tag
helm upgrade $RELEASE_NAME $CHART_PATH -n $NAMESPACE --set image.tag=$NEW_TAG

echo "Waiting for rollout to start..."
sleep 5

echo ""
echo "=== Rollout Status ==="
kubectl argo rollouts get rollout $RELEASE_NAME -n $NAMESPACE

echo ""
echo "=== Live Status Monitoring ==="
echo "The rollout is in progress. You can:"
echo "1. Watch live status: kubectl argo rollouts get rollout $RELEASE_NAME --watch"
echo "2. View in dashboard: http://localhost:31000"
echo "3. Check preview service: kubectl port-forward svc/$RELEASE_NAME-preview 8081:80"
echo "4. Promote manually: kubectl argo rollouts promote $RELEASE_NAME"
echo "5. Abort rollout: kubectl argo rollouts abort $RELEASE_NAME"

echo ""
echo "Rollout commands:"
echo "  Promote:  kubectl argo rollouts promote $RELEASE_NAME"
echo "  Retry:    kubectl argo rollouts retry rollout $RELEASE_NAME"
echo "  Abort:    kubectl argo rollouts abort $RELEASE_NAME"
echo "  Rollback: kubectl argo rollouts undo $RELEASE_NAME"