module "resource_group" {
  source = "../../modules/resource-group"

  environment = "dev"
  location    = var.location
}

module "container_platform" {
  count             = var.container_platform == null ? 0 : 1
  source            = "../../modules/container-platform"
  environment       = "dev"
  resource_group_id = module.resource_group.resource_group.id
  configuration     = var.container_platform
}
