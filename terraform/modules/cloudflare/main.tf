# Cloudflare DNS and Tunnel management module

# Cloudflare Tunnel for secure access
resource "cloudflare_tunnel" "homelab" {
  account_id = var.cloudflare_account_id
  name       = "homelab-tunnel"
  secret     = var.cloudflare_tunnel_secret
}

# DNS records for services
resource "cloudflare_record" "services" {
  for_each = var.services

  zone_id = var.cloudflare_zone_id
  name    = each.key
  value   = split(":", each.value)[0]  # Extract IP from "IP:PORT"
  type    = "A"
  ttl     = 300
  comment = "Managed by Terraform - ${each.key} service"
}

# Cloudflare Tunnel configuration
resource "cloudflare_tunnel_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.homelab.id

  config {
    ingress_rule {
      hostname = "${var.domain}"
      service  = "http://10.0.1.1:80"
    }

    dynamic "ingress_rule" {
      for_each = var.services
      content {
        hostname = "${ingress_rule.key}.${var.domain}"
        service  = "http://${ingress_rule.value}"
      }
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

