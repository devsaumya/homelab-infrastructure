variable "public_domain" {
  description = "Public domain name for internet-facing services (e.g., connect2home.online)"
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
  description = "Map of service names to internal IP:port (legacy)"
  type        = map(string)
  default     = {}
}

variable "public_services" {
  description = "List of service names that should be exposed publicly via Cloudflare"
  type        = list(string)
}

