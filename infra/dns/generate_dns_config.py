#!/usr/bin/env python3
"""
Generate DNS configuration from contracts/dns-zones.yaml.
Supports multiple DNS server formats (AdGuard Home, BIND, etc.)
"""

import yaml
import sys
from pathlib import Path
from typing import Dict, List, Any


class DNSConfigGenerator:
    def __init__(self, contracts_dir: Path):
        self.contracts_dir = contracts_dir
        
    def load_dns_zones(self) -> Dict[str, Any]:
        """Load DNS zones from contracts."""
        dns_file = self.contracts_dir / 'dns-zones.yaml'
        
        if not dns_file.exists():
            print(f"Error: DNS zones file not found: {dns_file}")
            sys.exit(1)
        
        with open(dns_file, 'r') as f:
            return yaml.safe_load(f) or {}
    
    def generate_adguard_config(self, dns_data: Dict[str, Any]) -> str:
        """Generate AdGuard Home configuration."""
        config_lines = []
        config_lines.append("# AdGuard Home DNS configuration")
        config_lines.append("# Generated from contracts/dns-zones.yaml")
        config_lines.append("")
        
        if 'zones' not in dns_data:
            return "\n".join(config_lines)
        
        for zone in dns_data['zones']:
            zone_name = zone.get('name', '')
            if not zone_name:
                continue
            
            config_lines.append(f"# Zone: {zone_name}")
            
            if 'records' in zone:
                for record in zone['records']:
                    name = record.get('name', '')
                    record_type = record.get('type', 'A')
                    value = record.get('value', '')
                    
                    if name and value:
                        fqdn = f"{name}.{zone_name}" if name != zone_name else zone_name
                        config_lines.append(f"{fqdn}\t{record_type}\t{value}")
            
            config_lines.append("")
        
        return "\n".join(config_lines)
    
    def generate_bind_config(self, dns_data: Dict[str, Any]) -> str:
        """Generate BIND zone file format."""
        config_lines = []
        config_lines.append("; BIND zone file")
        config_lines.append("; Generated from contracts/dns-zones.yaml")
        config_lines.append("")
        
        if 'zones' not in dns_data:
            return "\n".join(config_lines)
        
        for zone in dns_data['zones']:
            zone_name = zone.get('name', '')
            if not zone_name:
                continue
            
            config_lines.append(f"; Zone: {zone_name}")
            config_lines.append(f"$ORIGIN {zone_name}.")
            config_lines.append(f"$TTL 3600")
            config_lines.append("")
            config_lines.append("@\tIN\tSOA\tns1.{zone_name}.\tadmin.{zone_name}.\t(")
            config_lines.append("\t\t2024010101\t; Serial")
            config_lines.append("\t\t3600\t\t; Refresh")
            config_lines.append("\t\t1800\t\t; Retry")
            config_lines.append("\t\t604800\t\t; Expire")
            config_lines.append("\t\t86400\t\t; Minimum TTL")
            config_lines.append("\t)")
            config_lines.append("")
            
            if 'records' in zone:
                for record in zone['records']:
                    name = record.get('name', '')
                    record_type = record.get('type', 'A')
                    value = record.get('value', '')
                    
                    if name and value:
                        record_name = name if name != zone_name else "@"
                        config_lines.append(f"{record_name}\tIN\t{record_type}\t{value}")
            
            config_lines.append("")
        
        return "\n".join(config_lines)
    
    def generate_ansible_vars(self, dns_data: Dict[str, Any]) -> Dict[str, Any]:
        """Generate Ansible variables for DNS configuration."""
        vars_dict = {
            'dns_zones': [],
            'dns_policy': dns_data.get('dns_policy', {})
        }
        
        if 'zones' in dns_data:
            for zone in dns_data['zones']:
                zone_dict = {
                    'name': zone.get('name', ''),
                    'type': zone.get('type', 'authoritative'),
                    'records': zone.get('records', [])
                }
                vars_dict['dns_zones'].append(zone_dict)
        
        return vars_dict


def main():
    """Main entry point."""
    script_dir = Path(__file__).parent
    contracts_dir = script_dir.parent / 'contracts'
    
    generator = DNSConfigGenerator(contracts_dir)
    dns_data = generator.load_dns_zones()
    
    # Generate AdGuard Home config
    adguard_config = generator.generate_adguard_config(dns_data)
    output_file = script_dir / 'adguard_dns.conf'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(adguard_config)
    print(f"[SUCCESS] Generated AdGuard Home config: {output_file}")
    
    # Generate BIND config
    bind_config = generator.generate_bind_config(dns_data)
    output_file = script_dir / 'bind_zones.conf'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(bind_config)
    print(f"[SUCCESS] Generated BIND config: {output_file}")
    
    # Generate Ansible vars
    import json
    ansible_vars = generator.generate_ansible_vars(dns_data)
    output_file = script_dir / 'ansible_vars.json'
    with open(output_file, 'w') as f:
        json.dump(ansible_vars, f, indent=2)
    print(f"[SUCCESS] Generated Ansible vars: {output_file}")


if __name__ == '__main__':
    main()

