#!/bin/bash
set -euo pipefail

# Cleanup script for removing unused resources

echo "=== Homelab Infrastructure Cleanup ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Clean up Docker images
echo "Cleaning up Docker images..."
ansible all -i ansible/inventory/hosts.yml -m shell -a \
  "docker system prune -af --volumes" \
  --become || true

# Clean up Kubernetes resources
echo "Cleaning up Kubernetes resources..."
kubectl delete pods --field-selector=status.phase==Succeeded --all-namespaces || true
kubectl delete pods --field-selector=status.phase==Failed --all-namespaces || true

# Clean up old logs
echo "Cleaning up old logs..."
ansible all -i ansible/inventory/hosts.yml -m shell -a \
  "journalctl --vacuum-time=7d" \
  --become || true

echo "=== Cleanup complete ==="

