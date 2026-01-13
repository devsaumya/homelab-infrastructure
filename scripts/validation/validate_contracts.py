#!/usr/bin/env python3
"""
Contract validation script for homelab infrastructure.
Validates consistency across VLAN, IPAM, DNS, and access matrix contracts.
"""

import yaml
import ipaddress
import sys
from pathlib import Path
from typing import Dict, List, Set, Any


class ContractValidator:
    def __init__(self, contracts_dir: Path):
        self.contracts_dir = contracts_dir
        self.errors = []
        self.warnings = []
        
    def load_yaml(self, filename: str) -> Dict[str, Any]:
        """Load a YAML file and return its contents."""
        filepath = self.contracts_dir / filename
        if not filepath.exists():
            self.errors.append(f"Missing contract file: {filename}")
            return {}
        
        try:
            with open(filepath, 'r') as f:
                return yaml.safe_load(f) or {}
        except yaml.YAMLError as e:
            self.errors.append(f"Invalid YAML in {filename}: {e}")
            return {}
    
    def validate_vlans(self, vlans_data: Dict[str, Any]) -> Dict[str, Dict]:
        """Validate VLAN definitions and return normalized VLAN data."""
        vlans = {}
        
        if 'vlans' not in vlans_data:
            self.errors.append("vlans.yaml: Missing 'vlans' key")
            return vlans
        
        for vlan_name, vlan_config in vlans_data['vlans'].items():
            if 'id' not in vlan_config:
                self.errors.append(f"VLAN '{vlan_name}': Missing 'id' field")
                continue
            
            vlan_id = vlan_config['id']
            if vlan_id in [v['id'] for v in vlans.values()]:
                self.errors.append(f"VLAN '{vlan_name}': Duplicate VLAN ID {vlan_id}")
            
            vlans[vlan_name] = {
                'id': vlan_id,
                'name': vlan_name,
                'trust': vlan_config.get('trust', 'unknown'),
                'default_policy': vlan_config.get('default_policy', 'deny')
            }
        
        return vlans
    
    def validate_ipam(self, ipam_data: Dict[str, Any], vlans: Dict[str, Dict]) -> Dict[str, Dict]:
        """Validate IPAM configuration and check consistency with VLANs."""
        networks = {}
        
        if 'networks' not in ipam_data:
            self.errors.append("ipam.yaml: Missing 'networks' key")
            return networks
        
        # Build VLAN ID to name mapping
        vlan_id_to_name = {v['id']: name for name, v in vlans.items()}
        
        for network_name, network_config in ipam_data['networks'].items():
            if 'vlan_id' not in network_config:
                self.errors.append(f"Network '{network_name}': Missing 'vlan_id' field")
                continue
            
            vlan_id = network_config['vlan_id']
            if vlan_id not in vlan_id_to_name:
                self.errors.append(f"Network '{network_name}': VLAN ID {vlan_id} not defined in vlans.yaml")
            
            # Validate CIDR
            if 'cidr' not in network_config:
                self.errors.append(f"Network '{network_name}': Missing 'cidr' field")
                continue
            
            try:
                cidr = ipaddress.ip_network(network_config['cidr'], strict=False)
            except ValueError as e:
                self.errors.append(f"Network '{network_name}': Invalid CIDR '{network_config['cidr']}': {e}")
                continue
            
            # Validate gateway
            if 'gateway' not in network_config:
                self.errors.append(f"Network '{network_name}': Missing 'gateway' field")
                continue
            
            try:
                gateway = ipaddress.ip_address(network_config['gateway'])
                if gateway not in cidr:
                    self.errors.append(f"Network '{network_name}': Gateway {gateway} not in CIDR {cidr}")
            except ValueError as e:
                self.errors.append(f"Network '{network_name}': Invalid gateway '{network_config['gateway']}': {e}")
            
            networks[network_name] = {
                'vlan_id': vlan_id,
                'cidr': str(cidr),
                'gateway': network_config['gateway'],
                'vlan_name': vlan_id_to_name.get(vlan_id)
            }
        
        # Validate reservations
        if 'reservations' in ipam_data:
            for res_name, res_config in ipam_data['reservations'].items():
                if 'ip' not in res_config:
                    self.errors.append(f"Reservation '{res_name}': Missing 'ip' field")
                    continue
                
                if 'vlan' not in res_config:
                    self.errors.append(f"Reservation '{res_name}': Missing 'vlan' field")
                    continue
                
                try:
                    ip = ipaddress.ip_address(res_config['ip'])
                except ValueError as e:
                    self.errors.append(f"Reservation '{res_name}': Invalid IP '{res_config['ip']}': {e}")
                    continue
                
                vlan_ref = res_config['vlan']
                if vlan_ref not in networks:
                    self.errors.append(f"Reservation '{res_name}': VLAN reference '{vlan_ref}' not found in networks")
                    continue
                
                network_cidr = ipaddress.ip_network(networks[vlan_ref]['cidr'])
                if ip not in network_cidr:
                    self.errors.append(f"Reservation '{res_name}': IP {ip} not in network CIDR {network_cidr}")
        
        return networks
    
    def validate_dns(self, dns_data: Dict[str, Any], networks: Dict[str, Dict], 
                     reservations: Dict[str, Dict]) -> Dict[str, List]:
        """Validate DNS zones and check consistency with IPAM."""
        dns_records = {}
        
        if 'zones' not in dns_data:
            self.errors.append("dns-zones.yaml: Missing 'zones' key")
            return dns_records
        
        # Build IP to reservation mapping
        ip_to_reservation = {}
        if reservations:
            for res_name, res_config in reservations.items():
                if 'ip' in res_config:
                    ip_to_reservation[res_config['ip']] = res_name
        
        for zone in dns_data['zones']:
            zone_name = zone.get('name', 'unknown')
            if zone_name not in dns_records:
                dns_records[zone_name] = []
            
            if 'records' not in zone:
                self.warnings.append(f"Zone '{zone_name}': No records defined")
                continue
            
            for record in zone['records']:
                if record.get('type') == 'A':
                    ip = record.get('value')
                    if not ip:
                        self.errors.append(f"Zone '{zone_name}': Record '{record.get('name')}' missing IP value")
                        continue
                    
                    try:
                        ipaddress.ip_address(ip)
                    except ValueError as e:
                        self.errors.append(f"Zone '{zone_name}': Record '{record.get('name')}' has invalid IP '{ip}': {e}")
                        continue
                    
                    # Check if IP matches a reservation
                    if ip not in ip_to_reservation.values() and ip not in [r.get('ip') for r in reservations.values()]:
                        self.warnings.append(f"Zone '{zone_name}': Record '{record.get('name')}' IP {ip} not found in IPAM reservations")
        
        return dns_records
    
    def validate_access_matrix(self, access_data: Dict[str, Any], vlans: Dict[str, Dict]):
        """Validate access matrix rules reference valid VLANs."""
        if 'access_matrix' not in access_data:
            self.errors.append("access-matrix.yaml: Missing 'access_matrix' key")
            return
        
        vlan_names = set(vlans.keys())
        vlan_names.add('*')  # Wildcard is valid
        vlan_names.add('internet')  # Internet is a special target
        
        for rule in access_data['access_matrix']:
            if 'from' not in rule:
                self.errors.append(f"Access rule: Missing 'from' field")
                continue
            
            if 'to' not in rule:
                self.errors.append(f"Access rule: Missing 'to' field")
                continue
            
            from_vlan = rule['from']
            to_vlan = rule['to']
            
            if from_vlan not in vlan_names:
                self.errors.append(f"Access rule: Invalid 'from' VLAN '{from_vlan}'")
            
            if to_vlan not in vlan_names:
                self.errors.append(f"Access rule: Invalid 'to' VLAN '{to_vlan}'")
            
            if 'action' not in rule:
                self.errors.append(f"Access rule: Missing 'action' field")
            elif rule['action'] not in ['allow', 'deny']:
                self.errors.append(f"Access rule: Invalid action '{rule['action']}' (must be 'allow' or 'deny')")
    
    def validate_platform(self, platform_data: Dict[str, Any]):
        """Validate platform configuration."""
        if 'platform' not in platform_data:
            self.errors.append("platform.yaml: Missing 'platform' key")
            return
        
        platform = platform_data['platform']
        
        if 'kubernetes' in platform:
            k8s = platform['kubernetes']
            if 'primary_node' in k8s:
                node_name = k8s['primary_node']
                if not node_name.endswith('.home.internal'):
                    self.warnings.append(f"Platform: Kubernetes primary_node '{node_name}' doesn't match expected domain pattern")
    
    def validate_all(self) -> bool:
        """Run all validation checks."""
        print("Loading contract files...")
        
        vlans_data = self.load_yaml('vlans.yaml')
        ipam_data = self.load_yaml('ipam.yaml')
        dns_data = self.load_yaml('dns-zones.yaml')
        access_data = self.load_yaml('access-matrix.yaml')
        platform_data = self.load_yaml('platform.yaml')
        
        print("Validating VLANs...")
        vlans = self.validate_vlans(vlans_data)
        
        print("Validating IPAM...")
        networks = self.validate_ipam(ipam_data, vlans)
        reservations = ipam_data.get('reservations', {})
        
        print("Validating DNS zones...")
        dns_records = self.validate_dns(dns_data, networks, reservations)
        
        print("Validating access matrix...")
        self.validate_access_matrix(access_data, vlans)
        
        print("Validating platform configuration...")
        self.validate_platform(platform_data)
        
        # Print results
        print("\n" + "="*60)
        if self.errors:
            print(f"[ERROR] Found {len(self.errors)} error(s):")
            for error in self.errors:
                print(f"  - {error}")
        
        if self.warnings:
            print(f"\n[WARNING] Found {len(self.warnings)} warning(s):")
            for warning in self.warnings:
                print(f"  - {warning}")
        
        if not self.errors and not self.warnings:
            print("[SUCCESS] All contracts are valid!")
        
        print("="*60 + "\n")
        
        return len(self.errors) == 0


def main():
    """Main entry point."""
    contracts_dir = Path(__file__).parent.parent.parent / 'infra' / 'contracts'
    
    if not contracts_dir.exists():
        print(f"Error: Contracts directory not found: {contracts_dir}")
        sys.exit(1)
    
    validator = ContractValidator(contracts_dir)
    success = validator.validate_all()
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

