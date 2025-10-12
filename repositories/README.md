# ArgoCD Repository Configuration

This directory contains templates and scripts for securely configuring ArgoCD to access GitHub repositories.

## 🔒 Security Notice

**NEVER commit actual GitHub Personal Access Tokens to git!** This directory contains templates with placeholders that must be replaced with your actual credentials.

## Files

### `github-repo-template.yaml`
Template for ArgoCD repository secret configuration.

**Usage:**
```bash
# 1. Copy template to working file
cp github-repo-template.yaml github-repo.yaml

# 2. Edit github-repo.yaml and replace:
#    - YOUR_GITHUB_USERNAME → your actual GitHub username
#    - YOUR_GITHUB_TOKEN → your actual GitHub Personal Access Token

# 3. Apply to Kubernetes
kubectl apply -f github-repo.yaml
```

### `setup-repo-access.sh`
Automated script for setting up ArgoCD repository access using environment variables.

**Usage:**
```bash
# 1. Set environment variables (never commit these!)
export GITHUB_USERNAME='your-username'
export GITHUB_TOKEN='ghp_your-personal-access-token'

# 2. Run the setup script
./setup-repo-access.sh
```

## Creating a GitHub Personal Access Token

1. Go to https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Set expiration and select scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `read:packages` (if using GHCR)
4. Click "Generate token"
5. **Copy the token immediately** (you won't see it again!)

## Security Best Practices

- ✅ Use environment variables for credentials
- ✅ Store tokens in secure password managers
- ✅ Rotate tokens regularly
- ✅ Use minimal required permissions
- ❌ Never commit tokens to git
- ❌ Never share tokens in chat/email
- ❌ Never hardcode tokens in scripts

## GitIgnore Protection

The `.gitignore` file prevents committing sensitive files:
```gitignore
repositories/github-repo.yaml
**/secret*.yaml
**/secrets*.yaml
**/*token*.yaml
**/*credential*.yaml
```

## Troubleshooting

### GitHub Push Protection
If you see "Push cannot contain secrets" error:
1. Check commit history for hardcoded tokens
2. Use `git filter-branch` or `git filter-repo` to remove secrets
3. Force push the cleaned history
4. Use templates with placeholders going forward

### ArgoCD Not Syncing
1. Verify repository secret is created: `kubectl get secrets -n argocd`
2. Check ArgoCD logs: `kubectl logs -n argocd deployment/argocd-repo-server`
3. Restart ArgoCD components if needed

## Example Workflow

```bash
# Secure setup process
export GITHUB_USERNAME='triplom'
export GITHUB_TOKEN='ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

# Option 1: Use automated script
./setup-repo-access.sh

# Option 2: Manual configuration
cp github-repo-template.yaml github-repo.yaml
# Edit github-repo.yaml with actual credentials
kubectl apply -f github-repo.yaml

# Verify setup
kubectl get secrets -n argocd | grep infrastructure-repo
```

This ensures ArgoCD can access your GitHub repositories securely without exposing credentials in version control.