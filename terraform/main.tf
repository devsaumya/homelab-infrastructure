# Root composition of modules
module "cloudflare" {
  source = "./modules/cloudflare"

  domain              = var.domain
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id  = var.cloudflare_zone_id
  cloudflare_account_id = var.cloudflare_account_id
  services            = var.services
}

module "monitoring" {
  source = "./modules/monitoring"

  domain = var.domain
}

