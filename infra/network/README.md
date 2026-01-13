# Network Implementation

Network configuration generation from contracts.

## Overview

This directory contains scripts to generate network configurations from contracts:
- `vlans.yaml` - VLAN definitions
- `ipam.yaml` - IP address management
- `access-matrix.yaml` - Firewall rules

## Usage

### Generate Network Configurations

```bash
python3 network/generate_network_config.py
```

This generates:
- `ER605_VLAN_CONFIG.md` - ER605 router VLAN configuration guide
- `FIREWALL_RULES.md` - Firewall rules documentation
- `network-policies.yaml` - Kubernetes NetworkPolicy manifests
- `ansible_vars.json` - Ansible variables for network automation

### ER605 Router Configuration

The `ER605_VLAN_CONFIG.md` file provides step-by-step instructions for configuring VLANs on the TP-Link ER605 router based on your contracts.

### Firewall Rules

The `FIREWALL_RULES.md` file documents all firewall rules derived from the access matrix contract. Use this as a reference when configuring the ER605 firewall.

### Kubernetes Network Policies

The generated `network-policies.yaml` can be applied to your k3s cluster:

```bash
kubectl apply -f network/network-policies.yaml
```

### Ansible Integration

Use `ansible_vars.json` in Ansible playbooks:

```yaml
- name: Configure network
  include_vars:
    file: network/ansible_vars.json
  tasks:
    - name: Configure VLANs
      # Your network configuration tasks here
```

## Contract Source

Network configuration is derived from:
- `contracts/vlans.yaml` - VLAN definitions and trust levels
- `contracts/ipam.yaml` - IP address ranges, gateways, and reservations
- `contracts/access-matrix.yaml` - Inter-VLAN access rules

## Future Enhancements

- ER605 API integration for automated configuration
- Network topology visualization
- IP address conflict detection
- DHCP reservation generation
