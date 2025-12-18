# How to Use This Project - Step-by-Step Guide

This guide walks you through setting up and using the homelab infrastructure from scratch.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Configuration](#configuration)
4. [Deployment](#deployment)
5. [Verification](#verification)
6. [Daily Operations](#daily-operations)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Hardware Requirements

Before starting, ensure you have:

- **k3s-master VM**: Ubuntu 22.04 LTS, 2 CPU, 4GB RAM, 40GB disk
- **security-ops VM (VM2)**: Ubuntu 22.04 LTS, 2 CPU, 4GB RAM, 40GB disk
- **Synology NAS**: Accessible on network (optional but recommended)
- **Network**: Managed switch with VLAN support (optional for MVP)

### Software Requirements on Your Local Machine

Install the following tools on your local machine (where you'll run the deployment):

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

### Network Information

Gather the following information:

- IP addresses of your VMs (k3s-master, security-ops)
- SSH credentials for VMs (username, password or SSH key)
- Cloudflare account credentials (API token, Zone ID, Account ID)
- Domain name (if using Cloudflare)

---

## Initial Setup

### Step 1: Clone the Repository

```bash
# Clone the repository
git clone <your-repository-url>
cd homelab-infrastructure

# Verify structure
ls -la
# You should see: terraform/, ansible/, kubernetes/, docker/, scripts/, docs/
```

### Step 2: Run Prerequisites Check

```bash
# Make scripts executable (on Linux/Mac)
chmod +x scripts/**/*.sh

# Run prerequisites check
./scripts/setup/00-prereqs.sh
```

This script verifies all required tools are installed and accessible.

**Expected output:**
```
=== Homelab Infrastructure Prerequisites Setup ===
✓ All required commands are installed
✓ Terraform version: 1.5.x
✓ Ansible version: 2.x.x
✓ kubectl: Client Version: v1.28.x
✓ Docker version 24.x.x
Creating required directories...
=== Prerequisites check complete ===
```

---

## Configuration

### Step 3: Configure Ansible Inventory

Edit the Ansible inventory file with your VM details:

```bash
# Open the inventory file
nano ansible/inventory/hosts.yml
# or
vim ansible/inventory/hosts.yml
```

**Update the following:**

```yaml
all:
  children:
    k3s_cluster:
      hosts:
        k3s-master:
          ansible_host: 10.0.1.100    # ← Change to your k3s-master IP
          ansible_user: admin         # ← Change to your SSH username
          ansible_become: true
    
    monitoring:
      hosts:
        security-ops:
          ansible_host: 10.0.1.105    # ← Change to your VM2 IP
          ansible_user: admin         # ← Change to your SSH username
          ansible_become: true
```

**Save the file.**

### Step 4: Configure Ansible Variables

Edit common variables:

```bash
# Edit common variables
nano ansible/inventory/group_vars/all.yml
```

Update values like timezone, DNS servers, etc. if needed.

### Step 5: Encrypt Secrets with Ansible Vault

Create and encrypt the vault file with your secrets:

```bash
cd ansible

# Create the vault file (will prompt for vault password)
ansible-vault create inventory/group_vars/all/vault.yml
```

**Add the following content (replace with your actual values):**

```yaml
# Ansible Vault encrypted file
# Edit with: ansible-vault edit inventory/group_vars/all/vault.yml

vault_k3s_token: "your-secure-random-token-here"
vault_cloudflare_api_token: "your-cloudflare-api-token"
vault_cloudflare_zone_id: "your-cloudflare-zone-id"
vault_cloudflare_account_id: "your-cloudflare-account-id"
vault_synology_admin_password: "your-synology-password"
vault_grafana_admin_password: "your-secure-grafana-password"
vault_wireguard_private_key: "your-wireguard-private-key"
vault_wireguard_public_key: "your-wireguard-public-key"
```

**Important:** 
- Choose a strong vault password and store it securely
- You'll need this password every time you run Ansible playbooks
- Generate a secure k3s token: `openssl rand -hex 32`

**Save and exit.** The file will be encrypted.

### Step 6: Test SSH Connection

Verify you can SSH to your VMs:

```bash
# Test SSH to k3s-master
ssh admin@10.0.1.100

# Test SSH to security-ops
ssh admin@10.0.1.105

# If using SSH keys, ensure they're added to ssh-agent
ssh-add ~/.ssh/id_rsa
```

### Step 7: Configure Terraform (Optional - for Cloudflare)

If you're using Cloudflare for DNS/Tunnel:

```bash
cd terraform/environments/production

# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Update the file:**

```hcl
cloudflare_api_token = "your-cloudflare-api-token"
cloudflare_zone_id   = "your-zone-id"
cloudflare_account_id = "your-account-id"
domain               = "homelab.local"  # or your domain

services = {
  grafana = "10.0.1.105:3000"
  traefik = "10.0.1.80:9000"
  adguard = "10.0.1.53:3000"
}
```

**Save the file.**

---

## Deployment

### Step 8: Configure ER605 and Network (Manual)

**Important:** Before deploying infrastructure, configure your TP-Link ER605 router manually:

1. **Access ER605 Web UI:**
   - Connect to ER605 management interface
   - Default: http://192.168.0.1 or http://tplinkrouter.net

2. **Configure WAN:**
   - Set up internet connection
   - Configure static IP or DHCP as needed

3. **Configure VLANs:**
   - VLAN 1 (Management): 10.0.1.0/24
   - VLAN 2 (Trusted LAN): 10.0.2.0/24
   - VLAN 10 (IoT): 10.0.10.0/24
   - VLAN 20 (DMZ): 10.0.20.0/24
   - VLAN 99 (Guest): 10.0.99.0/24

4. **Configure DHCP:**
   - Set DHCP ranges for each VLAN
   - Configure DNS servers (will be updated after AdGuard Home deployment)

5. **Configure Firewall Rules:**
   - Set up inter-VLAN routing rules
   - Configure port forwarding if needed
   - Set up basic security policies

6. **Configure Synology NAS (if applicable):**
   - Access Synology DSM
   - Configure network settings
   - Set up shared folders
   - Enable NFS/SMB services

**Note:** ER605 and Synology configuration is **manual** and not managed by Terraform. Terraform only manages Cloudflare resources (DNS, Tunnel, WAF).

### Step 9: Bootstrap VMs

This step configures the base OS on all VMs:

```bash
# From project root
./scripts/setup/02-vm-bootstrap.sh
```

**What this does:**
- Updates system packages
- Installs base packages (curl, wget, git, etc.)
- Configures timezone
- Disables swap (required for Kubernetes)
- Configures kernel parameters for Kubernetes
- Sets up basic security

**Expected output:**
```
=== VM Bootstrap ===
Running Ansible bootstrap playbook...
PLAY [Bootstrap all hosts] ********************************
...
PLAY RECAP ********************************
k3s-master              : ok=15   changed=5    unreachable=0    failed=0
security-ops            : ok=15   changed=5    unreachable=0    failed=0
=== Bootstrap complete ===
```

### Step 10: Install k3s

Install Kubernetes (k3s) on the master node:

```bash
# Run k3s installation playbook
ansible-playbook \
  -i ansible/inventory/hosts.yml \
  ansible/playbooks/01-k3s-install.yml \
  --ask-vault-pass
```

**Note:** You'll be prompted for the Ansible vault password.

**What this does:**
- Downloads and installs k3s
- Configures k3s as a server (control plane)
- Sets up kubectl
- Creates kubeconfig file

**Expected output:**
```
PLAY [Install k3s control plane] ************************
...
TASK [k3s-master : Install k3s server] ******************
changed: [k3s-master]
...
PLAY RECAP ********************************
k3s-master              : ok=8    changed=3    unreachable=0    failed=0
```

### Step 11: Configure kubectl Locally

Copy the kubeconfig from k3s-master to your local machine:

```bash
# SSH to k3s-master and get kubeconfig
ssh admin@10.0.1.100 "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config

# Update server URL (replace 127.0.0.1 with actual IP)
sed -i 's/127.0.0.1/10.0.1.100/g' ~/.kube/config

# Set correct permissions
chmod 600 ~/.kube/config

# Test connection
kubectl get nodes
```

**Expected output:**
```
NAME          STATUS   ROLES                  AGE   VERSION
k3s-master    Ready    control-plane,master   2m    v1.28.0+k3s1
```

### Step 12: Deploy Kubernetes Services

Deploy the core Kubernetes services:

```bash
# Deploy all Kubernetes manifests
./scripts/deployment/deploy-k3s.sh
```

**What this does:**
- Creates namespaces (dns-system, ingress-traefik, monitoring, security)
- Applies network policies
- Deploys AdGuard Home (DNS blocker)
- Deploys Traefik (ingress controller)
- Sets up cert-manager (if configured)

**Expected output:**
```
=== Deploying Kubernetes Manifests ===
Applying namespaces...
namespace/dns-system created
namespace/ingress-traefik created
...
Applying AdGuard Home...
deployment.apps/adguard-home created
service/adguard-home created
...
Waiting for deployments to be ready...
deployment.apps/adguard-home condition met
=== Kubernetes deployment complete ===
```

**Verify deployments:**

```bash
# Check all pods
kubectl get pods --all-namespaces

# Check specific services
kubectl get svc -n dns-system
kubectl get svc -n ingress-traefik
```

### Step 13: Configure DNS

Update your router or DHCP server to use AdGuard Home as DNS:

1. **Get AdGuard Home service IP:**
   ```bash
   kubectl get svc -n dns-system adguard-home
   ```
   Note the CLUSTER-IP (e.g., 10.43.x.x)

2. **Update router/DHCP settings:**
   - Primary DNS: `10.43.x.x` (AdGuard Home cluster IP)
   - Secondary DNS: `1.1.1.1` (Cloudflare fallback)

3. **Or configure on individual devices:**
   - Set DNS server to the AdGuard Home cluster IP

4. **Access AdGuard Home admin:**
   ```bash
   kubectl port-forward -n dns-system svc/adguard-home 3000:3000
   ```
   Open browser: http://localhost:3000
   - Initial setup wizard will appear
   - Set admin username and password
   - Configure upstream DNS servers (e.g., 1.1.1.1, 8.8.8.8)

### Step 14: Deploy Monitoring Stack

Deploy Prometheus, Grafana, and Loki on VM2:

```bash
# Deploy monitoring stack
./scripts/deployment/deploy-monitoring.sh
```

**What this does:**
- Installs Docker on VM2 (if not already installed)
- Creates required directories
- Deploys Docker Compose stack with:
  - Prometheus (metrics)
  - Grafana (dashboards)
  - Loki (logs)
  - AlertManager (alerts)
  - Promtail (log shipper)

**Expected output:**
```
=== Deploying Monitoring Stack ===
PLAY [Deploy monitoring stack] **************************
...
Deploying Docker Compose monitoring stack...
Creating network monitoring_monitoring ... done
Creating container prometheus ... done
Creating container grafana ... done
...
=== Monitoring stack deployment complete ===
Access Grafana at: http://10.0.1.105:3000
Access Prometheus at: http://10.0.1.105:9090
```

**Access services:**
- Grafana: http://10.0.1.105:3000 (default: admin/admin)
- Prometheus: http://10.0.1.105:9090
- Loki: http://10.0.1.105:3100

**Configure Grafana:**
1. Login with default credentials (admin/admin)
2. Change password when prompted
3. Add Prometheus as data source (should be auto-configured)
4. Import dashboards from Grafana dashboard library

### Step 15: Deploy Security Tools

Deploy security scanning tools:

```bash
# Deploy security tools
./scripts/deployment/deploy-security.sh
```

**What this does:**
- Installs Trivy (container scanning)
- Installs fail2ban (intrusion prevention)
- Deploys Trivy server on VM2

**Expected output:**
```
=== Deploying Security Tools ===
PLAY [Deploy security tools] **************************
...
Deploying Trivy server...
Creating container trivy-server ... done
=== Security tools deployment complete ===
```

### Step 16: Configure Cloudflare (Optional)

If using Cloudflare for external access:

```bash
cd terraform/environments/production

# Initialize Terraform
terraform init

# Review changes
terraform plan

# Apply configuration
terraform apply
```

**What this does:**
- Creates Cloudflare Tunnel
- Configures DNS records
- Sets up tunnel routes for services

---

## Verification

### Step 17: Run Health Check

Verify everything is working:

```bash
# Run comprehensive health check
./scripts/maintenance/health-check.sh
```

**Expected output:**
```
=== Homelab Infrastructure Health Check ===
Checking k3s cluster...
✓ k3s cluster is accessible
NAME          STATUS   ROLES                  AGE   VERSION
k3s-master    Ready    control-plane,master   15m   v1.28.0+k3s1

NAMESPACE          NAME                              READY   STATUS    RESTARTS   AGE
dns-system         adguard-home-xxx                  1/1     Running   0          10m
ingress-traefik    traefik-xxx                      2/2     Running   0          10m
...

Checking Docker services on monitoring host...
NAME            STATUS          PORTS
prometheus      Up 5 minutes    0.0.0.0:9090->9090/tcp
grafana         Up 5 minutes    0.0.0.0:3000->3000/tcp
...

Checking network connectivity...
✓ 10.0.1.100 is reachable
✓ 10.0.1.105 is reachable
✓ 10.0.1.50 is reachable

=== Health check complete ===
```

### Step 18: Manual Verification

**Check Kubernetes services:**

```bash
# List all services
kubectl get svc --all-namespaces

# Check pod status
kubectl get pods --all-namespaces

# View logs
kubectl logs -n dns-system deployment/adguard-home
```

**Check Docker services:**

```bash
# SSH to VM2
ssh admin@10.0.1.105

# Check running containers
docker ps

# Check logs
docker compose -f /opt/docker/monitoring/docker-compose.yml logs
```

**Test DNS blocking:**

```bash
# Test DNS resolution
nslookup doubleclick.net 10.43.x.x  # Should be blocked
nslookup google.com 10.43.x.x        # Should resolve
```

**Test web services:**

```bash
# Test Grafana
curl http://10.0.1.105:3000

# Test Prometheus
curl http://10.0.1.105:9090

# Test AdGuard Home (via port-forward)
kubectl port-forward -n dns-system svc/adguard-home 3000:3000
# Open http://localhost:3000
```

---

## Daily Operations

### Viewing Logs

**Kubernetes logs:**

```bash
# View pod logs
kubectl logs -n dns-system deployment/adguard-home

# Follow logs
kubectl logs -f -n dns-system deployment/adguard-home

# View logs for all pods in namespace
kubectl logs -n dns-system --all-containers=true
```

**Docker logs:**

```bash
# View container logs
docker logs prometheus
docker logs grafana

# Follow logs
docker logs -f prometheus

# View all monitoring logs
cd /opt/docker/monitoring
docker compose logs -f
```

### Updating Services

**Update Kubernetes deployments:**

```bash
# Update a deployment
kubectl set image deployment/adguard-home adguard-home=adguard/adguardhome:latest -n dns-system

# Or edit directly
kubectl edit deployment adguard-home -n dns-system

# Restart a deployment
kubectl rollout restart deployment/adguard-home -n dns-system
```

**Update Docker services:**

```bash
# SSH to VM2
ssh admin@10.0.1.105

# Update and restart
cd /opt/docker/monitoring
docker compose pull
docker compose up -d
```

**Or use the update script:**

```bash
./scripts/maintenance/update-all.sh
```

### Adding New Services

**Add to Kubernetes:**

1. Create manifests in `kubernetes/base/your-service/`
2. Apply:
   ```bash
   kubectl apply -k kubernetes/base/your-service/
   ```

**Add to Docker:**

1. Add service to `docker/services/docker-compose.yml`
2. Deploy:
   ```bash
   ssh admin@10.0.1.105
   cd /opt/docker/services
   docker compose up -d
   ```

### Backup

**Backup Kubernetes resources:**

```bash
# Export all resources
kubectl get all --all-namespaces -o yaml > backup-$(date +%Y%m%d).yaml

# Backup specific namespace
kubectl get all -n dns-system -o yaml > dns-system-backup.yaml
```

**Backup Docker volumes:**

```bash
# SSH to VM2
ssh admin@10.0.1.105

# Backup Grafana data
docker run --rm -v grafana-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/grafana-backup-$(date +%Y%m%d).tar.gz /data
```

### Monitoring

**View metrics in Grafana:**

1. Open http://10.0.1.105:3000
2. Navigate to Dashboards
3. Import pre-built dashboards:
   - Node Exporter Full
   - Kubernetes Cluster Monitoring
   - Prometheus Stats

**View alerts:**

```bash
# Check Prometheus alerts
curl http://10.0.1.105:9090/api/v1/alerts

# Check AlertManager
curl http://10.0.1.105:9093/api/v2/alerts
```

---

## Troubleshooting

### Common Issues

#### Issue: Cannot connect to k3s cluster

**Symptoms:**
```bash
kubectl get nodes
# Error: unable to connect to the server
```

**Solutions:**

1. Check k3s service status:
   ```bash
   ssh admin@10.0.1.100
   sudo systemctl status k3s
   ```

2. Check k3s logs:
   ```bash
   sudo journalctl -u k3s -f
   ```

3. Verify kubeconfig:
   ```bash
   # Check server URL in ~/.kube/config
   cat ~/.kube/config | grep server
   # Should show: server: https://10.0.1.100:6443
   ```

4. Restart k3s:
   ```bash
   ssh admin@10.0.1.100
   sudo systemctl restart k3s
   ```

#### Issue: Pods not starting

**Symptoms:**
```bash
kubectl get pods
# STATUS: Pending or CrashLoopBackOff
```

**Solutions:**

1. Describe the pod:
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```

2. Check events:
   ```bash
   kubectl get events --sort-by='.lastTimestamp' -n <namespace>
   ```

3. Check logs:
   ```bash
   kubectl logs <pod-name> -n <namespace>
   ```

4. Check resource limits:
   ```bash
   kubectl top nodes
   kubectl top pods --all-namespaces
   ```

#### Issue: DNS not resolving

**Symptoms:**
- Cannot resolve domain names
- AdGuard Home not blocking ads

**Solutions:**

1. Check AdGuard Home pod:
   ```bash
   kubectl get pods -n dns-system
   kubectl logs -n dns-system deployment/adguard-home
   ```

2. Test DNS directly:
   ```bash
   # Get service IP
   kubectl get svc -n dns-system adguard-home
   # Test DNS
   nslookup google.com <service-ip>
   ```

3. Check network policies:
   ```bash
   kubectl get networkpolicies --all-namespaces
   ```

4. Restart AdGuard Home:
   ```bash
   kubectl rollout restart deployment/adguard-home -n dns-system
   ```

#### Issue: Docker services not starting

**Symptoms:**
```bash
docker ps
# Containers not running
```

**Solutions:**

1. Check Docker service:
   ```bash
   ssh admin@10.0.1.105
   sudo systemctl status docker
   ```

2. Check container logs:
   ```bash
   docker logs <container-name>
   ```

3. Check disk space:
   ```bash
   df -h
   ```

4. Restart Docker:
   ```bash
   sudo systemctl restart docker
   cd /opt/docker/monitoring
   docker compose up -d
   ```

#### Issue: Ansible playbook fails

**Symptoms:**
```bash
ansible-playbook ...
# FAILED! => ...
```

**Solutions:**

1. Check SSH connectivity:
   ```bash
   ansible all -i ansible/inventory/hosts.yml -m ping
   ```

2. Check vault password:
   ```bash
   # Ensure you're using correct vault password
   ansible-vault view ansible/inventory/group_vars/all/vault.yml
   ```

3. Run with verbose output:
   ```bash
   ansible-playbook ... -vvv
   ```

4. Check host variables:
   ```bash
   ansible-inventory -i ansible/inventory/hosts.yml --list
   ```

### Getting Help

**Check logs:**

```bash
# Kubernetes
kubectl logs --all-namespaces --tail=100

# Docker
docker compose -f /opt/docker/monitoring/docker-compose.yml logs --tail=100

# System
journalctl -xe
```

**Useful commands:**

```bash
# Cluster info
kubectl cluster-info

# Node status
kubectl get nodes -o wide

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Network policies
kubectl get networkpolicies --all-namespaces

# Services
kubectl get svc --all-namespaces
```

---

## Next Steps

After successful deployment:

1. **Configure Grafana dashboards** - Import pre-built dashboards
2. **Set up alerting** - Configure AlertManager notifications
3. **Add more services** - Deploy additional applications
4. **Set up backups** - Configure automated backup procedures
5. **Harden security** - Review and tighten security settings
6. **Scale infrastructure** - Add more nodes or services

---

## Quick Reference

### Common Commands

```bash
# Health check
./scripts/maintenance/health-check.sh

# Update everything
./scripts/maintenance/update-all.sh

# Deploy all
./scripts/deployment/deploy-all.sh

# View Kubernetes resources
kubectl get all --all-namespaces

# View Docker services
docker ps

# Access services
kubectl port-forward -n dns-system svc/adguard-home 3000:3000
```

### Service URLs

- **Grafana**: http://10.0.1.105:3000
- **Prometheus**: http://10.0.1.105:9090
- **AdGuard Home**: http://10.0.1.53:3000 (via port-forward)
- **Traefik Dashboard**: http://10.0.1.80:9000 (if exposed)

### Important Files

- **Ansible inventory**: `ansible/inventory/hosts.yml`
- **Ansible vault**: `ansible/inventory/group_vars/all/vault.yml`
- **Terraform vars**: `terraform/environments/production/terraform.tfvars`
- **Kubernetes manifests**: `kubernetes/base/`
- **Docker Compose**: `docker/monitoring/docker-compose.yml`

---

## Support

For issues or questions:

1. Check the [Architecture Documentation](architecture.md)
2. Review the [Deployment Guide](DEPLOYMENT.md)
3. Check logs and error messages
4. Review the troubleshooting section above

---

**Last Updated**: 2024
**Version**: 1.0

