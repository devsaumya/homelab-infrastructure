# Homelab Infrastructure - Master Documentation

Complete reference guide for the homelab infrastructure setup, deployment, and operations.

**Last Updated:** 2024  
**Version:** 1.0

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Hardware Setup](#hardware-setup)
4. [Network Configuration](#network-configuration)
5. [DNS and Domain Model](#dns-and-domain-model)
6. [Initial Setup](#initial-setup)
7. [Deployment Guide](#deployment-guide)
8. [Services and Components](#services-and-components)
9. [Configuration](#configuration)
10. [Operations and Maintenance](#operations-and-maintenance)
11. [Troubleshooting](#troubleshooting)
12. [Project Structure](#project-structure)

---

## Overview

This repository contains Infrastructure as Code (IaC) for managing a homelab infrastructure with:

- **Terraform** for Cloudflare/DNS and external integrations (cloud resources only)
- **Ansible** for VM configuration and OS-level setup
- **Kubernetes (k3s)** for container orchestration
- **Docker Compose** for VM2 services (monitoring, security, utilities)
- **Manual configuration** for ER605 router and Synology NAS (via web UI)

---

## Architecture

### Network Topology

```
Internet (ISP)
    |
TP-Link ER605 (WAN/Firewall edge)
    |
Managed Switch (VLAN trunk)
    |
    +-- VLAN 1 (Management) - 10.0.1.0/24
    |   +-- k3s-master (10.0.1.100)
    |   +-- Synology NAS (10.0.1.50)
    |   +-- AdGuard Home (10.0.1.53)
    |
    +-- VLAN 2 (Trusted LAN) - 10.0.2.0/24
    |   +-- Personal devices
    |
    +-- VLAN 10 (IoT) - 10.0.10.0/24
    |   +-- Smart home devices
    |
    +-- VLAN 20 (DMZ) - 10.0.20.0/24
    |   +-- Exposed services
    |
    +-- VLAN 99 (Guest) - 10.0.99.0/24
        +-- Guest Wi-Fi
```

### Key Components

#### Network & Security
- **TP-Link ER605**: Edge router with VLAN support
- **Network Policies**: Kubernetes NetworkPolicy for pod-level isolation
- **Cilium**: CNI with network policy enforcement (optional)

#### Compute & Storage
- **k3s Cluster**: Lightweight Kubernetes distribution
- **Synology NAS**: Centralized storage (NFS/SMB shares for k3s persistent volumes)

#### Kubernetes Services
- **AdGuard Home**: DNS blocking and filtering, serves `home.internal` DNS records
- **Traefik**: Reverse proxy and ingress controller
- **cert-manager**: Automated TLS certificate management
- **Cloudflare Tunnel**: Secure external access for `connect2home.online` services

#### Monitoring & Observability
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Dashboards and visualization
- **Loki**: Log aggregation
- **AlertManager**: Alert routing and notification
- **Promtail**: Log shipper

#### Security Tools
- **Trivy**: Container image scanning
- **Falco**: Runtime security monitoring (optional)
- **Kyverno**: Kubernetes policy engine (optional)
- **fail2ban**: Intrusion prevention

---

## Hardware Setup

See [HARDWARE_SETUP.md](./HARDWARE_SETUP.md) for detailed hardware configuration.

### Quick Hardware Reference

- **k3s-master**: 2 CPU, 4GB RAM, 40GB disk
- **security-ops (VM2)**: 2 CPU, 4GB RAM, 40GB disk
- **Synology NAS**: Existing storage device
- **TP-Link ER605**: Router with VLAN support
- **Managed Switch**: VLAN trunk support

---

## Network Configuration

### VLANs

- **VLAN 1 (Management)**: 10.0.1.0/24 - Admin/operational
- **VLAN 2 (Trusted LAN)**: 10.0.2.0/24 - Personal devices
- **VLAN 10 (IoT)**: 10.0.10.0/24 - Untrusted IoT devices
- **VLAN 20 (DMZ)**: 10.0.20.0/24 - Exposed services
- **VLAN 99 (Guest)**: 10.0.99.0/24 - Guest network

### Key IPs

- k3s-master: 10.0.1.100
- security-ops (VM2): 10.0.1.105
- Synology NAS: 10.0.1.50
- AdGuard Home: 10.0.1.53 (via k3s)
- Traefik: 10.0.1.100 (via k3s)

### Firewall Rules

#### Key Rules
1. **Management → Internet**: Allow HTTP/HTTPS/DNS
2. **Trusted LAN → Internet**: Full access
3. **IoT → Internet**: HTTP/HTTPS/DNS only
4. **IoT → Management/Trusted**: Deny all
5. **DMZ → Management**: Allow k3s API (6443)
6. **Internet → DMZ**: Allow HTTP/HTTPS (80/443)
7. **Guest → Internal**: Deny all

#### SMB Rules
- **Management → Synology**: Allow SMB3 (TCP 445) with encryption
- **Trusted LAN → Synology**: Allow SMB3 (read-only)
- **IoT → Synology**: Deny all

---

## DNS and Domain Model

### Dual-Domain Architecture

The infrastructure uses a dual-domain model to separate internal (LAN-only) and public (internet-facing) services:

#### Internal Domain: `home.internal`
- Served by AdGuard Home DNS on LAN
- Used for services accessible only from local network
- Examples:
  - `nas.home.internal` → 10.0.1.50
  - `k3s.home.internal` → 10.0.1.100
  - `portainer.home.internal` → 10.0.1.100 (via Traefik)
  - `adguard.home.internal` → 10.0.1.53

#### Public Domain: `connect2home.online`
- Managed by Cloudflare DNS
- Used for services exposed to the internet via Cloudflare Tunnel
- Examples:
  - `grafana.connect2home.online` → Monitoring dashboard
  - `vault.connect2home.online` → Password manager
  - `home.connect2home.online` → Traefik dashboard (with Zero Trust protection)

### DNS Flow

1. **Internal Queries**: Clients query AdGuard Home (10.0.1.53) for `*.home.internal` records
2. **External Queries**: Clients query AdGuard Home, which forwards to upstream DNS (Cloudflare/Google) for public domains
3. **Cloudflare Tunnel**: Routes `*.connect2home.online` traffic to Traefik ingress controller in k3s cluster
4. **ExternalDNS**: Automatically creates DNS records in Cloudflare for Kubernetes Ingress resources with `*.connect2home.online` hostnames

### AdGuard Home DNS Configuration

1. Access AdGuard Home admin interface: `http://10.0.1.53:3000` (initially via port-forward)
2. Configure DHCP settings on router to use AdGuard Home as primary DNS: `10.0.1.53`
3. Add DNS rewrites in AdGuard Home:
   - Navigate to **Settings → DNS settings → DNS rewrites**
   - Add A records:
     ```
     nas.home.internal          → 10.0.1.50
     k3s.home.internal          → 10.0.1.100
     adguard.home.internal      → 10.0.1.53
     traefik.home.internal      → 10.0.1.100
     ```
4. Configure upstream DNS servers: `1.1.1.1`, `8.8.8.8`

---

## Initial Setup

### Prerequisites

#### Software Requirements

Install the following tools on your local machine:

```bash
# Check if tools are installed
terraform --version    # Should be >= 1.5.0
ansible --version      # Should be >= 2.9
kubectl version --client
docker --version
git --version
```

**Installation guides:**
- **Terraform**: https://developer.hashicorp.com/terraform/downloads
- **Ansible**: `pip install ansible` or use package manager
- **kubectl**: https://kubernetes.io/docs/tasks/tools/
- **Docker**: https://docs.docker.com/get-docker/

#### Network Information

Gather the following information:
- IP addresses of your VMs (k3s-master, security-ops)
- SSH credentials for VMs (username, password or SSH key)
- Cloudflare account credentials (API token, Zone ID, Account ID)
- Domain configuration (internal: `home.internal`, public: `connect2home.online`)

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd homelab-infrastructure
```

### Step 2: Configure Ansible Inventory

Edit `infra/ansible/inventory/hosts.yml`:

```yaml
k3s-master:
  ansible_host: 10.0.1.100  # Your k3s master IP
  ansible_user: admin

security-ops:
  ansible_host: 10.0.1.105  # Your VM2 IP
  ansible_user: admin
```

### Step 3: Create Ansible Vault

```bash
cd ansible
ansible-vault create inventory/group_vars/all/vault.yml
```

Add the following variables:

```yaml
vault_k3s_token: "your-secure-random-token-here"  # Generate with: openssl rand -hex 32
vault_cloudflare_api_token: "your-cloudflare-api-token"
vault_cloudflare_zone_id: "your-cloudflare-zone-id"
vault_cloudflare_account_id: "your-cloudflare-account-id"
vault_grafana_admin_password: "your-secure-grafana-password"
```

**Important:** Remember the vault password - you'll need it for every Ansible playbook run.

### Step 4: Configure Terraform

```bash
cd terraform/environments/production
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
cloudflare_api_token = "your-cloudflare-api-token-here"
cloudflare_zone_id   = "your-zone-id-here"
cloudflare_account_id = "your-account-id-here"

# Domain configuration
internal_domain = "home.internal"  # Internal DNS zone for LAN-only services
public_domain   = "connect2home.online"  # Public domain for internet-facing services

# Services that should be exposed publicly via Cloudflare Tunnel
public_services = [
  "grafana",
  "home"  # Traefik dashboard
]
```

---

## Deployment Guide

### Deployment Order

1. Configure ER605 (WAN, VLANs, DHCP, firewall) and Synology/VMs manually using the router/NAS UI
2. Bootstrap VMs with Ansible (base OS hardening, packages, Docker, k3s)
3. Provision external infra with Terraform (Cloudflare DNS, Cloudflare Tunnel, WAF/Zero Trust)
4. Apply Kubernetes base + overlays to k3s
5. Bring up Docker stacks on VM2 (monitoring, services, security)

### Phase 0: Network Setup (Manual)

Before deploying infrastructure, manually configure your TP-Link ER605 router:

1. **Access ER605 Web UI** (typically http://192.168.0.1)
2. **Configure WAN** connection
3. **Set up VLANs**:
   - VLAN 1 (Management): 10.0.1.0/24
   - VLAN 2 (Trusted LAN): 10.0.2.0/24
   - VLAN 10 (IoT): 10.0.10.0/24
   - VLAN 20 (DMZ): 10.0.20.0/24
   - VLAN 99 (Guest): 10.0.99.0/24
4. **Configure DHCP** for each VLAN
5. **Set up firewall rules** for inter-VLAN communication
6. **Configure Synology NAS** (if applicable):
   - Network settings
   - Shared folders
   - NFS/SMB services

**Note:** ER605 and Synology configuration is manual and not managed by Terraform.

### Phase 1: Bootstrap VMs

```bash
# Run prerequisites check
./scripts/setup/00-prereqs.sh

# Bootstrap all VMs
./scripts/setup/02-vm-bootstrap.sh
```

This will:
- Update system packages
- Configure timezone
- Disable swap
- Install base packages
- Configure kernel parameters

### Phase 2: Install k3s

```bash
# Install k3s control plane
ansible-playbook -i infra/ansible/inventory/hosts.yml \
  infra/ansible/playbooks/01-k3s-install.yml \
  --ask-vault-pass

# Verify installation
ssh admin@10.0.1.100
sudo systemctl status k3s

# Get kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml
```

Configure kubectl locally:

```bash
mkdir -p ~/.kube
# Copy kubeconfig content to ~/.kube/config
# Update server URL from 127.0.0.1 to 10.0.1.100:6443

# Test connection
kubectl get nodes
```

### Phase 3: Deploy Kubernetes Services

```bash
# Deploy namespaces
kubectl apply -f kubernetes/base/namespaces/

# Deploy network policies
kubectl apply -f kubernetes/base/network-policies/

# Deploy AdGuard Home
kubectl apply -k kubernetes/base/adguard/
kubectl wait --for=condition=ready pod -l app=adguard-home -n dns-system --timeout=300s

# Deploy Traefik
kubectl apply -k kubernetes/base/traefik/

# Deploy cert-manager
kubectl apply -k kubernetes/base/cert-manager/

# Deploy Cloudflare Tunnel
kubectl apply -k kubernetes/base/cloudflare-tunnel/
```

### Phase 4: Configure DNS

1. **Update router/DHCP settings**:
   - Primary DNS: `10.0.1.53` (AdGuard Home)
   - Secondary DNS: `1.1.1.1` (Cloudflare fallback)

2. **Configure AdGuard Home**:
   ```bash
   kubectl port-forward -n dns-system svc/adguard-home 3000:3000
   ```
   - Open browser: http://localhost:3000
   - Complete initial setup wizard
   - Add DNS rewrites for `*.home.internal` records
   - Configure upstream DNS servers

### Phase 5: Deploy Monitoring Stack

```bash
# Prepare VM2
ansible-playbook -i infra/ansible/inventory/hosts.yml \
  infra/ansible/playbooks/02-monitoring.yml \
  --ask-vault-pass

# Deploy Docker Compose stack (on VM2)
ssh admin@10.0.1.105
cd /opt/docker/monitoring
docker compose up -d
```

Access services:
- Grafana: http://10.0.1.105:3000 (default: admin/admin)
- Prometheus: http://10.0.1.105:9090
- Loki: http://10.0.1.105:3100

### Phase 6: Configure Cloudflare

```bash
cd terraform/environments/production
terraform init
terraform plan
terraform apply
```

This will:
- Create Cloudflare Tunnel
- Configure DNS records (if using ExternalDNS)
- Set up tunnel routes

### Phase 7: Deploy Security Tools

```bash
# Run security playbook
ansible-playbook -i infra/ansible/inventory/hosts.yml \
  infra/ansible/playbooks/03-security.yml \
  --ask-vault-pass

# Deploy Trivy (on VM2)
ssh admin@10.0.1.105
cd /opt/docker/security
docker compose up -d
```

---

## Services and Components

### Kubernetes Services (k3s)

#### AdGuard Home
- **Purpose**: DNS blocking and filtering, serves `home.internal` DNS records
- **Namespace**: `dns-system`
- **Access**: `https://adguard.home.internal:3000` (after DNS config) or `http://10.0.1.53:3000`

#### Traefik
- **Purpose**: Reverse proxy and ingress controller
- **Namespace**: `ingress-traefik`
- **Access**: `https://traefik.home.internal` or `https://home.connect2home.online`

#### cert-manager
- **Purpose**: Automated TLS certificate management
- **Namespace**: `cert-manager`

#### Cloudflare Tunnel
- **Purpose**: Secure external access for `connect2home.online` services
- **Namespace**: `cloudflare-tunnel`

### Docker Services (VM2)

#### Prometheus
- **Purpose**: Metrics collection
- **Access**: http://10.0.1.105:9090

#### Grafana
- **Purpose**: Dashboards and visualization
- **Access**: http://10.0.1.105:3000 (internal) or https://grafana.connect2home.online (public)

#### Loki
- **Purpose**: Log aggregation
- **Access**: http://10.0.1.105:3100

#### AlertManager
- **Purpose**: Alert routing and notification

#### Trivy
- **Purpose**: Container image scanning
- **Access**: http://10.0.1.105:4954

#### Portainer
- **Purpose**: Docker management
- **Access**: `https://portainer.home.internal` (internal only)

#### Vaultwarden
- **Purpose**: Password manager
- **Access**: `https://vault.home.internal` or `https://vault.connect2home.online`

---

## Configuration

### Terraform Variables

Key variables in `infra/terraform/environments/production/terraform.tfvars`:

```hcl
internal_domain = "home.internal"
public_domain   = "connect2home.online"
public_services = ["grafana", "home"]
```

### Ansible Variables

Key variables in `infra/ansible/inventory/group_vars/all/vault.yml`:

```yaml
vault_k3s_token: "..."
vault_cloudflare_api_token: "..."
vault_grafana_admin_password: "..."
```

### Kubernetes Ingress Examples

#### Internal Service (home.internal)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: portainer-internal
  namespace: portainer
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  rules:
  - host: portainer.home.internal
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: portainer
            port:
              number: 9443
```

#### Public Service (connect2home.online)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-public
  namespace: monitoring
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls.certresolver: letsencrypt
    external-dns.alpha.kubernetes.io/hostname: grafana.connect2home.online
spec:
  rules:
  - host: grafana.connect2home.online
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
  tls:
  - hosts:
    - grafana.connect2home.online
    secretName: grafana-tls
```

---

## Operations and Maintenance

### Health Checks

```bash
# Run automated health check
./scripts/maintenance/health-check.sh

# Manual checks
kubectl get nodes
kubectl get pods --all-namespaces
docker ps  # On VM2
```

### Updates

```bash
# Update all services
./scripts/maintenance/update-all.sh

# Update Kubernetes manifests
kubectl apply -k kubernetes/base/

# Update Docker Compose services (on VM2)
ssh admin@10.0.1.105
cd /opt/docker/monitoring
docker compose pull
docker compose up -d
```

### Cleanup

```bash
# Run cleanup script
./scripts/maintenance/cleanup.sh

# Remove Kubernetes resources
kubectl delete -f kubernetes/base/

# Stop Docker services (on VM2)
ssh admin@10.0.1.105
docker compose down
```

### Backup Strategy

#### VM Snapshots
- Daily snapshots of critical VMs
- Retention: 7 days daily, 4 weeks weekly

#### Synology Backups
- HyperBackup to cloud storage (Backblaze B2)
- Daily incremental backups
- Monthly full backups

#### IaC State
- Terraform state in remote backend (S3)
- Git repository for all manifests
- Regular exports of k3s cluster config

### Monitoring and Alerting

#### Key Metrics
- Node CPU/Memory/Disk usage
- Pod restart counts
- DNS query rates
- Network traffic patterns
- Certificate expiration

#### Alert Channels
- Email (via SMTP)
- Webhook (for integrations)
- Grafana notifications

---

## Troubleshooting

### k3s Installation Issues

```bash
# Check k3s logs
ssh admin@10.0.1.100
sudo journalctl -u k3s -f

# Restart k3s
sudo systemctl restart k3s
```

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Network Connectivity

```bash
# Test DNS resolution
nslookup google.com 10.0.1.53
nslookup nas.home.internal 10.0.1.53

# Test service connectivity
curl http://10.0.1.53:3000
```

### DNS Not Resolving

- Verify AdGuard Home is running: `kubectl get pods -n dns-system`
- Check DNS rewrite exists in AdGuard Home UI
- Verify client is using AdGuard Home as DNS server
- Check AdGuard Home logs in admin UI

### Service Not Accessible

- Verify service is running: `kubectl get pods -n <namespace>`
- Check Ingress configuration: `kubectl get ingress -n <namespace>`
- Verify Traefik routing: Check Traefik dashboard
- Review service logs for errors
- Check network policies: `kubectl get networkpolicies -n <namespace>`

### Common Commands

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes -o wide

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Network policies
kubectl get networkpolicies --all-namespaces

# Services
kubectl get svc --all-namespaces

# View logs
kubectl logs --all-namespaces --tail=100

# Docker logs (on VM2)
docker compose -f /opt/docker/monitoring/docker-compose.yml logs --tail=100
```

---

## Project Structure

```
homelab-infrastructure/
├── terraform/          # Terraform for Cloudflare, DNS, external infra
│   ├── main.tf
│   ├── variables.tf
│   ├── modules/
│   │   ├── cloudflare/
│   │   └── monitoring/
│   └── environments/
│       ├── production/
│       └── staging/
├── ansible/            # VM provisioning & configuration
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── hosts.yml
│   │   └── group_vars/
│   ├── playbooks/
│   └── roles/
├── kubernetes/          # Manifests for k3s cluster
│   ├── base/
│   │   ├── adguard/
│   │   ├── traefik/
│   │   ├── cert-manager/
│   │   ├── cloudflare-tunnel/
│   │   ├── network-policies/
│   │   └── namespaces/
│   └── overlays/
│       ├── production/
│       └── staging/
├── docker/              # Docker Compose stacks on VM2
│   ├── monitoring/
│   ├── security/
│   └── services/
├── scripts/             # Helper scripts
│   ├── setup/
│   ├── deployment/
│   └── maintenance/
└── docs/                # Documentation
    ├── MASTER.md        # This file
    └── HARDWARE_SETUP.md
```

### Conventions

#### Terraform
- Terraform ≥ 1.5, always run `terraform fmt -recursive`
- Only cloud/remote resources are managed: Cloudflare DNS, Cloudflare Tunnel, Zero Trust/WAF
- Home hardware (ER605, Synology, VMs, VLANs) is configured via UI + Ansible, not Terraform
- Secrets only via `*.tfvars` or env vars, never hardcoded

#### Ansible
- Everything non-trivial goes into roles; playbooks are thin
- Secrets live in `group_vars/all/vault.yml` (Ansible Vault)
- `common` handles timezone, swap off, base packages

#### Kubernetes
- Kustomize for base + overlays
- Every app: `deployment.yaml`, `service.yaml`, `pvc.yaml` (if stateful), `kustomization.yaml`
- Default-deny NetworkPolicy plus explicit allow policies

---

## Quick Reference

### Service URLs

#### Internal Services (home.internal - LAN only)
- **AdGuard Home**: https://adguard.home.internal:3000 or http://10.0.1.53:3000
- **Traefik Dashboard**: https://traefik.home.internal or http://10.0.1.100:9000
- **NAS**: https://nas.home.internal

#### Public Services (connect2home.online - Internet accessible)
- **Grafana**: https://grafana.connect2home.online
- **Traefik Dashboard**: https://home.connect2home.online
- **Prometheus**: http://10.0.1.105:9090 (internal access only)

#### Direct IP Access (during setup)
- **Grafana**: http://10.0.1.105:3000
- **Prometheus**: http://10.0.1.105:9090
- **AdGuard Home**: http://10.0.1.53:3000

### Important Files

- **Ansible inventory**: `infra/ansible/inventory/hosts.yml`
- **Ansible vault**: `infra/ansible/inventory/group_vars/all/vault.yml`
- **Terraform vars**: `infra/terraform/environments/production/terraform.tfvars`
- **Kubernetes apps**: `k8s/apps/` (managed by ArgoCD)
- **Docker Compose**: `infra/docker/monitoring/docker-compose.yml`

---

## Security

- All secrets are encrypted with Ansible Vault
- Network policies enforce default-deny
- SMB encryption and signing required
- Firewall rules restrict inter-VLAN communication
- TLS certificates via Let's Encrypt
- Network segmentation with strict VLAN isolation
- Default deny policies with explicit allow rules
- Regular security updates and patches

---

**For detailed hardware setup instructions, see [HARDWARE_SETUP.md](./HARDWARE_SETUP.md)**

