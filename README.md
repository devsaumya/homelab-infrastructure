# Homelab Infrastructure as Code

Enterprise-grade home server network infrastructure managed with Infrastructure as Code (IaC) principles.

## Overview

This repository contains all Infrastructure as Code (IaC) for managing a homelab infrastructure with:

- **Terraform** for Cloudflare/DNS and external integrations (cloud resources only)
- **Ansible** for VM configuration and OS-level setup
- **Kubernetes (k3s)** for container orchestration
- **Docker Compose** for VM2 services (monitoring, security, utilities)
- **Manual configuration** for ER605 router and Synology NAS (via web UI)

## Architecture

The infrastructure consists of:

- **Network & Security**: VLAN segmentation, firewall rules, network policies
- **Compute & Storage**: k3s cluster, Synology NAS integration
- **Kubernetes**: k3s cluster with AdGuard Home, Traefik, cert-manager
- **Monitoring & Observability**: Prometheus, Grafana, Loki, AlertManager

See [Master Documentation](docs/MASTER.md) for complete structure and conventions.

## Directory Map

Quick reference for top-level directories:

| Directory | Purpose |
|-----------|---------|
| `infra/` | Provisioning (Ansible, Terraform) |
| `k8s/` | GitOps (ArgoCD managed) |
| `docker/` | Host-level services |
| `scripts/` | Orchestration & utilities |
| `docs/` | Architecture & ops |

## Quick Start

### Prerequisites

1. Install required tools:
   - Terraform >= 1.5.0
   - Ansible >= 2.9
   - kubectl
   - Docker
   - Git

2. Run prerequisites check:
   ```bash
   ./scripts/setup/00-prereqs.sh
   ```

### Initial Setup

1. **Configure Ansible inventory**:
   - Edit `infra/ansible/inventory/hosts.yml` with your VM IPs
   - Encrypt secrets: `ansible-vault encrypt infra/ansible/inventory/group_vars/all/vault.yml`

2. **Configure Terraform**:
   - Copy `infra/terraform/environments/production/terraform.tfvars.example` to `terraform.tfvars`
   - Fill in your Cloudflare credentials

3. **Setup SSH keys** (if not already configured):
   ```bash
   ./scripts/setup/03-setup-ssh-keys.sh
   ```
   Or manually:
   ```bash
   ssh-copy-id -i ~/.ssh/id_rsa.pub homelab@10.0.1.108
   ssh-copy-id -i ~/.ssh/id_rsa.pub homelab@10.0.1.109
   ```

4. **Bootstrap VMs**:
   ```bash
   ./scripts/setup/02-vm-bootstrap.sh
   ```

5. **Install ArgoCD** (one-time manual step):
   ```bash
   kubectl apply -f k8s/bootstrap/argocd/install.yaml
   ```

6. **Deploy root application** (ArgoCD will manage everything):
   ```bash
   kubectl apply -f k8s/root-app.yaml
   ```

## Project Structure

```
homelab-infrastructure/
├── infra/                    # Infrastructure as Code
│   ├── terraform/            # Cloud / DNS / tunnels only
│   ├── ansible/              # VM provisioning + k3s install
│   ├── contracts/            # Source of truth (IPAM, VLANs, DNS zones)
│   ├── network/              # Network config generation
│   └── dns/                  # DNS config generation
├── k8s/                      # Kubernetes manifests (GitOps)
│   ├── bootstrap/            # Installed ONCE manually (ArgoCD)
│   │   └── argocd/           # ArgoCD installation manifests
│   ├── base/                 # Core infrastructure services
│   │   ├── namespaces/       # Namespace definitions
│   │   ├── metrics-server/   # Kubernetes metrics
│   │   ├── cert-manager/     # TLS certificate management
│   │   ├── networking/       # CNI and network policies
│   │   │   ├── cilium/       # Cilium CNI
│   │   │   └── network-policies/  # Network policies
│   │   └── ingress/          # Ingress controller
│   │       └── traefik/      # Traefik ingress
│   ├── security/             # Security services
│   │   ├── falco/            # Runtime security (Helm)
│   │   ├── kyverno/          # Policy engine
│   │   └── sealed-secrets/   # Secret management
│   ├── apps/                 # Application workloads
│   │   └── platform/         # Platform services
│   │       ├── adguard/      # DNS filtering
│   │       └── cloudflare-tunnel/  # External access
│   ├── environments/        # Environment-specific configs
│   │   └── homelab/          # Homelab environment
│   │       ├── base.yaml     # Base services app
│   │       ├── security.yaml # Security services app
│   │       └── apps.yaml     # Application workloads app
│   └── root-app.yaml         # ArgoCD root application
├── docker/                   # Docker Compose stacks (VM2)
│   ├── monitoring/           # Monitoring stack
│   ├── security/             # Security tools
│   └── services/             # Utility services
├── scripts/                  # Helper scripts only
├── docs/                     # Documentation
└── .github/workflows/        # CI/CD workflows
    ├── validate-k8s.yml      # K8s manifest validation
    ├── validate-contracts.yml # Contract validation
    └── terraform-plan.yml     # Terraform plan
```

## Deployment Order

1. Configure ER605 (WAN, VLANs, DHCP, firewall) and Synology/VMs manually using the router/NAS UI
2. Bootstrap VMs with Ansible (base OS hardening, packages, Docker, k3s)
3. Provision external infra with Terraform (Cloudflare DNS, Cloudflare Tunnel, WAF/Zero Trust)
4. Install ArgoCD manually (one-time): `kubectl apply -f k8s/bootstrap/argocd-install.yaml`
5. Deploy root application: `kubectl apply -f k8s/root-app.yaml` (ArgoCD will manage all apps)
6. Bring up Docker stacks on VM2 (monitoring, services, security) via Ansible

## Network Configuration

### VLANs

- **VLAN 1 (Management)**: 10.0.1.0/24 - Admin/operational
- **VLAN 2 (Trusted LAN)**: 10.0.2.0/24 - Personal devices
- **VLAN 10 (IoT)**: 10.0.10.0/24 - Untrusted IoT devices
- **VLAN 20 (DMZ)**: 10.0.20.0/24 - Exposed services
- **VLAN 99 (Guest)**: 10.0.99.0/24 - Guest network

### Key IPs

- k3s-master: 10.0.1.108
- security-ops (VM2): 10.0.1.109
- Synology NAS: 10.0.1.50
- AdGuard Home: 10.0.1.53 (via k3s)

### Domains

- **Internal**: `home.internal` - LAN-only services (e.g., `nas.home.internal`, `k3s.home.internal`)
- **Public**: `connect2home.online` - Internet-facing services via Cloudflare Tunnel (e.g., `grafana.connect2home.online`)

## Services

### Kubernetes (k3s)

- **AdGuard Home**: DNS blocking and filtering, serves `home.internal` DNS records
- **Traefik**: Reverse proxy and ingress controller
- **cert-manager**: Automated TLS certificate management
- **Cloudflare Tunnel**: Secure external access for `connect2home.online` services

### Docker (VM2)

- **Prometheus**: Metrics collection
- **Grafana**: Dashboards and visualization
- **Loki**: Log aggregation
- **AlertManager**: Alert routing
- **Trivy**: Security scanning
- **Portainer**: Docker management
- **Vaultwarden**: Password manager

## Maintenance

### Health Check
```bash
./scripts/maintenance/health-check.sh
```

### Update All
```bash
./scripts/maintenance/update-all.sh
```

### Cleanup
```bash
./scripts/maintenance/cleanup.sh
```

## Documentation

- **[Master Documentation](docs/MASTER.md)** - Complete reference guide ⭐ **START HERE**
- **[Hardware Setup Guide](docs/HARDWARE_SETUP.md)** - Hardware configuration instructions
- **[Next Steps](docs/NEXT_STEPS.md)** - Production hardening & maturity roadmap

## Security

- All secrets are encrypted with Ansible Vault
- Network policies enforce default-deny
- SMB encryption and signing required
- Firewall rules restrict inter-VLAN communication
- TLS certificates via Let's Encrypt

## Contributing

1. Follow the conventions in [Master Documentation](docs/MASTER.md)
2. Always run `terraform fmt -recursive` before committing
3. Test changes in staging environment first
4. Update documentation for any structural changes

## License

MIT

