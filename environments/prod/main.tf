module "resource_group" {
  source = "../../modules/resource-group"

  environment = "prod"
  location    = var.location
}

module "container_platform" {
  count             = var.container_platform == null ? 0 : 1
  source            = "../../modules/container-platform"
  environment       = "prod"
  resource_group_id = module.resource_group.resource_group.id
  configuration     = var.container_platform
}

module "service_bus" {
  count             = var.service_bus == null ? 0 : 1
  source            = "../../modules/service-bus"
  environment       = "prod"
  resource_group_id = module.resource_group.resource_group.id
  configuration     = var.service_bus
}

module "postgresql" {
  count             = var.postgresql == null || var.container_platform == null ? 0 : 1
  source            = "../../modules/postgresql"
  environment       = "prod"
  resource_group_id = module.resource_group.resource_group.id
  configuration     = var.postgresql
  network = {
    id                           = module.container_platform[0].platform.network_id
    location                     = var.container_platform.location
    address_prefix               = var.container_platform.vnet_address_prefix
    infrastructure_subnet_prefix = var.container_platform.infrastructure_subnet_prefix
  }
}

module "application_insights" {
  count             = var.application_insights_enabled && var.container_platform != null ? 1 : 0
  source            = "../../modules/application-insights"
  environment       = "prod"
  resource_group_id = module.resource_group.resource_group.id
  workspace = {
    id       = module.container_platform[0].platform.workspace_id
    location = var.container_platform.location
  }
}

module "foundry" {
  count             = var.foundry == null ? 0 : 1
  source            = "../../modules/foundry"
  environment       = "prod"
  resource_group_id = module.resource_group.resource_group.id
  configuration     = var.foundry
}

module "static_web_app" {
  count             = var.static_web_app == null ? 0 : 1
  source            = "../../modules/static-web-app"
  environment       = "prod"
  resource_group_id = module.resource_group.resource_group.id
  configuration     = var.static_web_app
}
