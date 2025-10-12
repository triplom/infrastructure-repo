#!/bin/bash

# ArgoCD Repository Access Setup Script
# This script configures ArgoCD to access GitHub repositories securely
# 
# Usage:
#   export GITHUB_USERNAME='your-username'
#   export GITHUB_TOKEN='your-personal-access-token'
#   ./setup-repo-access.sh

echo "🔧 Setting up ArgoCD Repository Access"
echo "======================================"

# Check if required environment variables are set
if [[ -z "$GITHUB_USERNAME" || -z "$GITHUB_TOKEN" ]]; then
    echo "❌ Error: Please set the following environment variables:"
    echo "   export GITHUB_USERNAME='your-github-username'"
    echo "   export GITHUB_TOKEN='your-github-personal-access-token'"
    echo ""
    echo "💡 To create a GitHub token:"
    echo "   1. Go to https://github.com/settings/tokens"
    echo "   2. Generate a new token with 'repo' permissions"
    echo "   3. Copy the token and set it as GITHUB_TOKEN"
    echo ""
    echo "⚠️  SECURITY: Never commit your actual GitHub token to git!"
    exit 1
fi

echo "✅ Environment variables found"
echo "🔧 Creating ArgoCD repository secret..."

# Create the repository secret
kubectl create secret generic infrastructure-repo \
  --from-literal=type=git \
  --from-literal=url=https://github.com/triplom/infrastructure-repo.git \
  --from-literal=username="$GITHUB_USERNAME" \
  --from-literal=password="$GITHUB_TOKEN" \
  --from-literal=insecure="false" \
  --from-literal=enableLfs="false" \
  -n argocd \
  --dry-run=client -o yaml | kubectl apply -f -

# Label the secret for ArgoCD
kubectl label secret infrastructure-repo argocd.argoproj.io/secret-type=repository -n argocd --overwrite

echo "✅ Repository access configured successfully!"
echo ""
echo "🔄 Restarting ArgoCD components..."
kubectl rollout restart deployment/argocd-repo-server -n argocd
kubectl rollout restart deployment/argocd-server -n argocd

echo ""
echo "✅ Setup complete! ArgoCD can now access the GitHub repository."
echo ""
echo "🔒 Security reminder: The GitHub token is stored as a Kubernetes secret."
echo "   To rotate the token, simply run this script again with a new GITHUB_TOKEN."