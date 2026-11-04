module "naming" {
  source  = "Azure/avm-utl-naming/azure"
  version = "0.3.0"

  suffix        = ["pipesor", var.environment]
  unique_length = 0
}

module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.4.0"

  name             = module.naming.names.resource_group.name
  location         = var.location
  enable_telemetry = false
}
