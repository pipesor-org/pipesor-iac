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

module "service_bus" {
  count             = var.service_bus == null ? 0 : 1
  source            = "../../modules/service-bus"
  environment       = "qa"
  resource_group_id = module.resource_group.resource_group.id
  configuration     = var.service_bus
}

module "postgresql" {
  count             = var.postgresql == null || var.container_platform == null ? 0 : 1
  source            = "../../modules/postgresql"
  environment       = "qa"
  resource_group_id = module.resource_group.resource_group.id
  configuration     = var.postgresql
  network = {
    id                           = module.container_platform[0].platform.network_id
    location                     = var.container_platform.location
    address_prefix               = var.container_platform.vnet_address_prefix
    infrastructure_subnet_prefix = var.container_platform.infrastructure_subnet_prefix
  }
}
