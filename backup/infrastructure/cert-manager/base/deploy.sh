#!/bin/bash

set -e

# Add Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install/upgrade Cert Manager
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.12.0 \
  --set installCRDs=true \
  --set prometheus.enabled=true

# Wait for Cert Manager to be ready
kubectl -n cert-manager wait --for=condition=available --timeout=300s deployment/cert-manager

# Apply ClusterIssuers
kubectl apply -f clusterissuer.yaml
