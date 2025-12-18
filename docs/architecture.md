# Homelab Architecture

This document describes the architecture and design decisions for the homelab infrastructure.

## Network Topology

```
Internet (ISP)
    |
TP-Link ER605 (WAN/Firewall edge)
    |
Managed Switch (VLAN trunk)
    |
    +-- VLAN 1 (Management) - 10.0.1.0/24
    |   +-- OPNsense Firewall
    |   +-- k3s-master (10.0.1.100)
    |   +-- Synology NAS (10.0.1.50)
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

## Components

### Network & Security

- **TP-Link ER605**: Edge router with VLAN support
- **OPNsense**: Firewall and inter-VLAN routing
- **Network Policies**: Kubernetes NetworkPolicy for pod-level isolation
- **Cilium**: CNI with network policy enforcement (optional)

### Compute & Storage

- **k3s Cluster**: Lightweight Kubernetes distribution
  - Control plane: 1 node (MVP) or 3 nodes (HA)
  - Worker nodes: 2-3 nodes
- **Synology NAS**: Centralized storage
  - NFS/SMB shares for k3s persistent volumes
  - Samba AD integration for authentication

### Kubernetes Services

- **AdGuard Home**: DNS blocking and filtering
- **Traefik**: Ingress controller with TLS termination
- **cert-manager**: Automated TLS certificate management
- **Cloudflare Tunnel**: Secure external access without port forwarding

### Monitoring & Observability

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Dashboards and visualization
- **Loki**: Log aggregation
- **AlertManager**: Alert routing and notification
- **Promtail**: Log shipper

### Security Tools

- **Trivy**: Container image scanning
- **Falco**: Runtime security monitoring (optional)
- **Kyverno**: Kubernetes policy engine (optional)
- **fail2ban**: Intrusion prevention

## Firewall Rules

### Key Rules

1. **Management → Internet**: Allow HTTP/HTTPS/DNS
2. **Trusted LAN → Internet**: Full access
3. **IoT → Internet**: HTTP/HTTPS/DNS only
4. **IoT → Management/Trusted**: Deny all
5. **DMZ → Management**: Allow k3s API (6443)
6. **Internet → DMZ**: Allow HTTP/HTTPS (80/443)
7. **Guest → Internal**: Deny all

### SMB Rules

- **Management → Synology**: Allow SMB3 (TCP 445) with encryption
- **Trusted LAN → Synology**: Allow SMB3 (read-only)
- **IoT → Synology**: Deny all

## Storage Strategy

### Option 1: Longhorn (Distributed)

- Replicated storage across k3s nodes
- Automatic failover
- Snapshots and backups
- Requires 3+ nodes with local storage

### Option 2: Synology NFS

- Centralized storage on NAS
- Lower complexity
- Single point of failure
- Good for MVP

## Deployment Phases

### Phase 0: MVP

1. Bootstrap VMs
2. Install k3s (single control plane)
3. Deploy AdGuard Home
4. Deploy Traefik
5. Configure basic firewall rules

### Phase 1: Core Services

1. Deploy monitoring stack
2. Configure Cloudflare Tunnel
3. Set up cert-manager
4. Implement network policies

### Phase 2: Hardening

1. Integrate Synology with AD
2. Enable SMB encryption
3. Deploy security scanning
4. Set up backup procedures

### Phase 3: HA & Scale

1. Add k3s HA control plane
2. Add additional worker nodes
3. Implement Longhorn storage
4. Set up offsite backups

## Backup Strategy

### VM Snapshots

- Daily snapshots of critical VMs
- Retention: 7 days daily, 4 weeks weekly

### Synology Backups

- HyperBackup to cloud storage (Backblaze B2)
- Daily incremental backups
- Monthly full backups

### IaC State

- Terraform state in remote backend (S3)
- Git repository for all manifests
- Regular exports of k3s cluster config

## Monitoring & Alerting

### Key Metrics

- Node CPU/Memory/Disk usage
- Pod restart counts
- DNS query rates
- Network traffic patterns
- Certificate expiration

### Alert Channels

- Email (via SMTP)
- Webhook (for integrations)
- Grafana notifications

## Security Hardening

1. **Network Segmentation**: Strict VLAN isolation
2. **Default Deny**: Network policies block all by default
3. **TLS Everywhere**: All services use HTTPS
4. **Secret Management**: Ansible Vault + Kubernetes secrets
5. **Regular Updates**: Automated security patches
6. **Access Control**: RBAC for Kubernetes, firewall rules for network

## Troubleshooting

### Common Issues

1. **k3s not accessible**: Check firewall rules, verify kubeconfig
2. **DNS not resolving**: Check AdGuard Home pod status
3. **Services unreachable**: Verify Traefik ingress routes
4. **Storage issues**: Check PVC status, verify NFS/SMB mounts

### Debug Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Check network policies
kubectl get networkpolicies --all-namespaces

# Check services
kubectl get svc --all-namespaces

# View logs
kubectl logs -n dns-system deployment/adguard-home
```

## References

- [k3s Documentation](https://k3s.io/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome)
- [OPNsense Documentation](https://docs.opnsense.org/)

