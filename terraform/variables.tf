variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS and tunnel management"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Primary domain name for services"
  type        = string
  default     = "homelab.local"
}

variable "services" {
  description = "Map of service names to internal IP:port addresses"
  type = map(string)
  default = {
    grafana = "10.0.1.105:3000"
    traefik = "10.0.1.80:9000"
    adguard = "10.0.1.53:3000"
  }
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for DNS management"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID for tunnel management"
  type        = string
  sensitive   = true
}

