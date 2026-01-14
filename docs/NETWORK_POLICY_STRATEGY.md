# Network Policy Strategy

## Overview

Network policies in this repository use **namespace injection** via Kustomize instead of hardcoded namespace declarations. This approach provides flexibility and reusability across different namespaces.

## Structure

```
k8s/base/networking/network-policies/
├── kustomization.yaml       # Defines namespace injection
├── default-deny.yaml        # Default deny-all policy
├── allow-dns.yaml          # Allow DNS queries
└── allow-internet.yaml     # Allow internet egress
```

## How It Works

### 1. Policy Templates

Network policy manifests do **not** include a `namespace:` field in their metadata:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  # NO namespace field here
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### 2. Namespace Injection

The `kustomization.yaml` file specifies the target namespace:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: default  # Policies will be deployed to this namespace

resources:
  - default-deny.yaml
  - allow-dns.yaml
  - allow-internet.yaml
```

### 3. Deployment

When ArgoCD or `kubectl kustomize` processes these files, the namespace is automatically injected into each resource.

## Benefits

✅ **Reusability**: Same policy templates can be used across multiple namespaces
✅ **Maintainability**: Single source of truth for policy definitions
✅ **Flexibility**: Easy to create namespace-specific overlays
✅ **CI/CD Friendly**: Automated validation catches hardcoded namespaces

## Creating Namespace-Specific Policies

To deploy these policies to a different namespace, create an overlay:

```
k8s/overlays/my-namespace/
├── kustomization.yaml
└── (optional) patches/
```

Example `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: my-namespace  # Override target namespace

bases:
  - ../../base/networking/network-policies/
```

## Validation

The CI pipeline validates that application manifests do not contain hardcoded `namespace: default` declarations:

```bash
# This will fail CI:
metadata:
  name: my-policy
  namespace: default  # ❌ Hardcoded namespace

# This is correct:
metadata:
  name: my-policy
  # ✅ Namespace injected by kustomize
```

## Legitimate Uses of `namespace: default`

The following uses are acceptable and excluded from CI checks:

- **ArgoCD Application destinations**: `spec.destination.namespace: default`
- **AppProject destinations**: `spec.destinations[].namespace: default`
- **Environment configurations**: Files in `k8s/environments/`

## References

- [Kustomize Namespace Transformer](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/namespace/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
