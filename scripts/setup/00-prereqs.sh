#!/bin/bash
set -euo pipefail

# Prerequisites setup script
# This script checks and installs required tools for the homelab infrastructure

echo "=== Homelab Infrastructure Prerequisites Setup ==="

# Check for required commands
REQUIRED_COMMANDS=("terraform" "ansible" "kubectl" "docker" "git")
MISSING_COMMANDS=()

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_COMMANDS+=("$cmd")
    fi
done

if [ ${#MISSING_COMMANDS[@]} -ne 0 ]; then
    echo "Missing required commands: ${MISSING_COMMANDS[*]}"
    echo "Please install the missing tools before proceeding."
    exit 1
fi

echo "✓ All required commands are installed"

# Check Terraform version
TF_VERSION=$(terraform version -json | jq -r '.terraform_version')
echo "✓ Terraform version: $TF_VERSION"

# Check Ansible version
ANSIBLE_VERSION=$(ansible --version | head -n1)
echo "✓ $ANSIBLE_VERSION"

# Check kubectl version
KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || echo "kubectl not configured")
echo "✓ kubectl: $KUBECTL_VERSION"

# Check Docker version
DOCKER_VERSION=$(docker --version)
echo "✓ $DOCKER_VERSION"

# Create required directories
echo "Creating required directories..."
mkdir -p ~/.kube
mkdir -p ~/.ansible/vault

echo "=== Prerequisites check complete ==="

