# Homelab Network – Orbi + ER605 Rebuild Plan

Goal:  
- ER605 provides 4 VLANs (1 Management, 2 Trusted, 10 IoT, 99 Guest).  
- Orbi uplink on ER605 **LAN2 as trunk** carrying VLANs 1/2/10/99.  
- Orbi management IP stays on **10.0.1.200 (VLAN1)** so it is always reachable.  
- Wi‑Fi clients land in the correct VLANs via SSID → VLAN tags.

---

## Phase 0 – Reset to Known-Good Baseline

1. **Factory-reset Orbi RBR350**  
   - Hold reset pin until LED blinks, wait for full reboot.  
   - Connect a laptop to an Orbi LAN port or Orbi default Wi‑Fi.  
   - Browse to `http://orbilogin.com` or `http://192.168.1.1`. [file:121]

2. **Reset / clean ER605 config for LAN ports and VLANs**  
   - Ensure ER605 firmware is current.  
   - Keep WAN config as-is (working internet).  
   - Under **Network → LAN / VLAN**, recreate VLANs exactly:  
     - VLAN 1 (Management): 10.0.1.0/24, gateway 10.0.1.1, DHCP 10.0.1.108–200.  
     - VLAN 2 (Trusted): 10.0.2.0/24, gateway 10.0.2.1, DHCP 10.0.2.100–200.  
     - VLAN 10 (IoT): 10.0.10.0/24, gateway 10.0.10.1, DHCP 10.0.10.100–200.  
     - VLAN 99 (Guest): 10.0.99.0/24, gateway 10.0.99.1, DHCP 10.0.99.100–200. [file:121][file:122]

3. **Configure ER605 LAN port roles**  
   - LAN1: Access, PVID 1, untag VLAN1 only (Synology).  
   - **LAN2: Trunk, PVID 2, untag VLAN2, tag VLAN2/10/99, *not* VLAN1.**  
   - LAN3: Access, PVID 1 (admin laptop).  
   - LAN4: Access, PVID 2 (desktop). [file:121][file:122]

---

## Phase 1 – ER605 Core Configuration

1. **DHCP & gateways**  
   - Confirm each VLAN interface shows correct IP/gateway and DHCP ranges as above. [file:121]

2. **Firewall rules (security policy)**  
   - Rule 1: Block IoT (10.0.10.0/24) → Management (10.0.1.0/24). Deny.  
   - Rule 2: Block IoT (10.0.10.0/24) → Trusted (10.0.2.0/24). Deny.  
   - Rule 3: Block Guest (10.0.99.0/24) → any 10.0.0.0/8. Deny.  
   - Rule 4: Allow Trusted (10.0.2.0/24) → 10.0.1.53 (DNS) TCP/UDP 53. Allow.  
   - Rule 5: Allow all → WAN. Allow. [file:121][file:122]

3. **DHCP reservations (optional but recommended)**  
   - Reserve IPs in VLAN1:  
     - Synology: 10.0.1.100  
     - k3s VM: 10.0.1.108  
     - security‑ops VM: 10.0.1.109  
     - **Orbi: 10.0.1.200** (use Orbi MAC from status page). [file:121][file:122]

4. **Checkpoint – ER605**  
   - From a wired laptop on LAN3 (VLAN1):  
     - `ping 10.0.1.1`, `ping 8.8.8.8`, `nslookup google.com` all succeed.  
     - `ping 10.0.2.1` and `10.0.10.1` succeed (router inter‑VLAN). [file:122]

---

## Phase 2 – Orbi RBR350 Setup (Management on VLAN1)

1. **Initial Orbi setup (standalone)**  
   - On first‑boot wizard:  
     - Accept ToS.  
     - Set strong **admin password**.  
     - Skip any WAN/internet setup (ER605 is gateway).  
     - Create temporary SSID (e.g., `Orbi-Setup`). [file:121][file:122]

2. **Connect Orbi to ER605 trunk port**  
   - Plug ER605 **LAN2** ↔ Orbi **Port 1 (Internet/WAN)** via Cat6.  
   - Wait 2–3 minutes; Orbi should get a **10.0.1.x** IP via VLAN1 DHCP (through native VLAN2 trunk path plus VLAN1 tag from Orbi default).  
   - From ER605 **DHCP client list**, find Orbi’s IP and confirm connectivity. [file:121][file:122]

3. **Give Orbi a static IP in VLAN1**  
   - In Orbi UI: **Advanced → Setup → LAN Setup (or Router/AP Mode LAN page)**.  
   - Set:  
     - IP address: **10.0.1.200**  
     - Subnet mask: 255.255.255.0  
     - Gateway: **10.0.1.1**  
     - DNS: 1.1.1.1 (can change later to AdGuard). [file:121][file:122]  
   - Apply and reboot Orbi.  
   - Verify `http://10.0.1.200` is reachable from a VLAN1 client (LAN3).

4. **Enable VLAN support on Orbi**  
   - In Orbi: **Advanced → VLAN / Bridge Settings**.  
   - Enable VLAN/Bridge support.  
   - Save and reboot if prompted. [file:121]

5. **Configure Orbi Port 1 as trunk**  
   - Port type: **Trunk**.  
   - Tagged VLANs: **1, 2, 10, 99**.  
   - Native (untagged) VLAN: **2** (Trusted). [file:121][file:122]  
   - Apply and reboot.

---

## Phase 3 – SSID to VLAN Mapping

1. **Trusted Wi‑Fi (VLAN2)**  
   - SSID: `Orbi-Trusted` (or your choice).  
   - VLAN tag: **2**.  
   - Security: WPA3 / WPA2, strong password.  
   - Bands: 2.4 GHz + 5 GHz.  
   - Guest access: Disabled. [file:121][file:122]

2. **IoT Wi‑Fi (VLAN10)**  
   - SSID: `Orbi-IoT`.  
   - VLAN tag: **10**.  
   - Security: WPA2, different password.  
   - Bands: 5 GHz isolated or as available.  
   - Client isolation: Enabled. [file:121][file:122]

3. **Guest Wi‑Fi (VLAN99)**  
   - SSID: `Orbi-Guest`.  
   - VLAN tag: **99**.  
   - Security: WPA2, easy‑to‑share password.  
   - Bands: 2.4 GHz (for compatibility).  
   - Guest isolation: Enabled. [file:121][file:122]

4. **Checkpoint – Wi‑Fi**  
   - All three SSIDs visible.  
   - Orbi still reachable at **10.0.1.200** from a VLAN1 client. [file:121][file:122]

---

## Phase 4 – Validation Tests

### 4.1 From Trusted client (connected to `Orbi-Trusted`)

1. Confirm network config:  
   - IP: **10.0.2.x**  
   - Gateway: **10.0.2.1**  
2. Connectivity tests:  
   - `ping 10.0.2.1` → success.  
   - `ping 8.8.8.8` → success.  
   - `nslookup google.com` → resolves via public DNS.  
   - Try accessing `http://10.0.1.1` → **should fail** (blocked by firewall). [file:122]

### 4.2 From IoT client (`Orbi-IoT`)

1. IP: **10.0.10.x**, gateway 10.0.10.1.  
2. Tests:  
   - `ping 8.8.8.8` → success.  
   - `ping 10.0.1.1` or 10.0.2.1 → **fail** (isolated). [file:122]

### 4.3 From Guest client (`Orbi-Guest`)

1. IP: **10.0.99.x**, gateway 10.0.99.1.  
2. Tests:  
   - `ping 8.8.8.8` → success.  
   - `ping 10.0.1.1` or any 10.0.x.x → **fail**. [file:122]

### 4.4 From Management client (wired on VLAN1)

1. IP: 10.0.1.x, gateway 10.0.1.1.  
2. Tests:  
   - `ping 10.0.1.200` → reach Orbi.  
   - Access `http://10.0.1.200` → Orbi UI.  
   - `ping 10.0.2.1`, `10.0.10.1`, `10.0.99.1` → succeed. [file:121][file:122]

---

## Phase 5 – Backup & Documentation

1. **Backup ER605 config**  
   - System Tools → Backup & Restore → Download `ER605-config-backup-YYYY-MM-DD.cfg`. [file:122]

2. **Export Orbi config**  
   - Orbi UI → Backup Settings → Save `.cfg` file.

3. **Update docs repo**  
   - In your `homelab-infrastructure/docs` folder, capture:  
     - Final ER605 VLAN diagram.  
     - Orbi port and SSID/VLAN mapping.  
     - IP plan table (10.0.1.x management, 10.0.2.x trusted, etc.). [file:121]

4. **Store in Git**  
   - Commit updated Markdown to your repo so you can roll back or re‑apply easily.

---
