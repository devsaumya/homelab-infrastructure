# Cloudflare DNS and Tunnel management module

# Cloudflare Tunnel for secure access
resource "cloudflare_tunnel" "homelab" {
  account_id = var.cloudflare_account_id
  name       = "homelab-tunnel"
  secret     = var.cloudflare_tunnel_secret
}

# Cloudflare Tunnel configuration
# Tunnel routes all public services through Traefik ingress controller
resource "cloudflare_tunnel_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.homelab.id

  config {
    # Main entrypoint - routes to Traefik which handles routing to services
    ingress_rule {
      hostname = "${var.public_domain}"
      service  = "https://traefik.ingress-traefik.svc.cluster.local:443"
    }

    # Individual service hostnames - all route through Traefik
    dynamic "ingress_rule" {
      for_each = toset(var.public_services)
      content {
        hostname = "${ingress_rule.value}.${var.public_domain}"
        service  = "https://traefik.ingress-traefik.svc.cluster.local:443"
      }
    }

    # Catch-all 404
    ingress_rule {
      service = "http_status:404"
    }
  }
}

