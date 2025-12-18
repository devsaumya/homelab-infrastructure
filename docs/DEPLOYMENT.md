# Deployment Guide

Step-by-step guide for deploying the homelab infrastructure.

## Prerequisites

### Hardware Requirements

- **k3s-master**: 2 CPU, 4GB RAM, 40GB disk
- **security-ops (VM2)**: 2 CPU, 4GB RAM, 40GB disk
- **Synology NAS**: Existing storage device
- **Network**: Managed switch with VLAN support

### Software Requirements

- Ubuntu 22.04 LTS on all VMs
- Docker installed on VM2
- SSH access to all hosts
- Cloudflare account (for DNS/Tunnel)

## Step 1: Initial Setup

### 1.1 Clone Repository

```bash
git clone <repository-url>
cd homelab-infrastructure
```

### 1.2 Configure Ansible Inventory

Edit `ansible/inventory/hosts.yml`:

```yaml
k3s-master:
  ansible_host: 10.0.1.100  # Your k3s master IP
  ansible_user: admin

security-ops:
  ansible_host: 10.0.1.105  # Your VM2 IP
  ansible_user: admin
```

### 1.3 Encrypt Secrets

```bash
cd ansible
ansible-vault create inventory/group_vars/all/vault.yml
```

Add the following variables:

```yaml
vault_k3s_token: "your-secure-token-here"
vault_cloudflare_api_token: "your-cloudflare-token"
vault_grafana_admin_password: "your-grafana-password"
```

### 1.4 Configure Terraform

```bash
cd terraform/environments/production
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values.

## Step 2: Configure ER605 and Network (Manual)

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

**Note:** ER605 and Synology configuration is manual and not managed by Terraform. Terraform only manages Cloudflare resources.

## Step 3: Bootstrap VMs

### 2.1 Run Prerequisites Check

```bash
./scripts/setup/00-prereqs.sh
```

### 2.2 Bootstrap All VMs

```bash
./scripts/setup/02-vm-bootstrap.sh
```

This will:
- Update system packages
- Configure timezone
- Disable swap
- Install base packages
- Configure kernel parameters

## Step 4: Install k3s

### 3.1 Install k3s Control Plane

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/01-k3s-install.yml
```

### 3.2 Verify Installation

```bash
# SSH to k3s-master
ssh admin@10.0.1.100

# Check k3s status
sudo systemctl status k3s

# Get kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml
```

Copy the kubeconfig to your local machine:

```bash
mkdir -p ~/.kube
# Copy kubeconfig content to ~/.kube/config
# Update server URL from 127.0.0.1 to 10.0.1.100:6443
```

### 3.3 Test kubectl

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

## Step 5: Deploy Kubernetes Services

### 4.1 Deploy Namespaces

```bash
kubectl apply -f kubernetes/base/namespaces/
```

### 4.2 Deploy Network Policies

```bash
kubectl apply -f kubernetes/base/network-policies/
```

### 4.3 Deploy AdGuard Home

```bash
kubectl apply -k kubernetes/base/adguard/
```

Wait for pod to be ready:

```bash
kubectl wait --for=condition=ready pod -l app=adguard-home -n dns-system --timeout=300s
```

### 4.4 Deploy Traefik

```bash
kubectl apply -k kubernetes/base/traefik/
```

### 4.5 Configure DNS

Update your router/DHCP to use AdGuard Home as DNS server:
- Primary DNS: 10.0.1.53 (AdGuard Home service IP)
- Secondary DNS: 1.1.1.1

## Step 6: Deploy Monitoring Stack

### 5.1 Prepare VM2

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/02-monitoring.yml
```

### 5.2 Deploy Docker Compose Stack

```bash
# SSH to VM2
ssh admin@10.0.1.105

# Navigate to monitoring directory
cd /opt/docker/monitoring

# Create .env file with secrets
cat > .env <<EOF
GRAFANA_ADMIN_PASSWORD=your-secure-password
EOF

# Start services
docker compose up -d
```

### 5.3 Verify Services

```bash
# Check running containers
docker ps

# Check logs
docker compose logs -f
```

Access Grafana at: http://10.0.1.105:3000

## Step 7: Configure Cloudflare

### 6.1 Initialize Terraform

```bash
cd terraform
terraform init
```

### 6.2 Plan Changes

```bash
cd environments/production
terraform init
terraform plan
```

### 6.3 Apply Configuration

```bash
terraform apply
```

This will:
- Create Cloudflare Tunnel
- Configure DNS records
- Set up tunnel routes

## Step 8: Deploy Security Tools

### 7.1 Run Security Playbook

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/03-security.yml
```

### 7.2 Deploy Trivy

```bash
# On VM2
cd /opt/docker/security
docker compose up -d
```

## Step 9: Verification

### 8.1 Run Health Check

```bash
./scripts/maintenance/health-check.sh
```

### 8.2 Verify Services

- **AdGuard Home**: http://10.0.1.53:3000
- **Traefik Dashboard**: http://10.0.1.80:9000
- **Grafana**: http://10.0.1.105:3000
- **Prometheus**: http://10.0.1.105:9090

### 8.3 Test DNS Blocking

Visit a known ad domain (e.g., doubleclick.net) - should be blocked by AdGuard.

## Troubleshooting

### k3s Installation Issues

```bash
# Check k3s logs
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
```

### Network Connectivity

```bash
# Test DNS resolution
nslookup google.com 10.0.1.53

# Test service connectivity
curl http://10.0.1.53:3000
```

## Next Steps

1. Configure Grafana dashboards
2. Set up alerting rules
3. Configure backup procedures
4. Harden security settings
5. Add additional services

## Rollback

If something goes wrong:

```bash
# Remove Kubernetes resources
kubectl delete -f kubernetes/base/

# Stop Docker services
docker compose down

# Uninstall k3s (on k3s-master)
sudo /usr/local/bin/k3s-uninstall.sh
```

