#!/bin/bash
set -e

ALL_ENVS=("dev" "qa" "prod")

deploy_stack() {
  ENV=$1
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

  echo "Deploying monitoring stack to $ENV environment..."

  # Switch to the appropriate cluster context
  kubectl config use-context kind-${ENV}-cluster

  # Add Helm repositories if they don't exist
  if ! helm repo list | grep -q 'prometheus-community'; then
    echo "Adding Prometheus Community Helm repository..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  fi

  # Update Helm repositories
  helm repo update

  # Apply the namespace
  kubectl apply -f ${REPO_ROOT}/infrastructure/monitoring/base/namespace.yaml

  # Prepare values file
  cp ${REPO_ROOT}/infrastructure/monitoring/base/helm-values.yaml values-$ENV.yaml

  # Apply any environment-specific patches if they exist
  if [ -f "${REPO_ROOT}/infrastructure/monitoring/overlays/$ENV/values-patch.yaml" ]; then
    echo "Applying environment-specific values for $ENV..."
    # This requires yq to be installed
    if command -v yq &> /dev/null; then
      yq eval-all 'select(fileIndex==0) * select(fileIndex==1)' values-$ENV.yaml ${REPO_ROOT}/infrastructure/monitoring/overlays/$ENV/values-patch.yaml > values-$ENV-merged.yaml
      mv values-$ENV-merged.yaml values-$ENV.yaml
    else
      echo "Warning: yq not found, skipping environment-specific values merge"
    fi
  fi

  # Deploy using Helm
  echo "Deploying kube-prometheus-stack..."
  helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --values values-$ENV.yaml \
    --wait --timeout 10m

  # Apply additional Prometheus rules
  echo "Applying Prometheus rules..."
  kubectl apply -f ${REPO_ROOT}/infrastructure/monitoring/base/prometheus-rules.yaml

  echo "Monitoring stack deployed successfully for $ENV!"
  echo "Grafana can be accessed via port-forwarding:"
  echo "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
  echo ""
  echo "Prometheus can be accessed via port-forwarding:"
  echo "kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"

  # Clean up
  rm values-$ENV.yaml
}

if [ -z "$1" ]; then
  echo "No environment specified. Deploying to all: ${ALL_ENVS[*]}"
  for ENV in "${ALL_ENVS[@]}"; do
    deploy_stack "$ENV"
  done
else
  deploy_stack "$1"
fi