# ER605 VLAN Configuration
# Generated from contracts

## VLAN Setup

Navigate to **Network → VLAN** and create the following VLANs:

| VLAN ID | Name | IP Range | Gateway |
|---------|------|----------|---------|
| 1 | Management | 10.0.1.0/24 | 10.0.1.1 |
| 2 | Trusted | 10.0.2.0/24 | 10.0.2.1 |
| 10 | Iot | 10.0.10.0/24 | 10.0.10.1 |
| 20 | Dmz | 10.0.20.0/24 | 10.0.20.1 |
| 99 | Guest | 10.0.99.0/24 | 10.0.99.1 |

## DHCP Configuration

For each VLAN, configure DHCP:

1. Navigate to **Network → DHCP Server**
2. Select the VLAN
3. Enable DHCP Server
4. Configure:
   - **Gateway**: VLAN gateway IP
   - **Primary DNS**: `10.0.1.53` (AdGuard Home)
   - **Secondary DNS**: `1.1.1.1` (Cloudflare)
