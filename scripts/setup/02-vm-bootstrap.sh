#!/bin/bash
set -euo pipefail

# VM Bootstrap script
# This script runs the Ansible bootstrap playbook on all VMs

echo "=== VM Bootstrap ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "Running Ansible bootstrap playbook..."
ansible-playbook \
  -i infra/ansible/inventory/hosts.yml \
  infra/ansible/playbooks/00-bootstrap.yml \
  --ask-become-pass

echo "=== Bootstrap complete ==="

