# Cloudflare Tunnel (Edge)

This repository intentionally does not run Cloudflare Tunnel (`cloudflared`) inside Kubernetes. The Cloudflare Tunnel for this homelab is managed on the Synology NAS and acts as the single, always-on edge entry point for the network.

## Why the tunnel runs on the NAS

- **Always-on edge device**: The NAS is powered and reachable 24/7, making it a reliable tunnel host.
- **Single entry point**: Running the tunnel on the NAS keeps external ingress simple and auditable.
- **Avoids bootstrap dependency**: Running the tunnel inside Kubernetes creates a bootstrap dependency (cluster must be up to receive external connections). Putting it on the NAS avoids circular dependencies during cluster bootstrap, upgrades, or restores.
- **Reduces operational blast radius**: If the cluster is restarted, the tunnel remains available on the NAS. This reduces downtime for inbound traffic.

## How traffic flows

Internet → Cloudflare → Cloudflare Tunnel (Synology NAS) → Internal network

The NAS routes traffic to internal services, which may include:

- Kubernetes services exposed on the internal network (ClusterIP/NodePort/Traefik)
- Other NAS-hosted services (Synology apps)
- VM-hosted services

Kubernetes is behind the tunnel and does not act as the edge ingress.

## What changed in this repo

- The `k8s/apps/platform/cloudflare-tunnel` Kubernetes manifests have been removed from this repository and are no longer deployed by ArgoCD. The tunnel configuration is maintained on the Synology NAS instead.

## Recommendations

- Keep the tunnel configuration on the NAS and back up the `credentials.json` and `config.yml` securely (not in Git).
- Use internal DNS and Traefik/Ingress within the cluster to expose services to the NAS.
- Document any public hostnames and their internal targets in this `docs/edge` area for operational clarity.

If you want, I can add an example snippet showing how Traefik services map to Cloudflare hostnames.
