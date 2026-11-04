module "resource_group" {
  source = "../../modules/resource-group"

  environment = "qa"
  location    = var.location
}
