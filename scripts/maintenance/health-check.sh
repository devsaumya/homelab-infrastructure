#!/bin/bash
set -euo pipefail

# Health check script for homelab infrastructure

echo "=== Homelab Infrastructure Health Check ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Check k3s cluster
echo "Checking k3s cluster..."
if kubectl cluster-info &> /dev/null; then
    echo "✓ k3s cluster is accessible"
    kubectl get nodes
    echo ""
    kubectl get pods --all-namespaces
else
    echo "✗ k3s cluster is not accessible"
fi

echo ""

# Check Docker services
echo "Checking Docker services on monitoring host..."
ansible k3s-worker-01 -i infra/ansible/inventory/hosts.yml -m shell -a \
  "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" \
  --become || echo "✗ Cannot check Docker services"

echo ""

# Check network connectivity
echo "Checking network connectivity..."
HOSTS=("10.0.1.108" "10.0.1.109" "10.0.1.50")
for host in "${HOSTS[@]}"; do
    if ping -c 1 -W 2 "$host" &> /dev/null; then
        echo "✓ $host is reachable"
    else
        echo "✗ $host is not reachable"
    fi
done

echo ""
echo "=== Health check complete ==="

