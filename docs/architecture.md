# Architecture

## Overview

This homelab infrastructure follows a GitOps approach with clear separation between infrastructure provisioning and application deployment.

## Structure

### Infrastructure Layer (`infra/`)

Everything that runs **outside** Kubernetes or touches VMs/OS:

- **`terraform/`**: Cloud resources (Cloudflare DNS, tunnels, WAF)
- **`ansible/`**: VM provisioning, OS hardening, k3s installation
- **`docker/`**: Docker Compose stacks on VM2 (monitoring, security, services)
- **`contracts/`**: Network/DNS/IPAM contracts (source of truth)
- **`network/`**: Network configuration generation scripts
- **`dns/`**: DNS configuration generation scripts

### Kubernetes Layer (`k8s/`)

Everything that ArgoCD deploys:

- **`bootstrap/`**: One-time manual installation (ArgoCD itself)
- **`apps/`**: All applications managed by ArgoCD
  - **`security/`**: Security tools (Falco, Kyverno)
  - **`platform/`**: Platform services (Traefik, AdGuard, cert-manager, etc.)
- **`root-app.yaml`**: ArgoCD "app of apps" pattern entry point

## Network Architecture

### VLANs

- **VLAN 1 (Management)**: 10.0.1.0/24 - Admin/operational
- **VLAN 2 (Trusted LAN)**: 10.0.2.0/24 - Personal devices
- **VLAN 10 (IoT)**: 10.0.10.0/24 - Untrusted IoT devices
- **VLAN 20 (DMZ)**: 10.0.20.0/24 - Exposed services
- **VLAN 99 (Guest)**: 10.0.99.0/24 - Guest network

### Key Components

- **k3s-master**: 10.0.1.100
- **security-ops (VM2)**: 10.0.1.105
- **Synology NAS**: 10.0.1.50
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
   - ArgoCD watches `k8s/apps/`
   - Automatically syncs all applications
   - Self-healing and auto-pruning enabled

## Security Model

- Network policies: Default-deny with explicit allow rules
- Secrets: Encrypted with Ansible Vault (infra) and Sealed Secrets (k8s)
- Access control: VLAN segmentation and firewall rules
- Runtime security: Falco for threat detection

