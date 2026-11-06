resource "azapi_resource" "site" {
  type      = "Microsoft.Web/staticSites@2024-11-01"
  name      = var.configuration.name
  parent_id = var.resource_group_id
  location  = var.configuration.location
  tags      = { environment = var.environment }
  body = {
    sku = { name = "Free", tier = "Free" }
    properties = {
      publicNetworkAccess      = "Enabled"
      enterpriseGradeCdnStatus = "Disabled"
      stagingEnvironmentPolicy = "Disabled"
      buildProperties          = { skipGithubActionWorkflowGeneration = true }
    }
  }
  response_export_values           = ["properties.defaultHostname"]
  replace_triggers_external_values = [var.configuration.location]
}
