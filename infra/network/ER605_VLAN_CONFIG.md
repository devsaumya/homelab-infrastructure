# ER605 VLAN Configuration
# Generated from contracts

## VLAN Setup

Navigate to **Network → VLAN** and create the following VLANs:

| VLAN ID | Name | IP Range | Gateway |
|---------|------|----------|---------|

## DHCP Configuration

For each VLAN, configure DHCP:

1. Navigate to **Network → DHCP Server**
2. Select the VLAN
3. Enable DHCP Server
4. Configure:
   - **Gateway**: VLAN gateway IP
   - **Primary DNS**: `10.0.1.53` (AdGuard Home)
   - **Secondary DNS**: `1.1.1.1` (Cloudflare)
