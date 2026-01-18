# Architecture

## Overview

This homelab infrastructure follows a GitOps approach with clear separation between infrastructure provisioning and application deployment.

## Structure

### Infrastructure Layer (`infra/`)

Everything that runs **outside** Kubernetes or touches VMs/OS:

- **`terraform/`**: Cloud resources (Cloudflare DNS, tunnels, WAF)
- **`ansible/`**: VM provisioning, OS hardening, k3s installation
- **`contracts/`**: Network/DNS/IPAM contracts (source of truth)
- **`network/`**: Network configuration generation scripts
- **`dns/`**: DNS configuration generation scripts

### Docker Layer (`docker/`)

Docker Compose stacks running on VM2 (outside Kubernetes):

- **`monitoring/`**: Prometheus, Grafana, Loki, AlertManager
- **`security/`**: Security scanning tools
- **`services/`**: Utility services

### Kubernetes Layer (`k8s/`)

Everything that ArgoCD deploys (GitOps-managed):

- **`bootstrap/argocd/`**: One-time manual installation (ArgoCD itself)
- **`base/`**: Core infrastructure services
  - **`namespaces/`**: Namespace definitions
  - **`metrics-server/`**: Kubernetes metrics
  - **`cert-manager/`**: TLS certificate management
  - **`networking/`**: CNI (Cilium) and network policies
  - **`ingress/traefik/`**: Ingress controller
- **`security/`**: Security services
  - **`falco/`**: Runtime security (Helm chart)
  - **`kyverno/`**: Policy engine
  - **`sealed-secrets/`**: Secret management
- **`apps/platform/`**: Application workloads
  - **`adguard/`**: DNS filtering
  - **`cloudflare-tunnel/`**: External access
- **`environments/homelab/`**: Environment-specific ArgoCD Applications
  - **`base.yaml`**: Base services application
  - **`security.yaml`**: Security services application
  - **`apps.yaml`**: Application workloads application
- **`root-app.yaml`**: ArgoCD root application (app-of-apps pattern)

## Network Architecture

### Hardware Infrastructure

- **Router**: TP-Link ER605 (VLAN Controller, Firewall, Gateway)
- **NAS**: Synology DS720+ (VM Host & Management Server - 10.0.1.100)
- **WiFi**: Netgear Orbi RBR350 + RBS350 (Isolated AP Mode - 10.0.10.100/101)
- **Admin PC**: Management Workstation (10.0.1.105)

### VLANs

| VLAN | Name | Subnet | Isolation | Purpose |
|------|------|--------|-----------|---------|
| **1** | Management | 10.0.1.0/24 | **DEISOLATED** (Admin) | Admin/operational, VM host |
| **10** | Trusted_WiFi | 10.0.10.0/24 | **ISOLATED** (IoT) | WiFi devices, Orbi mesh |
| **2** | Trusted_LAN | 10.0.2.0/24 | **ISOLATED** | Future wired devices |
| **20** | DMZ | 10.0.20.0/24 | **ISOLATED** | Exposed services, Traefik |
| **99** | Guest | 10.0.99.0/24 | **ISOLATED** | Guest WiFi, Internet only |

**Isolation Model**:
- **DEISOLATED (Management)**: Full bidirectional access to all VLANs
- **ISOLATED (All Others)**: Internet access only, blocked from inter-VLAN communication

See [NETWORK_ARCHITECTURE.md](./NETWORK_ARCHITECTURE.md) for comprehensive network documentation.

### Network Documentation

- **[Network Architecture Guide](./NETWORK_ARCHITECTURE.md)** - Comprehensive network design reference
- **[Network Quick Reference](./NETWORK_QUICK_REFERENCE.md)** - One-page cheat sheet for VLANs, IPs, and ports
- **[Network Troubleshooting](./NETWORK_TROUBLESHOOTING.md)** - Systematic troubleshooting procedures
- **[ER605 VLAN Config](../infra/network/ER605_VLAN_CONFIG.md)** - Router port mappings and VLAN setup
- **[Firewall Rules](../infra/network/FIREWALL_RULES.md)** - Complete ACL and security policies
- **[WiFi Configuration](../infra/network/WIFI_CONFIG.md)** - Orbi mesh setup and multi-SSID config

### Visual Diagrams

- [VLAN Topology Diagram](./diagrams/vlan_topology.png) - VLAN segmentation and trust zones
- [Physical Topology Diagram](./diagrams/physical_topology.png) - Hardware connections and port mappings
- [Traffic Flow Diagram](./diagrams/traffic_flow.png) - Inter-VLAN routing and firewall enforcement

### Key Components

- **k3s-master-01**: 10.0.1.108
- **k3s-worker-01 (VM2)**: 10.0.1.109
- **Synology NAS**: 10.0.1.100
- **AdGuard Home**: 10.0.1.53 (via k3s)

### Domains

- **Internal**: `home.internal` - LAN-only services
- **Public**: `connect2home.online` - Internet-facing services via Cloudflare Tunnel

## Deployment Flow

1. **Infrastructure Provisioning** (Ansible/Terraform)
   - VM bootstrap and hardening
   - k3s installation
   - Cloudflare DNS/tunnels

2. **ArgoCD Bootstrap** (Manual, one-time)
   - Install ArgoCD to k3s cluster

3. **Application Deployment** (GitOps)
   - ArgoCD root app watches `k8s/environments/homelab/`
   - Creates three child applications: base, security, apps
   - Each application manages its respective directory
   - Automatically syncs all applications
   - Self-healing and auto-pruning enabled

## Security Model

- Network policies: Default-deny with explicit allow rules
- Secrets: Encrypted with Ansible Vault (infra) and Sealed Secrets (k8s)
- Access control: VLAN segmentation and firewall rules
- Runtime security: Falco for threat detection

