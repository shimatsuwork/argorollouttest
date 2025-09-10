#!/bin/bash

set -e

RELEASE_NAME="rollouts-demo"
NAMESPACE="default"

echo "=== Testing Rollback Functionality ==="

echo "Current rollout status:"
kubectl argo rollouts get rollout $RELEASE_NAME -n $NAMESPACE

echo ""
echo "=== Rolling back to previous revision ==="
kubectl argo rollouts undo $RELEASE_NAME -n $NAMESPACE

echo "Waiting for rollback to complete..."
sleep 5

echo ""
echo "=== Rollback Status ==="
kubectl argo rollouts get rollout $RELEASE_NAME -n $NAMESPACE

echo ""
echo "=== Rollback History ==="
kubectl argo rollouts history rollout $RELEASE_NAME -n $NAMESPACE

echo ""
echo "=== Rollback complete! ==="
echo "You can:"
echo "1. Check the current image: kubectl describe rollout $RELEASE_NAME | grep Image"
echo "2. View rollout history: kubectl argo rollouts history rollout $RELEASE_NAME"
echo "3. Monitor in dashboard: http://localhost:31000"