#!/bin/bash
set -euo pipefail

# Deploy Kubernetes manifests to k3s cluster

echo "=== Deploying Kubernetes Manifests ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: kubectl is not configured or cluster is not accessible"
    exit 1
fi

# Apply base namespaces
echo "Applying namespaces..."
kubectl apply -f kubernetes/base/namespaces/

# Apply network policies
echo "Applying network policies..."
kubectl apply -f kubernetes/base/network-policies/

# Apply AdGuard Home
echo "Applying AdGuard Home..."
kubectl apply -k kubernetes/base/adguard/

# Apply Traefik
echo "Applying Traefik..."
kubectl apply -k kubernetes/base/traefik/

# Apply cert-manager (if installed)
if kubectl get namespace cert-manager &> /dev/null; then
    echo "Applying cert-manager issuer..."
    kubectl apply -f kubernetes/base/cert-manager/
fi

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/adguard-home -n dns-system || true
kubectl wait --for=condition=available --timeout=300s deployment/traefik -n ingress-traefik || true

echo "=== Kubernetes deployment complete ==="

