#!/usr/bin/env bash

# setup-registry.sh - Configure a local container registry for KIND clusters

set -o errexit
set -o pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration with defaults
REG_NAME='kind-registry'
REG_PORT='5000'
NETWORK_NAME='kind-net'
CLUSTERS=("dev-cluster" "qa-cluster" "prod-cluster")
CLEAN=false
TEST_REGISTRY=false
SPECIFIC_CLUSTER=""

# Display script usage
usage() {
  cat << EOF
Usage: $0 [options]

Configure a local container registry for KIND clusters.

Options:
  -h, --help              Show this help message
  -p, --port PORT         Specify registry port (default: 5000)
  -n, --name NAME         Specify registry name (default: kind-registry)
  -N, --network NETWORK   Specify network name (default: kind-net)
  -c, --cluster CLUSTER   Configure only specific cluster
  -C, --clean             Clean up existing registry and network
  -t, --test              Test registry functionality after setup

Examples:
  $0                      Setup registry with default settings
  $0 --port 5001          Setup registry on port 5001
  $0 --cluster dev-cluster Only configure dev-cluster
  $0 --clean              Clean up existing registry before setup
  $0 --test               Test registry with a sample image after setup
EOF
}

# Log functions
log() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# Parse command-line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        usage
        exit 0
        ;;
      -p|--port)
        REG_PORT="$2"
        shift 2
        ;;
      -n|--name)
        REG_NAME="$2"
        shift 2
        ;;
      -N|--network)
        NETWORK_NAME="$2"
        shift 2
        ;;
      -c|--cluster)
        SPECIFIC_CLUSTER="$2"
        shift 2
        ;;
      -C|--clean)
        CLEAN=true
        shift
        ;;
      -t|--test)
        TEST_REGISTRY=true
        shift
        ;;
      *)
        warn "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

# Check prerequisites
check_prerequisites() {
  log "Checking prerequisites..."

  if ! command -v docker &> /dev/null; then
    error "Docker is required but not installed. Please install Docker first."
  fi

  if ! command -v kind &> /dev/null; then
    error "KIND is required but not installed. Please install KIND first."
  fi

  if ! command -v kubectl &> /dev/null; then
    error "kubectl is required but not installed. Please install kubectl first."
  fi

  # Check if Docker is running
  if ! docker info &> /dev/null; then
    error "Docker is not running. Please start Docker daemon first."
  fi

  success "All prerequisites satisfied."
}

# Clean up existing resources
cleanup() {
  if [[ "$CLEAN" == "true" ]]; then
    log "Cleaning up existing registry and network..."

    # Stop and remove registry container if exists
    if docker container inspect "$REG_NAME" &>/dev/null; then
      log "Removing existing registry container: $REG_NAME"
      docker container stop "$REG_NAME" &>/dev/null || true
      docker container rm "$REG_NAME" &>/dev/null || true
    fi

    # Remove network if exists
    if docker network inspect "$NETWORK_NAME" &>/dev/null; then
      log "Removing existing network: $NETWORK_NAME"
      docker network rm "$NETWORK_NAME" &>/dev/null || true
    fi

    success "Cleanup completed."
  fi
}

# Setup Docker network
setup_network() {
  log "Setting up Docker network: $NETWORK_NAME"

  if ! docker network inspect "$NETWORK_NAME" &>/dev/null; then
    log "Creating Docker network: $NETWORK_NAME"
    docker network create "$NETWORK_NAME" || error "Failed to create network: $NETWORK_NAME"
    success "Created Docker network: $NETWORK_NAME"
  else
    log "Network $NETWORK_NAME already exists"
  fi
}

# Setup container registry
setup_registry() {
  log "Setting up local container registry: $REG_NAME:$REG_PORT"

  # Check if registry container exists and is running
  if [ "$(docker inspect -f '{{.State.Running}}' "$REG_NAME" 2>/dev/null || echo "false")" == "true" ]; then
    log "Registry container $REG_NAME is already running"
  else
    # Remove container if it exists but is not running
    if docker container inspect "$REG_NAME" &>/dev/null; then
      log "Removing existing stopped registry container"
      docker container rm "$REG_NAME" &>/dev/null || error "Failed to remove existing registry container"
    fi

    log "Creating registry container"
    docker run \
      -d --restart=always -p "127.0.0.1:$REG_PORT:5000" --name "$REG_NAME" \
      --network "$NETWORK_NAME" \
      registry:2 || error "Failed to create registry container"
    
    success "Local registry created at localhost:$REG_PORT"
  fi

  # Ensure registry is connected to our network
  if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.'$NETWORK_NAME'}}' "$REG_NAME")" == "null" ]; then
    log "Connecting registry to network $NETWORK_NAME"
    docker network connect "$NETWORK_NAME" "$REG_NAME" || error "Failed to connect registry to network"
    success "Connected registry to $NETWORK_NAME"
  else
    log "Registry is already connected to network $NETWORK_NAME"
  fi
}

# Configure clusters
configure_clusters() {
  local clusters_to_configure=()
  
  # Determine which clusters to configure
  if [[ -n "$SPECIFIC_CLUSTER" ]]; then
    clusters_to_configure=("$SPECIFIC_CLUSTER")
  else
    clusters_to_configure=("${CLUSTERS[@]}")
  fi
  
  log "Configuring clusters: ${clusters_to_configure[*]}"

  # Configure each cluster
  for cluster in "${clusters_to_configure[@]}"; do
    configure_cluster "$cluster"
  done
}

# Configure specific cluster
configure_cluster() {
  local cluster="$1"
  local control_plane_node="${cluster}-control-plane"
  
  log "Configuring $cluster to use local registry..."
  
  # Check if the cluster exists
  if ! docker ps -a | grep -q "$control_plane_node"; then
    warn "Cluster $cluster does not exist, skipping configuration"
    return 1
  fi
  
  # Connect the cluster to our network
  if ! docker network inspect "$NETWORK_NAME" | grep -q "$control_plane_node"; then
    log "Connecting $control_plane_node to $NETWORK_NAME"
    docker network connect "$NETWORK_NAME" "$control_plane_node" || {
      warn "Failed to connect $control_plane_node to network"
      return 1
    }
    success "Connected $control_plane_node to $NETWORK_NAME"
  else
    log "$control_plane_node already connected to $NETWORK_NAME"
  fi
  
  # Configure containerd on each node of the cluster
  log "Configuring containerd on cluster nodes..."
  REGISTRY_DIR="/etc/containerd/certs.d/localhost:${REG_PORT}"
  
  for node in $(kind get nodes --name "$cluster"); do
    log "Configuring containerd on node $node..."
    
    # Create registry directory
    docker exec "$node" mkdir -p "$REGISTRY_DIR" || {
      warn "Failed to create registry directory on $node"
      continue
    }
    
    # Configure hosts.toml
    cat <<EOF | docker exec -i "$node" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${REG_NAME}:5000"]
capabilities = ["pull", "resolve", "push"]
skip_verify = true
EOF
    
    if [ $? -ne 0 ]; then
      warn "Failed to configure registry on $node"
      continue
    fi

    # Restart containerd
    log "Restarting containerd on $node..."
    docker exec "$node" systemctl restart containerd || {
      warn "Failed to restart containerd on $node"
      continue
    }
  done
  
  # Create ConfigMap for registry hosting
  log "Creating registry ConfigMap in $cluster..."
  if ! kubectl --context "kind-$cluster" apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REG_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
  then
    warn "Failed to create ConfigMap in $cluster"
    return 1
  fi
  
  success "Cluster $cluster configured to use local registry"
  return 0
}

# Test registry functionality
test_registry() {
  if [[ "$TEST_REGISTRY" != "true" ]]; then
    return 0
  fi
  
  log "Testing registry functionality..."
  
  # Create a test image
  log "Creating test image..."
  echo -e "FROM alpine:3.16\nCMD [\"echo\", \"Hello from test image\"]" > Dockerfile.test
  
  # Build and push test image
  local test_image="localhost:$REG_PORT/test-image:latest"
  if ! docker build -t "$test_image" -f Dockerfile.test .; then
    warn "Failed to build test image"
    rm Dockerfile.test
    return 1
  fi
  
  log "Pushing test image to registry..."
  if ! docker push "$test_image"; then
    warn "Failed to push test image to registry"
    rm Dockerfile.test
    return 1
  fi
  
  # Get first available cluster
  local test_cluster
  if [[ -n "$SPECIFIC_CLUSTER" ]]; then
    test_cluster="$SPECIFIC_CLUSTER"
  else
    for cluster in "${CLUSTERS[@]}"; do
      if docker ps -a | grep -q "${cluster}-control-plane"; then
        test_cluster="$cluster"
        break
      fi
    done
  fi
  
  if [[ -z "$test_cluster" ]]; then
    warn "No cluster available for testing"
    rm Dockerfile.test
    return 1
  fi
  
  log "Testing pull from $test_cluster..."
  cat <<EOF | kubectl --context "kind-$test_cluster" apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-registry-pod
spec:
  containers:
  - name: test
    image: localhost:$REG_PORT/test-image:latest
    imagePullPolicy: Always
  restartPolicy: Never
EOF
  
  log "Waiting for test pod to complete..."
  kubectl --context "kind-$test_cluster" wait --for=condition=Ready pod/test-registry-pod --timeout=60s || {
    warn "Test pod did not reach ready state"
    kubectl --context "kind-$test_cluster" describe pod/test-registry-pod
  }
  
  # Cleanup test resources
  log "Cleaning up test resources..."
  kubectl --context "kind-$test_cluster" delete pod test-registry-pod --wait=false
  rm Dockerfile.test
  
  success "Registry functionality test completed"
}

# Show configuration summary
show_summary() {
  success "Local registry setup complete!"
  echo "========================================================"
  echo "Registry: localhost:$REG_PORT"
  echo "Docker Network: $NETWORK_NAME"
  echo ""
  echo "Usage examples:"
  echo "1. Tag and push an image:"
  echo "   docker tag my-image:tag localhost:$REG_PORT/my-image:tag"
  echo "   docker push localhost:$REG_PORT/my-image:tag"
  echo ""
  echo "2. Reference in Kubernetes manifests:"
  echo "   image: localhost:$REG_PORT/my-image:tag"
  echo ""
  echo "3. List images in registry:"
  echo "   curl -X GET http://localhost:$REG_PORT/v2/_catalog"
  echo "========================================================"
}

# Main function
main() {
  parse_args "$@"
  check_prerequisites
  cleanup
  setup_network
  setup_registry
  configure_clusters
  test_registry
  show_summary
}

# Run main function
main "$@"