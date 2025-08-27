#!/bin/bash
set -e

# First set the Variables as environment variables 
export GITHUB_USERNAME="${GITHUB_USERNAME}"
export GITHUB_TOKEN="${GITHUB_TOKEN}"
export GITHUB_EMAIL="${GITHUB_EMAIL}"

# Check if required environment variables are set
if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_EMAIL" ]; then
  echo "Error: Required environment variables not set."
  echo "Please set GITHUB_USERNAME, GITHUB_TOKEN and GITHUB_EMAIL before running this script."
  exit 1
fi

# Create Kubernetes secrets for GitHub Container Registry authentication
for CLUSTER in dev-cluster qa-cluster prod-cluster; do
  echo "Configuring $CLUSTER to use GitHub Container Registry..."
  
  # Create namespace if it doesn't exist
  kubectl --context kind-$CLUSTER create namespace container-auth || true
  
  # Delete existing secret if it exists
  kubectl --context kind-$CLUSTER delete secret github-registry-secret --namespace=container-auth 2>/dev/null || true
  
  # Create secret for GitHub Container Registry
  kubectl --context kind-$CLUSTER create secret docker-registry github-registry-secret \
    --namespace=container-auth \
    --docker-server=ghcr.io \
    --docker-username=$GITHUB_USERNAME \
    --docker-password=$GITHUB_TOKEN \
    --docker-email=$GITHUB_EMAIL
    
  # Make the secret available to other namespaces
  # Use apply instead of create to handle existing resources
  kubectl --context kind-$CLUSTER apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: registry-auth
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["use"]
EOF

  kubectl --context kind-$CLUSTER apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: serviceaccount-registry-auth
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: registry-auth
subjects:
- kind: ServiceAccount
  name: default
  namespace: container-auth
EOF

  echo "GitHub Container Registry configured successfully for $CLUSTER"
done

echo "GitHub Container Registry setup complete!"