# HOMELAB INFRASTRUCTURE SETUP GUIDE
## Synology DS720+ | ER605 Router | Orbi RBR350 | Cloudflare Integration

**Date:** Saturday, December 20, 2025, 12:42 AM IST  
**Domain:** connect2home.online (Public) | home.internal (LAN)  
**Access:** Cloudflare WARP client and Cloudflare Tunnels  

---

## TABLE OF CONTENTS

1. Network Architecture Overview
2. ER605 Router Configuration
3. Orbi RBR350 WiFi Setup
4. Synology DS720+ Configuration
5. Cloudflare Tunnel Setup (External Access)
6. DNS Split-Horizon Configuration
7. Service Access Matrix
8. Verification Checklist

---

## 1. NETWORK ARCHITECTURE OVERVIEW

### Topology Diagram

```
ISP Modem
    |
    | WAN
    v
TP-LINK ER605 (Gateway 10.0.1.1)
├─ LAN1(Access) → Synology DS720+ (10.0.1.100, VLAN 1)
├─ LAN2(Trunk)  → Orbi RBR350 (VLAN 2,10,99 WiFi broadcast)
├─ LAN3(Access) → Admin Laptop (VLAN 1)
└─ LAN4(Access) → Desktop/Future (VLAN 2)

VLANs:
├─ VLAN 1 (Management): 10.0.1.0/24 - NAS, k3s, admin
├─ VLAN 2 (Trusted): 10.0.2.0/24 - Desktops, trusted apps
├─ VLAN 10 (IoT): 10.0.10.0/24 - Smart devices (isolated)
└─ VLAN 99 (Guest): 10.0.99.0/24 - Guest WiFi (fully isolated)

External:
Cloudflare (connect2home.online) → Tunnel → Traefik LB → Services
```

### IP Addressing Plan

| VLAN | Name      | Network      | Gateway    | DHCP Range      |
|------|-----------|--------------|------------|-----------------|
| 1    | Management| 10.0.1.0/24  | 10.0.1.1   | 100-200         |
| 2    | Trusted   | 10.0.2.0/24  | 10.0.2.1   | 100-200         |
| 10   | IoT       | 10.0.10.0/24 | 10.0.10.1  | 100-200         |
| 99   | Guest     | 10.0.99.0/24 | 10.0.99.1  | 100-200         |

### Static IP Reservations

- Synology DS720+: 10.0.1.100 (VLAN 1)
- VM1 k3s-master-01: 10.0.1.108 (VLAN 1)
- VM2 k3s-worker-01: 10.0.1.109 (VLAN 1)
- AdGuard DNS: 10.0.1.53 (VLAN 1)
- Traefik LB: 10.0.1.80 (VLAN 1)
- Orbi RBR350: 10.0.1.200 (VLAN 1)

### Domain Strategy

**Internal (LAN-Only via AdGuard Home):**
- nas.home.internal → 10.0.1.100
- k3s.home.internal → 10.0.1.108
- vault.home.internal → 10.0.1.109
- portainer.home.internal → 10.0.1.109

**External (Internet-Facing via Cloudflare):**
- vault.connect2home.online → Tunnel → 10.0.1.109:8080
- grafana.connect2home.online → Tunnel → 10.0.1.109:3000
- home.connect2home.online → Tunnel → 10.0.1.80:9000

---

## 2. ER605 ROUTER CONFIGURATION

### Step 1: Initial Access & Security

Default IP: 192.168.0.1  
Default Login: admin / admin

1. Connect laptop to any ER605 LAN port
2. Open browser: http://192.168.0.1
3. Login and **CHANGE PASSWORD IMMEDIATELY**
   - Use STRONG password (16+ chars, mixed case, numbers, symbols)
   - Save to password manager

### Step 2: WAN Configuration

Navigate to: Settings → Network → WAN

Configure based on your ISP:
- DHCP: Auto-detect
- PPPoE: Enter username/password from ISP
- Static: Configure IP/gateway/DNS

Test: Verify ER605 WAN light is solid green

### Step 3: Create 4 VLANs

Navigate to: Settings → Wired Networks → LAN

**VLAN 1 (Management):**
- ID: 1, Network: 10.0.1.0/24, Gateway: 10.0.1.1
- DHCP: 10.0.1.108-200, Lease: 86400s (24h)
- DNS: 1.1.1.1, 8.8.8.8

**VLAN 2 (Trusted):**
- ID: 2, Network: 10.0.2.0/24, Gateway: 10.0.2.1
- DHCP: 10.0.2.100-200, Lease: 43200s (12h)
- DNS: 1.1.1.1, 8.8.8.8

**VLAN 10 (IoT):**
- ID: 10, Network: 10.0.10.0/24, Gateway: 10.0.10.1
- DHCP: 10.0.10.100-200, Lease: 43200s (12h)
- DNS: 1.1.1.1, 8.8.8.8

**VLAN 99 (Guest):**
- ID: 99, Network: 10.0.99.0/24, Gateway: 10.0.99.1
- DHCP: 10.0.99.100-200, Lease: 3600s (1h - short for guests)
- DNS: 1.1.1.1, 8.8.8.8

### Step 4: Configure LAN Ports

Navigate to: Settings → Wired Networks → LAN → Port Settings

**LAN1:** Access Mode, PVID 1, Synology
**LAN2:** Trunk Mode, Native VLAN 2, Tagged VLANs 2/10/99, Orbi WiFi
**LAN3:** Access Mode, PVID 1, Admin Laptop
**LAN4:** Access Mode, PVID 2, Desktop/Future

### Step 5: Add DHCP Static Reservations

Settings → Wired Networks → LAN → DHCP Server → Reservations

Add entries as devices are created:
- Synology: 10.0.1.100 (MAC from label)
- VM1: 10.0.1.108 (MAC after creation)
- VM2: 10.0.1.109 (MAC after creation)
- Others: Add MACs as needed

### Step 6: Configure Firewall Rules

Settings → Firewall → Access Control

1. **Block IoT to Management:** Source 10.0.10.0/24 → Destination 10.0.1.0/24 → Deny
2. **Block IoT to Trusted:** Source 10.0.10.0/24 → Destination 10.0.2.0/24 → Deny
3. **Block Guest Isolation:** Source 10.0.99.0/24 → Destination 10.0.0.0/8 → Deny
4. **Allow Trusted to DNS:** Source 10.0.2.0/24 → Destination 10.0.1.53 (UDP 53) → Allow
5. **Allow All to Internet:** Source 0.0.0.0/0 → Destination WAN → Allow

Order matters! Rules evaluated top-to-bottom.

### Step 7: Backup ER605

Settings → System → Backup & Restore

Download backup file: ER605-config-backup-YYYY-MM-DD.cfg
Store safely for recovery.

### Step 8: Final Verification

Test from admin laptop:
```bash
ping 10.0.1.1        # Gateway
ping 10.0.2.1        # Cross-VLAN
ping 8.8.8.8         # Internet
nslookup google.com  # DNS
```

All should succeed. Proceed to Orbi setup.

---

## 3. ORBI RBR350 WIFI SETUP

### Step 1: Physical Connection

1. Disconnect any existing Orbi WAN/LAN connections
2. Connect Orbi (port 1) to ER605 LAN2 (trunk port)
3. Power on Orbi via UPS
4. Wait 2-3 minutes for boot

### Step 2: Initial Orbi Access

Browser: http://routerlogin.net or http://orbi.com

Or find IP from arp scan, then access directly.

Default SSID: Orbi  
Default password: (on back of device)

Accept EULA and create new admin password (STRONG).

### Step 3: Enable VLAN Support

Advanced → VLAN

1. Enable VLAN support
2. Port 1 (WAN from ER605): Set to Trunked (carries all VLANs)
3. Save and reboot

### Step 4: Create WiFi SSIDs per VLAN

**WiFi 1 - Orbi-Trusted (VLAN 2):**
- SSID: Orbi-Trusted
- VLAN: 2
- Security: WPA3 or WPA2
- Password: STRONG
- Bands: 2.4GHz + 5GHz

**WiFi 2 - Orbi-IoT (VLAN 10):**
- SSID: Orbi-IoT
- VLAN: 10
- Security: WPA2
- Password: Different from Trusted
- Bands: 5GHz-2 (isolated)

**WiFi 3 - Orbi-Guest (VLAN 99):**
- SSID: Orbi-Guest
- VLAN: 99
- Security: WPA2
- Password: Public-friendly
- Guest Access: Enable
- Isolation: Enable
- Bands: 2.4GHz

### Step 5: Set Orbi Static IP

Advanced → Network Settings
- IP: 10.0.1.200
- Subnet: 255.255.255.0
- Gateway: 10.0.1.1
- DNS: 1.1.1.1 (will change to 10.0.1.53 later)

### Step 6: Add Orbi to ER605 DHCP Reservations

Back in ER605:
- IP: 10.0.1.200
- MAC: (from Orbi status page)
- Description: Orbi RBR350

Reboot Orbi to confirm.

### Step 7: Test WiFi Connectivity

Connect laptop to Orbi-Trusted:
```bash
ping 10.0.1.1        # Should work
ping 10.0.10.1       # Should block
nslookup google.com  # Should resolve
```

Proceed to Synology setup.

---

## 4. SYNOLOGY DS720+ CONFIGURATION

### Step 1: Hardware Setup

1. Power off NAS, wait 30 seconds
2. Remove bottom panel (4 screws)
3. Install 16GB DDR4 SODIMM in empty slot
4. Install WD Red Plus 1TB in Tray 1
5. Reattach bottom panel
6. Power on (should beep, show lights)

### Step 2: Access Synology

Browser: http://10.0.1.100:5000 (or use Synology Assistant to find IP)

DSM Setup Wizard:
- Accept Terms
- Create admin account (STRONG password, SAVE)
- Skip QuickConnect
- Disable telemetry
- Allow DSM update
- Reboot (5-10 min)

### Step 3: Storage Configuration

Storage Manager → Storage Pool
- Select: WD Red Plus 1TB
- RAID: Basic
- Format: Btrfs (enable checksum + CoW)
- Create

Storage Manager → Volume
- Pool: pool-1
- Name: volume1
- Snapshots: Enable, Daily 2:00 AM, Keep 7 days
- Create

### Step 4: Set Static IP

Control Panel → Network → Network Interface → LAN
- IPv4: Manual
- IP: 10.0.1.100
- Netmask: 255.255.255.0
- Gateway: 10.0.1.1
- DNS: 1.1.1.1, 8.8.8.8
- Apply (reboots ~1 min)

### Step 5: Install Packages

Package Center → Install:
1. Docker (3-5 min)
2. Virtual Machine Manager (2-3 min)
3. Snapshot Replication (1 min)

All should appear on DSM Desktop.

### Step 6: Create Shared Folders

Control Panel → Shared Folder → Create:

1. **docker:** Path /volume1/docker, Recycle Bin Enable
2. **vms:** Path /volume1/vms, Recycle Bin Enable
3. **backups:** Path /volume1/backups, Recycle Bin Enable

All 3 should appear in Shared Folders list.

### Step 7: Final Verification

- Synology accessible at http://10.0.1.100:5000
- Storage status: Normal
- Time zone: Asia/Kolkata
- All packages installed
- All shared folders created

---

## 5. CLOUDFLARE TUNNEL SETUP

### Step 1: Create Tunnel in Cloudflare Zero Trust

1. Access: https://one.dash.cloudflare.com/
2. Access → Tunnels → Create a tunnel
3. Name: homelab-prod
4. Choose connector for Docker deployment

### Step 2: Install Tunnel on VM2

SSH into VM2 (after VM creation):
```bash
ssh homelab@10.0.1.109

mkdir -p /data/cloudflare

docker run -d \\
  --name cloudflared \\
  --restart unless-stopped \\
  cloudflare/cloudflared:latest tunnel run homelab-prod \\
  --token YOUR_TOKEN_HERE
```

Replace YOUR_TOKEN_HERE with token from Cloudflare UI.

Wait 1-2 minutes for tunnel to show "Connected" in Cloudflare.

### Step 3: Add Tunnel Routes

In Cloudflare Tunnel UI, add Public Hostnames:

1. **grafana.connect2home.online** → http://10.0.1.109:3000
2. **vault.connect2home.online** → http://10.0.1.109:8080
3. **prometheus.connect2home.online** → http://10.0.1.109:9090
4. **home.connect2home.online** → http://10.0.1.80:9000

### Step 4: Enable Zero Trust Access

Access → Applications → Add Application
- Type: Self-hosted
- Name: Homelab-Grafana
- Subdomain: grafana
- Domain: connect2home.online
- Policies: Include your email domain, require registered device
- Save

Repeat for other services.

### Step 5: Test External Access

From external network:
```bash
# Install WARP client on your computer
# Login with Cloudflare Zero Trust account
# Visit: https://grafana.connect2home.online
# Should redirect to Cloudflare login, then access Grafana
```

---

## 6. DNS SPLIT-HORIZON CONFIGURATION

### LAN DNS (.home.internal)

After deploying AdGuard Home in k3s:

1. Access AdGuard: http://10.0.1.53:3000
2. Settings → DNS Settings → Local DNS
3. Add records:
   - nas.home.internal → 10.0.1.100
   - k3s.home.internal → 10.0.1.108
   - vault.home.internal → 10.0.1.109
   - portainer.home.internal → 10.0.1.109

### Update ER605 DNS

Settings → Wired Networks → LAN → VLAN 1 & 2
- Primary DNS: 10.0.1.53 (AdGuard)
- Secondary DNS: 1.1.1.1 (fallback)
- Apply

Test: `nslookup nas.home.internal` should return 10.0.1.100

### External DNS (.connect2home.online)

DNS records automatically created by Cloudflare when tunnel routes added.

Verify in Cloudflare DNS tab: connect2home.online zone shows A records.

---

## 7. SERVICE ACCESS MATRIX

| Service        | Internal                        | External                          | VLAN |
|----------------|--------------------------------|-----------------------------------|------|
| Synology       | http://nas.home.internal:5000  | Manual tunnel                     | 1    |
| Grafana        | http://grafana.home.internal   | https://grafana.connect2home.online | 2  |
| Vaultwarden    | http://vault.home.internal     | https://vault.connect2home.online | 2    |
| Portainer      | https://portainer.home.internal| Internal HTTPS only               | 1    |
| Prometheus     | http://prometheus.home.internal| https://prometheus.connect2home.online | 1 |

### Access Rules

**From Management VLAN 1:**
- Access all internal services
- Use .home.internal DNS
- Example: http://nas.home.internal:5000

**From Trusted VLAN 2:**
- Limited internal access
- External services via Cloudflare Tunnel + WARP
- Example: https://grafana.connect2home.online (requires WARP login)

**From IoT VLAN 10:**
- No access to Management/Trusted
- Internet only
- Cannot resolve .internal

**From Guest VLAN 99:**
- Internet only
- Completely isolated
- No access to 10.0.x.x networks

---

## 8. VERIFICATION CHECKLIST

### Network Layer
- [ ] ER605 accessible at 10.0.1.1
- [ ] Ping 8.8.8.8 works (internet)
- [ ] All 4 VLANs created
- [ ] All ports configured correctly
- [ ] Firewall 5 rules active in order
- [ ] Orbi connected to LAN2 trunk
- [ ] Orbi SSIDs visible on each VLAN
- [ ] ER605 backup saved

### Synology
- [ ] Accessible at 10.0.1.100:5000
- [ ] Storage pool: Normal status
- [ ] Volume: Ready status
- [ ] Docker installed
- [ ] VMM installed
- [ ] All shared folders created
- [ ] Static IP working

### Cloudflare
- [ ] Tunnel created and connected
- [ ] Tunnel routes added (4+ services)
- [ ] Zero Trust policies configured
- [ ] WARP client installed
- [ ] External access working

### DNS
- [ ] nslookup google.com → via 10.0.1.53
- [ ] nslookup nas.home.internal → 10.0.1.100 (after AdGuard)
- [ ] Guest DNS → public only
- [ ] External DNS → Cloudflare records active

### Security
- [ ] All default passwords changed
- [ ] Firewall rules blocking IoT/Guest
- [ ] HTTPS on all services
- [ ] Snapshots running daily
- [ ] SSH keys configured

---

## QUICK REFERENCE

**Critical IPs:**
- ER605: 10.0.1.1
- Synology: 10.0.1.100
- Orbi: 10.0.1.200
- VM1: 10.0.1.108
- VM2: 10.0.1.109

**Critical Ports:**
- HTTP: 80
- HTTPS: 443
- SSH: 22
- DNS: 53
- Synology DSM: 5000

**Common Tests:**
```bash
ping 10.0.1.1                 # Network working
nslookup google.com           # DNS working
curl https://grafana.connect2home.online  # External access
ssh homelab@10.0.1.108          # VM access
```

---

**Document Version:** 1.0  
**Last Updated:** Saturday, December 20, 2025  
**Status:** Ready for Implementation
