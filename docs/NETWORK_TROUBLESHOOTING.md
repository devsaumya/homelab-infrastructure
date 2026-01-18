# Network Troubleshooting Guide

Comprehensive troubleshooting procedures for common network issues in the homelab infrastructure.

---

## General Troubleshooting Approach

1. **Identify the symptom**: What exactly is not working?
2. **Isolate the layer**: Network (L1-3), Service (L4-7), or Application?
3. **Check recent changes**: What was modified recently?
4. **Test systematically**: Work from physical layer upwards
5. **Document findings**: Note what works and what doesn't
6. **Fix and verify**: Apply fix, then test thoroughly

---

## Connectivity Issues

### Cannot Access Internet

**Symptoms**: Devices cannot reach external websites, ping to Internet IPs fails.

**Diagnosis**:
```bash
# Step 1: Test basic connectivity
ping 1.1.1.1          # Cloudflare DNS (bypasses DNS issues)
ping 8.8.8.8          # Google DNS (alternative test)

# Step 2: Test DNS resolution
nslookup google.com   # If ping fails but nslookup works → routing issue
```

**Possible Causes & Solutions**:

| Cause | Verification | Solution |
|-------|--------------|----------|
| **WAN down** | Check ER605 WAN status LED | Check ISP connection, reboot modem |
| **Default gateway issue** | `ip route` or `route print` | Verify gateway is 10.0.x.1 (VLAN gateway) |
| **DNS failure** | `nslookup` fails but ping IP works | Change DNS to 1.1.1.1, check AdGuard Home |
| **Firewall blocking** | Check ER605 firewall logs | Review firewall rules, check for deny hits |

---

### Cannot Access Devices on Other VLANs

**Symptoms**: Can ping devices on same VLAN but not other VLANs (except from Management VLAN).

**Expected Behavior**: 
- ✅ Management VLAN (1) can access ALL VLANs
- ❌ All other VLANs are isolated (by design)

**Diagnosis**:
```bash
# From VLAN 10 device
ping 10.0.10.1        # VLAN 10 gateway - should work
ping 10.0.1.1         # Management gateway - should FAIL (isolation)
ping 10.0.1.100       # NAS - should FAIL (isolation)

# From Management VLAN device (Admin PC)
ping 10.0.10.100      # Orbi - should WORK
ping 10.0.1.100       # NAS - should WORK
```

**Solutions**:

| Issue | Cause | Fix |
|-------|-------|-----|
| **Isolation is working** | This is expected behavior | Use Management VLAN for admin tasks |
| **Need cross-VLAN access** | Firewall rules too strict | Add specific allow rule in ER605 firewall |
| **Management cannot access** | Firewall misconfiguration | Check MGMT-TO-ALL-ALLOW rule exists (priority 10) |

---

## VLAN Configuration Issues

### Devices on Wrong VLAN

**Symptoms**: Device receives IP from unexpected VLAN (e.g., WiFi client gets 10.0.1.x instead of 10.0.10.x).

**Diagnosis**:
```bash
# Check device IP address
ipconfig         # Windows
ifconfig         # Linux/Mac
ip addr show     # Linux

# Expected IP ranges:
# VLAN 1: 10.0.1.x
# VLAN 10: 10.0.10.x
# VLAN 2: 10.0.2.x
# VLAN 20: 10.0.20.x
# VLAN 99: 10.0.99.x
```

**Possible Causes & Solutions**:

| Cause | Verification | Solution |
|-------|--------------|----------|
| **Port PVID incorrect** | Check ER605 Port Config | Set correct PVID on ER605 port |
| **SSID-to-VLAN mapping wrong** | Check Orbi WiFi settings | Map SSID to correct VLAN in Orbi config |
| **Tagged vs untagged issue** | Check switch port config | Ensure untagged traffic uses PVID |

---

### VLAN Trunk Not Working

**Symptoms**: Tagged VLAN traffic not passing through (e.g., Orbi Guest SSID not working on VLAN 99).

**Diagnosis**:
```bash
# From ER605
# Check port configuration for tagged VLANs
# Port 4 should have: PVID 10, Tags: 2, 20, 99

# Test by connecting device to Guest WiFi
# Should receive IP: 10.0.99.x
# If receives 10.0.10.x → VLAN tagging not working
```

**Solutions**:
1. **Verify ER605 port config**: Navigate to **Network → LAN → VLAN → Port Config**
   - Port 4 should show VLAN 99 in "Tagged VLANs" column
2. **Verify Orbi VLAN tagging**: Ensure Guest SSID is mapped to VLAN 99 in Orbi settings
3. **Test with single VLAN**: Temporarily map Guest SSID to VLAN 10 (untagged) - if this works, issue is VLAN tagging

---

## DNS Issues

### DNS Resolution Failing

**Symptoms**: Cannot resolve domain names (e.g., `nslookup google.com` fails), but `ping 1.1.1.1` works.

**Diagnosis**:
```bash
# Test DNS servers
nslookup google.com 10.0.1.53      # AdGuard Home
nslookup google.com 1.1.1.1        # Cloudflare (fallback)

# Check DNS server in use
ipconfig /all        # Windows
cat /etc/resolv.conf # Linux
```

**Possible Causes & Solutions**:

| Cause | Verification | Solution |
|-------|--------------|----------|
| **AdGuard Home down** | `kubectl get pods -n dns-system` | Restart AdGuard: `kubectl rollout restart -n dns-system deployment/adguard-home` |
| **Wrong DNS server** | Check DHCP settings | Configure DNS in ER605 DHCP: Primary 10.0.1.53, Secondary 1.1.1.1 |
| **DNS not accessible** | Ping 10.0.1.53 | Check firewall rules allow DNS (port 53) from all VLANs |
| **Upstream DNS issue** | Check AdGuard upstream config | Log into AdGuard UI, verify upstream DNS (1.1.1.1, 8.8.8.8) |

---

### Internal DNS Not Working (home.internal)

**Symptoms**: `nas.home.internal` does not resolve, but external domains work.

**Diagnosis**:
```bash
# Test internal DNS
nslookup nas.home.internal       # Should return 10.0.1.100
nslookup k3s.home.internal       # Should return 10.0.1.108

# If fails, test direct to AdGuard
nslookup nas.home.internal 10.0.1.53
```

**Solutions**:
1. **Check AdGuard DNS rewrites**: 
   - Login to AdGuard: http://10.0.1.53:3000
   - Navigate to **Filters → DNS rewrites**
   - Add missing records:
     ```
     nas.home.internal → 10.0.1.100
     k3s.home.internal → 10.0.1.108
     adguard.home.internal → 10.0.1.53
     ```
2. **Verify DNS server**: Ensure clients are using 10.0.1.53 as primary DNS
3. **Check AdGuard config**: Verify custom DNS rules are enabled

---

## WiFi Issues

### WiFi Network Not Visible

**Symptoms**: SSID not appearing in WiFi list.

**Diagnosis**:
1. Check Orbi status LEDs:
   - **Solid white**: Good connection
   - **Solid blue**: Syncing
   - **Solid amber**: Fair connection
   - **Pulsing white**: Booting
   - **Pulsing amber**: Firmware update
   - **Off**: No power

2. Verify Orbi is powered on and connected to ER605 Port 4

**Solutions**:

| Cause | Fix |
|-------|-----|
| **SSID broadcast disabled** | Login to Orbi, enable SSID broadcast in **Wireless Settings** |
| **Orbi in router mode** | Switch Orbi to AP mode: **Advanced → Router/AP Mode → AP Mode** |
| **Wrong frequency band** | Check both 2.4GHz and 5GHz - SSID may be on single band |
| **Orbi hardware failure** | Power cycle Orbi, check Ethernet connection, factory reset if needed |

---

### WiFi Connected but No Internet

**Symptoms**: WiFi shows connected, but no Internet access. Devices get IP address but cannot browse.

**Diagnosis**:
```bash
# Check IP address
ipconfig         # Windows - should be 10.0.10.x or 10.0.99.x
ip addr          # Linux

# Test connectivity
ping 10.0.10.1   # Gateway (for VLAN 10) - should work
ping 1.1.1.1     # Internet - if fails, routing/firewall issue
nslookup google.com  # DNS test
```

**Solutions**:

| Symptom | Cause | Fix |
|---------|-------|-----|
| **Can ping gateway, not Internet** | Firewall blocking | Check VLAN-TO-INTERNET firewall rules |
| **Wrong gateway** | DHCP misconfiguration | Verify ER605 DHCP gateway for VLAN 10 is 10.0.10.1 |
| **No DNS** | DNS server unreachable | Check AdGuard Home status, fallback to 1.1.1.1 |
| **IP conflict** | Duplicate IP address | Release/renew IP: `ipconfig /release && ipconfig /renew` |

---

### Poor WiFi Signal / Dropouts

**Symptoms**: Weak signal strength, frequent disconnections, slow speeds.

**Diagnosis**:
```bash
# Check signal strength (dBm)
# Good: -30 to -67 dBm
# Fair: -68 to -80 dBm
# Poor: -81 dBm or worse

# Use WiFi analyzer app to check:
# - Channel congestion
# - Interference from neighbors
# - 2.4GHz vs 5GHz performance
```

**Solutions**:
1. **Reposition Orbi satellite**:
   - Check RBS350 LED (white=good, amber=fair, magenta=poor placement)
   - Move closer to RBR350 if LED is amber/magenta
   - Ideal: 30-50 feet from primary router, line of sight

2. **Change WiFi channels**:
   - Login to Orbi: http://10.0.10.100
   - **Wireless → Advanced Settings → Select Channel**
   - **2.4GHz**: Use channels 1, 6, or 11 (non-overlapping)
   - **5GHz**: Use DFS channels if available and stable

3. **Reduce interference**:
   - Move Orbi away from: microwaves, cordless phones, baby monitors
   - Lower transmit power if too many nearby networks

4. **Use wired backhaul**: Connect RBS350 to ER605 via Ethernet for best performance

---

## Firewall Issues

### Legitimate Traffic Being Blocked

**Symptoms**: Service should be accessible but connection times out or is refused.

**Diagnosis**:
```bash
# Test connectivity
ping <service-ip>
telnet <service-ip> <port>

# Example: Test k8s API from Management VLAN
telnet 10.0.1.108 6443    # Should connect
```

**Solutions**:
1. **Check ER605 firewall logs**:
   - Login to ER605: http://10.0.1.1
   - Navigate: **Firewall → Logs**
   - Look for DENY entries matching your source/destination

2. **Verify firewall rules**:
   - Navigate: **Firewall → Access Control**
   - Check rule order (rules processed top-to-bottom)
   - Ensure allow rule exists BEFORE deny rule

3. **Common fixes**:
   - Add explicit allow rule for the service
   - Check rule priority (specific rules before general rules)
   - Verify source and destination VLANs are correct

---

### Unexpected Traffic Passing Through

**Symptoms**: Isolated VLANs can communicate when they shouldn't (e.g., VLAN 10 can ping VLAN 1).

**Diagnosis**:
```bash
# From VLAN 10 device (should FAIL)
ping 10.0.1.100    # NAS on VLAN 1 - should be blocked

# If succeeds, isolation is broken
```

**Solutions**:
1. **Verify VLAN isolation rules exist**:
   - Login to ER605
   - Check for DENY rules (priorities 90-93):
     - VLAN10-TO-INTERNAL-DENY
     - VLAN2-TO-INTERNAL-DENY
     - VLAN99-TO-INTERNAL-DENY

2. **Check rule order**:
   - Deny rules should come AFTER specific allow rules (e.g., DNS)
   - Place at priority 90+ (near end of rule list)

3. **Verify SPI firewall enabled**:
   - **Settings → Security → SPI Firewall** should be ON
   - This prevents return traffic from being treated as new sessions

---

## DHCP Issues

### Not Getting IP Address

**Symptoms**: Device shows "No network access" or "169.254.x.x" (APIPA) address.

**Diagnosis**:
```bash
# Release and renew DHCP
ipconfig /release && ipconfig /renew    # Windows
sudo dhclient -r && sudo dhclient       # Linux

# Check if static IP is set
ipconfig /all       # Look for "DHCP Enabled: No"
```

**Solutions**:

| Cause | Fix |
|-------|-----|
| **DHCP server disabled** | Login to ER605 → **Network → DHCP Server** → Enable for VLAN |
| **DHCP pool exhausted** | Expand DHCP range or remove old leases |
| **Static IP conflict** | Check for duplicate IP reservations |
| **Wrong VLAN** | Verify device is on correct VLAN (check IP range) |

---

### Getting IP from Wrong DHCP Server

**Symptoms**: Device gets IP outside expected range (e.g., 192.168.x.x instead of 10.0.x.x).

**Diagnosis**:
```bash
# Check gateway
ipconfig /all    # Look at "Default Gateway"

# Expected gateways:
# VLAN 1: 10.0.1.1
# VLAN 10: 10.0.10.1
# VLAN 2: 10.0.2.1
```

**Solutions**:
1. **Disable rogue DHCP servers**: Check if Orbi is still in Router Mode (should be AP Mode)
   - Login to Orbi → **Advanced → Router/AP Mode** → Select **AP Mode**
2. **Disable NAS DHCP**: If Synology has DHCP enabled, disable it
3. **Factory reset device**: Last resort - reset device and reconnect

---

## Service Access Issues

### Cannot Access ER605 Admin Interface

**Symptoms**: http://10.0.1.1 times out or refuses connection.

**Solutions**:
1. **Verify you're on Management VLAN**:
   - Check your IP: Should be 10.0.1.x
   - If on another VLAN, connect via Port 5 (Management Spare)

2. **Direct connection**:
   - Connect PC directly to ER605 Port 5
   - Set static IP: 10.0.1.50/24, Gateway: 10.0.1.1
   - Access: http://10.0.1.1

3. **Factory reset** (last resort):
   - Hold reset button for 10 seconds
   - Wait for reboot
   - Access at default IP (usually 192.168.0.1)
   - Restore configuration backup

---

### Cannot Access K8s Services

**Symptoms**: Cannot access services running in k3s cluster (e.g., AdGuard Home, Traefik).

**Diagnosis**:
```bash
# Check k8s cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Check specific service
kubectl get svc -n dns-system
kubectl logs -n dns-system deployment/adguard-home
```

**Solutions**:

| Issue | Fix |
|-------|-----|
| **k3s down** | SSH to k3s-master-01 → `sudo systemctl status k3s` → restart if needed |
| **Pod not running** | `kubectl describe pod <pod-name> -n <namespace>` → check events |
| **Service not exposed** | Check Service type (LoadBalancer, ClusterIP) and external IP |
| **Firewall blocking** | Verify Management VLAN can access k3s API (port 6443) |

---

## Hardware Issues

### ER605 Not Responding

**Symptoms**: All LEDs off, or power LED on but no connectivity.

**Solutions**:
1. **Power cycle**: Unplug power, wait 30 seconds, plug back in
2. **Check power supply**: Verify power adapter is working
3. **Check cables**: Ensure Ethernet cables are properly connected
4. **Factory reset**: Hold reset button 10 seconds (if device is on but unresponsive)

---

### NAS Not Accessible

**Symptoms**: Cannot access Synology NAS at 10.0.1.100.

**Diagnosis**:
```bash
# Test connectivity
ping 10.0.1.100

# Check if responding on management port
telnet 10.0.1.100 5000    # DSM web interface
telnet 10.0.1.100 22      # SSH
```

**Solutions**:
1. **Check NAS status LEDs**: Solid green = OK, blinking = disk activity, red = error
2. **Power cycle NAS**: Graceful shutdown via button, wait 30sec, power on
3. **Check Ethernet cable**: Port 2 on ER605 to NAS
4. **Access via keyboard/monitor**: Connect directly to NAS if network fails

---

## Monitoring and Logs

### Where to Check Logs

| System | Log Location | Access Method |
|--------|--------------|---------------|
| **ER605 Firewall** | Web UI | http://10.0.1.1 → **Firewall → Logs** |
| **AdGuard Home** | Web UI | http://10.0.1.53:3000 → **Dashboard** |
| **k8s Pods** | kubectl | `kubectl logs <pod-name> -n <namespace>` |
| **k3s System** | journalctl | `sudo journalctl -u k3s -f` |
| **VM2 Docker** | docker logs | `docker logs <container-name>` |
| **Synology NAS** | DSM | **Control Panel → Log Center** |

---

## Network Performance Testing

### Bandwidth Testing

```bash
# Test Internet speed
speedtest-cli    # Linux
# Or use: fast.com, speedtest.net

# Test LAN speed (between devices)
iperf3 -s        # On server device
iperf3 -c <server-ip>  # On client device
```

### Latency Testing

```bash
# Test latency to gateway
ping -c 100 10.0.1.1    # Linux
ping -n 100 10.0.1.1    # Windows

# Check for packet loss and jitter
```

---

## Recovery Procedures

### Complete Network Failure

**Order of Recovery**:
1. **Check physical**: Verify all devices powered on, cables connected
2. **Restore ER605**: Factory reset if needed, restore config backup
3. **Verify WAN**: Confirm Internet connectivity working
4. **Check VLANs**: Test DHCP on each VLAN
5. **Test services**: AdGuard → k3s → other services

### Backup and Restore

**ER605 Configuration**:
- **Backup**: **Settings → Maintenance → Backup** → Download config
- **Restore**: **Settings → Maintenance → Restore** → Upload config file

**Orbi Configuration**:
- **Backup**: **Administration → Backup Settings**
- **Restore**: **Administration → Restore Settings**

---

## Related Documentation

- [Network Architecture](./NETWORK_ARCHITECTURE.md) - Complete architecture reference
- [Quick Reference](./NETWORK_QUICK_REFERENCE.md) - One-page cheat sheet
- [ER605 VLAN Config](../infra/network/ER605_VLAN_CONFIG.md) - VLAN setup
- [Firewall Rules](../infra/network/FIREWALL_RULES.md) - ACL documentation
- [WiFi Config](../infra/network/WIFI_CONFIG.md) - Orbi configuration
