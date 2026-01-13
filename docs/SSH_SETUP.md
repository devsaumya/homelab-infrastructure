# SSH Key Setup for Ansible

## Overview

Ansible requires SSH key authentication to connect to your VMs. This guide helps you set up SSH keys for passwordless access.

## Quick Setup

### Option 1: Automated Script

```bash
./scripts/setup/03-setup-ssh-keys.sh
```

This script will:
- Check for existing SSH key or generate one
- Copy your public key to both VMs
- Test the connections

### Option 2: Manual Setup

#### Step 1: Generate SSH Key (if needed)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_rsa -N "" -C "ansible@homelab"
```

#### Step 2: Copy Public Key to VMs

```bash
# Copy to k3s-master
ssh-copy-id -i ~/.ssh/id_rsa.pub homelab@10.0.1.108

# Copy to security-ops
ssh-copy-id -i ~/.ssh/id_rsa.pub homelab@10.0.1.109
```

You'll be prompted for the password on each VM during this step.

#### Step 3: Test Connection

```bash
# Test k3s-master
ssh homelab@10.0.1.108 "echo 'Connection successful'"

# Test security-ops
ssh homelab@10.0.1.109 "echo 'Connection successful'"
```

Both should work without password prompts.

## Verify Ansible Connection

After setting up SSH keys, test Ansible:

```bash
cd infra/ansible
ansible all -i inventory/hosts.yml -m ping
```

Expected output:
```
k3s-master | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
security-ops | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
synology-nas | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

## Troubleshooting

### Permission Denied Errors

If you see `Permission denied (publickey,password)`:

1. **Verify SSH key exists:**
   ```bash
   ls -la ~/.ssh/id_rsa
   ```

2. **Check key permissions:**
   ```bash
   chmod 600 ~/.ssh/id_rsa
   chmod 644 ~/.ssh/id_rsa.pub
   ```

3. **Verify key is on remote host:**
   ```bash
   ssh homelab@10.0.1.108 "cat ~/.ssh/authorized_keys"
   ```
   Should show your public key.

4. **Check remote permissions:**
   ```bash
   ssh homelab@10.0.1.108 "ls -la ~/.ssh/"
   ```
   Should show:
   - `~/.ssh` directory: `drwx------` (700)
   - `~/.ssh/authorized_keys`: `-rw-------` (600)

### Using Different SSH Key

If your SSH key is in a different location:

1. **Update inventory:**
   Edit `infra/ansible/inventory/hosts.yml`:
   ```yaml
   vars:
     ansible_ssh_private_key_file: /path/to/your/key
   ```

2. **Or set per-host:**
   ```yaml
   k3s-master:
     ansible_ssh_private_key_file: /path/to/your/key
   ```

### SSH Key Not in Default Location

If your key is not at `~/.ssh/id_rsa`:

```bash
# Set environment variable
export SSH_KEY=~/.ssh/my_custom_key

# Run setup script
./scripts/setup/03-setup-ssh-keys.sh
```

## Security Notes

- **Never commit private keys** to the repository
- Use strong passphrases for production keys
- Consider using separate keys for different environments
- Rotate keys periodically

## Next Steps

After SSH keys are configured:
1. Test Ansible connection: `ansible all -i inventory/hosts.yml -m ping`
2. Proceed with VM bootstrap: `./scripts/setup/02-vm-bootstrap.sh`

