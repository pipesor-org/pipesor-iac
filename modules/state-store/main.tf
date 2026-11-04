module "naming" {
  source        = "Azure/avm-utl-naming/azure"
  version       = "0.3.0"
  suffix        = ["pipesor", "state", var.environment]
  unique_length = 0
}
module "resource_group" {
  source           = "Azure/avm-res-resources-resourcegroup/azurerm"
  version          = "0.4.0"
  name             = module.naming.names.resource_group.name
  location         = var.settings.location
  enable_telemetry = false
}
module "storage" {
  source                          = "Azure/avm-res-storage-storageaccount/azurerm"
  version                         = "0.8.0"
  name                            = var.settings.account_name
  parent_id                       = module.resource_group.resource_id
  location                        = var.settings.location
  account_kind                    = "StorageV2"
  account_sku_name                = "Standard_${var.settings.replication}"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  local_user_enabled              = false
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  public_network_access_enabled   = true
  network_rules = {
    default_action = "Deny"
    bypass         = ["None"]
    ip_rules       = var.settings.allowed_ips
  }
  enable_telemetry = false
  # Children are owned below so their recovery and access contracts are independently testable.
  blob_properties = null
  containers      = {}
}
module "blob_service" {
  source             = "Azure/avm-res-storage-storageaccount/azurerm//modules/blob_service"
  version            = "0.8.0"
  storage_account_id = module.storage.resource_id
  blob_properties = {
    versioning_enabled = true
    delete_retention_policy = {
      enabled                = true
      days                   = var.settings.recovery_days
      allow_permanent_delete = false
    }
    container_delete_retention_policy = {
      enabled                = true
      days                   = var.settings.recovery_days
      allow_permanent_delete = false
    }
  }
}
module "container" {
  source                                    = "Azure/avm-res-storage-storageaccount/azurerm//modules/container"
  version                                   = "0.8.0"
  name                                      = "tfstate-${var.environment}"
  storage_account_id                        = module.storage.resource_id
  public_access                             = "None"
  role_assignment_definition_lookup_enabled = false
  role_assignments = {
    for id in var.settings.principal_ids : lower(id) => {
      principal_id               = lower(id)
      role_definition_id_or_name = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe"
    }
  }
  depends_on = [module.blob_service]
}
