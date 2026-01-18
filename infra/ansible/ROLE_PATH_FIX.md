# Ansible CI Fix - Role Path Issue

This fix addresses the CI error: `the role 'common' was not found`

## Problem

The `ansible.cfg` file had `roles_path = roles` which is a relative path. When playbooks are executed from the `playbooks/` directory (as in CI), Ansible looks for:
- `/path/to/playbooks/roles/` ❌ (doesn't exist)

Instead of:
- `/path/to/ansible/roles/` ✅ (actual location)

## Solution

Updated `infra/ansible/ansible.cfg` to include proper role search paths:

```ini
roles_path = ./roles:~/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles
```

This tells Ansible to search for roles in:
1. `./roles` - Relative to the `ansible.cfg` location (`infra/ansible/roles/`)
2. `~/.ansible/roles` - User's Ansible roles directory
3. `/usr/share/ansible/roles` - System-wide roles
4. `/etc/ansible/roles` - System config roles

## Verification

To verify the fix works:

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/00-bootstrap.yml --syntax-check

# Expected: Playbook Syntax is fine
```

Or test role resolution:

```bash
cd infra/ansible
ansible-galaxy role list

# Should show roles from infra/ansible/roles/
```

## CI Pipeline Fix

This fix will resolve the GitHub Actions error where the CI pipeline couldn't find the `common` role during playbook execution.
