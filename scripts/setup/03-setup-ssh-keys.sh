#!/bin/bash
set -euo pipefail

# Setup SSH keys for Ansible access to VMs
# This script helps configure SSH key authentication

echo "=== SSH Key Setup for Ansible ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Check if SSH key exists
SSH_KEY="${SSH_KEY:-~/.ssh/id_rsa}"
SSH_KEY_EXPANDED="${SSH_KEY/#\~/$HOME}"

if [ ! -f "$SSH_KEY_EXPANDED" ]; then
    echo "SSH key not found at $SSH_KEY"
    echo ""
    read -p "Generate new SSH key? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ssh-keygen -t ed25519 -f "$SSH_KEY_EXPANDED" -N "" -C "ansible@homelab"
        echo "✓ SSH key generated at $SSH_KEY"
    else
        echo "Please generate an SSH key or specify path with SSH_KEY environment variable"
        exit 1
    fi
else
    echo "✓ SSH key found at $SSH_KEY"
fi

# Get public key
PUBLIC_KEY="${SSH_KEY_EXPANDED}.pub"
if [ ! -f "$PUBLIC_KEY" ]; then
    echo "Error: Public key not found at $PUBLIC_KEY"
    exit 1
fi

echo ""
echo "Public key to copy:"
cat "$PUBLIC_KEY"
echo ""

# VMs to configure
VMS=(
    "admin@10.0.1.108:k3s-master"
    "admin@10.0.1.109:security-ops"
)

echo "Copying SSH key to VMs..."
echo "You may be prompted for passwords during this process."
echo ""

for vm in "${VMS[@]}"; do
    IFS=':' read -r user_host name <<< "$vm"
    echo "Setting up SSH access to $name ($user_host)..."
    
    # Try to copy key
    if ssh-copy-id -i "$PUBLIC_KEY" "$user_host" 2>/dev/null; then
        echo "✓ SSH key copied to $name"
    else
        echo "⚠ Failed to copy key automatically to $name"
        echo "  Manual steps:"
        echo "  1. ssh $user_host"
        echo "  2. mkdir -p ~/.ssh && chmod 700 ~/.ssh"
        echo "  3. Add the public key above to ~/.ssh/authorized_keys"
        echo "  4. chmod 600 ~/.ssh/authorized_keys"
        echo ""
    fi
done

echo ""
echo "Testing SSH connections..."
echo ""

# Test connections
for vm in "${VMS[@]}"; do
    IFS=':' read -r user_host name <<< "$vm"
    if ssh -i "$SSH_KEY_EXPANDED" -o ConnectTimeout=5 -o BatchMode=yes "$user_host" "echo 'Connection successful'" 2>/dev/null; then
        echo "✓ $name ($user_host) - SSH key authentication working"
    else
        echo "✗ $name ($user_host) - SSH key authentication failed"
        echo "  Run: ssh-copy-id -i $PUBLIC_KEY $user_host"
    fi
done

echo ""
echo "=== SSH Key Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Test Ansible connection:"
echo "   cd $PROJECT_ROOT/infra/ansible"
echo "   ansible all -i inventory/hosts.yml -m ping"
echo ""
echo "2. If using a different SSH key path, update:"
echo "   infra/ansible/inventory/hosts.yml"
echo "   (Set ansible_ssh_private_key_file to your key path)"

