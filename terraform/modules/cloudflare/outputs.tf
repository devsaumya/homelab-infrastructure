output "tunnel_id" {
  description = "Cloudflare Tunnel ID"
  value       = cloudflare_tunnel.homelab.id
}

output "dns_records" {
  description = "Created DNS records"
  value = {
    for k, v in cloudflare_record.services : k => {
      name  = v.name
      value = v.value
      type  = v.type
    }
  }
}

output "service_urls" {
  description = "Public URLs for services"
  value = {
    for k, v in var.services : k => "https://${k}.${var.domain}"
  }
}

