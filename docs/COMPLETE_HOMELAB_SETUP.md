# HOMELAB INFRASTRUCTURE COMPLETE SETUP GUIDE

## Synology DS720+ | TP-Link ER605 | Orbi RBR350 | Cloudflare Integration

**Project Name:** Home Infrastructure  
**Domain:** connect2home.online (Public) | home.internal (LAN)  
**Date:** Saturday, December 20, 2025  
**Status:** Ready for Implementation  

---

## EXECUTIVE SUMMARY

This guide provides a complete step-by-step setup for a professional homelab using:
- **ER605 Router** for network management with VLAN segregation (4 networks)
- **Synology DS720+** for storage and container/VM hosting
- **Orbi RBR350** for multi-VLAN wireless distribution
- **Cloudflare Tunnel & WARP** for secure external access

**Total Setup Time:** 6-8 hours  
**Complexity Level:** Intermediate  
**Prerequisites:** Basic networking knowledge, comfortable with CLI

---

## TABLE OF CONTENTS

1. [Network Architecture Overview](#1-network-architecture-overview)
2. [Phase 0: Pre-Deployment Checklist](#phase-0-pre-deployment-checklist)
3. [Phase 1: ER605 Router Configuration](#phase-1-er605-router-configuration)
4. [Phase 2: Orbi RBR350 WiFi Setup](#phase-2-orbi-rbr350-wifi-setup)
5. [Phase 3: Synology DS720+ Configuration](#phase-3-synology-ds720-configuration)
6. [Phase 4: Cloudflare Tunnel Setup](#phase-4-cloudflare-tunnel-setup)
7. [Phase 5: DNS & Service Access](#phase-5-dns--service-access)
8. [Verification Checklist](#verification-checklist)
9. [Troubleshooting Guide](#troubleshooting-guide)

---

## 1. NETWORK ARCHITECTURE OVERVIEW

### Complete Network Topology

```
INTERNET (ISP)
    |
    | WAN (DHCP/PPPoE)
    v
┌─────────────────────────────────────┐
│   TP-LINK ER605 (10.0.1.1)         │
│  ├─ LAN1: Synology Access Port      │
│  ├─ LAN2: Orbi Trunk (Multi-VLAN)  │
│  ├─ LAN3: Admin Access Port        │
│  └─ LAN4: Desktop Access Port      │
└──┬────────┬────────┬────────────────┘
   │        │        │
   │        │        └─→ Orbi RBR350 (10.0.1.200)
   │        │            ├─ VLAN 1: Management WiFi
   │        │            ├─ VLAN 2: Trusted WiFi
   │        │            ├─ VLAN 10: IoT WiFi
   │        │            └─ VLAN 99: Guest WiFi
   │        └─→ Admin Laptop
   │
   └─→ Synology DS720+ (10.0.1.50)
       ├─ Docker Services
       ├─ VMs (k3s, security-ops)
       ├─ Storage Pool (Btrfs)
       └─ Daily Snapshots

CLOUDFLARE (connect2home.online)
    ↓
Tunnel → Traefik → Services
```

### VLAN Design

| VLAN | Name        | Network      | Gateway   | Purpose | Security |
|------|-------------|--------------|-----------|---------|----------|
| 1    | Management  | 10.0.1.0/24  | 10.0.1.1  | NAS, VMs, k3s, Admin | High |
| 2    | Trusted     | 10.0.2.0/24  | 10.0.2.1  | Laptops, Desktops | Medium |
| 10   | IoT         | 10.0.10.0/24 | 10.0.10.1 | Smart devices, Cameras | Isolated |
| 99   | Guest       | 10.0.99.0/24 | 10.0.99.1 | Visitors, Temporary | Fully Isolated |

**Security Rules:**
- IoT cannot access Management or Trusted
- Guest cannot access ANY internal network
- All have internet access
- DNS via AdGuard (10.0.1.53)

### Static IP Allocations

```
Management VLAN (10.0.1.0/24):
├─ Gateway: 10.0.1.1 (ER605)
├─ Synology: 10.0.1.50
├─ VM1 k3s-master: 10.0.1.100
├─ VM2 security-ops: 10.0.1.105
├─ AdGuard DNS: 10.0.1.53
├─ Traefik LB: 10.0.1.80
└─ Orbi: 10.0.1.200

Dynamic DHCP Pools:
├─ VLAN 1: 10.0.1.100-200
├─ VLAN 2: 10.0.2.100-200
├─ VLAN 10: 10.0.10.100-200
└─ VLAN 99: 10.0.99.100-200
```

---

## PHASE 0: PRE-DEPLOYMENT CHECKLIST

### Hardware Verification

- [ ] ER605 router (latest firmware capable)
- [ ] Synology DS720+ (sealed box, warranty valid)
- [ ] Orbi RBR350 (all accessories included)
- [ ] Ethernet cables (Cat6+, at least 4)
- [ ] UPS backup power (APC/Belkin)
- [ ] Network switch (optional, for expansions)

### Software & Accounts Setup

- [ ] Cloudflare Account (free tier sufficient) at https://dash.cloudflare.com/
- [ ] Domain registered: connect2home.online (check nameservers set to Cloudflare)
- [ ] GitHub Account (for dotfiles storage)
- [ ] Gmail Account (for system alerts)
- [ ] Zerodha/Groww Account (if monitoring investments on homelab)

### Security Preparation

- [ ] Password manager ready (1Password, Bitwarden, KeePass)
- [ ] Master password generated (30+ chars)
- [ ] SSH key pair created: `ssh-keygen -t ed25519 -f ~/.ssh/homelab_ed25519`
- [ ] Backup external drive available
- [ ] UPS battery tested (press self-test button)

### Network Planning

- [ ] ISP contact number saved
- [ ] ISP connection type confirmed (DHCP/PPPoE/Static)
- [ ] ISP credentials if PPPoE: username/password saved
- [ ] WiFi interference checked (WiFi analyzer app for 2.4/5GHz)
- [ ] Orbi placement planned (central location)

---

## PHASE 1: ER605 ROUTER CONFIGURATION

**Duration:** 45 minutes  
**Difficulty:** Intermediate

### Step 1.1: Physical Connection & Initial Access

**Physical Setup:**
```
ISP Modem
    |
    | Ethernet
    v
ER605 WAN Port (Orange)
    |
    | (Power via UPS)
    v
Ready for Configuration
```

1. Connect ISP modem to ER605 WAN port (orange)
2. Power on ER605 via UPS
3. Wait 30 seconds for boot
4. Connect admin laptop to ER605 LAN1 port
5. Open browser: **http://192.168.0.1**

**Default Credentials:**
- Username: admin
- Password: admin
- **IMMEDIATELY change password to STRONG value (20+ chars, mixed)**

### Step 1.2: WAN Configuration

Navigate to: **Settings → Network → WAN**

**Option A: DHCP (Most Common - ISP automatically assigns IP)**
```
Type: DHCP
Apply and test with: ping 8.8.8.8
Expected result: 4 packets transmitted, 4 received
```

**Option B: PPPoE (ADSL/Fiber with username/password)**
```
Type: PPPoE
Username: [from ISP email]
Password: [from ISP email]
Apply and reboot (wait 2-3 minutes)
```

**Option C: Static IP (Business connections)**
```
Type: Static
IP Address: [from ISP]
Netmask: [from ISP]
Gateway: [from ISP]
DNS: 1.1.1.1 (temporary, will change)
Apply
```

**Verify WAN is working:**
```bash
ping 8.8.8.8              # Should get replies
nslookup google.com       # Should resolve
```

### Step 1.3: Create 4 VLANs

Navigate to: **Settings → Wired Networks → LAN**

**Important:** Do this carefully - wrong config causes network issues.

**VLAN 1 - Management:**
```
VLAN ID: 1
Network Address: 10.0.1.0
Netmask: 255.255.255.0
Gateway: 10.0.1.1
DHCP Enabled: Yes
DHCP Start: 10.0.1.100
DHCP End: 10.0.1.200
Lease Time: 86400 (24 hours)
Primary DNS: 1.1.1.1
Secondary DNS: 8.8.8.8
Status: Click Save
```

**VLAN 2 - Trusted:**
```
VLAN ID: 2
Network Address: 10.0.2.0
Netmask: 255.255.255.0
Gateway: 10.0.2.1
DHCP Enabled: Yes
DHCP Start: 10.0.2.100
DHCP End: 10.0.2.200
Lease Time: 43200 (12 hours)
Primary DNS: 1.1.1.1
Secondary DNS: 8.8.8.8
Status: Click Save
```

**VLAN 10 - IoT:**
```
VLAN ID: 10
Network Address: 10.0.10.0
Netmask: 255.255.255.0
Gateway: 10.0.10.1
DHCP Enabled: Yes
DHCP Start: 10.0.10.100
DHCP End: 10.0.10.200
Lease Time: 43200 (12 hours)
Primary DNS: 1.1.1.1
Secondary DNS: 8.8.8.8
Status: Click Save
```

**VLAN 99 - Guest:**
```
VLAN ID: 99
Network Address: 10.0.99.0
Netmask: 255.255.255.0
Gateway: 10.0.99.1
DHCP Enabled: Yes
DHCP Start: 10.0.99.100
DHCP End: 10.0.99.200
Lease Time: 3600 (1 hour - SHORT for guests)
Primary DNS: 1.1.1.1
Secondary DNS: 8.8.8.8
Status: Click Save
```

**Checkpoint:** All 4 VLANs should appear in Settings → Summary

### Step 1.4: Configure LAN Ports

Navigate to: **Settings → Wired Networks → LAN → Port Settings**

**LAN1 - Access Port (Synology):**
```
Mode: Access (not trunk)
PVID (Native VLAN): 1
Allowed VLANs: 1 only
Description: Synology DS720+
Save
```

**LAN2 - Trunk Port (Orbi WiFi):**
```
Mode: Trunk (carries multiple VLANs)
PVID (Native VLAN): 2
Untagged VLANs: 2
Tagged VLANs: 2, 10, 99 (NOT 1 - security)
Description: Orbi RBR350 Multi-VLAN
Save
```

**LAN3 - Access Port (Admin Laptop):**
```
Mode: Access
PVID: 1
Allowed VLANs: 1 only
Description: Admin Laptop Temporary
Save
```

**LAN4 - Access Port (Desktop/Future):**
```
Mode: Access
PVID: 2
Allowed VLANs: 2 only
Description: Desktop or Future Device
Save
```

**Checkpoint:** Refresh page, all 4 ports should show correct configuration

### Step 1.5: Configure Firewall Rules

Navigate to: **Settings → Firewall → Access Control**

**Rule 1 - Block IoT → Management:**
```
Source: 10.0.10.0/24 (IoT VLAN)
Destination: 10.0.1.0/24 (Management VLAN)
Service: All
Action: Deny
Logging: Enable
Priority: 1 (highest)
Save
```

**Rule 2 - Block IoT → Trusted:**
```
Source: 10.0.10.0/24
Destination: 10.0.2.0/24
Service: All
Action: Deny
Logging: Enable
Priority: 2
Save
```

**Rule 3 - Block Guest to ALL Internal:**
```
Source: 10.0.99.0/24 (Guest)
Destination: 10.0.0.0/8 (All 10.x.x.x)
Service: All
Action: Deny
Logging: Enable
Priority: 3
Save
```

**Rule 4 - Allow Trusted to DNS:**
```
Source: 10.0.2.0/24 (Trusted)
Destination: 10.0.1.53/32 (AdGuard DNS)
Service: DNS (UDP/TCP 53)
Action: Allow
Logging: Disable
Priority: 4
Save
```

**Rule 5 - Allow All to Internet:**
```
Source: 0.0.0.0/0 (any)
Destination: WAN (internet)
Service: All
Action: Allow
Logging: Disable
Priority: 5
Save
```

**Order matters!** Rules evaluated top-to-bottom.

**Checkpoint:** All 5 rules visible in Settings → Summary, in order

### Step 1.6: Add DHCP Reservations

Navigate to: **Settings → Wired Networks → LAN → DHCP Server → Reservations**

Add these now (MAC addresses to be filled later):

```
Device: Synology
IP: 10.0.1.50
MAC: [Get from device label - add after network boot]
VLAN: 1
Save

Device: VM1 k3s-master
IP: 10.0.1.100
MAC: [Add after VM creation]
VLAN: 1
Save

Device: VM2 security-ops
IP: 10.0.1.105
MAC: [Add after VM creation]
VLAN: 1
Save

Device: Orbi RBR350
IP: 10.0.1.200
MAC: [Get from Orbi status page after connection]
VLAN: 1
Save
```

### Step 1.7: Backup Configuration

Navigate to: **Settings → System → Backup & Restore**

1. Click: **Backup**
2. Downloads file: ER605-config-backup-YYYY-MM-DD.cfg
3. Save to: ~/backups/networking/
4. Keep this safe - it's your recovery point

### Step 1.8: Final ER605 Verification

From admin laptop (connected to LAN1 or LAN3):

```bash
# Test gateway
ping 10.0.1.1          # Should respond ✓

# Test cross-VLAN routing (should work)
ping 10.0.2.1          # Should respond ✓

# Test internet
ping 8.8.8.8           # Should respond ✓

# Test DNS
nslookup google.com    # Should resolve ✓
```

**Checkpoint:** ER605 fully configured and tested

---

## PHASE 2: ORBI RBR350 WIFI SETUP

**Duration:** 30 minutes  
**Difficulty:** Intermediate

### Step 2.1: Physical Connection

**Setup:**
```
ER605 LAN2 (Trunk) ← Cat6 Ethernet → Orbi Port 1 (WAN from ER605)
                                        |
                                    Orbi Antennas
                                    Orbi App
```

1. Disconnect any existing Orbi connections
2. Connect Orbi Port 1 to ER605 LAN2 with Cat6 cable
3. Power on Orbi through UPS
4. Wait 2-3 minutes for full boot (satellite lights become solid)

### Step 2.2: Initial Orbi Configuration

**Find Orbi IP:**
Option 1: Browser directly to: **http://routerlogin.net** or **http://orbi.com**
Option 2: Check ER605 DHCP clients list for Orbi
Option 3: Use Orbi app from app store (smartphone)

**Initial Setup:**
1. Accept Terms of Service
2. Create **new admin password (STRONG 16+ chars)**
3. Skip initial WAN setup (using ER605 as gateway)
4. Setup WiFi:
   - SSID: Orbi-Main (or your preference)
   - Password: STRONG
5. Skip advanced features initially
6. Reboot Orbi

### Step 2.3: Enable VLAN Support

Navigate to: **Settings → Advanced → VLAN**

1. Enable: VLAN Support
2. Save and reboot Orbi (2-3 minutes)

After reboot, access Orbi again.

### Step 2.4: Configure Port 1 as Trunk

Navigate to: **Settings → Network → LAN Port Settings**

**Port 1 Configuration:**
```
Port 1 Type: Trunk (carries multiple VLANs)
Tagged VLANs: 1, 2, 10, 99 (all VLANs)
Untagged VLAN: 2 (native)
Description: Trunk from ER605
Save and Reboot
```

### Step 2.5: Create WiFi SSIDs per VLAN

Navigate to: **Settings → WiFi**

**WiFi Network 1 - Trusted (VLAN 2):**
```
Name: Orbi-Trusted
VLAN Tag: 2
Security: WPA3 (or WPA2 if WPA3 unavailable)
Password: STRONG_PASSWORD_TRUSTED
802.11 Bands: 2.4GHz + 5GHz (Auto)
Broadcast: Enabled
Guest Access: Disabled
Isolation: Disabled (devices can see each other)
Save
```

**WiFi Network 2 - IoT (VLAN 10):**
```
Name: Orbi-IoT
VLAN Tag: 10
Security: WPA2
Password: DIFFERENT_PASSWORD_IOT
802.11 Bands: 5GHz-1 or 5GHz-2 (isolated band)
Broadcast: Enabled
Guest Access: Disabled
Isolation: Enabled (devices cannot see each other)
Save
```

**WiFi Network 3 - Guest (VLAN 99):**
```
Name: Orbi-Guest
VLAN Tag: 99
Security: WPA2
Password: PUBLIC_FRIENDLY_PASSWORD
802.11 Bands: 2.4GHz (older devices)
Broadcast: Enabled
Guest Access: Enabled
Guest Isolation: Enabled (cannot access internal networks)
Guest Bandwidth Limit: 50Mbps (optional)
Save
```

**Checkpoint:** All 3 WiFi networks appear in WiFi settings

### Step 2.6: Set Static IP

Navigate to: **Settings → Network → LAN IP**

```
LAN IP Type: Manual/Static
IP Address: 10.0.1.200
Subnet Mask: 255.255.255.0
Gateway: 10.0.1.1 (ER605)
Primary DNS: 1.1.1.1 (temporary)
Secondary DNS: 8.8.8.8
Save and Reboot
```

After reboot, verify:
```bash
# From admin laptop
ping 10.0.1.200        # Orbi should respond
```

### Step 2.7: Add to ER605 DHCP Reservation

Back in ER605:
**Settings → Wired Networks → LAN → DHCP Server → Reservations**

```
Device: Orbi RBR350
IP: 10.0.1.200
MAC: [Get from Orbi → Advanced → System → Device Info]
VLAN: 1
Save
```

Reboot Orbi. Static IP should persist.

### Step 2.8: Test WiFi Connectivity

**Connect to Orbi-Trusted SSID:**
```bash
# From laptop connected to Orbi-Trusted
ping 10.0.1.1          # ER605 - should work ✓
ping 10.0.10.1         # IoT gateway - should BLOCK ✗
ping 8.8.8.8           # Internet - should work ✓
nslookup google.com    # DNS - should resolve ✓
```

**Connect to Orbi-IoT SSID (from IoT device):**
```bash
# From phone/IoT on Orbi-IoT
ping 10.0.2.1          # Trusted gateway - should BLOCK ✗
ping 10.0.1.1          # Management - should BLOCK ✗
ping 8.8.8.8           # Internet - should work ✓
```

**Connect to Orbi-Guest SSID (from visitor device):**
```bash
# From guest on Orbi-Guest
ping 10.0.1.1          # All internal - should BLOCK ✗
ping 8.8.8.8           # Internet - should work ✓
```

**Checkpoint:** All WiFi networks functional, isolation working

---

## PHASE 3: SYNOLOGY DS720+ CONFIGURATION

**Duration:** 1 hour  
**Difficulty:** Beginner-Intermediate

### Step 3.1: Hardware Assembly

**Power Off & Safety First:**
```
1. Unplug Synology from power
2. Wait 30 seconds
3. Ground yourself (touch metal case)
4. Keep away from moisture
```

**Install RAM:**
```
1. Remove 4 rubber feet screws from bottom
2. Locate single DDR4-2400 slot (center of motherboard)
3. Remove existing 2GB module if present:
   - Push both clips away from module
   - Module pops up at 45°
   - Remove carefully
4. Install 16GB DDR4 SODIMM:
   - Orient key notch on module
   - Insert at 45° angle
   - Press down firmly
   - Both clips should lock automatically
   - Verify module sits flush (fully inserted)
5. Reinstall 4 rubber feet screws
```

**Install HDD:**
```
1. Locate Tray 1 (left side, labeled "1")
2. Pull tray out completely
3. Insert WD Red Plus 1TB:
   - Align 3 screw holes on right side
   - Align SATA connector on back
   - Gently push in fully
   - Install 3 screws (snug, not over-tight)
4. Slide tray back in until **click**
5. Verify HDD light turns green
```

**Connect Cables:**
```
1. Connect power to UPS
2. Connect network cable to LAN port
3. Power on Synology
4. Wait 30 seconds (beep = good sign)
5. Check lights:
   - Status light: green = normal
   - HDD light: green = recognized
```

**Checkpoint:** Synology powered on, lights green

### Step 3.2: Access Synology DSM

**Find Synology IP:**

Option 1: Use Synology Assistant (download from Synology site)
Option 2: Check ER605 DHCP clients: should be around 10.0.1.x
Option 3: Network scan: `arp-scan -l` (Linux/Mac)

**Access DSM:**
```
Browser: http://SYNOLOGY_IP:5000
Expected: DSM login page or setup wizard
```

**DSM Setup Wizard:**
1. Accept Terms & Conditions
2. Create Admin Account:
   - Username: admin
   - Password: STRONG (20+ chars)
   - **SAVE this password!**
3. QuickConnect: **Skip** (using Cloudflare instead)
4. Telemetry: Opt out
5. DSM Update: **Allow to install**
6. Wait 5-10 minutes for reboot and update

After reboot:
```
Browser: http://SYNOLOGY_IP:5000
Login with credentials created above
DSM desktop appears
```

**Checkpoint:** DSM running, logged in, updated

### Step 3.3: Storage Configuration

**Create Storage Pool:**

Main Menu → Storage Manager → Storage Pool
1. Click: **Create**
2. Step 1 - Choose Disks:
   - Select your WD Red Plus 1TB
   - RAID Type: **Basic** (single disk)
3. Step 2 - File System:
   - Type: **Btrfs** (data protection)
   - Enable: Data Checksum ✓
   - Enable: CoW (Copy-on-Write) ✓
4. Step 3 - Confirm:
   - Review settings
   - Confirm: **"I want to proceed"**
   - Formatting starts (~15 seconds)
   - Status shows: **pool-1 Created**

**Create Volume:**

Storage Manager → Volume
1. Click: **Create**
2. Step 1:
   - Choose Pool: **pool-1**
3. Step 2:
   - Volume Name: **volume1**
   - Size: **Use All Available Space**
4. Step 3 - Snapshots:
   - Enable Snapshots: **Yes** ✓
   - Schedule: **Daily** at **2:00 AM**
   - Snapshot Count: Keep **7 days**
5. Step 4 - Confirm:
   - Review settings
   - Click: **Create**
   - Volume creation completes (~10 seconds)
   - Status shows: **volume1 Ready**

**Verification:**

Storage Manager → Summary
```
Pool-1:
├─ Status: NORMAL ✓
├─ Type: Btrfs
└─ Health: Good ✓

Volume1:
├─ Status: READY ✓
├─ Free: ~900GB
└─ Health: Good ✓
```

**Checkpoint:** Storage pool and volume created

### Step 3.4: Network Configuration

**Set Static IP:**

Control Panel → Network → Network Interface → LAN

1. Click: **Edit**
2. IPv4 Settings:
   - Method: **Manual**
   - IP Address: **10.0.1.50**
   - Netmask: **255.255.255.0**
   - Gateway: **10.0.1.1** (ER605)
   - DNS 1: **1.1.1.1**
   - DNS 2: **8.8.8.8** (will change to AdGuard later)
3. Click: **Apply**
4. NAS disconnects/reconnects (wait 30 seconds)
5. Browser automatically reconnects or refresh

**Verify Static IP:**

Control Panel → Network → Network Interface → Summary
```
LAN:
├─ IP Address: 10.0.1.50 ✓
├─ Gateway: 10.0.1.1 ✓
└─ Status: Connected ✓
```

**Time Zone Configuration:**

Control Panel → Regional Options → Time
1. Time Zone: **Asia/Kolkata**
2. NTP Server: **time.google.com**
3. Sync Now: Click **Sync**
4. Time should update to current time

**Checkpoint:** Static IP configured, time accurate

### Step 3.5: Install Required Packages

**Install Docker:**

Main Menu → Package Center
1. Search: "Docker"
2. Select: Docker (official package)
3. Click: **Install**
4. Accept EULA
5. Installation starts (3-5 minutes)
6. Status: **Docker appears on DSM desktop**
7. Verify: Main Menu → Docker icon visible

**Install Virtual Machine Manager:**

Package Center (still open)
1. Search: "Virtual Machine Manager"
2. Click: **Install**
3. Accept EULA
4. Installation starts (2-3 minutes)
5. Status: **VM Manager appears on DSM desktop**

**Install Snapshot Replication:**

Package Center
1. Search: "Snapshot Replication"
2. Click: **Install**
3. Accept EULA
4. Installation completes (~1 minute)
5. Status: Package installed

**Verification:**

Main Menu should show:
```
├─ Docker ✓
├─ Virtual Machine Manager ✓
├─ Snapshot Replication ✓
└─ Other apps
```

**Checkpoint:** All 3 packages installed

### Step 3.6: Create Shared Folders

Control Panel → Shared Folder

**Folder 1 - docker:**
1. Click: **Create**
2. Folder Name: **docker**
3. Location: **/volume1**
4. Recycle Bin: **Enable** ✓
5. Permissions: admin (read/write)
6. Click: **Create**

**Folder 2 - vms:**
1. Click: **Create**
2. Folder Name: **vms**
3. Location: **/volume1**
4. Recycle Bin: **Enable** ✓
5. Permissions: admin
6. Click: **Create**

**Folder 3 - backups:**
1. Click: **Create**
2. Folder Name: **backups**
3. Location: **/volume1**
4. Recycle Bin: **Enable** ✓
5. Permissions: admin
6. Click: **Create**

**Verification:**

Control Panel → Shared Folder → Summary
```
Folders:
├─ docker ✓
├─ vms ✓
└─ backups ✓
```

Access via SMB from laptop:
```bash
# Windows: \\10.0.1.50\docker
# Mac/Linux: smb://10.0.1.50/docker
# Should connect with admin credentials
```

**Checkpoint:** All shared folders created and accessible

### Step 3.7: Final Synology Verification

Checklist:
- [ ] DSM accessible at http://10.0.1.50:5000
- [ ] Static IP: 10.0.1.50
- [ ] Storage pool: Normal status
- [ ] Volume1: Ready status
- [ ] Docker installed
- [ ] VMM installed
- [ ] Snapshot Replication installed
- [ ] 3 shared folders created
- [ ] Time zone correct (Asia/Kolkata)
- [ ] Daily snapshots scheduled for 2:00 AM

**Checkpoint:** Synology fully configured

---

## PHASE 4: CLOUDFLARE TUNNEL SETUP

**Duration:** 20 minutes  
**Difficulty:** Intermediate

### Step 4.1: Cloudflare Account Setup

1. Go to: https://dash.cloudflare.com
2. Sign up or login with existing account
3. Verify email
4. Add domain: **connect2home.online**
5. Change nameservers at registrar to Cloudflare:
   - NS1: ellie.ns.cloudflare.com
   - NS2: rex.ns.cloudflare.com
6. Wait 24-48 hours for DNS propagation
7. Verify in Cloudflare: DNS shows "Active nameservers"

### Step 4.2: Create Tunnel

**Access Zero Trust Dashboard:**

1. Go to: https://one.dash.cloudflare.com/
2. Login with Cloudflare account
3. Sidebar → Access → Tunnels
4. Click: **Create a tunnel**
5. Tunnel Type: **Cloudflared**
6. Name: **homelab-prod**
7. Click: **Save tunnel**

**Get Tunnel Token:**

1. You're shown: Cloudflared connector options
2. Select: **Docker**
3. Copy the installation command (contains TOKEN)
4. Save command securely

Example format:
```bash
docker run -d \
  --name cloudflared \
  cloudflare/cloudflared:latest tunnel run \
  --token eyJhIjoiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### Step 4.3: Install Tunnel on Synology Docker

**Via Synology DSM:**

Main Menu → Docker → Registry
1. Search: **cloudflare/cloudflared**
2. Select official image
3. Click: **Download**
4. Wait for download completion

**Create Container:**

Main Menu → Docker → Container
1. Click: **Create**
2. Image: cloudflare/cloudflared:latest
3. Container Name: cloudflared
4. Command: (paste the token command from above)
5. Enable auto-restart: **Yes**
6. Ports: (cloudflared doesn't need port mapping)
7. Create

**Monitor Container:**

Docker → Container
1. Select: cloudflared
2. Click: Logs
3. Should see: "Registered tunnel" message
4. Go to Cloudflare → Tunnels
5. Status should show: **Connected** ✓

**Checkpoint:** Tunnel connected and showing online

### Step 4.4: Add Tunnel Routes

**In Cloudflare Tunnel UI:**

1. Click tunnel: homelab-prod
2. Tab: **Public Hostname**
3. Click: **Add a public hostname**

**Add Route 1 - Grafana:**
```
Subdomain: grafana
Domain: connect2home.online
Protocol: HTTP
URL: 10.0.1.105:3000
Save
```

**Add Route 2 - Vaultwarden:**
```
Subdomain: vault
Domain: connect2home.online
Protocol: HTTP
URL: 10.0.1.105:8080
Save
```

**Add Route 3 - Prometheus:**
```
Subdomain: prometheus
Domain: connect2home.online
Protocol: HTTP
URL: 10.0.1.105:9090
Save
```

**Add Route 4 - Traefik Dashboard:**
```
Subdomain: home
Domain: connect2home.online
Protocol: HTTP
URL: 10.0.1.80:9000
Save
```

**Add Route 5 - Synology (optional):**
```
Subdomain: nas
Domain: connect2home.online
Protocol: HTTP (or HTTPS if available)
URL: 10.0.1.50:5000
Save
```

**Checkpoint:** All routes configured

### Step 4.5: Test Tunnel Access

From external network (not home WiFi):

**Option 1: Install Cloudflare WARP**
1. Download WARP client: https://one.dash.cloudflare.com/downloads
2. Install on your laptop/phone
3. Login with Cloudflare account
4. Open browser: https://grafana.connect2home.online
5. WARP intercepts → Cloudflare Zero Trust checks credentials
6. If approved → Tunneled to 10.0.1.105:3000 (Grafana)

**Option 2: Public Access (if Zero Trust not configured)**
1. Browser: https://grafana.connect2home.online
2. Should directly access (if no access policies configured)

**Expected Results:**
- grafana.connect2home.online → Grafana login page (after k3s deployment)
- vault.connect2home.online → Vaultwarden interface (after deployment)
- home.connect2home.online → Traefik dashboard (after k3s deployment)

**Checkpoint:** Tunnel routes accessible externally

---

## PHASE 5: DNS & SERVICE ACCESS

**Duration:** 30 minutes  
**Difficulty:** Beginner

### Step 5.1: Internal DNS Configuration (LAN)

After deploying AdGuard Home in Kubernetes (Phase 6 if deploying k3s), configure internal DNS.

**Access AdGuard Home:**
```
Browser: http://10.0.1.53:3000
(After k3s + AdGuard deployment)
```

**Add Local DNS Records:**

1. Settings → DNS Settings → Local DNS
2. Add records:

```
nas.home.internal           → 10.0.1.50
k3s.home.internal           → 10.0.1.100
vault.home.internal         → 10.0.1.105
portainer.home.internal     → 10.0.1.105
grafana.home.internal       → 10.0.1.105
prometheus.home.internal    → 10.0.1.105
```

3. Save all records

**Update ER605 DNS Servers:**

Settings → Wired Networks → LAN → (edit each VLAN)

For VLAN 1 & 2:
```
Primary DNS: 10.0.1.53 (AdGuard Home)
Secondary DNS: 1.1.1.1 (Cloudflare - fallback)
Apply
```

For VLAN 10 & 99 (can leave public):
```
Primary DNS: 1.1.1.1 (Cloudflare)
Secondary DNS: 8.8.8.8 (Google - fallback)
Apply
```

**Test LAN DNS:**

From laptop on VLAN 1:
```bash
nslookup nas.home.internal
# Expected: 10.0.1.50

nslookup google.com
# Expected: Resolved via 10.0.1.53
```

### Step 5.2: External DNS Configuration

Cloudflare automatically creates DNS records when tunnel routes added.

**Verify in Cloudflare:**

1. Go to: https://dash.cloudflare.com
2. Select domain: connect2home.online
3. DNS → Records
4. Should show A records:
   ```
   grafana.connect2home.online    A    103.21.244.x (Cloudflare IP)
   vault.connect2home.online      A    103.21.244.x
   prometheus.connect2home.online A    103.21.244.x
   home.connect2home.online       A    103.21.244.x
   ```

### Step 5.3: Service Access Matrix

**From Management VLAN (10.0.1.x):**
```
Service           URL                          Port
Synology DSM      http://nas.home.internal     5000
Prometheus        http://prometheus.home...    9090
Traefik          http://10.0.1.80:9000        9000
```

**From Trusted VLAN (10.0.2.x):**
```
Service           URL                          Access
Grafana          https://grafana.connect...   Via Cloudflare WARP
Vaultwarden      https://vault.connect2...    Via Cloudflare WARP
(Full isolation from Management)
```

**From IoT VLAN (10.0.10.x):**
```
Internet only - No internal service access
No .internal DNS resolution
```

**From Guest VLAN (10.0.99.x):**
```
Internet only - Fully isolated
Lease time: 1 hour (auto-disconnect)
```

---

## VERIFICATION CHECKLIST

### Network Layer
- [ ] ER605 WAN connection stable (green light)
- [ ] All 4 VLANs created and active
- [ ] All 4 firewall rules in correct order
- [ ] DHCP working on all VLANs
- [ ] Ping 8.8.8.8 works from all VLANs

### WiFi Layer
- [ ] Orbi connected to LAN2 trunk port
- [ ] Orbi shows 3 SSIDs (Trusted, IoT, Guest)
- [ ] Devices on Orbi-Trusted connect to VLAN 2
- [ ] Devices on Orbi-IoT blocked from VLAN 1/2
- [ ] Devices on Orbi-Guest blocked from all internal

### Synology Layer
- [ ] DSM accessible at 10.0.1.50:5000
- [ ] Static IP 10.0.1.50 confirmed
- [ ] Storage pool shows "Normal" status
- [ ] Volume1 shows "Ready" status
- [ ] All 3 packages installed (Docker, VMM, Snapshot)
- [ ] All 3 shared folders accessible

### Cloudflare Layer
- [ ] Domain connect2home.online points to Cloudflare nameservers
- [ ] Tunnel "homelab-prod" shows "Connected"
- [ ] 5+ public hostname routes configured
- [ ] WARP client installed and logged in
- [ ] External test: Can access grafana.connect2home.online

### DNS Layer
- [ ] `nslookup google.com` resolves
- [ ] `nslookup nas.home.internal` returns 10.0.1.50
- [ ] Guest WiFi DNS: public only (1.1.1.1)
- [ ] Management DNS: includes AdGuard (10.0.1.53)

---

## TROUBLESHOOTING GUIDE

### ER605 Issues

**Problem: Can't access http://192.168.0.1**
- Solution: Unplug ER605, wait 30 seconds, plug back in
- Verify: Use laptop connected to LAN port directly
- Check: Browser → advanced → ignore certificate warning

**Problem: VLANs not working**
- Solution: Verify all 4 VLANs created in LAN settings
- Check: Port assignments (LAN1=Access 1, LAN2=Trunk, etc.)
- Restart: ER605 → Settings → Reboot

**Problem: No internet after WAN setup**
- Solution: Check WAN light on ER605 (should be green)
- Verify: ISP modem is connected and working
- Test: ping 8.8.8.8 from admin laptop
- If PPPoE: verify username/password correct

### Synology Issues

**Problem: Can't access http://10.0.1.50:5000**
- Solution: Check network cable connection
- Verify: Synology has network activity light
- Find IP: Use Synology Assistant (download from Synology site)
- Reset: Power off 30 seconds, power on again

**Problem: HDD not recognized**
- Solution: Remove HDD, reseat it firmly in tray
- Verify: HDD light is green after reboot
- Check: Tray fully inserted with click

**Problem: Storage pool shows degraded**
- Solution: This is normal for first 24 hours
- Monitor: Should show "Normal" after daily checks complete
- Note: Don't power off during this period

### Orbi Issues

**Problem: Orbi not connecting to ER605 LAN2**
- Solution: Verify LAN2 port not in Access mode (should be Trunk)
- Check: Cat6 cable is fully inserted in both devices
- Reset: Orbi → power cycle (wait 2 minutes)
- Verify: Orbi lights show white = connected

**Problem: Specific WiFi SSID not broadcasting**
- Solution: Check WiFi enabled in Orbi settings
- Verify: VLAN tag correct (2 for Trusted, 10 for IoT, etc.)
- Fix: Edit WiFi → check "Broadcast" is enabled
- Test: Other VLAN SSIDs working?

**Problem: Guest WiFi has access to internal networks**
- Solution: Verify ER605 firewall rule 3 blocks 10.0.99.x to 10.0.0.0/8
- Check: Rule priority (should be #3)
- Fix: Create new rule if missing

### Cloudflare Issues

**Problem: Tunnel shows "Disconnected"**
- Solution: Check cloudflared container is running
- Via Synology Docker: should see "Running" status
- Logs: should show "Registered tunnel" message
- Fix: Restart container (stop/start)

**Problem: Can't connect to tunnel from external network**
- Solution: Verify WARP client installed and logged in
- Check: firewall/VPN settings blocking Cloudflare IPs
- Test: Without VPN first to rule it out

**Problem: Domain not resolving externally**
- Solution: Verify nameservers changed at registrar
- Wait: Can take up to 24-48 hours for propagation
- Check: https://www.whatsmydns.net → connect2home.online
- Verify: Cloudflare DNS shows A record

### DNS Issues

**Problem: Can't resolve .internal domains**
- Solution: Verify AdGuard Home deployed and running
- Check: ER605 DNS set to 10.0.1.53 primary
- Test: On Management VLAN only
- Fix: Add records to AdGuard manually

**Problem: Guest WiFi can resolve internal domains**
- Solution: Verify Guest ER605 DNS set to 1.1.1.1 (public)
- Check: ER605 VLAN 99 settings
- Fix: Change DNS for VLAN 99 to public only

---

## NEXT STEPS (OPTIONAL)

After completing all 5 phases:

1. **Deploy Kubernetes (k3s)** on VM1
   - Adds: Container orchestration
   - Services: AdGuard DNS, Prometheus, Grafana, Traefik
   
2. **Setup Docker Services** on VM2
   - Services: Vaultwarden, Portainer, Monitoring stack
   
3. **Enable HTTPS/TLS**
   - cert-manager for automatic certificates
   - Traefik integration for auto-renewal
   
4. **Configure Backups**
   - External cloud storage integration
   - Incremental sync to cloud
   - Test recovery process
   
5. **Deploy Monitoring**
   - Full observability stack
   - Custom dashboards
   - Alert notifications

---

## DOCUMENT INFO

**Status:** Complete and Ready  
**Last Updated:** Saturday, December 20, 2025  
**Version:** 1.0  
**Total Time:** 6-8 hours (spread over 2-3 days)  
**Complexity:** Intermediate Level  
**Support:** Detailed troubleshooting included

**Files Created:**
- This guide (PDF downloadable)
- Network diagrams (images)
- Venn diagram (component relationships)
- Configuration templates (ready to use)

**Questions?** Refer to troubleshooting section or device manuals.

---

**END OF SETUP GUIDE**
