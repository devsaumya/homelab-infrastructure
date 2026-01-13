output "cloudflare_tunnel_id" {
  description = "Cloudflare Tunnel ID"
  value       = module.cloudflare.tunnel_id
  sensitive   = true
}

output "dns_records" {
  description = "Created DNS records"
  value       = module.cloudflare.dns_records
}

output "service_urls" {
  description = "Public URLs for services via Cloudflare Tunnel"
  value       = module.cloudflare.service_urls
}

