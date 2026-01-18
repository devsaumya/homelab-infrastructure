# ER605 VLAN Configuration
# Generated from verified architecture (2026-01-18)

This document provides step-by-step instructions for configuring VLANs on the TP-Link ER605 router based on the verified homelab network architecture.

## Physical Port Mapping

Configure the following port-level VLAN settings on the ER605:

| Port | Device | PVID (Native VLAN) | Tagged VLANs | Purpose |
|------|--------|-------------------|--------------|---------|
| **Port 1** | ISP | - | - | WAN Interface |
| **Port 2** | Synology DS720+ NAS | 1 | 2, 10, 20, 99 | VM Host & Management |
| **Port 3** | Admin PC | 1 | 2, 10, 20, 99 | Administrative Access |
| **Port 4** | Netgear Orbi RBR350 | 10 | 2, 20, 99 | WiFi Access Point |
| **Port 5** | Management Spare | 1 | - | Reserved for Management |

### Port Configuration Details

#### Port 1 (WAN)
- **Type**: WAN uplink to ISP
- **Configuration**: Configured in WAN settings, not VLAN settings

#### Port 2 (Synology DS720+ NAS)
- **Native VLAN (PVID)**: 1 (Management)
- **Reason**: NAS itself is a management device (IP: 10.0.1.100)
- **Tagged VLANs**: 2, 10, 20, 99
- **Reason**: NAS hosts VMs (k3s-master, security-ops) that need access to multiple VLANs
- **Traffic**: Untagged traffic from NAS goes to VLAN 1; VMs send tagged traffic for other VLANs

#### Port 3 (Admin PC)
- **Native VLAN (PVID)**: 1 (Management)
- **Reason**: Primary administrative workstation (IP: 10.0.1.105)
- **Tagged VLANs**: 2, 10, 20, 99
- **Reason**: Admin access to all network segments for troubleshooting and management
- **Requirements**: Admin PC must support 802.1Q VLAN tagging if accessing non-VLAN-1 networks

#### Port 4 (Netgear Orbi RBR350)
- **Native VLAN (PVID)**: 10 (Trusted WiFi)
- **Reason**: Primary WiFi SSID on Trusted_WiFi network (IP: 10.0.10.100)
- **Tagged VLANs**: 2, 20, 99
- **Reason**: Support for multi-SSID configuration (Guest WiFi on VLAN 99, future SSIDs)
- **Note**: VLAN 1 (Management) is NOT tagged on this port for security isolation

#### Port 5 (Management Spare)
- **Native VLAN (PVID)**: 1 (Management)
- **Purpose**: Reserved spare port for emergency management access or future expansion

---

## VLAN Setup

Navigate to **Network → LAN → VLAN** in the ER605 web interface and create the following VLANs:

| VLAN ID | Name | IP Range | Gateway | Isolation | Reserved IPs |
|---------|------|----------|---------|-----------|--------------|
| **1** | Management | 10.0.1.0/24 | 10.0.1.1 | **Deisolated** (Admin) | 10.0.1.100 (NAS), 10.0.1.105 (PC) |
| **10** | Trusted_WiFi | 10.0.10.0/24 | 10.0.10.1 | **Isolated** (IoT) | 10.0.10.100 (RBR), 10.0.10.101 (RBS) |
| **2** | Trusted_LAN | 10.0.2.0/24 | 10.0.2.1 | **Isolated** | Future Wired Expansion |
| **20** | DMZ | 10.0.20.0/24 | 10.0.20.1 | **Isolated** | Traefik / Ingress Targets |
| **99** | Guest | 10.0.99.0/24 | 10.0.99.1 | **Isolated** | Visitor Internet Access |

### Isolation Status Explanation

- **Deisolated (Management - VLAN 1)**: Full bidirectional access to ALL other VLANs. This is the administrative network with unrestricted access for management and troubleshooting.
  
- **Isolated (All Other VLANs)**: Devices on these VLANs **cannot** communicate with each other or with other VLANs by default. Each isolated VLAN only has Internet access and specific allowed exceptions configured in firewall rules.

---

## DHCP Configuration

For each VLAN, configure DHCP server settings:

### Access DHCP Settings
1. Navigate to **Network → LAN → DHCP Server**
2. Select the VLAN from the dropdown
3. Enable DHCP Server

### DHCP Server Settings per VLAN

| VLAN | Gateway IP | DHCP Range | Lease Time | Primary DNS | Secondary DNS |
|------|-----------|------------|------------|-------------|---------------|
| **1 (Management)** | 10.0.1.1 | 10.0.1.50 - 10.0.1.250 | 24 hours | 10.0.1.53 (AdGuard) | 1.1.1.1 |
| **10 (Trusted WiFi)** | 10.0.10.1 | 10.0.10.50 - 10.0.10.250 | 24 hours | 10.0.1.53 (AdGuard) | 1.1.1.1 |
| **2 (Trusted LAN)** | 10.0.2.1 | 10.0.2.50 - 10.0.2.250 | 24 hours | 10.0.1.53 (AdGuard) | 1.1.1.1 |
| **20 (DMZ)** | 10.0.20.1 | 10.0.20.50 - 10.0.20.250 | 12 hours | 10.0.1.53 (AdGuard) | 1.1.1.1 |
| **99 (Guest)** | 10.0.99.1 | 10.0.99.50 - 10.0.99.250 | 2 hours | 10.0.1.53 (AdGuard) | 1.1.1.1 |

### DHCP Reservations

Configure static DHCP reservations for key infrastructure devices:

#### VLAN 1 (Management)
- **10.0.1.100**: Synology DS720+ NAS (MAC: *enter NAS MAC*)
- **10.0.1.105**: Admin PC (MAC: *enter PC MAC*)
- **10.0.1.108**: k3s-master VM (MAC: *enter VM1 MAC*)
- **10.0.1.109**: security-ops VM (VM2) (MAC: *enter VM2 MAC*)
- **10.0.1.53**: AdGuard Home (assigned via k8s LoadBalancer)

#### VLAN 10 (Trusted WiFi)
- **10.0.10.100**: Netgear Orbi RBR350 (MAC: *enter RBR MAC*)
- **10.0.10.101**: Netgear Orbi RBS350 (MAC: *enter RBS MAC*)

---

## Port-Based VLAN Assignment

Configure which ports belong to which VLANs:

### Navigate to: Network → LAN → VLAN → Port Config

Set port membership as follows:

| Port | Untagged VLANs | Tagged VLANs |
|------|----------------|--------------|
| Port 1 (WAN) | - | - |
| Port 2 (NAS) | 1 | 2, 10, 20, 99 |
| Port 3 (Admin PC) | 1 | 2, 10, 20, 99 |
| Port 4 (Orbi) | 10 | 2, 20, 99 |
| Port 5 (Spare) | 1 | - |

**Important**: Ensure PVID (Port VLAN ID) matches the "Untagged VLANs" column for each port.

---

## Inter-VLAN Routing

The ER605 acts as the router between VLANs:

- **Inter-VLAN routing is ENABLED** on the ER605
- **Default behavior**: All VLANs can route to each other (this will be restricted by firewall rules)
- **Firewall rules** (configured separately) enforce isolation policies

See [FIREWALL_RULES.md](./FIREWALL_RULES.md) for ACL configuration.

---

## Verification Steps

After completing configuration, verify VLAN setup:

### 1. Check Port Configuration
```bash
# From Admin PC (10.0.1.105), verify you can access:
ping 10.0.1.1      # ER605 gateway on VLAN 1
ping 10.0.1.100    # NAS on VLAN 1
ping 10.0.10.100   # Orbi on VLAN 10 (should work from Management VLAN)
```

### 2. Test VLAN Isolation
From a device on VLAN 10 (Trusted WiFi), test isolation:
```bash
# Should succeed (Internet access)
ping 1.1.1.1

# Should fail (blocked by firewall - VLAN isolation)
ping 10.0.1.100    # NAS on VLAN 1
ping 10.0.2.1      # VLAN 2 gateway
```

### 3. Verify DHCP
- Connect a test device to each VLAN
- Confirm device receives IP in correct range
- Verify DNS settings (Primary: 10.0.1.53)

### 4. Check Tagged VLAN Traffic
If Admin PC supports VLAN tagging:
```bash
# Create VLAN interface for VLAN 10
# Linux: ip link add link eth0 name eth0.10 type vlan id 10
# Windows: Configure VLAN ID in network adapter advanced settings

# Request DHCP on VLAN 10 interface
# Should receive IP in 10.0.10.x range
```

---

## Troubleshooting

### Issue: Devices not getting DHCP address
- Verify DHCP server is enabled for the VLAN
- Check DHCP pool has available IPs
- Ensure port PVID matches expected VLAN
- Check cable connection and link status

### Issue: Cannot access devices on other VLANs from Management
- Verify Management VLAN firewall rules allow inter-VLAN traffic
- Check device has gateway configured correctly
- Verify routing is enabled between VLANs on ER605

### Issue: Tagged VLAN traffic not working
- Confirm port has VLAN ID in "Tagged VLANs" list
- Verify device/switch supports 802.1Q tagging
- Check VLAN interface configuration on client device

### Issue: WiFi devices on wrong VLAN
- Verify Orbi port (Port 4) PVID is set to 10
- Check SSID-to-VLAN mapping in Orbi configuration
- Confirm WiFi clients are receiving IP in 10.0.10.x range

---

## Next Steps

1. Configure firewall rules: See [FIREWALL_RULES.md](./FIREWALL_RULES.md)
2. Set up WiFi: See [WIFI_CONFIG.md](./WIFI_CONFIG.md)
3. Configure AdGuard Home DNS: See main documentation in `docs/MASTER.md`
4. Deploy Kubernetes networking: See `k8s/base/networking/`
