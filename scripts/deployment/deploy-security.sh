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

# Deploy Falco (if kubectl is configured)
if kubectl cluster-info &> /dev/null; then
    echo "Deploying Falco runtime security..."
    
    # Check if Helm is installed
    if ! command -v helm &> /dev/null; then
        echo "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    
    # Add Falco Helm repository
    helm repo add falcosecurity https://falcosecurity.github.io/charts
    helm repo update
    
    # Install Falco
    helm install falco falcosecurity/falco \
      --namespace falco \
      --create-namespace \
      --set driver.enabled=true \
      --set falco.grpc.enabled=true \
      --set falco.grpcOutput.enabled=true || echo "Falco installation skipped (may already exist)"
fi

# Deploy Kyverno (if kubectl is configured)
if kubectl cluster-info &> /dev/null; then
    echo "Deploying Kyverno policy engine..."
    
    # Check if Helm is installed
    if ! command -v helm &> /dev/null; then
        echo "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    
    # Add Kyverno Helm repository
    helm repo add kyverno https://kyverno.github.io/kyverno/
    helm repo update
    
    # Install Kyverno
    helm install kyverno kyverno/kyverno \
      --namespace kyverno \
      --create-namespace \
      --set replicaCount=1 || echo "Kyverno installation skipped (may already exist)"
fi

echo "=== Security tools deployment complete ==="

