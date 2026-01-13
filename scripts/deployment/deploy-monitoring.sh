#!/bin/bash
set -euo pipefail

# Deploy monitoring stack on VM2 (security-ops)

echo "=== Deploying Monitoring Stack ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Run Ansible playbook for monitoring
ansible-playbook \
  -i infra/ansible/inventory/hosts.yml \
  infra/ansible/playbooks/02-monitoring.yml \
  --limit monitoring

# Deploy Docker Compose stack
echo "Deploying Docker Compose monitoring stack..."
ansible monitoring -i infra/ansible/inventory/hosts.yml -m shell -a \
  "cd /opt/docker/monitoring && docker compose up -d" \
  --become

echo "=== Monitoring stack deployment complete ==="
echo "Access Grafana at: http://10.0.1.105:3000"
echo "Access Prometheus at: http://10.0.1.105:9090"

