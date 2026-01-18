# Network Quick Reference Guide

One-page cheat sheet for the homelab network architecture. Keep this handy for quick lookups!

## VLANs at a Glance

| VLAN | Name | Subnet | Gateway | Isolation | Purpose |
|------|------|--------|---------|-----------|---------|
| **1** | Management | 10.0.1.0/24 | 10.0.1.1 | ❌ **DEISOLATED** | Admin/Ops |
| **10** | Trusted_WiFi | 10.0.10.0/24 | 10.0.10.1 | ✅ ISOLATED | IoT WiFi |
| **2** | Trusted_LAN | 10.0.2.0/24 | 10.0.2.1 | ✅ ISOLATED | Wired Devices |
| **20** | DMZ | 10.0.20.0/24 | 10.0.20.1 | ✅ ISOLATED | Public Services |
| **99** | Guest | 10.0.99.0/24 | 10.0.99.1 | ✅ ISOLATED | Visitor WiFi |

---

## Reserved IP Addresses

### VLAN 1 (Management)
| IP | Device | Purpose |
|----|--------|---------|
| 10.0.1.1 | ER605 | Router/Gateway |
| 10.0.1.53 | AdGuard Home | DNS Server |
| 10.0.1.100 | Synology DS720+ | NAS/VM Host |
| 10.0.1.105 | Admin PC | Workstation |
| 10.0.1.108 | k3s-master-01 | Kubernetes VM |
| 10.0.1.109 | k3s-worker-01 | Monitoring VM |

### VLAN 10 (Trusted WiFi)
| IP | Device | Purpose |
|----|--------|---------|
| 10.0.10.100 | Orbi RBR350 | WiFi Router |
| 10.0.10.101 | Orbi RBS350 | WiFi Satellite |

---

## ER605 Port Map

| Port | Device | PVID | Tags | Notes |
|------|--------|------|------|-------|
| **1** | ISP (WAN) | - | - | Internet |
| **2** | Synology NAS | 1 | 2,10,20,99 | VM Trunk |
| **3** | Admin PC | 1 | 2,10,20,99 | Admin Access |
| **4** | Orbi RBR | 10 | 2,20,99 | WiFi AP |
| **5** | *Spare* | 1 | - | Emergency |

---

## WiFi Networks

| SSID | VLAN | Password Location | Isolation |
|------|------|-------------------|-----------|
| `HomeNetwork` | 10 | Password Manager | Internet Only |
| `HomeNetwork-Guest` | 99 | Shared with Guests | Complete Isolation |

---

## Key Services

| Service | IP:Port | Access | Credentials |
|---------|---------|--------|-------------|
| **ER605 Admin** | http://10.0.1.1 | Management VLAN | Vault |
| **Orbi Admin** | http://10.0.10.100 | Admin/VLAN 10 | Vault |
| **Synology NAS** | http://10.0.1.100:5000 | Management VLAN | Vault |
| **AdGuard Home** | http://10.0.1.53:3000 | Management VLAN | Vault |
| **k3s API** | https://10.0.1.108:6443 | Management VLAN | kubeconfig |
| **Grafana** | http://10.0.1.109:3000 | Management VLAN | Vault |

---

## Firewall Rules Summary

### Allow Rules
- ✅ Management (VLAN 1) → **All VLANs** + Internet
- ✅ All VLANs → Internet (HTTP, HTTPS, DNS, NTP)
- ✅ All VLANs → AdGuard DNS (10.0.1.53:53)
- ✅ WAN → DMZ (HTTP/HTTPS)
- ✅ DMZ → NAS (NFS/SMB for k8s PVs)

### Deny Rules
- ❌ VLAN 10 → All other VLANs (except Internet, DNS)
- ❌ VLAN 2 → All other VLANs (except Internet, DNS)
- ❌ VLAN 20 → All internal VLANs (except allowed NAS)
- ❌ VLAN 99 → **ALL** internal VLANs (Internet only)

---

## DNS Configuration

**Primary DNS**: 10.0.1.53 (AdGuard Home)  
**Secondary DNS**: 1.1.1.1 (Cloudflare)

### Internal DNS Records (home.internal)
- `nas.home.internal` → 10.0.1.100
- `k3s.home.internal` → 10.0.1.108
- `adguard.home.internal` → 10.0.1.53
- `traefik.home.internal` → 10.0.1.108

### External DNS (connect2home.online)
- Managed by Cloudflare DNS
- Services: `grafana.connect2home.online`, `vault.connect2home.online`

---

## Common Commands

### Test Network Connectivity
```bash
# Test Internet
ping 1.1.1.1

# Test DNS
nslookup google.com
nslookup nas.home.internal

# Test VLAN isolation (should fail from VLAN 10)
ping 10.0.1.100

# Test k8s cluster
kubectl get nodes
kubectl get pods --all-namespaces
```

### Check DHCP Leases (ER605)
1. Login: http://10.0.1.1
2. Navigate: **Network → DHCP Server**
3. Select VLAN → View **Client List**

### View Firewall Logs (ER605)
1. Login: http://10.0.1.1
2. Navigate: **Firewall → Logs**
3. Filter by DENY rules to see blocked traffic

### AdGuard Home Query Logs
1. Login: http://10.0.1.53:3000
2. Navigate: **Dashboard** → View blocked queries

---

## Emergency Procedures

### Lost Admin Access to ER605
1. Connect directly via **Port 5** (Management Spare)
2. Set static IP on PC: 10.0.1.50/24, Gateway: 10.0.1.1
3. Access router: http://10.0.1.1
4. Alternatively: Factory reset ER605 (hold reset 10sec), restore config backup

### DNS Not Working
1. Check AdGuard Home status: `kubectl get pods -n dns-system`
2. Fallback: Change DNS to 1.1.1.1 manually on client device
3. Restart AdGuard: `kubectl rollout restart deployment adguard-home -n dns-system`

### WiFi Down
1. Check Orbi status LEDs (white=good, amber=fair, magenta=poor)
2. Reboot Orbi: Power cycle RBR350 and RBS350
3. Access via Ethernet if WiFi fails: http://10.0.10.100

### Cannot Access Services
1. Verify device is on correct VLAN (check IP address)
2. Test firewall rules (ping gateways, check ER605 logs)
3. Verify service status: `kubectl get svc -A` or `docker ps` (on VM2)

---

## Network Diagrams

Quick visual references:
- **VLAN Topology**: [docs/diagrams/vlan_topology.png](./diagrams/vlan_topology.png)
- **Physical Layout**: [docs/diagrams/physical_topology.png](./diagrams/physical_topology.png)
- **Traffic Flow**: [docs/diagrams/traffic_flow.png](./diagrams/traffic_flow.png)

---

## Configuration Files

- **ER605 VLAN Config**: [infra/network/ER605_VLAN_CONFIG.md](../infra/network/ER605_VLAN_CONFIG.md)
- **Firewall Rules**: [infra/network/FIREWALL_RULES.md](../infra/network/FIREWALL_RULES.md)
- **WiFi Setup**: [infra/network/WIFI_CONFIG.md](../infra/network/WIFI_CONFIG.md)
- **Network Architecture**: [docs/NETWORK_ARCHITECTURE.md](./NETWORK_ARCHITECTURE.md)
- **Troubleshooting**: [docs/NETWORK_TROUBLESHOOTING.md](./NETWORK_TROUBLESHOOTING.md)

---

## Quick Troubleshooting Decision Tree

```
Problem: Cannot access service
  │
  ├─ Is Internet working? (ping 1.1.1.1)
  │   ├─ NO → Check WAN connection, ER605 status, ISP
  │   └─ YES → Continue
  │
  ├─ Is DNS working? (nslookup google.com)
  │   ├─ NO → Check AdGuard Home, fallback to 1.1.1.1
  │   └─ YES → Continue
  │
  ├─ Can you ping the service IP?
  │   ├─ NO → Check firewall rules, VLAN isolation
  │   └─ YES → Continue
  │
  └─ Is the service running?
      ├─ NO → Start service (kubectl/docker)
      └─ YES → Check service logs for errors
```

---

**Last Updated**: 2026-01-18  
**Maintained by**: Homelab Admin
