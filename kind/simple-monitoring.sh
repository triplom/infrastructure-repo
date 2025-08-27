#!/bin/bash
set -e

ENV=${1:-dev}

echo "🔧 Setting up simple monitoring for $ENV environment..."

# Switch to the appropriate cluster context
kubectl config use-context kind-${ENV}-cluster

# Create monitoring namespace
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Deploy simple Prometheus stack using manifest files instead of Helm
echo "📊 Deploying Prometheus..."
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml

# Wait for operator to be ready
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=prometheus-operator -n default --timeout=300s

# Apply basic Prometheus instance
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prometheus
  namespace: monitoring
spec:
  serviceAccountName: prometheus
  serviceMonitorSelector:
    matchLabels:
      team: frontend
  resources:
    requests:
      memory: 400Mi
  enableAdminAPI: false
EOF

# Create service account
kubectl create serviceaccount prometheus -n monitoring --dry-run=client -o yaml | kubectl apply -f -

# Create basic RBAC
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
EOF

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
EOF

echo "✅ Simple monitoring stack deployed!"
echo "📊 Access Prometheus via port-forward:"
echo "kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090"
