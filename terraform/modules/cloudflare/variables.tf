variable "domain" {
  description = "Primary domain name"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_tunnel_secret" {
  description = "Cloudflare Tunnel secret (base64 encoded)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "services" {
  description = "Map of service names to internal IP:port"
  type        = map(string)
}

