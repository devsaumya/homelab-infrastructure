#!/usr/bin/env python3
"""
Generate network configuration from contracts.
Supports ER605 router config, firewall rules, and network policies.
"""

import yaml
import sys
from pathlib import Path
from typing import Dict, List, Any


class NetworkConfigGenerator:
    def __init__(self, contracts_dir: Path):
        self.contracts_dir = contracts_dir
        
    def load_contracts(self) -> Dict[str, Any]:
        """Load all network-related contracts."""
        contracts = {}
        
        files = {
            'vlans': 'vlans.yaml',
            'ipam': 'ipam.yaml',
            'access': 'access-matrix.yaml'
        }
        
        for key, filename in files.items():
            filepath = self.contracts_dir / filename
            if filepath.exists():
                with open(filepath, 'r') as f:
                    contracts[key] = yaml.safe_load(f) or {}
            else:
                print(f"Warning: Contract file not found: {filename}")
                contracts[key] = {}
        
        return contracts
    
    def generate_er605_vlan_config(self, contracts: Dict[str, Any]) -> str:
        """Generate ER605 VLAN configuration guide."""
        lines = []
        lines.append("# ER605 VLAN Configuration")
        lines.append("# Generated from contracts")
        lines.append("")
        lines.append("## VLAN Setup")
        lines.append("")
        lines.append("Navigate to **Network → VLAN** and create the following VLANs:")
        lines.append("")
        lines.append("| VLAN ID | Name | IP Range | Gateway |")
        lines.append("|---------|------|----------|---------|")
        
        vlans = contracts.get('vlans', {}).get('vlans', {})
        ipam = contracts.get('ipam', {}).get('networks', {})
        
        # Build VLAN ID to network mapping
        vlan_to_network = {}
        for net_name, net_config in ipam.items():
            vlan_id = net_config.get('vlan_id')
            if vlan_id:
                vlan_to_network[vlan_id] = net_config
        
        for vlan_name, vlan_config in vlans.items():
            vlan_id = vlan_config.get('id')
            network = vlan_to_network.get(vlan_id, {})
            cidr = network.get('cidr', 'N/A')
            gateway = network.get('gateway', 'N/A')
            
            lines.append(f"| {vlan_id} | {vlan_name.title()} | {cidr} | {gateway} |")
        
        lines.append("")
        lines.append("## DHCP Configuration")
        lines.append("")
        lines.append("For each VLAN, configure DHCP:")
        lines.append("")
        lines.append("1. Navigate to **Network → DHCP Server**")
        lines.append("2. Select the VLAN")
        lines.append("3. Enable DHCP Server")
        lines.append("4. Configure:")
        lines.append("   - **Gateway**: VLAN gateway IP")
        lines.append("   - **Primary DNS**: `10.0.1.53` (AdGuard Home)")
        lines.append("   - **Secondary DNS**: `1.1.1.1` (Cloudflare)")
        lines.append("")
        
        return "\n".join(lines)
    
    def generate_firewall_rules(self, contracts: Dict[str, Any]) -> str:
        """Generate firewall rules from access matrix."""
        lines = []
        lines.append("# Firewall Rules Configuration")
        lines.append("# Generated from contracts/access-matrix.yaml")
        lines.append("")
        lines.append("Navigate to **Security → Firewall → ACL Rules**")
        lines.append("")
        
        access_matrix = contracts.get('access', {}).get('access_matrix', [])
        ipam = contracts.get('ipam', {}).get('networks', {})
        
        # Build VLAN name to CIDR mapping
        vlan_to_cidr = {}
        for net_name, net_config in ipam.items():
            vlan_id = net_config.get('vlan_id')
            cidr = net_config.get('cidr', '')
            # Try to match VLAN name from network name
            vlan_name = net_name.replace('vlan', '').replace('_', '').split('_')[0]
            vlan_to_cidr[vlan_name] = cidr
        
        rule_num = 1
        for rule in access_matrix:
            from_vlan = rule.get('from', '')
            to_vlan = rule.get('to', '')
            action = rule.get('action', 'deny')
            ports = rule.get('ports', [])
            
            if from_vlan == '*' or to_vlan == '*':
                continue  # Skip wildcard rules for now
            
            from_cidr = vlan_to_cidr.get(from_vlan, '')
            to_cidr = vlan_to_cidr.get(to_vlan, '')
            
            if not from_cidr:
                continue
            
            lines.append(f"### Rule {rule_num}: {from_vlan.title()} -> {to_vlan.title()}")
            lines.append("")
            lines.append(f"- **Source**: {from_cidr}")
            
            if to_vlan == 'internet':
                lines.append("- **Destination**: Any")
            else:
                lines.append(f"- **Destination**: {to_cidr}")
            
            if ports:
                lines.append(f"- **Service**: {', '.join(map(str, ports))}")
            else:
                lines.append("- **Service**: Any")
            
            lines.append(f"- **Action**: {action.title()}")
            lines.append("")
            
            rule_num += 1
        
        return "\n".join(lines)
    
    def generate_kubernetes_network_policies(self, contracts: Dict[str, Any]) -> str:
        """Generate Kubernetes NetworkPolicy manifests."""
        lines = []
        lines.append("# Kubernetes Network Policies")
        lines.append("# Generated from contracts/access-matrix.yaml")
        lines.append("")
        lines.append("apiVersion: networking.k8s.io/v1")
        lines.append("kind: NetworkPolicy")
        lines.append("metadata:")
        lines.append("  name: default-deny-all")
        lines.append("  namespace: default")
        lines.append("spec:")
        lines.append("  podSelector: {}")
        lines.append("  policyTypes:")
        lines.append("  - Ingress")
        lines.append("  - Egress")
        lines.append("---")
        lines.append("")
        
        # Generate policies based on access matrix
        access_matrix = contracts.get('access', {}).get('access_matrix', [])
        
        for rule in access_matrix:
            from_vlan = rule.get('from', '')
            to_vlan = rule.get('to', '')
            action = rule.get('action', 'deny')
            
            if action == 'deny' or from_vlan == '*' or to_vlan == '*':
                continue
            
            # This is a simplified example - real implementation would be more complex
            lines.append(f"# Policy: Allow {from_vlan} -> {to_vlan}")
            lines.append("")
        
        return "\n".join(lines)
    
    def generate_ansible_vars(self, contracts: Dict[str, Any]) -> Dict[str, Any]:
        """Generate Ansible variables for network configuration."""
        vars_dict = {
            'vlans': contracts.get('vlans', {}).get('vlans', {}),
            'networks': contracts.get('ipam', {}).get('networks', {}),
            'reservations': contracts.get('ipam', {}).get('reservations', {}),
            'firewall_rules': contracts.get('access', {}).get('access_matrix', [])
        }
        
        return vars_dict


def main():
    """Main entry point."""
    script_dir = Path(__file__).parent
    contracts_dir = script_dir.parent.parent / 'contracts'
    
    generator = NetworkConfigGenerator(contracts_dir)
    contracts = generator.load_contracts()
    
    # Generate ER605 config guide
    er605_config = generator.generate_er605_vlan_config(contracts)
    output_file = script_dir / 'ER605_VLAN_CONFIG.md'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(er605_config)
    print(f"[SUCCESS] Generated ER605 VLAN config: {output_file}")
    
    # Generate firewall rules
    firewall_rules = generator.generate_firewall_rules(contracts)
    output_file = script_dir / 'FIREWALL_RULES.md'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(firewall_rules)
    print(f"[SUCCESS] Generated firewall rules: {output_file}")
    
    # Generate Kubernetes network policies
    k8s_policies = generator.generate_kubernetes_network_policies(contracts)
    output_file = script_dir / 'network-policies.yaml'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(k8s_policies)
    print(f"[SUCCESS] Generated Kubernetes network policies: {output_file}")
    
    # Generate Ansible vars
    import json
    ansible_vars = generator.generate_ansible_vars(contracts)
    output_file = script_dir / 'ansible_vars.json'
    with open(output_file, 'w') as f:
        json.dump(ansible_vars, f, indent=2)
    print(f"[SUCCESS] Generated Ansible vars: {output_file}")


if __name__ == '__main__':
    main()

