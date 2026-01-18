#!/bin/bash
set -euo pipefail

# VM Bootstrap script
# This script runs the Ansible bootstrap playbook on all VMs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "=== VM Bootstrap ==="
echo ""

echo "Setting Ansible configuration..."
export ANSIBLE_CONFIG="${PROJECT_ROOT}/infra/ansible/ansible.cfg"
export ANSIBLE_ROLES_PATH="${PROJECT_ROOT}/infra/ansible/roles"

echo "Running Ansible bootstrap playbook..."
ansible-playbook \
  -i infra/ansible/inventory/hosts.yml \
  infra/ansible/playbooks/00-bootstrap.yml \
  --ask-become-pass

echo ""
echo "=== Bootstrap complete ==="
