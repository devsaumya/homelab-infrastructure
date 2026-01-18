#!/bin/bash
set -euo pipefail

# Deploy monitoring stack on VM2 (k3s-worker-01)

echo "=== Deploying Monitoring Stack ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Set Ansible configuration
export ANSIBLE_CONFIG="${PROJECT_ROOT}/infra/ansible/ansible.cfg"
export ANSIBLE_ROLES_PATH="${PROJECT_ROOT}/infra/ansible/roles"

# Run Ansible playbook for monitoring
ansible-playbook \
  -i infra/ansible/inventory/hosts.yml \
  infra/ansible/playbooks/02-monitoring.yml \
  --limit k3s-worker-01

# Deploy Docker Compose stack
echo "Deploying Docker Compose monitoring stack..."
ansible k3s-worker-01 -i infra/ansible/inventory/hosts.yml -m shell -a \
  "cd /opt/docker/monitoring && docker compose up -d" \
  --become

echo "=== Monitoring stack deployment complete ==="
echo "Access Grafana at: http://10.0.1.109:3000"
echo "Access Prometheus at: http://10.0.1.109:9090"

