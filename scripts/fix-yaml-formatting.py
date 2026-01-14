#!/usr/bin/env python3
"""
Fix common yamllint errors in YAML files.
- Adds missing newline at end of files
- Removes extra blank lines at end of files
"""

import os
import sys
from pathlib import Path


def fix_yaml_file(filepath):
    """Fix common yamllint issues in a YAML file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if not content:
            return False
        
        original_content = content
        
        # Remove trailing blank lines (keep only one newline at end)
        content = content.rstrip() + '\n'
        
        if content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ Fixed: {filepath}")
            return True
        
        return False
    except Exception as e:
        print(f"❌ Error fixing {filepath}: {e}")
        return False


def main():
    """Find and fix all YAML files."""
    base_dirs = ['k8s', 'infra']
    fixed_count = 0
    
    for base_dir in base_dirs:
        if not os.path.exists(base_dir):
            continue
        
        for yaml_file in Path(base_dir).rglob('*.yaml'):
            if fix_yaml_file(yaml_file):
                fixed_count += 1
        
        for yml_file in Path(base_dir).rglob('*.yml'):
            if fix_yaml_file(yml_file):
                fixed_count += 1
    
    print(f"\n✅ Fixed {fixed_count} files")
    return 0


if __name__ == '__main__':
    sys.exit(main())
