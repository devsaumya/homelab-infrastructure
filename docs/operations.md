# Operations Guide

Day-to-day operations and maintenance procedures for the homelab infrastructure.

## Health Checks

Run the health check script to verify all components:
```bash
./scripts/maintenance/health-check.sh
```

This checks:
- k3s cluster status
- Docker services on VM2
- Network connectivity

## Updating Infrastructure

### Update All Components

Update everything at once:
```bash
./scripts/maintenance/update-all.sh
```

This updates:
- k3s cluster
- Docker images on VM2
- Kubernetes deployments

### Update Individual Components

**Update k3s:**
```bash
ansible-playbook -i infra/ansible/inventory/hosts.yml infra/ansible/playbooks/01-k3s-install.yml --tags update
```

**Update Docker stacks:**
```bash
ansible monitoring -i infra/ansible/inventory/hosts.yml -m shell -a \
  "cd /opt/docker/monitoring && docker compose pull && docker compose up -d" \
  --become
```

**Update Kubernetes apps:**
ArgoCD will automatically sync changes when you push to the repository. To force sync:
```bash
kubectl patch app <app-name> -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"master"}}}'
```

Or use the ArgoCD UI to trigger a sync.

## Managing Applications

### View Applications

List all ArgoCD applications:
```bash
kubectl get applications -n argocd
```

### Application Status

Check detailed status:
```bash
kubectl describe application <app-name> -n argocd
```

### Manual Sync

Force a manual sync via CLI:
```bash
argocd app sync <app-name>
```

Or via kubectl:
```bash
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"master"}}}'
```

### Rollback

Rollback to a previous revision:
```bash
argocd app rollback <app-name> <revision>
```

## Network Configuration

### Generate Network Configs

Generate router and firewall configurations from contracts:
```bash
cd infra/network
python generate_network_config.py
```

This generates:
- ER605 VLAN configuration guide
- Firewall rules
- Kubernetes network policies
- Ansible variables

### Update Contracts

Edit contract files in `infra/contracts/`:
- `vlans.yaml` - VLAN definitions
- `ipam.yaml` - IP address management
- `dns-zones.yaml` - DNS zones and records
- `access-matrix.yaml` - Firewall rules

Validate contracts:
```bash
python scripts/validation/validate_contracts.py
```

## DNS Management

### Generate DNS Configs

Generate DNS configurations:
```bash
cd infra/dns
python generate_dns_config.py
```

### Update DNS Records

Edit `infra/contracts/dns-zones.yaml` and regenerate configs.

## Monitoring

### Access Monitoring Services

- **Grafana**: http://10.0.1.109:3000 (VM2)
- **Prometheus**: http://10.0.1.109:9090 (VM2)
- **Loki**: http://10.0.1.109:3100 (VM2)

### ArgoCD UI

Port-forward to access ArgoCD:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access: https://localhost:8080

## Troubleshooting

### k3s Issues

Check k3s status:
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

View k3s logs:
```bash
journalctl -u k3s -f
```

### ArgoCD Sync Issues

Check application sync status:
```bash
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd
```

View ArgoCD logs:
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
```

### Network Issues

Test connectivity:
```bash
ping 10.0.1.108  # k3s-master-01
ping 10.0.1.109  # VM2
ping 10.0.1.50   # Synology NAS
```

## Cleanup

Run cleanup script to remove unused resources:
```bash
./scripts/maintenance/cleanup.sh
```

This removes:
- Unused Docker images
- Completed/failed Kubernetes pods
- Old log files (>7 days)

## Backup and Recovery

### Backup k3s

Backup k3s data:
```bash
ansible k3s-master-01 -i infra/ansible/inventory/hosts.yml -m shell -a \
  "sudo tar -czf /tmp/k3s-backup-$(date +%Y%m%d).tar.gz /var/lib/rancher/k3s" \
  --become
```

### Backup Docker Volumes

Backup Docker volumes on VM2:
```bash
ansible monitoring -i infra/ansible/inventory/hosts.yml -m shell -a \
  "docker run --rm -v <volume>:/data -v $(pwd):/backup alpine tar czf /backup/<volume>-backup.tar.gz /data" \
  --become
```

## Security

### Rotate Secrets

Rotate Ansible Vault secrets:
```bash
ansible-vault rekey infra/ansible/inventory/group_vars/all/vault.yml
```

### Update Certificates

cert-manager automatically manages TLS certificates. To check status:
```bash
kubectl get certificates --all-namespaces
```

### Security Scanning

Run Trivy scans:
```bash
ansible monitoring -i infra/ansible/inventory/hosts.yml -m shell -a \
  "docker exec trivy trivy image <image-name>" \
  --become
```

## Maintenance Windows

Schedule regular maintenance:
- **Weekly**: Health checks, cleanup
- **Monthly**: Update all components, review logs
- **Quarterly**: Security audits, backup verification

