# Quick Start Guide

Get your homelab infrastructure up and running in 15 minutes.

## Prerequisites Checklist

- [ ] Terraform >= 1.5.0 installed
- [ ] Ansible >= 2.9 installed
- [ ] kubectl installed
- [ ] Docker installed
- [ ] SSH access to VMs (k3s-master and security-ops)
- [ ] Cloudflare account (optional)

## 5-Minute Setup

### 0. Configure ER605 (Manual - Before Starting)

**Important:** Configure your TP-Link ER605 router manually first:
- Set up VLANs (Management, Trusted, IoT, DMZ, Guest)
- Configure DHCP for each VLAN
- Set up basic firewall rules
- Configure Synology NAS if applicable

**Note:** ER605 configuration is manual and not managed by Terraform.

### 1. Configure Inventory (2 minutes)

```bash
# Edit with your VM IPs
nano ansible/inventory/hosts.yml
```

Update:
- `ansible_host: 10.0.1.100` → Your k3s-master IP
- `ansible_host: 10.0.1.105` → Your security-ops IP
- `ansible_user: admin` → Your SSH username

### 2. Create Secrets (2 minutes)

```bash
cd ansible
ansible-vault create inventory/group_vars/all/vault.yml
```

Add:
```yaml
vault_k3s_token: "$(openssl rand -hex 32)"
vault_grafana_admin_password: "your-secure-password"
```

Save with a vault password (remember it!).

### 3. Bootstrap & Deploy (10 minutes)

```bash
# From project root

# Bootstrap VMs
./scripts/setup/02-vm-bootstrap.sh

# Install k3s
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/01-k3s-install.yml \
  --ask-vault-pass

# Configure kubectl
ssh admin@<k3s-master-ip> "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config
sed -i 's/127.0.0.1/<k3s-master-ip>/g' ~/.kube/config

# Deploy everything
./scripts/deployment/deploy-all.sh
```

### 4. Verify (1 minute)

```bash
# Check cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Check health
./scripts/maintenance/health-check.sh
```

## Access Your Services

- **Grafana**: http://<vm2-ip>:3000 (admin/admin)
- **Prometheus**: http://<vm2-ip>:9090
- **AdGuard Home**: `kubectl port-forward -n dns-system svc/adguard-home 3000:3000` → http://localhost:3000

## Next Steps

1. Configure AdGuard Home DNS blocking
2. Set up Grafana dashboards
3. Configure Cloudflare Tunnel (optional)
4. Review [Full Guide](HOW_TO_USE.md) for detailed instructions

## Troubleshooting

**Can't connect to k3s?**
```bash
ssh admin@<k3s-master-ip>
sudo systemctl status k3s
```

**Pods not starting?**
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

**Need help?** See [HOW_TO_USE.md](HOW_TO_USE.md) for detailed troubleshooting.

