# Homelab IaC Code Layout

Authoritative structure and conventions for all Infrastructure as Code (IaC) in the `homelab-infrastructure` repository.

---

## Goals

- All infra changes are declarative, reproducible, and versioned.
- Core tools:
  - Terraform for Cloudflare/DNS and external integrations.
  - Ansible for VM configuration and OS-level setup.
  - Kubernetes manifests (with Kustomize) for k3s workloads.
  - Docker Compose for VM2 services (monitoring, security, utilities).

---

## Top-level IaC layout

homelab-infrastructure/
├── terraform/ # Terraform for Cloudflare, DNS, external infra
├── ansible/ # VM provisioning & configuration
├── kubernetes/ # Manifests for k3s cluster
├── docker/ # Docker Compose stacks on VM2
├── scripts/ # Helper scripts to glue IaC together
└── docs/IAC_CODE.md # This file


---

## Terraform

terraform/
├── main.tf # Root composition of modules
├── variables.tf # Input variables
├── outputs.tf # Exported values
├── providers.tf # Provider config (Cloudflare, etc.)
├── modules/
│ ├── cloudflare/
│ │ ├── main.tf
│ │ ├── variables.tf
│ │ └── outputs.tf
│ └── monitoring/
│ ├── main.tf
│ ├── variables.tf
│ └── outputs.tf
└── environments/
├── production/
│ ├── backend.tf
│ └── terraform.tfvars
└── staging/
├── backend.tf
└── terraform.tfvars


**Conventions**:  
- Terraform ≥ 1.5, always run `terraform fmt -recursive`.  
- **Only cloud/remote resources are managed here**: Cloudflare DNS, Cloudflare Tunnel, Zero Trust/WAF, external monitoring hooks.  
- Home hardware (ER605, Synology, VMs, VLANs, Wi‑Fi, UPS) is configured via the ER605 UI + Synology UI + Ansible, not Terraform.  
- Secrets (API tokens, passwords) only via `*.tfvars` or env vars, never hardcoded.

### What Terraform does not manage

- No TP-Link ER605 configuration (ports, VLANs, ACLs are manual or via future Ansible).  
- No Synology DSM settings or VM definitions.  
- No local Docker/k3s networking; Terraform only knows service IPs/ports as data to build Cloudflare Tunnel and DNS records.

### Network automation (future)

- ER605 configuration is currently **documented + manual**, not fully automated.  
- If TP-Link exposes stable APIs/CLI in future, add an `ansible/roles/er605/` role to template VLANs, ACLs, and backups; keep Terraform focused on Cloudflare and other cloud providers.  

**Example `providers.tf`:**

terraform {
required_version = ">= 1.5.0"
required_providers {
cloudflare = {
source = "cloudflare/cloudflare"
version = "~> 4.0"
}
}
}

provider "cloudflare" {
api_token = var.cloudflare_api_token
}


**Example `main.tf`:**

module "cloudflare" {
source = "./modules/cloudflare"

domain = var.domain
cloudflare_api_token = var.cloudflare_api_token

services = {
grafana = "10.0.1.105:3000"
traefik = "10.0.1.80:9000"
adguard = "10.0.1.53:3000"
}


---

## Ansible

ansible/
├── ansible.cfg
├── inventory/
│ ├── hosts.yml # VM inventory (k3s-master, security-ops)
│ └── group_vars/
│ ├── all.yml
│ └── vault.yml # Encrypted with Ansible Vault
├── playbooks/
│ ├── 00-bootstrap.yml # Base OS config on all VMs
│ ├── 01-k3s-install.yml # k3s control-plane setup
│ ├── 02-monitoring.yml # Prometheus/Grafana/Loki on VM2
│ ├── 03-security.yml # Trivy/Falco/Kyverno
│ └── 99-destroy.yml # Tear down (use carefully)
└── roles/
├── common/
├── k3s-master/
├── docker-host/
├── prometheus/
├── loki/
├── grafana/
└── security-scanning/


**Conventions**:  
- Everything non-trivial goes into roles; playbooks are thin.  
- Secrets live in `group_vars/all/vault.yml` (Ansible Vault).  
- `common` handles timezone, swap off, base packages.  

**Example `inventory/hosts.yml`:**

all:
children:
k3s_cluster:
hosts:
k3s-master:
ansible_host: 10.0.1.100
ansible_user: admin
ansible_become: true
monitoring:
hosts:
security-ops:
ansible_host: 10.0.1.105
ansible_user: admin
ansible_become: true
vars:
ansible_python_interpreter: /usr/bin/python3


---

## Kubernetes (k3s)

kubernetes/
├── base/
│ ├── namespaces/
│ │ ├── adguard.yaml
│ │ ├── traefik.yaml
│ │ ├── monitoring.yaml
│ │ └── security.yaml
│ ├── adguard/
│ │ ├── deployment.yaml
│ │ ├── service.yaml
│ │ ├── pvc.yaml
│ │ └── kustomization.yaml
│ ├── traefik/
│ ├── cert-manager/
│ ├── cloudflare-tunnel/
│ ├── falco/
│ ├── kyverno/
│ └── network-policies/
│ ├── default-deny.yaml
│ ├── allow-dns.yaml
│ └── allow-internet.yaml
├── overlays/
│ ├── production/
│ │ └── kustomization.yaml
│ └── staging/
│ └── kustomization.yaml
└── argocd/
├── applications/
└── projects/


**Conventions**:  
- Kustomize for base + overlays.  
- Every app: `deployment.yaml`, `service.yaml`, `pvc.yaml` (if stateful), `kustomization.yaml`.  
- Default-deny NetworkPolicy plus explicit allow policies.  

---

## Docker Compose (VM2)

docker/
├── monitoring/
│ ├── docker-compose.yml # Prometheus, Grafana, Loki, Alertmanager
│ ├── prometheus/
│ │ ├── prometheus.yml
│ │ └── alerts.yml
│ ├── loki/
│ │ └── loki-config.yml
│ └── grafana/
│ ├── grafana.ini
│ └── datasources.yml
├── security/
│ ├── docker-compose.yml # Trivy server, etc.
└── services/
├── docker-compose.yml # Portainer, Vaultwarden, Dozzle


**Conventions**:  
- `version: "3.8"` everywhere, `restart: unless-stopped`.  
- Use `/data/...` named volumes for all persistence.  
- Secrets via `.env` (git-ignored) or Ansible Vault.  

---

## Scripts

scripts/
├── setup/
│ ├── 00-prereqs.sh
│ ├── 01-synology-setup.sh
│ └── 02-vm-bootstrap.sh
├── deployment/
│ ├── deploy-all.sh
│ ├── deploy-k3s.sh
│ ├── deploy-monitoring.sh
│ └── deploy-security.sh
└── maintenance/
├── health-check.sh
├── update-all.sh
└── cleanup.sh


**Conventions**:  
- All scripts: `#!/bin/bash` and `set -euo pipefail`.  
- Scripts are thin wrappers around Terraform/Ansible/kubectl/Docker.  

---

## Apply Order

1. Configure ER605 (WAN, VLANs, DHCP, firewall) and Synology/VMs manually using the router/NAS UI, following the ER605-only network design.  
2. Bootstrap VMs with Ansible (base OS hardening, packages, Docker, k3s).  
3. Provision external infra with Terraform (Cloudflare DNS, Cloudflare Tunnel, WAF/Zero Trust, health checks).  
4. Apply Kubernetes base + overlays to k3s.  
5. Bring up Docker stacks on VM2 (monitoring, services, security).  

This file is the single source of truth for IaC structure; extend it instead of adding ad-hoc layouts when you grow the lab.


