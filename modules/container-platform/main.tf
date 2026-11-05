module "naming" {
  source        = "Azure/avm-utl-naming/azure"
  version       = "0.3.0"
  suffix        = ["pipesor", var.environment]
  unique_length = 0
}
resource "azapi_resource" "network" {
  type                  = "Microsoft.Network/virtualNetworks@2024-05-01"
  parent_id             = var.resource_group_id
  name                  = module.naming.names.virtual_network.name
  location              = var.configuration.location
  body                  = { properties = { addressSpace = { addressPrefixes = [var.configuration.vnet_address_prefix] } } }
  replace_triggers_refs = ["properties.addressSpace.addressPrefixes"]
}
resource "azapi_resource" "subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  parent_id = azapi_resource.network.id
  name      = module.naming.names.virtual_network_subnet.name
  body = { properties = {
    addressPrefix = var.configuration.infrastructure_subnet_prefix
    delegations   = [{ name = "container-apps", properties = { serviceName = "Microsoft.App/environments" } }]
  } }
  replace_triggers_refs = ["properties.addressPrefix"]
  lifecycle { replace_triggered_by = [azapi_resource.network] }
}
resource "azapi_resource" "workspace" {
  type      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  parent_id = var.resource_group_id
  name      = module.naming.names.operational_insights_workspace.name
  location  = var.configuration.location
  body = { properties = {
    sku                             = { name = "PerGB2018" }
    retentionInDays                 = var.configuration.log_retention_days
    workspaceCapping                = { dailyQuotaGb = var.configuration.log_daily_cap_gb }
    features                        = { disableLocalAuth = true, enableLogAccessUsingOnlyResourcePermissions = false }
    publicNetworkAccessForIngestion = "Enabled"
    publicNetworkAccessForQuery     = "Enabled"
  } }
}
resource "azapi_resource" "environment" {
  type      = "Microsoft.App/managedEnvironments@2025-07-01"
  parent_id = var.resource_group_id
  name      = module.naming.names.managed_environment.name
  location  = var.configuration.location
  body = { properties = {
    workloadProfiles     = [{ name = "Consumption", workloadProfileType = "Consumption" }]
    zoneRedundant        = false
    publicNetworkAccess  = "Enabled"
    vnetConfiguration    = { infrastructureSubnetId = azapi_resource.subnet.id, internal = false }
    appLogsConfiguration = { destination = "azure-monitor" }
  } }
  # Network allocation is immutable after environment creation, including subnet sizing.
  replace_triggers_external_values = {
    vnet_prefix   = var.configuration.vnet_address_prefix
    subnet_prefix = var.configuration.infrastructure_subnet_prefix
  }
  replace_triggers_refs = ["properties.vnetConfiguration", "properties.zoneRedundant", "properties.workloadProfiles"]
  lifecycle { replace_triggered_by = [azapi_resource.subnet] }
}
resource "azapi_resource" "logs" {
  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  parent_id = azapi_resource.environment.id
  name      = "platform-logs"
  body = { properties = {
    workspaceId                 = azapi_resource.workspace.id
    logAnalyticsDestinationType = "Dedicated"
    logs = [
      { category = "ContainerAppSystemLogs", enabled = true },
      { category = "ContainerAppConsoleLogs", enabled = true }
    ]
  } }
}
