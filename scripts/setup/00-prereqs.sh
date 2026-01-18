#!/bin/bash
set -euo pipefail

# Prerequisites setup script
# This script checks and installs required tools for the homelab infrastructure

echo "=== Homelab Infrastructure Prerequisites Setup ==="
echo ""

# Required commands
REQUIRED_COMMANDS=(
    "git"
    "ansible"
    "kubectl"
    "docker"
    "terraform"
    "jq"
)

MISSING_COMMANDS=()

echo "Checking for required tools..."
echo ""

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        echo "✓ $cmd is installed"
    else
        echo "✗ $cmd is NOT installed"
        MISSING_COMMANDS+=("$cmd")
    fi
done

echo ""

if [ ${#MISSING_COMMANDS[@]} -eq 0 ]; then
    echo "✓ All required commands are installed"
    echo ""
    
    # Show versions
    echo "=== Installed Versions ==="
    git --version
    ansible --version | head -n 1
    kubectl version --client --short 2>/dev/null || kubectl version --client
    docker --version
    terraform version -json 2>/dev/null | jq -r '.terraform_version' || terraform --version | head -n 1
    jq --version
    
    echo ""
    
    # Create required directories
    echo "Creating required directories..."
    mkdir -p ~/.kube
    mkdir -p ~/.ansible/vault
    
    echo ""
    echo "=== Prerequisites check complete ==="
    exit 0
else
    echo "✗ Missing tools detected: ${MISSING_COMMANDS[*]}"
    echo ""
    echo "=== Installation Instructions (Ubuntu/Debian) ==="
    echo ""
    
    for cmd in "${MISSING_COMMANDS[@]}"; do
        case $cmd in
            ansible)
                echo "📦 Install Ansible:"
                echo "   sudo apt update && sudo apt install ansible -y"
                echo ""
                ;;
            docker)
                echo "📦 Install Docker:"
                echo "   sudo apt install docker.io -y"
                echo "   sudo usermod -aG docker \$USER"
                echo "   newgrp docker"
                echo ""
                ;;
            kubectl)
                echo "📦 Install kubectl:"
                echo "   sudo apt install -y apt-transport-https ca-certificates curl"
                echo "   sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg"
                echo "   echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list"
                echo "   sudo apt update && sudo apt install -y kubectl"
                echo ""
                ;;
            terraform)
                echo "📦 Install Terraform:"
                echo "   wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg"
                echo "   echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \$(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list"
                echo "   sudo apt update && sudo apt install terraform -y"
                echo ""
                ;;
            jq)
                echo "📦 Install jq:"
                echo "   sudo apt update && sudo apt install jq -y"
                echo ""
                ;;
            git)
                echo "📦 Install git:"
                echo "   sudo apt update && sudo apt install git -y"
                echo ""
                ;;
        esac
    done
    
    echo "After installing the missing tools, re-run this script to verify."
    exit 1
fi
