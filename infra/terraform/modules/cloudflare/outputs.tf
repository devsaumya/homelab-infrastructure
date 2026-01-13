output "tunnel_id" {
  description = "Cloudflare Tunnel ID"
  value       = cloudflare_tunnel.homelab.id
}

output "public_domain" {
  description = "Public domain configured"
  value       = var.public_domain
}

output "service_urls" {
  description = "Public URLs for services"
  value = {
    for service in var.public_services : service => "https://${service}.${var.public_domain}"
  }
}

