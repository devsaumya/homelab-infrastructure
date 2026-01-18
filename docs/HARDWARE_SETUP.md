# Hardware Setup Guide

Complete guide for setting up and configuring all hardware components in the homelab infrastructure.

---

## Table of Contents

1. [Hardware Overview](#hardware-overview)
2. [TP-Link ER605 Router](#tp-link-er605-router)
3. [Synology NAS](#synology-nas)
4. [Virtual Machines](#virtual-machines)
5. [Network Switch](#network-switch)
6. [Initial Network Configuration](#initial-network-configuration)

---

## Hardware Overview

### Required Hardware

| Component | Model/Specs | Purpose | IP Address |
|-----------|------------|---------|------------|
| **Router** | TP-Link ER605 | Edge router, VLAN management, firewall | 10.0.1.1 |
| **NAS** | Synology (varies) | Centralized storage, NFS/SMB shares | 10.0.1.50 |
| **VM Host** | Varies (Proxmox/ESXi/etc) | Virtualization host | - |
| **k3s-master-01** | 2 CPU, 4GB RAM, 40GB disk | Kubernetes control plane | 10.0.1.108 |
| **k3s-worker-01** | 2 CPU, 4GB RAM, 40GB disk | Docker services, monitoring | 10.0.1.109 |
| **Managed Switch** | VLAN-capable | Network switching, VLAN trunking | - |

### Optional Hardware

- **UPS**: Uninterruptible Power Supply for critical equipment
- **Access Points**: Wi-Fi access points for VLAN-based Wi-Fi networks
- **Firewall Appliance**: Additional firewall (if not using ER605 firewall features)

---

## TP-Link ER605 Router

### Overview

The TP-Link ER605 serves as the edge router, firewall, and VLAN gateway for the homelab network.

### Initial Configuration

#### 1. Access Router Web UI

1. Connect to router via Ethernet cable
2. Default IP: `http://192.168.0.1` or `http://tplinkrouter.net`
3. Default credentials: `admin` / `admin` (change immediately)

#### 2. Configure WAN Connection

1. Navigate to **Network → WAN**
2. Configure your internet connection type:
   - **DHCP**: For most residential connections
   - **PPPoE**: If required by ISP
   - **Static IP**: If ISP provides static IP
3. Set MTU if needed (typically 1500)
4. Enable NAT

#### 3. Configure LAN Settings

1. Navigate to **Network → LAN**
2. Set management IP: `10.0.1.1`
3. Subnet mask: `255.255.255.0`
4. DHCP range: `10.0.1.108 - 10.0.1.200` (for VLAN 1)

### VLAN Configuration

#### Create VLANs

Navigate to **Network → VLAN** and create the following VLANs:

| VLAN ID | Name | IP Range | DHCP Range | Gateway |
|---------|------|----------|------------|---------|
| 1 | Management | 10.0.1.0/24 | 10.0.1.108-10.0.1.200 | 10.0.1.1 |
| 2 | Trusted LAN | 10.0.2.0/24 | 10.0.2.100-10.0.2.200 | 10.0.2.1 |
| 10 | IoT | 10.0.10.0/24 | 10.0.10.100-10.0.10.200 | 10.0.10.1 |
| 20 | DMZ | 10.0.20.0/24 | 10.0.20.100-10.0.20.200 | 10.0.20.1 |
| 99 | Guest | 10.0.99.0/24 | 10.0.99.100-10.0.99.200 | 10.0.99.1 |

**Note:** Assign VLAN 1 (Management) to the port connecting to your managed switch (trunk port).

#### Configure DHCP for Each VLAN

For each VLAN:

1. Navigate to **Network → DHCP Server**
2. Select the VLAN
3. Enable DHCP Server
4. Configure:
   - **Start IP**: Start of DHCP range
   - **End IP**: End of DHCP range
   - **Lease Time**: 86400 (24 hours)
   - **Gateway**: VLAN gateway IP
   - **Primary DNS**: `10.0.1.53` (AdGuard Home - after deployment)
   - **Secondary DNS**: `1.1.1.1` (Cloudflare)

### Firewall Rules Configuration

#### Inter-VLAN Routing Rules

Navigate to **Security → Firewall → ACL Rules**:

1. **Management → Internet**: Allow HTTP/HTTPS/DNS
   - Source: 10.0.1.0/24
   - Destination: Any
   - Service: HTTP, HTTPS, DNS
   - Action: Allow

2. **Trusted LAN → Internet**: Full access
   - Source: 10.0.2.0/24
   - Destination: Any
   - Service: Any
   - Action: Allow

3. **IoT → Internet**: HTTP/HTTPS/DNS only
   - Source: 10.0.10.0/24
   - Destination: Any
   - Service: HTTP, HTTPS, DNS
   - Action: Allow

4. **IoT → Management/Trusted**: Deny all
   - Source: 10.0.10.0/24
   - Destination: 10.0.1.0/24, 10.0.2.0/24
   - Service: Any
   - Action: Deny

5. **DMZ → Management**: Allow k3s API (6443)
   - Source: 10.0.20.0/24
   - Destination: 10.0.1.108
   - Service: TCP 6443
   - Action: Allow

6. **Internet → DMZ**: Allow HTTP/HTTPS (80/443)
   - Source: Any
   - Destination: 10.0.20.0/24
   - Service: HTTP, HTTPS
   - Action: Allow

7. **Guest → Internal**: Deny all
   - Source: 10.0.99.0/24
   - Destination: 10.0.0.0/8
   - Service: Any
   - Action: Deny

8. **Guest → Internet**: Allow HTTP/HTTPS/DNS
   - Source: 10.0.99.0/24
   - Destination: Any
   - Service: HTTP, HTTPS, DNS
   - Action: Allow

#### SMB Rules (Synology Access)

1. **Management → Synology**: Allow SMB3 (TCP 445) with encryption
   - Source: 10.0.1.0/24
   - Destination: 10.0.1.50
   - Service: TCP 445
   - Action: Allow

2. **Trusted LAN → Synology**: Allow SMB3 (read-only)
   - Source: 10.0.2.0/24
   - Destination: 10.0.1.50
   - Service: TCP 445
   - Action: Allow

3. **IoT → Synology**: Deny all
   - Source: 10.0.10.0/24
   - Destination: 10.0.1.50
   - Service: Any
   - Action: Deny

### Port Configuration

Configure ports on ER605:

- **Port 1**: WAN (internet connection)
- **Port 2-5**: Trunk to managed switch (VLAN 1 tagged, others as needed)

### Backup Configuration

1. Navigate to **System → Backup & Restore**
2. Export configuration
3. Save backup file securely
4. **Important**: Update backup after any configuration changes

---

## Synology NAS

### Overview

The Synology NAS provides centralized storage for the homelab, including NFS/SMB shares for Kubernetes persistent volumes.

### Initial Setup

#### 1. Access Synology DSM

1. Connect to NAS via network
2. Default IP: Assigned via DHCP (check router)
3. Access via: `http://<nas-ip>:5000` or use Synology Assistant
4. Complete initial setup wizard:
   - Create admin account
   - Set timezone
   - Configure network

#### 2. Configure Network

1. Navigate to **Control Panel → Network → Network Interface**
2. Set static IP: `10.0.1.50`
3. Subnet mask: `255.255.255.0`
4. Gateway: `10.0.1.1`
5. DNS servers:
   - Primary: `10.0.1.53` (AdGuard Home - after deployment)
   - Secondary: `1.1.1.1`

#### 3. Create Storage Pools and Volumes

1. Navigate to **Storage Manager**
2. Create storage pool (if not already created)
3. Create volumes:
   - **Volume 1**: Main storage (largest)
   - **Volume 2**: Backups (if needed)

#### 4. Create Shared Folders

Navigate to **Control Panel → Shared Folder** and create:

| Folder Name | Purpose | NFS | SMB | Notes |
|-------------|---------|-----|-----|-------|
| `k8s-pv` | Kubernetes persistent volumes | Yes | No | NFS export for k3s |
| `backups` | System backups | Yes | Yes | Backup storage |
| `media` | Media files | No | Yes | Media library |
| `docker-data` | Docker data | No | Yes | Docker volume mounts |

#### 5. Configure NFS Service

1. Navigate to **Control Panel → File Services → NFS**
2. Enable NFS v4
3. Configure NFS permissions for `k8s-pv`:
   - **Network**: `10.0.1.0/24`
   - **Squash**: Map all users to admin
   - **Permissions**: Read/Write
   - **Security**: sys

#### 6. Configure SMB Service

1. Navigate to **Control Panel → File Services → SMB**
2. Enable SMB service
3. Enable SMB3 encryption (recommended)
4. Enable SMB signing (recommended)
5. Configure SMB permissions:
   - **Management VLAN** (10.0.1.0/24): Full access
   - **Trusted LAN** (10.0.2.0/24): Read-only

#### 7. Create Users and Groups

1. Navigate to **Control Panel → User & Group**
2. Create service accounts as needed:
   - `k8s-service`: For Kubernetes NFS mounts
   - `backup-service`: For backup operations

#### 8. Configure Backups

1. Navigate to **Hyper Backup**
2. Create backup task:
   - **Destination**: Cloud storage (Backblaze B2, AWS S3, etc.)
   - **Schedule**: Daily incremental, weekly full
   - **Retention**: 30 days daily, 12 weeks weekly

### Security Hardening

1. **Enable 2FA** for admin account
2. **Disable default admin account** (create new admin)
3. **Enable firewall** rules:
   - Allow only Management VLAN (10.0.1.0/24)
   - Allow specific ports: 22 (SSH), 443 (HTTPS), 445 (SMB), 2049 (NFS)
4. **Enable auto-updates** for DSM
5. **Enable SSL/TLS** certificates (via Let's Encrypt)
6. **Configure SSH**: Disable root login, use key-based auth

---

## Virtual Machines

### VM Host Requirements

- **Virtualization Platform**: Proxmox, ESXi, Hyper-V, or similar
- **CPU**: Support for virtualization (Intel VT-x/AMD-V)
- **RAM**: Minimum 16GB (32GB+ recommended)
- **Storage**: SSD recommended for VMs
- **Network**: Support for VLAN tagging

### k3s-master-01 VM

#### Specifications
- **OS**: Ubuntu 22.04 LTS
- **CPU**: 2 cores
- **RAM**: 4GB
- **Disk**: 40GB (SSD recommended)
- **Network**: 
  - VLAN 1 (Management)
  - Static IP: 10.0.1.108

#### Installation Steps

1. **Create VM** in virtualization platform
2. **Install Ubuntu 22.04 LTS**:
   - Minimal installation
   - Enable SSH server
   - Create user: `admin`
3. **Configure Network**:
   ```bash
   sudo nano /etc/netplan/00-installer-config.yaml
   ```
   ```yaml
   network:
     version: 2
     ethernets:
       eth0:
         addresses:
           - 10.0.1.108/24
         gateway4: 10.0.1.1
         nameservers:
           addresses:
             - 10.0.1.53
             - 1.1.1.1
   ```
   ```bash
   sudo netplan apply
   ```
4. **Configure SSH**:
   - Disable password auth (use keys)
   - Change SSH port (optional)
5. **Verify connectivity**:
   ```bash
   ping 10.0.1.1
   ping 8.8.8.8
   ```

### k3s-worker-01 VM (VM2)

#### Specifications
- **OS**: Ubuntu 22.04 LTS
- **CPU**: 2 cores
- **RAM**: 4GB
- **Disk**: 40GB (SSD recommended)
- **Network**: 
  - VLAN 1 (Management)
  - Static IP: 10.0.1.109

#### Installation Steps

1. **Create VM** in virtualization platform
2. **Install Ubuntu 22.04 LTS** (same as k3s-master-01)
3. **Configure Network** (same as k3s-master-01, use IP 10.0.1.109)
4. **Verify connectivity**

---

## Network Switch

### Requirements

- **Type**: Managed switch with VLAN support
- **Ports**: Minimum 8 ports (16+ recommended)
- **Features**: 
  - VLAN tagging (802.1Q)
  - Port-based VLANs
  - Trunk ports
  - Basic management interface

### Configuration

#### Port Assignment

- **Port 1**: Trunk to ER605 (all VLANs tagged)
- **Port 2**: k3s-master-01 (VLAN 1, untagged)
- **Port 3**: k3s-worker-01 (VLAN 1, untagged)
- **Port 4**: Synology NAS (VLAN 1, untagged)
- **Port 5-8**: Available for other devices

#### VLAN Configuration

Configure VLANs on switch:

1. **Create VLANs**: 1, 2, 10, 20, 99
2. **Configure trunk port** (to ER605):
   - Tag all VLANs: 1, 2, 10, 20, 99
   - Native VLAN: 1
3. **Configure access ports**:
   - Assign ports to VLAN 1 (untagged)
   - Add ports to VLAN 1 member list

#### Access Points (if applicable)

If using VLAN-capable access points:

1. Configure trunk port to access point
2. Tag VLANs: 1, 2, 10, 99
3. Configure SSIDs on access point:
   - **SSID 1**: Trusted (VLAN 2)
   - **SSID 2**: IoT (VLAN 10)
   - **SSID 3**: Guest (VLAN 99)

---

## Initial Network Configuration

### Pre-Deployment Checklist

- [ ] ER605 router configured and accessible
- [ ] VLANs created on ER605
- [ ] DHCP configured for each VLAN
- [ ] Firewall rules configured
- [ ] Synology NAS configured and accessible
- [ ] VMs created and accessible via SSH
- [ ] Network switch configured with VLANs
- [ ] All devices can ping gateway (10.0.1.1)
- [ ] All devices can resolve DNS (temporarily use 1.1.1.1)

### Testing Network Connectivity

```bash
# From k3s-master-01 (10.0.1.108)
ping 10.0.1.1      # Gateway
ping 10.0.1.50     # Synology NAS
ping 10.0.1.109    # k3s-worker-01 VM
ping 8.8.8.8       # Internet

# From k3s-worker-01 (10.0.1.109)
ping 10.0.1.1      # Gateway
ping 10.0.1.50     # Synology NAS
ping 10.0.1.108    # k3s-master-01
ping 8.8.8.8       # Internet
```

### Next Steps

After hardware setup is complete:

1. Proceed with [MASTER.md](./MASTER.md) Phase 1: Bootstrap VMs
2. Configure Ansible inventory with VM IPs
3. Begin software deployment

---

## Troubleshooting Hardware Issues

### Router Issues

**Cannot access router web UI:**
- Check IP address (try 192.168.0.1, 192.168.1.1, or check DHCP)
- Try direct connection to router
- Reset router to factory defaults if needed

**VLANs not working:**
- Verify VLAN IDs match on router and switch
- Check trunk port configuration
- Verify ports are assigned to correct VLANs

### NAS Issues

**Cannot access Synology:**
- Check network connectivity
- Verify IP address (10.0.1.50)
- Check firewall rules on ER605
- Access via Synology Assistant if needed

**NFS/SMB not working:**
- Verify services are enabled
- Check firewall rules
- Verify user permissions
- Check network connectivity from client

### VM Issues

**VMs cannot reach internet:**
- Verify gateway (10.0.1.1)
- Check DNS configuration
- Verify firewall rules on ER605
- Check VM network adapter settings

**VMs cannot communicate with each other:**
- Verify all VMs are on same VLAN
- Check network switch configuration
- Verify firewall rules allow inter-VLAN communication
- Check VM network adapter settings

---

**For software deployment and configuration, proceed to [MASTER.md](./MASTER.md)**

