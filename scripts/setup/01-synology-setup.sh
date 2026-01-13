#!/bin/bash
set -euo pipefail

# Synology NAS initial setup script
# This script helps configure the Synology NAS for integration

echo "=== Synology NAS Setup ==="

SYNOLOGY_IP="${SYNOLOGY_IP:-10.0.1.50}"
SYNOLOGY_USER="${SYNOLOGY_USER:-admin}"

echo "Synology IP: $SYNOLOGY_IP"
echo "Synology User: $SYNOLOGY_USER"
echo ""
echo "Please ensure the following are configured on your Synology NAS:"
echo "1. Enable SSH (Control Panel > Terminal & SNMP > Enable SSH service)"
echo "2. Enable NFS (Control Panel > File Services > NFS)"
echo "3. Enable SMB with SMB3 encryption (Control Panel > File Services > SMB)"
echo "4. Create shared folder for k3s storage: /volume1/k3s-storage"
echo "5. Set appropriate permissions for the shared folder"
echo ""
echo "After configuration, run the Ansible playbook to automate setup:"
echo "  ansible-playbook -i infra/ansible/inventory/hosts.yml infra/ansible/playbooks/00-bootstrap.yml"

