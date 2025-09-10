#!/bin/bash

echo "=== Setting up Argo Rollouts Dashboard ==="

# Create service account and RBAC for dashboard
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo-rollouts-dashboard
  namespace: argo-rollouts
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argo-rollouts-dashboard
rules:
- apiGroups:
  - argoproj.io
  resources:
  - rollouts
  - rollouts/status
  - experiments
  - analysisruns
  - analysistemplates
  - clusteranalysistemplates
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - pods
  - replicasets
  - services
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - apps
  resources:
  - replicasets
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-rollouts-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argo-rollouts-dashboard
subjects:
- kind: ServiceAccount
  name: argo-rollouts-dashboard
  namespace: argo-rollouts
EOF

echo "=== Creating Dashboard Service ==="

# Create dashboard service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argo-rollouts-dashboard
  namespace: argo-rollouts
  labels:
    app.kubernetes.io/name: argo-rollouts-dashboard
spec:
  type: NodePort
  ports:
  - port: 3100
    targetPort: 3100
    nodePort: 31000
    protocol: TCP
    name: dashboard
  selector:
    app.kubernetes.io/name: argo-rollouts-dashboard
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argo-rollouts-dashboard
  namespace: argo-rollouts
  labels:
    app.kubernetes.io/name: argo-rollouts-dashboard
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: argo-rollouts-dashboard
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argo-rollouts-dashboard
    spec:
      serviceAccountName: argo-rollouts-dashboard
      containers:
      - name: dashboard
        image: quay.io/argoproj/kubectl-argo-rollouts:v1.8.3
        command: 
        - /bin/sh
        - -c
        - |
          kubectl-argo-rollouts dashboard --listen 0.0.0.0:3100
        ports:
        - containerPort: 3100
        livenessProbe:
          httpGet:
            path: /
            port: 3100
          initialDelaySeconds: 30
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /
            port: 3100
          initialDelaySeconds: 10
          periodSeconds: 5
EOF

echo "Waiting for dashboard to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argo-rollouts-dashboard -n argo-rollouts --timeout=300s

echo ""
echo "=== Dashboard Setup Complete ==="
echo "Dashboard is available at: http://localhost:31000"
echo "If using a remote cluster, replace localhost with your cluster IP"
echo ""
echo "To access the dashboard:"
echo "1. If using kind/minikube: http://localhost:31000"
echo "2. If using remote cluster: http://<cluster-ip>:31000"
echo "3. Or port-forward: kubectl port-forward -n argo-rollouts service/argo-rollouts-dashboard 3100:3100"
echo "   Then access: http://localhost:3100"