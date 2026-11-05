module "resource_group" {
  source = "../../modules/resource-group"

  environment = "qa"
  location    = var.location
}

module "container_platform" {
  count             = var.container_platform == null ? 0 : 1
  source            = "../../modules/container-platform"
  environment       = "qa"
  resource_group_id = module.resource_group.resource_group.id
  configuration     = var.container_platform
}
