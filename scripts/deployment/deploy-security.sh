#!/bin/bash
set -euo pipefail

# Deploy security tools

echo "=== Deploying Security Tools ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Run Ansible playbook for security
ansible-playbook \
  -i ansible/inventory/hosts.yml \
  ansible/playbooks/03-security.yml

# Deploy Trivy server on monitoring host
echo "Deploying Trivy server..."
ansible monitoring -i ansible/inventory/hosts.yml -m shell -a \
  "cd /opt/docker/security && docker compose up -d" \
  --become

echo "=== Security tools deployment complete ==="

