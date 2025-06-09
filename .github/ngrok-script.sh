#!/bin/bash
# Run this locally to generate a proper ngrok kubeconfig

# Your current ngrok URL
NGROK_URL="https://9342-87-103-115-149.ngrok-free.app"

# Create a simple test kubeconfig for ngrok
cat > ngrok-kubeconfig << EOF
apiVersion: v1
kind: Config
clusters:
- name: ngrok-cluster
  cluster:
    server: ${NGROK_URL}
    insecure-skip-tls-verify: true
contexts:
- name: ngrok-context
  context:
    cluster: ngrok-cluster
    user: ngrok-user
current-context: ngrok-context
users:
- name: ngrok-user
  user:
    # Create a service account token with the required permissions
    token: $(kubectl create token kubernetes-admin -n default --duration=24h)
EOF

# Test the config locally first
KUBECONFIG=ngrok-kubeconfig kubectl cluster-info

# If successful, encode for GitHub
cat ngrok-kubeconfig | base64 -w0