# HOMELAB INFRASTRUCTURE - QUICK REFERENCE GUIDE
## Configuration Checklists & Command Reference

**Date:** Saturday, December 20, 2025  
**Domain:** connect2home.online | home.internal  
**Last Updated:** December 20, 2025

---

## SECTION 1: CRITICAL IPs & CREDENTIALS

### Network Infrastructure IPs

```
GATEWAY & CORE:
├─ ER605 Router Primary: 10.0.1.1
├─ ER605 Management: 192.168.0.1 (factory default)
├─ Synology NAS: 10.0.1.50 (port 5000)
├─ Orbi RBR350: 10.0.1.200
└─ UPS Backup Power: Local only (no IP)

SERVICES (VLAN 1 - Management):
├─ VM1 k3s-master: 10.0.1.100
├─ VM2 security-ops: 10.0.1.105
├─ AdGuard DNS: 10.0.1.53 (port 3000)
├─ Traefik LoadBalancer: 10.0.1.80 (port 9000)
└─ Prometheus: 10.0.1.105 (port 9090)

EXTERNAL ACCESS:
├─ Cloudflare: https://one.dash.cloudflare.com
├─ Tunnel: homelab-prod
└─ Domain: connect2home.online
```

### VLAN Configuration Matrix

| VLAN | Name        | Network       | Gateway    | Purpose | Isolation |
|------|-------------|---------------|------------|---------|-----------|
| 1    | Management  | 10.0.1.0/24   | 10.0.1.1   | Admin, NAS, VMs | None (trusted) |
| 2    | Trusted     | 10.0.2.0/24   | 10.0.2.1   | Devices, Services | Blocked from 1,10 |
| 10   | IoT         | 10.0.10.0/24  | 10.0.10.1  | Smart Devices | Blocked from all |
| 99   | Guest       | 10.0.99.0/24  | 10.0.99.1  | Visitors | Fully Isolated |

### Port Assignments

```
LAN1 (Access): Synology DS720+ → VLAN 1
LAN2 (Trunk): Orbi RBR350 → VLANs 1,2,10,99
LAN3 (Access): Admin Laptop → VLAN 1
LAN4 (Access): Desktop/Future → VLAN 2
WAN: ISP Modem
```

---

## SECTION 2: ER605 ROUTER CONFIGURATION CHECKLIST

### Initial Setup (15 min)

```
☐ Power on ER605 via UPS
☐ Connect ISP modem to WAN port
☐ Connect LAN1/LAN3 to admin laptop
☐ Access http://192.168.0.1
☐ Change default password (admin/admin)
☐ Configure WAN (DHCP/PPPoE/Static based on ISP)
☐ Verify internet: ping 8.8.8.8
```

### VLAN Creation (15 min)

```
VLAN 1 (Management):
☐ ID: 1
☐ Network: 10.0.1.0/24
☐ Gateway: 10.0.1.1
☐ DHCP: 10.0.1.100-200 (86400s lease)
☐ DNS: 1.1.1.1, 8.8.8.8

VLAN 2 (Trusted):
☐ ID: 2
☐ Network: 10.0.2.0/24
☐ Gateway: 10.0.2.1
☐ DHCP: 10.0.2.100-200 (43200s lease)
☐ DNS: 1.1.1.1, 8.8.8.8

VLAN 10 (IoT):
☐ ID: 10
☐ Network: 10.0.10.0/24
☐ Gateway: 10.0.10.1
☐ DHCP: 10.0.10.100-200 (43200s lease)
☐ DNS: 1.1.1.1, 8.8.8.8

VLAN 99 (Guest):
☐ ID: 99
☐ Network: 10.0.99.0/24
☐ Gateway: 10.0.99.1
☐ DHCP: 10.0.99.100-200 (3600s lease)
☐ DNS: 1.1.1.1, 8.8.8.8
```

### Port Configuration (10 min)

```
☐ LAN1: Access, PVID 1, Synology only
☐ LAN2: Trunk, PVID 2, Tagged 2/10/99 (NOT 1)
☐ LAN3: Access, PVID 1, Admin only
☐ LAN4: Access, PVID 2, Desktop only
```

### Firewall Rules (in order!)

```
☐ Rule 1: Block IoT (10.0.10.0/24) → Management (10.0.1.0/24) - Deny
☐ Rule 2: Block IoT (10.0.10.0/24) → Trusted (10.0.2.0/24) - Deny
☐ Rule 3: Block Guest (10.0.99.0/24) → All Internal (10.0.0.0/8) - Deny
☐ Rule 4: Allow Trusted → DNS (10.0.1.53:53) - Allow
☐ Rule 5: Allow All → Internet - Allow
```

### DHCP Reservations

```
☐ Synology: 10.0.1.50 (MAC from device label)
☐ VM1: 10.0.1.100 (MAC after creation)
☐ VM2: 10.0.1.105 (MAC after creation)
☐ Orbi: 10.0.1.200 (MAC from Orbi status page)
☐ AdGuard: 10.0.1.53 (MAC after k3s deployment)
☐ Traefik: 10.0.1.80 (MAC after k3s deployment)
```

### Final ER605 Verification

```
☐ Backup config: ER605-config-backup-YYYY-MM-DD.cfg
☐ Test: ping 10.0.1.1 (gateway works)
☐ Test: ping 10.0.2.1 (cross-VLAN routing works)
☐ Test: ping 8.8.8.8 (internet works)
☐ Test: nslookup google.com (DNS works)
☐ All lights green
```

---

## SECTION 3: ORBI RBR350 CONFIGURATION CHECKLIST

### Physical Connection (5 min)

```
☐ Connect Orbi Port 1 to ER605 LAN2 (trunk) with Cat6
☐ Power on Orbi (via UPS)
☐ Wait 2-3 minutes for full boot
☐ Verify lights: Port 1 light green, WiFi lights white
```

### Initial Setup (10 min)

```
☐ Access routerlogin.net or orbi.com
☐ Accept Terms of Service
☐ Create strong admin password (16+ chars)
☐ Skip WAN setup (using ER605 as gateway)
☐ Setup base WiFi (Orbi-Main or preference)
☐ Reboot Orbi
```

### VLAN & Port Configuration (10 min)

```
☐ Enable VLAN support (Advanced → VLAN)
☐ Port 1: Trunk mode
☐ Port 1 Tagged VLANs: 1, 2, 10, 99
☐ Port 1 Native VLAN: 2
☐ Reboot Orbi
```

### Create WiFi SSIDs (15 min)

```
WiFi 1 - Orbi-Trusted (VLAN 2):
☐ Name: Orbi-Trusted
☐ VLAN Tag: 2
☐ Security: WPA3 or WPA2
☐ Password: STRONG (20+ chars, saved in password manager)
☐ Bands: 2.4GHz + 5GHz
☐ Guest Access: Disabled

WiFi 2 - Orbi-IoT (VLAN 10):
☐ Name: Orbi-IoT
☐ VLAN Tag: 10
☐ Security: WPA2
☐ Password: DIFFERENT from Trusted
☐ Bands: 5GHz-1 or 5GHz-2 (isolated band)
☐ Isolation: Enabled
☐ Guest Access: Disabled

WiFi 3 - Orbi-Guest (VLAN 99):
☐ Name: Orbi-Guest
☐ VLAN Tag: 99
☐ Security: WPA2
☐ Password: PUBLIC_FRIENDLY
☐ Bands: 2.4GHz only
☐ Guest Access: Enabled
☐ Guest Isolation: Enabled
```

### Static IP & Registration (10 min)

```
☐ Set Orbi static IP: 10.0.1.200
☐ Gateway: 10.0.1.1 (ER605)
☐ DNS: 1.1.1.1 (temporary)
☐ Reboot Orbi
☐ Get MAC address from Orbi Status → Device Info
☐ Add to ER605 DHCP reservation: 10.0.1.200, Orbi MAC
```

### Final Orbi Verification

```
☐ Access Orbi at 10.0.1.200
☐ All 3 WiFi networks visible
☐ Can connect to each VLAN SSID separately
☐ Orbi VLAN isolation working (test later)
```

---

## SECTION 4: SYNOLOGY DS720+ CONFIGURATION CHECKLIST

### Hardware Assembly (20 min)

```
☐ Power off and unplug Synology
☐ Wait 30 seconds
☐ Remove bottom panel (4 screws)
☐ Install 16GB DDR4 SODIMM in RAM slot
☐ Install WD Red Plus 1TB in Tray 1
☐ Reinstall bottom panel
☐ Connect power and network cables
☐ Power on (wait 30 seconds for beep and lights)
```

### DSM Access & Setup (15 min)

```
☐ Browser: http://10.0.1.50:5000 (or find via Synology Assistant)
☐ Accept Terms of Service
☐ Create admin account (STRONG password, saved)
☐ Skip QuickConnect
☐ Opt out of telemetry
☐ Allow DSM update
☐ Wait 5-10 minutes for reboot and update completion
```

### Storage Configuration (15 min)

```
Storage Pool:
☐ Select disk: WD Red Plus 1TB
☐ RAID: Basic
☐ Format: Btrfs
☐ Enable Data Checksum
☐ Enable CoW (Copy-on-Write)
☐ Create pool (confirm "I want to proceed")

Volume:
☐ Pool: pool-1
☐ Name: volume1
☐ Size: Use all available
☐ Enable Daily Snapshots at 2:00 AM
☐ Keep 7 days of snapshots
☐ Create volume

Verification:
☐ Storage Manager → Summary
☐ Pool-1 status: NORMAL
☐ Volume1 status: READY
```

### Network Configuration (10 min)

```
☐ Control Panel → Network → Network Interface → LAN
☐ IPv4: Manual
☐ IP: 10.0.1.50
☐ Netmask: 255.255.255.0
☐ Gateway: 10.0.1.1
☐ DNS 1: 1.1.1.1
☐ DNS 2: 8.8.8.8
☐ Apply (NAS reboots ~30 seconds)
☐ Verify static IP: Control Panel → Network → Summary

Time Zone:
☐ Regional Options → Time
☐ Zone: Asia/Kolkata
☐ NTP: time.google.com
☐ Sync Now
```

### Package Installation (5 min)

```
☐ Package Center → Install: Docker (3-5 min)
☐ Package Center → Install: Virtual Machine Manager (2-3 min)
☐ Package Center → Install: Snapshot Replication (1 min)
☐ Verify all appear on DSM desktop
```

### Shared Folders (5 min)

```
☐ Control Panel → Shared Folder → Create
☐ Folder 1: docker (/volume1/docker)
☐ Folder 2: vms (/volume1/vms)
☐ Folder 3: backups (/volume1/backups)
☐ All with Recycle Bin enabled
☐ Verify access: smb://10.0.1.50/docker
```

### Final Synology Verification

```
☐ DSM accessible at http://10.0.1.50:5000
☐ Storage pool: Normal status
☐ Volume: Ready status
☐ Docker installed and visible
☐ VMM installed and visible
☐ All shared folders accessible
☐ Time zone: Asia/Kolkata
☐ Snapshots scheduled
```

---

## SECTION 5: CLOUDFLARE TUNNEL CONFIGURATION CHECKLIST

### Cloudflare Account Setup (10 min)

```
☐ Account: https://dash.cloudflare.com
☐ Add domain: connect2home.online
☐ Change nameservers at registrar:
   ☐ NS1: ellie.ns.cloudflare.com
   ☐ NS2: rex.ns.cloudflare.com
☐ Wait 24-48 hours for propagation
☐ Verify: Cloudflare DNS shows "Active"
```

### Create Tunnel (5 min)

```
☐ Access: https://one.dash.cloudflare.com
☐ Access → Tunnels → Create a tunnel
☐ Type: Cloudflared
☐ Name: homelab-prod
☐ Get token and save securely
☐ Select Docker connector
```

### Install Tunnel on Synology (10 min)

```
☐ Docker → Registry → Search: cloudflare/cloudflared
☐ Download latest image
☐ Docker → Container → Create
☐ Image: cloudflare/cloudflared:latest
☐ Name: cloudflared
☐ Command: docker run with TOKEN (from tunnel creation)
☐ Auto-restart: Yes
☐ Create
☐ Verify: Container shows "Running"
☐ Cloudflare UI: Tunnel status → Connected
```

### Add Public Hostnames (10 min)

```
In Cloudflare Tunnel UI:
☐ Hostname 1: grafana.connect2home.online → 10.0.1.105:3000
☐ Hostname 2: vault.connect2home.online → 10.0.1.105:8080
☐ Hostname 3: prometheus.connect2home.online → 10.0.1.105:9090
☐ Hostname 4: home.connect2home.online → 10.0.1.80:9000
☐ Hostname 5: nas.connect2home.online → 10.0.1.50:5000
☐ All routes saved
```

### Test Tunnel Access (5 min)

```
☐ Install Cloudflare WARP client
☐ Login with Cloudflare account
☐ Test: https://grafana.connect2home.online (redirects to login)
☐ Test: https://vault.connect2home.online (page loads after auth)
☐ DNS: nslookup grafana.connect2home.online (resolves)
```

---

## SECTION 6: CRITICAL COMMANDS REFERENCE

### Network Testing

```bash
# Test basic connectivity
ping 10.0.1.1                    # ER605 gateway
ping 8.8.8.8                     # Internet
ping 10.0.1.50                   # Synology

# Test DNS
nslookup google.com              # Public DNS
nslookup nas.home.internal       # LAN DNS (after AdGuard)

# Find Synology IP (first time)
arp-scan -l                      # Find all IPs on subnet

# SSH access
ssh admin@10.0.1.100             # VM1
ssh admin@10.0.1.105             # VM2
ssh admin@10.0.1.50              # Synology (if SSH enabled)
```

### Synology SMB Access

```bash
# Linux/Mac
smb://10.0.1.50/docker
smb://10.0.1.50/vms
smb://10.0.1.50/backups

# Windows
\\10.0.1.50\docker
\\10.0.1.50\vms
\\10.0.1.50\backups

# Mount on Linux
sudo mount -t cifs //10.0.1.50/docker /mnt/docker \
  -o username=admin,password=PASSWORD,uid=1000,gid=1000
```

### SSH Key Setup

```bash
# Generate key (run once on admin laptop)
ssh-keygen -t ed25519 -C "homelab-admin" \
  -f ~/.ssh/homelab_ed25519

# Copy key to VMs
ssh-copy-id -i ~/.ssh/homelab_ed25519.pub admin@10.0.1.100
ssh-copy-id -i ~/.ssh/homelab_ed25519.pub admin@10.0.1.105

# Use key for login
ssh -i ~/.ssh/homelab_ed25519 admin@10.0.1.100
```

### Docker on Synology

```bash
# List containers
docker ps

# View logs
docker logs container-name

# SSH into Synology (if SSH enabled)
ssh admin@10.0.1.50

# Check Docker version
docker --version
```

---

## SECTION 7: CONNECTIVITY TEST PROCEDURES

### From Management VLAN (10.0.1.x)

```bash
# All of these should SUCCEED ✓
ping 10.0.1.1              # ER605 gateway
ping 10.0.1.50             # Synology
ping 10.0.2.1              # Cross-VLAN to Trusted
ping 10.0.10.1             # Cross-VLAN to IoT
ping 8.8.8.8               # Internet
nslookup google.com        # Public DNS
ssh admin@10.0.1.100       # VM1 SSH
http://10.0.1.50:5000      # Synology DSM
```

### From Trusted VLAN (10.0.2.x)

```bash
# These should SUCCEED ✓
ping 10.0.2.1              # Trusted gateway
ping 8.8.8.8               # Internet
nslookup google.com        # Public DNS

# These should FAIL ✗ (blocked by firewall)
ping 10.0.1.1              # Management gateway - BLOCK
ping 10.0.1.50             # Synology - BLOCK
ssh admin@10.0.1.100       # VM1 SSH - BLOCK
```

### From IoT VLAN (10.0.10.x)

```bash
# These should SUCCEED ✓
ping 10.0.10.1             # IoT gateway
ping 8.8.8.8               # Internet

# These should FAIL ✗ (blocked by firewall)
ping 10.0.1.1              # Management - BLOCK
ping 10.0.2.1              # Trusted - BLOCK
ping 10.0.1.50             # Synology - BLOCK
```

### From Guest VLAN (10.0.99.x)

```bash
# These should SUCCEED ✓
ping 10.0.99.1             # Guest gateway
ping 8.8.8.8               # Internet
nslookup google.com        # Public DNS

# These should FAIL ✗ (fully isolated)
ping 10.0.1.0              # Any 10.0.x.x - ALL BLOCKED
ping 10.0.2.0              # Any 10.0.x.x - ALL BLOCKED
ping 10.0.10.0             # Any 10.0.x.x - ALL BLOCKED
```

---

## SECTION 8: TROUBLESHOOTING QUICK REFERENCE

### Issue: Can't connect to ER605 (192.168.0.1)

**Causes:** Bad cable, ER605 not powered, port down, routing issue

**Fix:**
1. Reseat Ethernet cable in LAN1/LAN3
2. Power cycle ER605 (30 seconds)
3. Try different LAN port
4. Check ER605 lights (should be green/amber)
5. Try direct cable (not through switch)

### Issue: No Internet on WAN

**Causes:** Modem not connected, wrong config, ISP issue

**Fix:**
1. Verify ISP modem is powered and has internet light
2. Reseat cable between modem and ER605 WAN
3. Check ER605 WAN config (DHCP/PPPoE/Static)
4. Power cycle modem (30 seconds) then ER605
5. Check with ISP if outage

### Issue: VLANs not working

**Causes:** Port misconfigured, VLAN ID mismatch, trunk issue

**Fix:**
1. Verify all 4 VLANs created in ER605 settings
2. Check port configurations (Access vs Trunk)
3. Verify LAN2 is Trunk with tagged VLANs 1,2,10,99
4. Power cycle all devices
5. Restart ER605

### Issue: Orbi WiFi SSID not broadcasting

**Causes:** WiFi disabled, VLAN tag wrong, isolation issue

**Fix:**
1. Verify WiFi enabled in Orbi settings
2. Check VLAN tag matches (2 for Trusted, 10 for IoT, 99 for Guest)
3. Verify "Broadcast" is checked
4. Test other SSID on same VLAN (rules out Orbi issue)
5. Power cycle Orbi

### Issue: Can't access Synology (10.0.1.50:5000)

**Causes:** Network not connected, IP conflict, DSM issue

**Fix:**
1. Verify Synology network light is green
2. Power cycle Synology (wait 2 minutes for full boot)
3. Ping 10.0.1.50 (if fails, find IP via Synology Assistant)
4. Check for IP conflict (arp-scan -l)
5. Reboot Synology DSM from control panel

### Issue: Cloudflare Tunnel shows Disconnected

**Causes:** Container stopped, token expired, network issue

**Fix:**
1. Check Synology Docker container cloudflared status
2. Container should show "Running"
3. Check container logs for errors
4. Stop/start container to restart
5. Verify tunnel token in container command

### Issue: Can't resolve .internal domains

**Causes:** AdGuard not running, DNS not set, no records added

**Fix:**
1. Verify AdGuard Home deployed and running on k3s
2. Check ER605 DNS set to 10.0.1.53 (primary)
3. Verify .internal records added in AdGuard
4. Test: nslookup nas.home.internal
5. May take 1-2 minutes after config change

---

## SECTION 9: SECURITY VERIFICATION

### Firewall Rules Active

```
☐ Rule 1: IoT blocked from Management (10.0.10→10.0.1)
☐ Rule 2: IoT blocked from Trusted (10.0.10→10.0.2)
☐ Rule 3: Guest blocked from all internal (10.0.99→10.0.x)
☐ Rule 4: Trusted can reach DNS (10.0.2→10.0.1.53:53)
☐ Rule 5: All can reach internet
```

### Password Security

```
☐ ER605 admin password: STRONG (20+ chars)
☐ Synology admin password: STRONG (20+ chars)
☐ Orbi admin password: STRONG (20+ chars)
☐ WiFi passwords: STRONG and DIFFERENT per SSID
☐ All passwords saved in secure password manager
☐ Master password: 30+ chars, stored securely
```

### Network Segmentation

```
☐ VLAN 1: Management only (admin, NAS, VMs)
☐ VLAN 2: Trusted devices (laptops, desktops)
☐ VLAN 10: IoT isolated (smart devices)
☐ VLAN 99: Guest fully isolated (visitors)
☐ No cross-VLAN device-to-device traffic
☐ All VLANs have internet access
```

### Backup & Recovery

```
☐ ER605 config backed up: ER605-config-backup-YYYY-MM-DD.cfg
☐ Synology daily snapshots: 7-day retention
☐ Cloudflare tunnel token: Saved securely
☐ SSH keys: Backed up and stored safely
☐ Recovery procedure tested (optional but recommended)
```

---

## SECTION 10: SUPPORT & DOCUMENTATION

### Device Support Sites

```
ER605: https://www.tp-link.com/us/support/download-center/
Orbi: https://www.netgear.com/support/
Synology: https://www.synology.com/en-us/support
Cloudflare: https://support.cloudflare.com
```

### Important URLs

```
ER605 Management:      http://192.168.0.1 (factory default)
                       http://10.0.1.1 (after config)
Orbi Management:       http://routerlogin.net
                       http://orbi.com
Synology DSM:          http://10.0.1.50:5000
Cloudflare Zero Trust: https://one.dash.cloudflare.com
Cloudflare DNS:        https://dash.cloudflare.com
```

### Emergency Contacts

```
ISP Support:           [Your ISP number]
Netgear Support:       https://www.netgear.com/support
TP-Link Support:       https://www.tp-link.com/support
Synology Support:      https://www.synology.com/support
```

---

## FINAL VERIFICATION CHECKLIST

```
NETWORK LAYER:
☐ ER605 WAN connected (green light)
☐ All 4 VLANs created and active
☐ All firewall rules in correct order
☐ DHCP working on all VLANs
☐ Internet access verified

WIFI LAYER:
☐ Orbi connected to LAN2 trunk
☐ 3 SSIDs broadcasting (Trusted, IoT, Guest)
☐ Each SSID on correct VLAN
☐ Isolation working (IoT/Guest blocked)

STORAGE LAYER:
☐ Synology accessible at 10.0.1.50:5000
☐ Storage pool: Normal
☐ Volume: Ready
☐ Daily snapshots running
☐ Shared folders accessible

EXTERNAL ACCESS:
☐ Tunnel connected to Cloudflare
☐ Public hostnames configured
☐ WARP client installed
☐ Can access services externally

DNS:
☐ Public DNS working (nslookup google.com)
☐ Internal DNS working (nslookup nas.home.internal) - after AdGuard
☐ Guest DNS: public only

SECURITY:
☐ All default passwords changed
☐ Firewall rules active
☐ VLANs isolated per design
☐ SSH keys configured
☐ Backups in place
```

---

**Document Status:** Complete  
**Last Updated:** Saturday, December 20, 2025  
**Ready for Implementation:** YES ✓

---

**USE THIS AS YOUR REFERENCE DURING SETUP**
