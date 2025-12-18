# Deployment Checklist

Use this checklist to track your deployment progress.

## Pre-Deployment

- [ ] All prerequisites installed (Terraform, Ansible, kubectl, Docker)
- [ ] VMs created and accessible via SSH
- [ ] Network connectivity verified
- [ ] Repository cloned locally
- [ ] Prerequisites check passed: `./scripts/setup/00-prereqs.sh`

## Network Configuration (Manual)

- [ ] ER605 router accessible via web UI
- [ ] WAN connection configured
- [ ] VLANs configured:
  - [ ] VLAN 1 (Management): 10.0.1.0/24
  - [ ] VLAN 2 (Trusted LAN): 10.0.2.0/24
  - [ ] VLAN 10 (IoT): 10.0.10.0/24
  - [ ] VLAN 20 (DMZ): 10.0.20.0/24
  - [ ] VLAN 99 (Guest): 10.0.99.0/24
- [ ] DHCP configured for each VLAN
- [ ] Firewall rules configured
- [ ] Synology NAS configured (if applicable):
  - [ ] Network settings
  - [ ] Shared folders
  - [ ] NFS/SMB services enabled

## Configuration

- [ ] Ansible inventory configured (`ansible/inventory/hosts.yml`)
  - [ ] k3s-master IP address set
  - [ ] security-ops IP address set
  - [ ] SSH username configured
- [ ] Ansible vault created (`ansible/inventory/group_vars/all/vault.yml`)
  - [ ] k3s token generated
  - [ ] Grafana password set
  - [ ] Cloudflare credentials added (if using)
  - [ ] Vault password stored securely
- [ ] Terraform variables configured (if using Cloudflare)
  - [ ] `terraform.tfvars` created
  - [ ] Cloudflare API token added
  - [ ] Zone ID and Account ID added
- [ ] SSH access tested to all VMs
  - [ ] k3s-master: `ssh admin@<ip>`
  - [ ] security-ops: `ssh admin@<ip>`

## Deployment Phase 0: Network Setup

- [ ] ER605 configuration completed (manual)
- [ ] Synology configuration completed (manual)
- [ ] Network connectivity tested

## Deployment Phase 1: Bootstrap

- [ ] VMs bootstrapped: `./scripts/setup/02-vm-bootstrap.sh`
  - [ ] System packages updated
  - [ ] Base packages installed
  - [ ] Timezone configured
  - [ ] Swap disabled
  - [ ] Kernel parameters configured

## Deployment Phase 2: Kubernetes

- [ ] k3s installed: `ansible-playbook ... 01-k3s-install.yml`
  - [ ] k3s service running
  - [ ] kubeconfig available
- [ ] kubectl configured locally
  - [ ] kubeconfig copied to `~/.kube/config`
  - [ ] Server URL updated
  - [ ] Connection tested: `kubectl get nodes`
- [ ] Kubernetes namespaces created
- [ ] Network policies applied
- [ ] AdGuard Home deployed
  - [ ] Pod running: `kubectl get pods -n dns-system`
  - [ ] Service accessible
- [ ] Traefik deployed
  - [ ] Pod running: `kubectl get pods -n ingress-traefik`
  - [ ] Service accessible

## Deployment Phase 3: Monitoring

- [ ] Monitoring playbook executed: `ansible-playbook ... 02-monitoring.yml`
- [ ] Docker Compose stack deployed
  - [ ] Prometheus running
  - [ ] Grafana running
  - [ ] Loki running
  - [ ] AlertManager running
  - [ ] Promtail running
- [ ] Services accessible
  - [ ] Grafana: http://<vm2-ip>:3000
  - [ ] Prometheus: http://<vm2-ip>:9090

## Deployment Phase 4: Security

- [ ] Security playbook executed: `ansible-playbook ... 03-security.yml`
- [ ] Trivy server deployed
- [ ] fail2ban configured

## Deployment Phase 5: Configuration

- [ ] AdGuard Home configured
  - [ ] Admin interface accessed
  - [ ] Initial setup completed
  - [ ] Upstream DNS servers configured
  - [ ] Blocklists added
- [ ] DNS configured on network
  - [ ] Router/DHCP updated with AdGuard IP
  - [ ] DNS resolution tested
- [ ] Grafana configured
  - [ ] Admin password changed
  - [ ] Prometheus data source verified
  - [ ] Dashboards imported

## Verification

- [ ] Health check passed: `./scripts/maintenance/health-check.sh`
- [ ] All pods running: `kubectl get pods --all-namespaces`
- [ ] All Docker containers running: `docker ps` (on VM2)
- [ ] DNS blocking tested
- [ ] Services accessible
  - [ ] Grafana dashboard working
  - [ ] Prometheus metrics visible
  - [ ] AdGuard Home blocking ads

## Post-Deployment

- [ ] Backup procedures configured
- [ ] Monitoring alerts configured
- [ ] Documentation reviewed
- [ ] Team access configured (if applicable)
- [ ] Cloudflare Tunnel configured (if using)

## Troubleshooting Notes

Document any issues encountered and their resolutions:

```
Issue: 
Resolution: 

Issue: 
Resolution: 
```

## Sign-Off

- [ ] All services operational
- [ ] Health checks passing
- [ ] Documentation reviewed
- [ ] Team trained (if applicable)

**Deployed by:** _________________  
**Date:** _________________  
**Version:** _________________

