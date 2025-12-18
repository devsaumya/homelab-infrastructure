#!/bin/bash
set -euo pipefail

# Deploy all infrastructure components
# This script orchestrates the full deployment

echo "=== Deploying Homelab Infrastructure ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Step 1: Bootstrap VMs
echo "Step 1: Bootstrapping VMs..."
./scripts/setup/02-vm-bootstrap.sh

# Step 2: Install k3s
echo "Step 2: Installing k3s..."
ansible-playbook \
  -i ansible/inventory/hosts.yml \
  ansible/playbooks/01-k3s-install.yml

# Step 3: Deploy Kubernetes manifests
echo "Step 3: Deploying Kubernetes manifests..."
./scripts/deployment/deploy-k3s.sh

# Step 4: Deploy monitoring stack
echo "Step 4: Deploying monitoring stack..."
./scripts/deployment/deploy-monitoring.sh

# Step 5: Deploy security tools
echo "Step 5: Deploying security tools..."
./scripts/deployment/deploy-security.sh

echo "=== Deployment complete ==="

