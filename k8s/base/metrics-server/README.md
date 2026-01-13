# Metrics Server

## Overview

The Kubernetes Metrics Server is a cluster-wide aggregator of resource usage data.

## Installation

Metrics Server is typically installed automatically with k3s. If you need to install it manually or use a custom configuration, add manifests here.

## Default k3s Installation

k3s includes metrics-server by default. No additional configuration is required for basic usage.

## Custom Installation

If you need a custom metrics-server configuration:

1. Add your manifests to this directory
2. Update `k8s/base/kustomization.yaml` to include this directory
3. ArgoCD will automatically sync the changes

## Resources

- [Kubernetes Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [k3s Documentation](https://docs.k3s.io/)

