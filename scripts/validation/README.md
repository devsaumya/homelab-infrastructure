# Validation

This directory contains validation scripts and tests for the homelab infrastructure contracts.

## Contract Validation

The `validate_contracts.py` script validates consistency across all contract files:

- **VLAN consistency**: Ensures VLAN IDs are unique and match across files
- **IPAM validation**: Validates CIDR ranges, gateways, and IP reservations
- **DNS consistency**: Checks DNS records match IPAM reservations
- **Access matrix**: Validates firewall rules reference valid VLANs
- **Platform config**: Validates platform configuration

### Usage

```bash
# Run validation
python3 validation/validate_contracts.py

# Or make it executable and run directly
chmod +x validation/validate_contracts.py
./validation/validate_contracts.py
```

### Requirements

- Python 3.6+
- PyYAML (`pip install pyyaml`)

### Example Output

```
Loading contract files...
Validating VLANs...
Validating IPAM...
Validating DNS zones...
Validating access matrix...
Validating platform configuration...

============================================================
✅ All contracts are valid!
============================================================
```

## Validation Gates

Validation gates can be integrated into CI/CD pipelines:

1. **Pre-commit**: Run validation before commits
2. **Pre-deployment**: Validate contracts before applying infrastructure changes
3. **Scheduled checks**: Periodic validation to catch drift

### Pre-commit Hook Example

```bash
#!/bin/bash
# .git/hooks/pre-commit

python3 validation/validate_contracts.py
if [ $? -ne 0 ]; then
    echo "Contract validation failed. Please fix errors before committing."
    exit 1
fi
```

## Future Enhancements

- Schema validation using JSON Schema or similar
- Network topology validation
- Security policy validation
- Integration with Terraform/Ansible validation
