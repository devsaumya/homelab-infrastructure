# Bootstrap Guide

This guide covers the initial setup and bootstrap process for the homelab infrastructure.

## Prerequisites

1. Install required tools:
   ```bash
   ./scripts/setup/00-prereqs.sh
   ```

   Required tools:
   - Terraform >= 1.5.0
   - Ansible >= 2.9
   - kubectl
   - Docker
   - Git

## Step 1: Configure Infrastructure

### Ansible Inventory

Edit `infra/ansible/inventory/hosts.yml` with your VM IPs and hostnames.

### Ansible Secrets

Encrypt secrets with Ansible Vault:
```bash
ansible-vault encrypt infra/ansible/inventory/group_vars/all/vault.yml
```

### Terraform Configuration

1. Copy the example terraform variables:
   ```bash
   cp infra/terraform/environments/production/terraform.tfvars.example terraform.tfvars
   ```

2. Fill in your Cloudflare credentials and other variables.

## Step 2: Manual Router/NAS Configuration

Configure the following manually via web UI:

- **ER605 Router**: VLANs, DHCP, firewall rules
- **Synology NAS**: Storage pools, shares, SMB settings

See `docs/HARDWARE_SETUP.md` for detailed instructions.

## Step 3: Bootstrap VMs

Run the Ansible bootstrap playbook:
```bash
./scripts/setup/02-vm-bootstrap.sh
```

This will:
- Harden the base OS
- Install required packages
- Configure Docker
- Install k3s

## Step 4: Provision External Infrastructure

Deploy Cloudflare resources:
```bash
cd infra/terraform/environments/production
terraform init
terraform plan
terraform apply
```

## Step 5: Install ArgoCD (One-Time Manual Step)

ArgoCD must be installed manually before it can manage itself:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Or use Helm:
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd --create-namespace
```

Wait for ArgoCD to be ready:
```bash
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

## Step 6: Deploy Root Application

Once ArgoCD is running, deploy the root application:

```bash
kubectl apply -f k8s/root-app.yaml
```

This will:
- Create the ArgoCD project (if needed)
- Deploy the root application that manages all other apps
- ArgoCD will automatically discover and sync all applications in `k8s/apps/`

## Step 7: Deploy Docker Stacks (VM2)

Deploy monitoring and other Docker Compose stacks:

```bash
./scripts/deployment/deploy-monitoring.sh
```

Or manually via Ansible:
```bash
ansible-playbook -i infra/ansible/inventory/hosts.yml infra/ansible/playbooks/02-monitoring.yml
```

## Verification

1. Check ArgoCD UI:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   # Access https://localhost:8080
   # Default username: admin
   # Get password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

2. Check applications:
   ```bash
   kubectl get applications -n argocd
   ```

3. Health check:
   ```bash
   ./scripts/maintenance/health-check.sh
   ```

## Next Steps

- Review [Operations Guide](operations.md) for day-to-day management
- See [Architecture](architecture.md) for system design details

