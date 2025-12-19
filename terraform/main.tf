# Root composition of modules
module "cloudflare" {
  source = "./modules/cloudflare"

  public_domain        = var.public_domain
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
  cloudflare_account_id = var.cloudflare_account_id
  services             = var.services
  public_services      = var.public_services
}

module "monitoring" {
  source = "./modules/monitoring"

  public_domain = var.public_domain
  internal_domain = var.internal_domain
}

