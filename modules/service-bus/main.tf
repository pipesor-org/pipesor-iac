resource "azapi_resource" "namespace" {
  type      = "Microsoft.ServiceBus/namespaces@2024-01-01"
  name      = var.configuration.namespace_name
  parent_id = var.resource_group_id
  location  = var.configuration.location
  tags      = { environment = var.environment }

  body = {
    sku = {
      name = "Standard"
      tier = "Standard"
    }
    properties = {
      disableLocalAuth    = true
      publicNetworkAccess = "Enabled"
      minimumTlsVersion   = "1.2"
    }
  }
}
