module "resource_group" {
  source = "../../modules/resource-group"

  environment = "dev"
  location    = var.location
}

module "container_platform" {
  count                              = var.container_platform == null ? 0 : 1
  source                             = "../../modules/container-platform"
  environment                        = "dev"
  resource_group_id                  = module.resource_group.resource_group.id
  configuration                      = var.container_platform
  key_vault_service_endpoint_enabled = var.key_vault != null
}

module "service_bus" {
  count             = var.service_bus == null ? 0 : 1
  source            = "../../modules/service-bus"
  environment       = "dev"
  resource_group_id = module.resource_group.resource_group.id
  configuration     = var.service_bus
}

module "postgresql" {
  count             = var.postgresql == null || var.container_platform == null ? 0 : 1
  source            = "../../modules/postgresql"
  environment       = "dev"
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
  environment       = "dev"
  resource_group_id = module.resource_group.resource_group.id
  workspace = {
    id       = module.container_platform[0].platform.workspace_id
    location = var.container_platform.location
  }
}

module "foundry" {
  count             = var.foundry == null ? 0 : 1
  source            = "../../modules/foundry"
  environment       = "dev"
  resource_group_id = module.resource_group.resource_group.id
  configuration     = var.foundry
}

module "static_web_app" {
  count             = var.static_web_app == null ? 0 : 1
  source            = "../../modules/static-web-app"
  environment       = "dev"
  resource_group_id = module.resource_group.resource_group.id
  configuration     = var.static_web_app
}

module "key_vault" {
  count              = var.key_vault == null ? 0 : 1
  source             = "../../modules/key-vault"
  environment        = "dev"
  resource_group_id  = module.resource_group.resource_group.id
  configuration      = var.key_vault
  allowed_subnet_ids = var.container_platform == null ? [] : [module.container_platform[0].platform.infrastructure_subnet_id]
}

# Deployed application images are versioned in Git (images.json, schema 1): each entry is the
# candidate.json identity published by the service CI. Deploying, promoting or rolling back an image
# is a reviewed change to that file followed by a fresh plan; tools/images.js writes and checks it.
locals {
  deployed_images = jsondecode(file("${path.module}/images.json"))
  images          = { for workload, entry in local.deployed_images.images : workload => "${entry.image}@${entry.digest}" }
}

module "workloads" {
  count             = var.workloads == null ? 0 : 1
  source            = "../../modules/workloads"
  environment       = "dev"
  resource_group_id = module.resource_group.resource_group.id
  configuration = {
    location                 = var.container_platform.location
    platform_tenant_id       = var.workloads.platform_tenant_id
    container_environment_id = module.container_platform[0].platform.environment_id
    images                   = local.images
    registry                 = var.workloads.registry
    key_vault                = { id = module.key_vault[0].vaults["app_material"].id, uri = module.key_vault[0].vaults["app_material"].uri }
    custody_vault            = { id = module.key_vault[0].vaults["custody"].id, uri = module.key_vault[0].vaults["custody"].uri }
    service_bus = {
      namespace_name   = module.service_bus[0].namespace.name
      topic_id         = module.service_bus[0].topology.topic_id
      topic_name       = module.service_bus[0].topology.topic_name
      subscription_ids = module.service_bus[0].topology.subscription_ids
    }
    foundry = {
      account_id              = module.foundry[0].foundry.account_id
      account_name            = module.foundry[0].foundry.account_name
      chat_deployment         = var.workloads.chat_deployment
      embedding_deployment    = var.workloads.embedding_deployment
      embedding_model_version = var.workloads.embedding_model_version
    }
    postgresql = {
      server_id = module.postgresql[0].database.id
      fqdn      = module.postgresql[0].database.fqdn
      database  = var.workloads.database
      tenant_id = var.postgresql.tenant_id
    }
    github = var.workloads.github
  }
}
