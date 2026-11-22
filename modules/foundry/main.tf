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

# Model deployments. Versions are pinned (no automatic upgrade) so the thesis evaluation keeps one model.
resource "azapi_resource" "deployment" {
  for_each  = var.configuration.deployments
  type      = "Microsoft.CognitiveServices/accounts/deployments@2025-06-01"
  name      = each.key
  parent_id = azapi_resource.account.id
  body = {
    sku = { name = each.value.sku_name, capacity = each.value.capacity }
    properties = {
      model                = { format = "OpenAI", name = each.value.model_name, version = each.value.model_version }
      versionUpgradeOption = "NoAutoUpgrade"
      raiPolicyName        = "Microsoft.DefaultV2"
    }
  }
  # Azure serializes deployment operations per account; a concurrent sibling update returns a conflict.
  retry = { error_message_regex = ["AnotherOperationInProgress", "RequestConflict", "Conflict"] }
}
