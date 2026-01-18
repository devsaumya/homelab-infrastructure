# WiFi Configuration Guide
# Netgear Orbi RBR350 + RBS350 Setup

This document provides step-by-step instructions for configuring the Netgear Orbi mesh WiFi system in **isolated AP mode** for the homelab network.

## Hardware Overview

- **Primary Router**: Netgear Orbi RBR350 (10.0.10.100)
- **Satellite**: Netgear Orbi RBS350 (10.0.10.101)
- **Mode**: AP (Access Point) Mode - Router functions handled by TP-Link ER605
- **Connection**: RBR350 connected to ER605 Port 4 (PVID 10, Tags: 2, 20, 99)

---

## Initial Setup

### 1. Factory Reset (If Needed)
If Orbi was previously configured:
1. Press and hold **Reset** button on RBR350 for 10 seconds
2. Wait for LED to blink amber, then release
3. Device will reboot (takes ~2 minutes)
4. Repeat for RBS350 satellite

### 2. Physical Connection
1. Connect Orbi RBR350 **WAN/Internet port** to ER605 **Port 4** using Ethernet cable
2. Power on RBR350
3. Wait for LED to turn **solid white** (ready for setup)

---

## AP Mode Configuration

### 3. Access Orbi Admin Interface

**Initial Setup (via WiFi)**:
1. Connect to default WiFi network: `NETGEAR_ORBI_XXXX` (SSID printed on Orbi label)
2. Open browser and navigate to: `http://orbilogin.com` or `http://192.168.1.1`
3. Complete initial setup wizard

**Switch to AP Mode**:
1. Log into Orbi admin interface
2. Navigate to: **Advanced → Advanced Setup → Router/AP Mode**
3. Select **AP Mode**
4. Click **Apply**
5. Orbi will reboot and request new IP from ER605 DHCP server

### 4. Update Orbi Network Settings

After reboot in AP Mode:
1. Orbi will receive IP from ER605 DHCP on VLAN 10: **10.0.10.100** (DHCP reservation recommended)
2. Access new admin interface at: `http://10.0.10.100`
3. Login with admin credentials set during initial setup

---

## VLAN Configuration (Multi-SSID)

The Orbi system supports multiple SSIDs mapped to different VLANs.

### 5. Configure Primary SSID (Trusted WiFi - VLAN 10)

1. Navigate to: **Wireless → Wireless Settings**
2. Configure primary SSID:
   - **SSID Name**: `HomeNetwork` (or your preferred name)
   - **Security**: WPA3-Personal (or WPA2/WPA3 Mixed for compatibility)
   - **Password**: Use strong passphrase (16+ characters)
   - **VLAN ID**: 10 (Trusted_WiFi)
   - **Enable**: ✅ YES

**Security Settings**:
- **Encryption**: AES
- **PMF (Protected Management Frames)**: Enabled (if WPA3)
- **Fast Roaming (802.11r)**: Enabled (recommended for mesh)

### 6. Configure Guest SSID (VLAN 99)

1. Navigate to: **Wireless → Guest Network**
2. Enable Guest Network:
   - **SSID Name**: `HomeNetwork-Guest`
   - **Security**: WPA2-Personal (guests may not support WPA3)
   - **Password**: Separate guest password
   - **VLAN ID**: 99 (Guest)
   - **Enable**: ✅ YES

**Guest Network Settings**:
- **Allow guests to see each other**: ❌ NO (client isolation)
- **Allow guests to access my local network**: ❌ NO (enforced by ER605 VLAN isolation)
- **Access Schedule**: Optional (e.g., limit to business hours)

### 7. Additional SSID Configuration (Optional)

If you need more SSIDs for VLAN 2 or VLAN 20:
1. Navigate to: **Wireless → Add Additional SSID**
2. Configure as needed:
   - **SSID for VLAN 2 (Trusted LAN)**: For wired-like WiFi devices
   - **SSID for VLAN 20 (DMZ)**: For isolated IoT devices with less trust

**Note**: Check Orbi RBR350 specifications for maximum supported SSIDs (usually 3-4 total).

---

## Satellite Configuration (RBS350)

### 8. Sync Satellite to Primary Router

**Automatic Sync (Recommended)**:
1. Place RBS350 near RBR350 (within 10 feet initially)
2. Power on RBS350
3. Press **Sync** button on RBR350
4. Within 2 minutes, press **Sync** button on RBS350
5. Wait for LED on RBS350 to turn **solid blue** (synced) or **solid white** (good connection)

**Manual Configuration (If Automatic Fails)**:
1. Access RBR350 admin interface: `http://10.0.10.100`
2. Navigate to: **Attached Devices**
3. RBS350 should appear in the list with MAC address
4. If not, try factory reset on RBS350 and repeat sync process

### 9. Assign Static IP to Satellite

Configure DHCP reservation on ER605 for RBS350:
1. Log into ER605 admin interface
2. Navigate to: **Network → DHCP Server → VLAN 10**
3. Add DHCP reservation:
   - **MAC Address**: RBS350 MAC address (found on device label or in Orbi admin)
   - **IP Address**: 10.0.10.101
   - **Description**: Orbi RBS350 Satellite

---

## Network Settings

### 10. Configure DNS and Gateway

In AP Mode, Orbi relies on ER605 for DHCP/DNS:
- **Gateway**: 10.0.10.1 (ER605 VLAN 10 gateway) - set by DHCP
- **DNS Server**: 10.0.1.53 (AdGuard Home) - set by ER605 DHCP

**Verify** in Orbi admin:
1. Navigate to: **Internet → Internet Status**
2. Confirm:
   - **IP Address**: 10.0.10.100
   - **Gateway**: 10.0.10.1
   - **DNS**: 10.0.1.53

### 11. Disable Orbi Router Features (AP Mode)

Since ER605 handles routing, ensure these are disabled on Orbi:
- **DHCP Server**: ❌ Disabled (ER605 provides DHCP)
- **NAT**: ❌ Disabled (ER605 handles NAT)
- **Firewall**: ❌ Disabled (ER605 enforces firewall rules)
- **Port Forwarding**: ❌ Not applicable in AP mode

These should be automatically disabled when switching to AP Mode.

---

## Advanced WiFi Settings

### 12. Optimize WiFi Performance

**Channel Selection**:
1. Navigate to: **Wireless → Advanced Settings**
2. Configure channels:
   - **2.4 GHz Channel**: Auto (or manually select 1, 6, or 11 if interference)
   - **5 GHz Channel**: Auto (or manually select DFS channels if supported and stable)
   - **Channel Width**: 
     - 2.4 GHz: 20 MHz (better range, less interference)
     - 5 GHz: 40 MHz or 80 MHz (faster speeds, shorter range)

**Transmit Power**:
- **2.4 GHz**: 100% (better range for IoT devices)
- **5 GHz**: 75-100% (adjust based on home size)

**Beamforming**:
- **Enable**: ✅ YES (improves signal to specific devices)

**MU-MIMO**:
- **Enable**: ✅ YES (supports multiple simultaneous devices)

### 13. Band Steering (Optional)

- **Purpose**: Automatically move dual-band devices to 5 GHz when possible
- **Setting**: Navigate to **Wireless → Band Steering**
- **Recommendation**: Enable for better performance on capable devices

### 14. Backhaul Configuration

**Wireless Backhaul** (default):
- RBR350 and RBS350 communicate via dedicated 5 GHz band
- **Best for**: Satellite placement where Ethernet is not feasible
- **Performance**: Good (but half the bandwidth of wired backhaul)

**Wired Backhaul** (recommended if possible):
- Connect RBS350 to ER605 or a managed switch via Ethernet
- **Trade-off**: Requires Ethernet cable run, but provides best performance
- **Configuration**: Plug Ethernet cable into RBS350 **LAN port** (not WAN)
- **Note**: If using wired backhaul on VLAN 10, ensure switch port is configured with PVID 10

---

## Security Hardening

### 15. Change Default Admin Password
1. Navigate to: **Administration → Set Password**
2. Change from default to strong password
3. Store securely (e.g., password manager)

### 16. Disable WPS
1. Navigate to: **Wireless → WPS Settings**
2. **Disable WPS**: ❌ WPS is insecure, do not use

### 17. Enable Access Control (Optional)
If you want to whitelist devices:
1. Navigate to: **Security → Access Control**
2. **Enable Access Control**: ✅ YES
3. **Mode**: Allow listed devices only
4. Add MAC addresses of trusted devices

**Note**: This is optional and can be cumbersome to maintain.

### 18. Update Firmware
1. Navigate to: **Administration → Firmware Update**
2. Check for updates and install latest firmware
3. Enable **Auto Update** for security patches

---

## DHCP Reservations (ER605 Configuration)

Configure static IP assignments for WiFi infrastructure:

| Device | MAC Address | Reserved IP | VLAN | Description |
|--------|-------------|-------------|------|-------------|
| Orbi RBR350 | `XX:XX:XX:XX:XX:XX` | 10.0.10.100 | 10 | Primary WiFi Router (AP Mode) |
| Orbi RBS350 | `XX:XX:XX:XX:XX:XX` | 10.0.10.101 | 10 | WiFi Satellite |

**To configure in ER605**:
1. Log into ER605: `http://10.0.1.1`
2. Navigate to: **Network → DHCP Server**
3. Select **VLAN 10**
4. Add reservations in **DHCP Reservation List**

---

## Verification and Testing

### Test SSID Connectivity

**Test Primary SSID (VLAN 10)**:
1. Connect device to `HomeNetwork` SSID
2. Verify IP address in range: 10.0.10.50 - 10.0.10.250
3. Test Internet: `ping 1.1.1.1`
4. Test DNS: `nslookup google.com`
5. **Verify isolation**: `ping 10.0.1.100` (NAS) - should **FAIL** (blocked by firewall)

**Test Guest SSID (VLAN 99)**:
1. Connect device to `HomeNetwork-Guest` SSID
2. Verify IP address in range: 10.0.99.50 - 10.0.99.250
3. Test Internet: `ping 1.1.1.1`
4. **Verify complete isolation**:
   - `ping 10.0.1.100` - should **FAIL**
   - `ping 10.0.10.100` - should **FAIL**
   - Only Internet access should work

### Test Mesh Roaming
1. Connect device to `HomeNetwork` near RBR350
2. Walk towards RBS350 location
3. Device should seamlessly roam to RBS350 (no disconnect)
4. Check signal strength in WiFi settings (should improve near satellite)

### Verify Backhaul Status
1. Access Orbi admin: `http://10.0.10.100`
2. Navigate to: **Attached Devices → Orbi Devices**
3. Check RBS350 connection quality:
   - **Good** (solid white LED) = Strong connection
   - **Fair** (amber LED) = Weak connection - reposition satellite
   - **Poor** (magenta LED) = Too far - move closer to RBR350

---

## Troubleshooting

### Issue: Cannot Access Orbi Admin Interface
- **Solution**: Verify Orbi received IP 10.0.10.100 from DHCP
- **Check**: Log into ER605, view DHCP leases on VLAN 10
- **Alternative**: Reset Orbi and reconfigure

### Issue: Guest Network Can Access Internal Resources
- **Solution**: Verify VLAN 99 firewall rules on ER605 block internal access
- **Check**: Test from guest device - `ping 10.0.1.1` should fail

### Issue: Satellite Not Syncing
- **Solution 1**: Factory reset RBS350, move closer to RBR350, retry sync
- **Solution 2**: Check RBR350 firmware is up to date
- **Solution 3**: Try wired backhaul setup

### Issue: Slow WiFi Speeds
- **Solution 1**: Check channel congestion (use WiFi analyzer app)
- **Solution 2**: Manually select less congested channels
- **Solution 3**: Reduce transmit power to avoid interference
- **Solution 4**: Use wired backhaul for satellite

### Issue: Devices Not Getting DHCP Address
- **Solution**: Verify ER605 DHCP server is enabled on VLAN 10/99
- **Check**: Verify ER605 Port 4 has VLAN 10 as PVID and VLAN 99 tagged

---

## Placement Recommendations

### RBR350 (Primary Router)
- **Location**: Near ER605 for wired connection
- **Placement**: Central location, elevated (e.g., on shelf)
- **Avoid**: Near metal objects, microwaves, thick walls

### RBS350 (Satellite)
- **Distance**: 30-50 feet from RBR350 (adjust based on home layout)
- **Placement**: Line of sight to RBR350 if possible
- **Test**: Check connection quality LED (white = good, amber = fair, magenta = poor)
- **Iterate**: Reposition if connection quality is poor

---

## Related Documentation

- [ER605 VLAN Configuration](./ER605_VLAN_CONFIG.md) - Port and VLAN setup
- [Firewall Rules](./FIREWALL_RULES.md) - VLAN isolation and security
- [Network Architecture](../../docs/NETWORK_ARCHITECTURE.md) - Overall network design
- [Quick Reference](../../docs/NETWORK_QUICK_REFERENCE.md) - IP and VLAN cheat sheet
