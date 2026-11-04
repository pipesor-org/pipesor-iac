module "state_store" {
  source          = "../../modules/state-store"
  environment     = "prod"
  subscription_id = var.subscription_id
  settings        = var.settings
}
