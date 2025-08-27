# Simplified Infrastructure Repository

A streamlined infrastructure repository for deploying applications to Kubernetes clusters using GitOps principles.

## 🏗️ Structure

```bash
infrastructure-repo/
├── apps/                     # Application manifests
│   ├── app1/                # Python Flask app
│   └── app2/                # Python Flask app
├── templates/               # Simplified app templates
│   └── simple-app/         # Basic Kubernetes manifests
├── kind/                   # Local development with KIND
│   ├── setup-kind.sh      # Setup KIND clusters
│   └── simple-monitoring.sh # Basic monitoring stack
└── .github/workflows/     # Simplified CI/CD pipelines
    ├── simple-ci.yaml     # Build and test apps
    └── simple-deploy.yaml # Deploy apps to clusters
```

## 🚀 Quick Start

### 1. Setup Local Environment

```bash
# Setup all KIND clusters (dev, qa, prod)
make setup

# Setup basic monitoring
make setup-monitoring

# Deploy apps to development
make deploy
```

### 2. Manual Deployment

```bash
# Deploy specific app
kubectl apply -k apps/app1

# Deploy to specific environment
kubectl config use-context kind-qa-cluster
kubectl apply -k apps/app1
```

## 📊 Monitoring

Simple Prometheus-based monitoring:

```bash
# Setup monitoring
./kind/simple-monitoring.sh dev

# Access Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
```

## 🔧 App Templates

Use the simplified app template for new applications:

```bash
# Copy template for new app
cp -r templates/simple-app apps/my-new-app

# Edit the manifests
vim apps/my-new-app/kustomization.yaml
vim apps/my-new-app/deployment.yaml
```

## 🤖 CI/CD Pipeline

The simplified pipeline handles:

- ✅ Basic testing
- 🐳 Docker image building
- 🚀 Automatic deployment
- 📦 GitOps updates

### Manual Triggers

```bash
# Deploy specific app to environment
gh workflow run simple-ci.yaml -f environment=qa -f app=app1
```

## 📝 Key Simplifications

1. **Removed Complex Features:**
   - Security scanning
   - Complex promotion workflows
   - Multiple overlay environments
   - Helm-based monitoring
   - Service mesh integration

2. **Kept Essential Features:**
   - Basic CI/CD pipeline
   - GitOps deployment
   - Multi-environment support
   - Simple monitoring
   - Kustomize for manifest management

3. **Benefits:**
   - Easier to understand and maintain
   - Faster deployment times
   - Reduced complexity
   - Perfect for learning/thesis projects

## 🛠️ Available Commands

```bash
make help                 # Show all commands
make setup               # Setup all clusters
make setup-monitoring    # Setup monitoring
make deploy             # Deploy to dev
make test               # Run tests
make clean              # Clean up everything
```

## 📚 Learn More

This simplified setup is perfect for:

- Learning Kubernetes and GitOps
- Thesis/research projects
- Proof of concepts
- Educational purposes

For production use, consider adding back security scanning, proper RBAC, and comprehensive monitoring.
