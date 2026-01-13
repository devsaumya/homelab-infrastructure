# DNS Implementation

DNS configuration generation from contracts.

## Overview

This directory contains scripts to generate DNS server configurations from `contracts/dns-zones.yaml`.

## Usage

### Generate DNS Configurations

```bash
python3 dns/generate_dns_config.py
```

This generates:
- `adguard_dns.conf` - AdGuard Home DNS records
- `bind_zones.conf` - BIND zone file format
- `ansible_vars.json` - Ansible variables for DNS automation

### AdGuard Home Integration

The generated `adguard_dns.conf` can be imported into AdGuard Home:

1. Log into AdGuard Home web UI
2. Navigate to **DNS Settings → DNS Rewrites**
3. Import or manually add the records from `adguard_dns.conf`

### Ansible Integration

Use `ansible_vars.json` in Ansible playbooks:

```yaml
- name: Configure DNS zones
  include_vars:
    file: dns/ansible_vars.json
  tasks:
    - name: Add DNS records to AdGuard
      # Your AdGuard configuration tasks here
```

## Contract Source

DNS configuration is derived from `contracts/dns-zones.yaml` which defines:
- Authoritative zones (e.g., `home.internal`)
- A records for internal services
- DNS policy (ad blocking, malware protection, DNSSEC)

## Future Enhancements

- Support for CNAME, MX, TXT records
- Dynamic DNS updates
- Integration with Cloudflare DNS API
- DNS over HTTPS (DoH) configuration
