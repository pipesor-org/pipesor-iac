resource "azapi_resource" "subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  parent_id = var.network.id
  name      = "snet-pipesor-${var.environment}-postgresql"
  body = { properties = {
    addressPrefix = var.configuration.subnet_prefix
    delegations   = [{ name = "postgresql", properties = { serviceName = "Microsoft.DBforPostgreSQL/flexibleServers" } }]
  } }
  replace_triggers_refs            = ["properties.addressPrefix"]
  replace_triggers_external_values = { vnet_prefix = var.network.address_prefix, vnet_location = var.network.location }
}
resource "azapi_resource" "dns" {
  type      = "Microsoft.Network/privateDnsZones@2020-06-01"
  parent_id = var.resource_group_id
  name      = "pipesor-${var.environment}.postgres.database.azure.com"
  location  = "global"
  body      = { properties = {} }
}
resource "azapi_resource" "dns_link" {
  type                             = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01"
  parent_id                        = azapi_resource.dns.id
  name                             = "pipesor-${var.environment}"
  location                         = "global"
  body                             = { properties = { registrationEnabled = false, virtualNetwork = { id = var.network.id } } }
  replace_triggers_external_values = { vnet_id = var.network.id, vnet_prefix = var.network.address_prefix, vnet_location = var.network.location }
}
resource "azapi_resource" "server" {
  type      = "Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01"
  parent_id = var.resource_group_id
  name      = var.configuration.server_name
  location  = var.configuration.location
  tags      = { environment = var.environment }
  body = {
    sku = var.configuration.sku
    properties = {
      createMode       = "Default"
      version          = "17"
      authConfig       = { activeDirectoryAuth = "Enabled", passwordAuth = "Disabled", tenantId = var.configuration.tenant_id }
      backup           = { backupRetentionDays = 7, geoRedundantBackup = "Disabled" }
      highAvailability = { mode = "Disabled" }
      storage          = { storageSizeGB = 32, autoGrow = "Disabled", type = "Premium_LRS" }
      network          = { delegatedSubnetResourceId = azapi_resource.subnet.id, privateDnsZoneArmResourceId = azapi_resource.dns.id }
    }
  }
  response_export_values           = ["properties.fullyQualifiedDomainName"]
  replace_triggers_refs            = ["properties.network.delegatedSubnetResourceId"]
  replace_triggers_external_values = { location = var.configuration.location, network_id = var.network.id }
  depends_on                       = [azapi_resource.dns_link]
  lifecycle { replace_triggered_by = [azapi_resource.subnet] }
}
resource "azapi_resource" "administrator" {
  type      = "Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-08-01"
  parent_id = azapi_resource.server.id
  name      = var.configuration.administrator.object_id
  body = { properties = {
    principalName = var.configuration.administrator.principal_name
    principalType = var.configuration.administrator.principal_type
    tenantId      = var.configuration.tenant_id
  } }
  # Finish the server configuration write before Azure checks Entra admin accessibility.
  depends_on = [azapi_update_resource.extensions]
  lifecycle { replace_triggered_by = [azapi_resource.server] }
}
resource "azapi_update_resource" "extensions" {
  type      = "Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01"
  parent_id = azapi_resource.server.id
  name      = "azure.extensions"
  body      = { properties = { source = "user-override", value = "vector" } }
  lifecycle { replace_triggered_by = [azapi_resource.server] }
}
