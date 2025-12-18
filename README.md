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

See [IAC_CODE.md](IAC_CODE.md) for the complete structure and conventions.

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
   - Edit `ansible/inventory/hosts.yml` with your VM IPs
   - Encrypt secrets: `ansible-vault encrypt ansible/inventory/group_vars/all/vault.yml`

2. **Configure Terraform**:
   - Copy `terraform/environments/production/terraform.tfvars.example` to `terraform.tfvars`
   - Fill in your Cloudflare credentials

3. **Bootstrap VMs**:
   ```bash
   ./scripts/setup/02-vm-bootstrap.sh
   ```

4. **Deploy infrastructure**:
   ```bash
   ./scripts/deployment/deploy-all.sh
   ```

## Project Structure

```
homelab-infrastructure/
├── terraform/          # Terraform for Cloudflare, DNS, external infra
├── ansible/            # VM provisioning & configuration
├── kubernetes/          # Manifests for k3s cluster
├── docker/              # Docker Compose stacks on VM2
├── scripts/             # Helper scripts to glue IaC together
└── docs/                # Documentation
```

## Deployment Order

1. Configure ER605 (WAN, VLANs, DHCP, firewall) and Synology/VMs manually using the router/NAS UI
2. Bootstrap VMs with Ansible (base OS hardening, packages, Docker, k3s)
3. Provision external infra with Terraform (Cloudflare DNS, Cloudflare Tunnel, WAF/Zero Trust)
4. Apply Kubernetes base + overlays to k3s
5. Bring up Docker stacks on VM2 (monitoring, services, security)

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

## Services

### Kubernetes (k3s)

- **AdGuard Home**: DNS blocking and filtering
- **Traefik**: Reverse proxy and ingress controller
- **cert-manager**: TLS certificate management
- **Cloudflare Tunnel**: Secure external access

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

## Security

- All secrets are encrypted with Ansible Vault
- Network policies enforce default-deny
- SMB encryption and signing required
- Firewall rules restrict inter-VLAN communication
- TLS certificates via Let's Encrypt

## Documentation

- **[How to Use This Project](docs/HOW_TO_USE.md)** - Complete step-by-step guide ⭐ **START HERE**
- **[Quick Start Guide](docs/QUICK_START.md)** - Get running in 15 minutes
- **[Deployment Checklist](docs/DEPLOYMENT_CHECKLIST.md)** - Track your deployment progress
- [IAC_CODE.md](docs/IAC_CODE.md) - Complete IaC structure and conventions
- [Architecture Document](docs/architecture.md) - Detailed architecture design
- [Deployment Guide](docs/DEPLOYMENT.md) - Detailed deployment instructions

## Contributing

1. Follow the conventions in [IAC_CODE.md](IAC_CODE.md)
2. Always run `terraform fmt -recursive` before committing
3. Test changes in staging environment first
4. Update documentation for any structural changes

## License

MIT

