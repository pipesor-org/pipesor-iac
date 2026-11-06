provider "azapi" {
  subscription_id              = var.subscription_id
  skip_provider_registration   = true
  enable_preflight             = false
  disable_terraform_partner_id = true
}
