resource "azapi_resource" "account" {
  type      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name      = var.configuration.account_name
  parent_id = var.resource_group_id
  location  = var.configuration.location
  tags      = { environment = var.environment }
  identity { type = "SystemAssigned" }
  body = {
    kind = "AIServices"
    sku  = { name = "S0" }
    properties = {
      allowProjectManagement = true
      customSubDomainName    = var.configuration.account_name
      disableLocalAuth       = true
      publicNetworkAccess    = "Enabled"
      networkAcls = {
        defaultAction       = "Allow"
        ipRules             = []
        virtualNetworkRules = []
      }
    }
  }
  response_export_values           = ["properties.endpoint"]
  replace_triggers_external_values = [var.configuration.location]
}

resource "azapi_resource" "project" {
  type      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name      = var.configuration.project_name
  parent_id = azapi_resource.account.id
  location  = var.configuration.location
  tags      = { environment = var.environment }
  identity { type = "SystemAssigned" }
  body = {
    properties = {
      displayName = var.configuration.project_name
    }
  }
  lifecycle {
    replace_triggered_by = [azapi_resource.account]
  }
}
