#!/bin/bash
set -euo pipefail

# Update all infrastructure components

echo "=== Updating Homelab Infrastructure ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Update k3s
echo "Updating k3s..."
ansible-playbook \
  -i ansible/inventory/hosts.yml \
  ansible/playbooks/01-k3s-install.yml \
  --tags update

# Update Docker images
echo "Updating Docker images on monitoring host..."
ansible monitoring -i ansible/inventory/hosts.yml -m shell -a \
  "cd /opt/docker/monitoring && docker compose pull && docker compose up -d" \
  --become

ansible monitoring -i ansible/inventory/hosts.yml -m shell -a \
  "cd /opt/docker/security && docker compose pull && docker compose up -d" \
  --become

ansible monitoring -i ansible/inventory/hosts.yml -m shell -a \
  "cd /opt/docker/services && docker compose pull && docker compose up -d" \
  --become

# Update Kubernetes deployments
echo "Updating Kubernetes deployments..."
kubectl rollout restart deployment/adguard-home -n dns-system || true
kubectl rollout restart deployment/traefik -n ingress-traefik || true

echo "=== Update complete ==="

