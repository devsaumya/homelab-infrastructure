#!/bin/bash
set -euo pipefail

# Deploy Cilium CNI to k3s cluster

echo "=== Deploying Cilium CNI ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: kubectl is not configured or cluster is not accessible"
    exit 1
fi

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Add Cilium Helm repository
echo "Adding Cilium Helm repository..."
helm repo add cilium https://helm.cilium.io/
helm repo update

# Install Cilium
echo "Installing Cilium CNI..."
helm install cilium cilium/cilium \
  --version 1.14.5 \
  --namespace cilium-system \
  --create-namespace \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=strict \
  --set k8sServiceHost=10.0.1.100 \
  --set k8sServicePort=6443

# Wait for Cilium to be ready
echo "Waiting for Cilium to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=cilium -n cilium-system --timeout=300s

echo "=== Cilium CNI deployment complete ==="
echo "Verify installation:"
echo "  kubectl get pods -n cilium-system"

