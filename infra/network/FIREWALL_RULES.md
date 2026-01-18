# ER605 Firewall Rules
# Network Access Control and Security Policies

This document defines comprehensive firewall and ACL rules for the TP-Link ER605 router to enforce VLAN isolation and security policies.

## Architecture Overview

The homelab network uses a **zero-trust, default-deny** security model with the following isolation policies:

- **Management VLAN (1)**: **DEISOLATED** - Full bidirectional access to all VLANs and Internet
- **Trusted WiFi VLAN (10)**: **ISOLATED** - Internet access only, blocked from all other VLANs
- **Trusted LAN VLAN (2)**: **ISOLATED** - Internet access only, blocked from all other VLANs
- **DMZ VLAN (20)**: **ISOLATED** - Internet access + specific ingress rules for exposed services
- **Guest VLAN (99)**: **ISOLATED** - Internet access only, completely blocked from all internal VLANs

---

## Firewall Rule Configuration

### Access Path
1. Log into ER605 web interface
2. Navigate to **Firewall → Access Control**
3. Create rules in the order specified below (rule order matters!)

### Rule Priority
- Rules are processed **top-to-bottom**
- First matching rule is applied
- Place most specific rules first, general rules last
- Explicit ALLOW rules before implicit DENY rules

---

## Rule Set 1: Management VLAN (Deisolated)

**Purpose**: Allow full administrative access from Management VLAN to all network segments.

| Priority | Name | Source | Destination | Service | Action | Notes |
|----------|------|--------|-------------|---------|--------|-------|
| 10 | MGMT-TO-ALL-ALLOW | VLAN 1 (10.0.1.0/24) | ANY | ANY | **ACCEPT** | Admin full access |
| 11 | ALL-TO-MGMT-ALLOW | ANY | VLAN 1 (10.0.1.0/24) | ANY | **ACCEPT** | Return traffic to Management |

**Rationale**: Management VLAN requires unrestricted access for:
- Network administration and troubleshooting
- VM management on NAS (k3s-master, security-ops)
- Cross-VLAN service deployment and monitoring
- Emergency access to all network segments

---

## Rule Set 2: Internet Access (All VLANs)

**Purpose**: Allow outbound Internet access for all VLANs.

| Priority | Name | Source | Destination | Service | Action | Notes |
|----------|------|--------|-------------|---------|--------|-------|
| 20 | VLAN10-TO-INTERNET | VLAN 10 (10.0.10.0/24) | WAN | HTTP, HTTPS, DNS, NTP | **ACCEPT** | IoT Internet access |
| 21 | VLAN2-TO-INTERNET | VLAN 2 (10.0.2.0/24) | WAN | HTTP, HTTPS, DNS, NTP, SSH | **ACCEPT** | Trusted LAN Internet |
| 22 | VLAN20-TO-INTERNET | VLAN 20 (10.0.20.0/24) | WAN | HTTP, HTTPS, DNS, NTP | **ACCEPT** | DMZ outbound |
| 23 | VLAN99-TO-INTERNET | VLAN 99 (10.0.99.0/24) | WAN | HTTP, HTTPS, DNS | **ACCEPT** | Guest Internet only |

**Service Definitions**:
- **HTTP**: TCP port 80
- **HTTPS**: TCP port 443
- **DNS**: UDP port 53, TCP port 53
- **NTP**: UDP port 123
- **SSH**: TCP port 22 (Trusted LAN only for remote work)

---

## Rule Set 3: DNS Forwarding (Internal)

**Purpose**: Allow all VLANs to query AdGuard Home DNS server on Management VLAN.

| Priority | Name | Source | Destination | Service | Action | Notes |
|----------|------|--------|-------------|---------|--------|-------|
| 30 | ALL-TO-ADGUARD-DNS | ANY | 10.0.1.53 | DNS (TCP/UDP 53) | **ACCEPT** | AdGuard Home DNS |
| 31 | ALL-TO-DNS-GATEWAY | ANY | 10.0.x.1 (per VLAN) | DNS (TCP/UDP 53) | **ACCEPT** | Gateway DNS relay |

**Rationale**: All devices need DNS resolution for Internet access. AdGuard Home (10.0.1.53) provides:
- DNS filtering and ad blocking
- Custom DNS records for `home.internal` domain
- DNS-based security (malware blocking)

---

## Rule Set 4: DMZ Ingress Rules

**Purpose**: Allow specific external and internal traffic to DMZ services.

| Priority | Name | Source | Destination | Service | Action | Notes |
|----------|------|--------|-------------|---------|--------|-------|
| 40 | WAN-TO-DMZ-HTTP | WAN | VLAN 20 (10.0.20.0/24) | HTTP (80) | **ACCEPT** | Public web services |
| 41 | WAN-TO-DMZ-HTTPS | WAN | VLAN 20 (10.0.20.0/24) | HTTPS (443) | **ACCEPT** | Public HTTPS services |
| 42 | MGMT-TO-DMZ-K8S-API | VLAN 1 (10.0.1.0/24) | VLAN 20 (10.0.20.0/24) | K8s API (6443) | **ACCEPT** | k3s cluster management |
| 43 | DMZ-TO-MGMT-NAS | VLAN 20 (10.0.20.0/24) | 10.0.1.100 | NFS, SMB | **ACCEPT** | DMZ persistent storage |

**Service Definitions**:
- **K8s API**: TCP port 6443
- **NFS**: TCP port 2049
- **SMB**: TCP port 445 (SMB3 with encryption required)

**Rationale**:
- DMZ hosts Traefik ingress controller and exposed k8s services
- Allows inbound HTTP/HTTPS for public-facing applications
- Management VLAN can access k8s API for cluster administration
- DMZ services can mount NFS/SMB shares from NAS for persistent volumes

---

## Rule Set 5: VLAN Isolation (Deny Rules)

**Purpose**: Block unauthorized inter-VLAN traffic (default-deny).

| Priority | Name | Source | Destination | Service | Action | Notes |
|----------|------|--------|-------------|---------|--------|-------|
| 90 | VLAN10-TO-INTERNAL-DENY | VLAN 10 (10.0.10.0/24) | 10.0.0.0/8 | ANY | **DROP** | Block IoT to internal |
| 91 | VLAN2-TO-INTERNAL-DENY | VLAN 2 (10.0.2.0/24) | 10.0.0.0/8 | ANY | **DROP** | Block Trusted LAN to internal |
| 92 | VLAN99-TO-INTERNAL-DENY | VLAN 99 (10.0.99.0/24) | 10.0.0.0/8 | ANY | **DROP** | Block Guest to ALL internal |
| 93 | VLAN20-TO-INTERNAL-DENY | VLAN 20 (10.0.20.0/24) | 10.0.0.0/8 | ANY | **DROP** | Block DMZ to internal (except allowed) |

**Rationale**: These rules enforce isolation by blocking:
- IoT devices (VLAN 10) from accessing internal services
- Trusted LAN (VLAN 2) from accessing management/NAS
- Guest WiFi (VLAN 99) from ANY internal network access
- DMZ (VLAN 20) from accessing internal resources (except NAS for PVs)

**Important**: These DENY rules are placed AFTER specific ALLOW rules (e.g., DNS, DMZ-to-NAS), so allowed traffic passes first.

---

## Rule Set 6: Anti-Spoofing (Security)

**Purpose**: Prevent IP spoofing and invalid traffic.

| Priority | Name | Source | Destination | Service | Action | Notes |
|----------|------|--------|-------------|---------|--------|-------|
| 5 | ANTI-SPOOF-VLAN1 | NOT 10.0.1.0/24 | ANY | ANY (source IP 10.0.1.x) | **DROP** | Block VLAN 1 spoofing |
| 6 | ANTI-SPOOF-VLAN10 | NOT 10.0.10.0/24 | ANY | ANY (source IP 10.0.10.x) | **DROP** | Block VLAN 10 spoofing |
| 7 | ANTI-SPOOF-VLAN2 | NOT 10.0.2.0/24 | ANY | ANY (source IP 10.0.2.x) | **DROP** | Block VLAN 2 spoofing |
| 8 | ANTI-SPOOF-VLAN20 | NOT 10.0.20.0/24 | ANY | ANY (source IP 10.0.20.x) | **DROP** | Block VLAN 20 spoofing |
| 9 | ANTI-SPOOF-VLAN99 | NOT 10.0.99.0/24 | ANY | ANY (source IP 10.0.99.x) | **DROP** | Block VLAN 99 spoofing |

**Rationale**: Prevent malicious devices from spoofing IP addresses from other VLANs.

---

## Rule Set 7: Default Policies

**Purpose**: Explicit default deny for unmatched traffic.

| Priority | Name | Source | Destination | Service | Action | Notes |
|----------|------|--------|-------------|---------|--------|-------|
| 999 | DEFAULT-DENY | ANY | ANY | ANY | **DROP** | Catch-all deny rule |

**Rationale**: Ensure any traffic not matching explicit ALLOW rules is blocked (defense-in-depth).

---

## Complete Rule Order (Summary)

1. **Priority 5-9**: Anti-spoofing rules
2. **Priority 10-11**: Management VLAN full access
3. **Priority 20-23**: Internet access for all VLANs
4. **Priority 30-31**: DNS forwarding (AdGuard Home)
5. **Priority 40-43**: DMZ ingress rules
6. **Priority 90-93**: VLAN isolation (inter-VLAN blocking)
7. **Priority 999**: Default deny

---

## NAT Configuration

### Outbound NAT (SNAT)
Enable outbound NAT for all private VLANs to WAN interface:

- **Source**: 10.0.0.0/8 (all internal VLANs)
- **Destination**: WAN
- **Action**: SNAT (Source NAT) to WAN IP

### Port Forwarding (DNAT) - Optional
If exposing DMZ services directly (not recommended - use Cloudflare Tunnel instead):

| External Port | Internal IP | Internal Port | Protocol | Service |
|---------------|-------------|---------------|----------|---------|
| 80 | 10.0.20.10 | 80 | TCP | HTTP to Traefik (if not using CF Tunnel) |
| 443 | 10.0.20.10 | 443 | TCP | HTTPS to Traefik (if not using CF Tunnel) |

**Recommendation**: Use Cloudflare Tunnel instead of port forwarding for increased security (no open ports on WAN).

---

## Advanced Security Settings

### SPI Firewall (Stateful Packet Inspection)
- **Enable**: ✅ YES
- **Purpose**: Track connection state, allow return traffic for established connections

### DoS Protection
- **Enable**: ✅ YES
- **Settings**:
  - SYN Flood Protection: Enabled
  - UDP Flood Protection: Enabled
  - ICMP Flood Protection: Enabled

### WAN Ping Response
- **Disable**: ❌ NO (do not respond to WAN pings for stealth)

### IP-MAC Binding (Optional)
For critical infrastructure, bind IP to MAC addresses:
- 10.0.1.100 → NAS MAC address
- 10.0.1.108 → k3s-master MAC address
- 10.0.10.100 → Orbi RBR MAC address

---

## Verification and Testing

### Test VLAN Isolation
From a device on **VLAN 10 (Trusted WiFi)**:
```bash
# Should succeed (allowed by rules)
ping 1.1.1.1           # Internet access
nslookup google.com    # DNS via AdGuard Home

# Should FAIL (blocked by isolation rules)
ping 10.0.1.100        # NAS on VLAN 1
ping 10.0.2.1          # VLAN 2 gateway
ping 10.0.99.1         # VLAN 99 gateway
ssh 10.0.1.108         # k3s-master on VLAN 1
```

### Test Management Access
From **Admin PC on VLAN 1**:
```bash
# Should ALL succeed (Management has full access)
ping 10.0.1.100        # NAS
ping 10.0.10.100       # Orbi on VLAN 10
ping 10.0.2.1          # VLAN 2 gateway
ping 10.0.20.1         # DMZ gateway
ping 10.0.99.1         # Guest gateway
ssh 10.0.1.108         # k3s-master
```

### Test Guest Isolation
From a device on **VLAN 99 (Guest)**:
```bash
# Should succeed
ping 1.1.1.1           # Internet access

# Should ALL FAIL (complete isolation)
ping 10.0.1.1          # Management gateway
ping 10.0.10.1         # Trusted WiFi gateway
ping 10.0.1.53         # DNS should still work (exception rule)
```

### Test DMZ Ingress
From **Internet/WAN**:
```bash
# Test HTTP/HTTPS access to DMZ services
curl http://<public-ip>    # Should reach Traefik in DMZ (if port forwarding enabled)
curl https://<public-ip>   # Should reach Traefik in DMZ
```

From **Admin PC (VLAN 1)**:
```bash
# Test k8s API access to DMZ
kubectl get nodes
curl -k https://10.0.1.108:6443  # k3s API should be accessible
```

---

## Logging and Monitoring

### Enable Firewall Logging
- **Navigate to**: Firewall → Access Control → Logging
- **Enable logging for**: DENY rules (priorities 90-93, 999)
- **Purpose**: Monitor blocked traffic attempts, detect intrusion attempts

### Log Review
Regularly review firewall logs for:
- Repeated deny events from same source (potential attack)
- Unusual traffic patterns (e.g., IoT device trying to access internal network)
- Failed authentication attempts

---

## Maintenance and Updates

### Regular Review
- **Frequency**: Monthly
- **Actions**:
  - Review firewall logs for anomalies
  - Update rules for new services or VLANs
  - Test isolation rules after any network changes

### Rule Modifications
When adding new rules:
1. Insert at appropriate priority (maintain rule order)
2. Test rule with live traffic
3. Document changes in this file
4. Commit to version control

### Emergency Access
If firewall rules cause loss of access:
1. Connect directly to ER605 via Port 5 (Management Spare)
2. Factory reset ER605 if needed (last resort)
3. Restore configuration from backup

---

## Related Documentation

- [ER605 VLAN Configuration](./ER605_VLAN_CONFIG.md) - VLAN setup and port configuration
- [WiFi Configuration](./WIFI_CONFIG.md) - Orbi WiFi setup for VLAN 10 and 99
- [Network Architecture](../../docs/NETWORK_ARCHITECTURE.md) - Overall network design
- [Quick Reference](../../docs/NETWORK_QUICK_REFERENCE.md) - Network cheat sheet
