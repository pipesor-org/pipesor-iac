module "state_store" {
  source          = "../../modules/state-store"
  environment     = "preprod"
  subscription_id = var.subscription_id
  settings        = var.settings
}
