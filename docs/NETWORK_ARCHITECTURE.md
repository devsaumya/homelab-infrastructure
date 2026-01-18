# Network Architecture

Comprehensive reference documentation for the homelab network infrastructure architecture, verified as of 2026-01-18.

## Overview

This homelab network implements enterprise-grade security through VLAN segmentation, zero-trust firewall policies, and defense-in-depth principles. The architecture separates trust zones to isolate potentially vulnerable IoT devices, provide guest access without internal network exposure, and maintain a secure management plane.

---

## Network Topology

### Visual Reference

See comprehensive network diagrams:
- [VLAN Topology Diagram](./diagrams/vlan_topology.png) - VLAN segmentation and isolation
- [Physical Topology Diagram](./diagrams/physical_topology.png) - Hardware connections and port mappings
- [Traffic Flow Diagram](./diagrams/traffic_flow.png) - Inter-VLAN routing and firewall rules

### Hardware Components

| Component | Model | Role | Management IP |
|-----------|-------|------|---------------|
| **Router** | TP-Link ER605 | VLAN Controller, Firewall, Gateway | 10.0.1.1 |
| **NAS** | Synology DS720+ | VM Host, Storage, Management Server | 10.0.1.100 |
| **WiFi Router** | Netgear Orbi RBR350 | Primary WiFi AP (AP Mode) | 10.0.10.100 |
| **WiFi Satellite** | Netgear Orbi RBS350 | Mesh WiFi Satellite | 10.0.10.101 |
| **Admin Workstation** | PC | Network Administration | 10.0.1.105 |

---

## VLAN Architecture

### VLAN Summary Table

| VLAN ID | Name | Subnet | Gateway | Purpose | Isolation | Devices |
|---------|------|--------|---------|---------|-----------|---------|
| **1** | Management | 10.0.1.0/24 | 10.0.1.1 | Administrative Network | **DEISOLATED** | NAS, VMs, Admin PC |
| **10** | Trusted_WiFi | 10.0.10.0/24 | 10.0.10.1 | WiFi for IoT Devices | **ISOLATED** | Orbi AP, WiFi Clients |
| **2** | Trusted_LAN | 10.0.2.0/24 | 10.0.2.1 | Wired Trusted Devices | **ISOLATED** | Future Expansion |
| **20** | DMZ | 10.0.20.0/24 | 10.0.20.1 | Exposed Services | **ISOLATED** | Traefik, Public Services |
| **99** | Guest | 10.0.99.0/24 | 10.0.99.1 | Guest WiFi | **ISOLATED** | Visitor Devices |

### Trust Zones

#### Management Zone (VLAN 1) - GREEN
- **Trust Level**: Full Trust (Deisolated)
- **Access**: Bidirectional access to ALL VLANs + Internet
- **Purpose**: Network administration, infrastructure management, VM hosting
- **Security**: Restricted physical access, strong authentication, encrypted management protocols

#### Trusted Zones (VLAN 2, 10) - BLUE
- **Trust Level**: Medium Trust (Isolated)
- **Access**: Internet only, no inter-VLAN communication
- **Purpose**: Personal devices, IoT devices, WiFi clients
- **Security**: VLAN isolation prevents lateral movement, DNS filtering via AdGuard Home

#### DMZ Zone (VLAN 20) - YELLOW
- **Trust Level**: Low Trust (Isolated)
- **Access**: Internet + limited inbound (HTTP/HTTPS), specific egress to Management (NFS/SMB for PVs)
- **Purpose**: Externally exposed services (Traefik ingress, public-facing apps)
- **Security**: Strict firewall rules, separate from internal network, monitored ingress

#### Guest Zone (VLAN 99) - RED
- **Trust Level**: Zero Trust (Fully Isolated)
- **Access**: Internet only, completely blocked from internal networks
- **Purpose**: Visitor WiFi access without internal network exposure
- **Security**: Complete isolation, short DHCP leases, no saved credentials

---

## Physical Network Topology

### ER605 Port Configuration

| Port | Connected Device | Cable | Native VLAN (PVID) | Tagged VLANs | Notes |
|------|------------------|-------|-------------------|--------------|-------|
| **Port 1** | ISP Modem (WAN) | Ethernet | - | - | Internet uplink |
| **Port 2** | Synology DS720+ | Ethernet | 1 (Management) | 2, 10, 20, 99 | Trunk port for VMs |
| **Port 3** | Admin PC | Ethernet | 1 (Management) | 2, 10, 20, 99 | Admin workstation |
| **Port 4** | Orbi RBR350 | Ethernet | 10 (Trusted WiFi) | 2, 20, 99 | WiFi AP multi-SSID |
| **Port 5** | *Unassigned* | - | 1 (Management) | - | Emergency access |

### Device Connections

```
Internet (ISP)
    │
    └─[WAN]─ TP-Link ER605 Router ─────────────────────┐
                │         │         │           │       │
             [Port 2]  [Port 3]  [Port 4]   [Port 5]   │
                │         │         │                   │
                │         │         │                   │
         Synology    Admin PC   Orbi RBR350    (Spare) │
         DS720+                     │                   │
            │                  [Wireless]               │
            │                       │                   │
       ┌────┴────┐            Orbi RBS350              │
       │         │                                      │
  VM1: k3s   VM2: sec-ops                              │
  (10.0.1.108) (10.0.1.109)                            │
                                                        │
    [Management VLAN 1 provides routing to all VLANs] ─┘
```

---

## IP Address Management (IPAM)

### Reserved IP Addresses

#### VLAN 1 (Management) - 10.0.1.0/24

| IP Address | Hostname | Device | Purpose |
|------------|----------|--------|---------|
| 10.0.1.1 | er605 | TP-Link ER605 | Gateway / Router |
| 10.0.1.53 | adguard | AdGuard Home (k8s) | DNS Server |
| 10.0.1.100 | nas | Synology DS720+ | NAS / VM Host |
| 10.0.1.105 | admin-pc | Admin Workstation | Network Admin |
| 10.0.1.108 | k3s-master-01 | Kubernetes VM1 | k3s Control Plane |
| 10.0.1.109 | k3s-worker-01 | VM2 | Monitoring / Security Tools |

**DHCP Range**: 10.0.1.100 - 10.0.1.250 (excludes reserved IPs)

#### VLAN 10 (Trusted WiFi) - 10.0.10.0/24

| IP Address | Hostname | Device | Purpose |
|------------|----------|--------|---------|
| 10.0.10.1 | gateway | ER605 VLAN 10 Interface | Gateway |
| 10.0.10.100 | orbi-rbr | Netgear Orbi RBR350 | WiFi Router (AP Mode) |
| 10.0.10.101 | orbi-rbs | Netgear Orbi RBS350 | WiFi Satellite |

**DHCP Range**: 10.0.10.50 - 10.0.10.250

#### VLAN 2 (Trusted LAN) - 10.0.2.0/24

| IP Address | Hostname | Device | Purpose |
|------------|----------|--------|---------|
| 10.0.2.1 | gateway | ER605 VLAN 2 Interface | Gateway |

**DHCP Range**: 10.0.2.50 - 10.0.2.250 (future wired devices)

#### VLAN 20 (DMZ) - 10.0.20.0/24

| IP Address | Hostname | Device | Purpose |
|------------|----------|--------|---------|
| 10.0.20.1 | gateway | ER605 VLAN 20 Interface | Gateway |

**DHCP Range**: 10.0.20.50 - 10.0.20.250 (Traefik and exposed k8s services)

#### VLAN 99 (Guest) - 10.0.99.0/24

| IP Address | Hostname | Device | Purpose |
|------------|----------|--------|---------|
| 10.0.99.1 | gateway | ER605 VLAN 99 Interface | Gateway |

**DHCP Range**: 10.0.99.50 - 10.0.99.250 (guest devices)

---

## Security Model

### Firewall Principles

1. **Default Deny**: All traffic is blocked unless explicitly allowed
2. **Zero Trust**: No implicit trust between VLANs
3. **Least Privilege**: Only necessary traffic is permitted
4. **Defense in Depth**: Multiple layers of security (network, host, application)

### Key Firewall Rules

See [FIREWALL_RULES.md](../infra/network/FIREWALL_RULES.md) for complete ACL documentation.

**Allow Rules**:
- Management (VLAN 1) → All VLANs (bidirectional)
- All VLANs → Internet (HTTP, HTTPS, DNS, NTP)
- All VLANs → AdGuard DNS (10.0.1.53:53)
- WAN → DMZ (HTTP/HTTPS for ingress)
- DMZ → Management NAS (NFS/SMB for persistent volumes)
- Management → DMZ k8s API (port 6443)

**Deny Rules**:
- VLAN 10 (Trusted WiFi) → VLAN 1, 2, 20, 99
- VLAN 2 (Trusted LAN) → VLAN 1, 10, 20, 99
- VLAN 20 (DMZ) → VLAN 1, 2, 10, 99 (except allowed NAS access)
- VLAN 99 (Guest) → VLAN 1, 2, 10, 20 (complete isolation)

### Network Isolation Testing

```bash
# From VLAN 10 (Trusted WiFi)
ping 1.1.1.1           # ✅ PASS - Internet access
nslookup google.com    # ✅ PASS - DNS via AdGuard
ping 10.0.1.100        # ❌ FAIL - Blocked by firewall
ping 10.0.2.1          # ❌ FAIL - Blocked by firewall

# From VLAN 1 (Management)
ping 10.0.10.100       # ✅ PASS - Management can access all VLANs
ssh 10.0.1.108         # ✅ PASS - Admin access to k3s
```

---

## DNS and Service Discovery

### DNS Architecture

**Primary DNS**: AdGuard Home (10.0.1.53)
- Runs as Kubernetes service in k3s cluster
- Provides DNS filtering, ad blocking, and malware protection
- Serves internal `home.internal` DNS zone
- Forwards external queries to upstream DNS (Cloudflare 1.1.1.1, Google 8.8.8.8)

**Secondary DNS**: 1.1.1.1 (Cloudflare)
- Configured as fallback in ER605 DHCP settings
- Used if AdGuard Home is unavailable

### Internal Domain: `home.internal`

DNS rewrites configured in AdGuard Home:

| FQDN | IP Address | Service |
|------|------------|---------|
| nas.home.internal | 10.0.1.100 | Synology NAS |
| k3s.home.internal | 10.0.1.108 | k3s Cluster |
| adguard.home.internal | 10.0.1.53 | AdGuard Home UI |
| traefik.home.internal | 10.0.1.108 | Traefik Dashboard |

### External Domain: `connect2home.online`

Managed by Cloudflare DNS:
- Public-facing services via Cloudflare Tunnel
- Examples: `grafana.connect2home.online`, `vault.connect2home.online`
- Zero-trust access with Cloudflare Access (optional)

---

## Routing and NAT

### Inter-VLAN Routing

- **Handled by**: TP-Link ER605 router
- **Method**: Layer 3 routing between VLANs (controlled by firewall rules)
- **Default**: All VLANs can route to each other (restricted by ACLs)

### NAT (Network Address Translation)

- **SNAT (Source NAT)**: All internal VLANs (10.0.0.0/8) → WAN IP
- **DNAT (Destination NAT)**: Optional port forwarding for DMZ services (not recommended - use Cloudflare Tunnel instead)

---

## WiFi Configuration

### SSIDs and VLAN Mapping

| SSID | VLAN | Security | Access | Purpose |
|------|------|----------|--------|---------|
| `HomeNetwork` | 10 (Trusted WiFi) | WPA3-Personal | Internet + DNS | Primary WiFi for trusted devices |
| `HomeNetwork-Guest` | 99 (Guest) | WPA2-Personal | Internet only | Guest WiFi with complete isolation |

**WiFi Security**:
- WPA3 encryption (or WPA2/WPA3 Mixed for compatibility)
- Strong passphrases (16+ characters)
- WPS disabled
- Fast roaming (802.11r) enabled for seamless mesh handoff

See [WIFI_CONFIG.md](../infra/network/WIFI_CONFIG.md) for detailed Orbi configuration.

---

## Monitoring and Observability

### Network Monitoring Tools

- **Prometheus**: Metrics collection (VM2: 10.0.1.109:9090)
- **Grafana**: Dashboards and visualization (VM2: 10.0.1.109:3000)
- **Loki**: Log aggregation (VM2: 10.0.1.109:3100)
- **AlertManager**: Alert routing (VM2)

### Key Metrics to Monitor

- Network throughput per VLAN
- Firewall rule hit counts (especially deny rules)
- DNS query rates and blocked queries (AdGuard Home)
- WiFi client count and signal strength (Orbi)
- NAT connection table utilization (ER605)

---

## Disaster Recovery and Backup

### Configuration Backups

**ER605 Router**:
- Regular config exports via web UI: **Settings → Maintenance → Backup/Restore**
- Store backups in version control: `homelab-infrastructure/infra/network/backups/`

**Orbi WiFi**:
- Backup configuration: **Administration → Backup Settings**
- Store WiFi credentials securely (password manager)

**AdGuard Home**:
- Kubernetes manifest-based config (GitOps via ArgoCD)
- DNS rewrite rules backed up in `k8s/apps/platform/adguard/`

### Network Recovery Procedures

1. **ER605 Failure**: Replace router, restore configuration backup, verify VLAN and firewall rules
2. **Switch Failure**: Replace switch, reconfigure trunk ports for VLAN tagging
3. **WiFi Failure**: Replace Orbi, restore configuration, re-sync satellite
4. **DNS Failure**: Fallback to secondary DNS (1.1.1.1), restore AdGuard Home from k8s manifests

---

## Future Enhancements

- **VLAN 2 (Trusted LAN)**: Expand with managed switch for wired devices
- **802.1X Authentication**: Implement port-based authentication for enhanced security
- **VLAN 20 (DMZ) Segmentation**: Create sub-VLANs for different service tiers
- **IDS/IPS**: Deploy Suricata or Snort for intrusion detection
- **VXLAN Overlay**: Extend network to remote sites via VPN with VXLAN tunnels

---

## Related Documentation

- [ER605 VLAN Configuration](../infra/network/ER605_VLAN_CONFIG.md) - Detailed router setup
- [Firewall Rules](../infra/network/FIREWALL_RULES.md) - Complete ACL documentation
- [WiFi Configuration](../infra/network/WIFI_CONFIG.md) - Orbi mesh setup
- [Quick Reference Guide](./NETWORK_QUICK_REFERENCE.md) - One-page cheat sheet
- [Troubleshooting Guide](./NETWORK_TROUBLESHOOTING.md) - Common issues and solutions
- [Master Documentation](./MASTER.md) - Complete infrastructure guide
