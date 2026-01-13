variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS and tunnel management"
  type        = string
  sensitive   = true
}

variable "internal_domain" {
  description = "Internal domain name for LAN-only services (e.g., home.internal)"
  type        = string
  default     = "home.internal"
}

variable "public_domain" {
  description = "Public domain name for internet-facing services (e.g., connect2home.online)"
  type        = string
  default     = "connect2home.online"
}

variable "services" {
  description = "Map of service names to internal IP:port addresses (legacy, kept for backward compatibility)"
  type = map(string)
  default = {}
}

variable "public_services" {
  description = "List of service names that should be exposed publicly via connect2home.online"
  type = list(string)
  default = ["grafana", "home"]
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

