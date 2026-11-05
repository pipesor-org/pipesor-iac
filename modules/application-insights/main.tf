module "naming" {
  source        = "Azure/avm-utl-naming/azure"
  version       = "0.3.0"
  suffix        = ["pipesor", var.environment]
  unique_length = 0
}
resource "azapi_resource" "component" {
  type      = "Microsoft.Insights/components@2020-02-02"
  parent_id = var.resource_group_id
  name      = module.naming.names.component.name
  location  = var.workspace.location
  tags      = { environment = var.environment }
  body = {
    kind = "web"
    properties = {
      Application_Type                = "web"
      Flow_Type                       = "Bluefield"
      WorkspaceResourceId             = var.workspace.id
      DisableLocalAuth                = true
      DisableIpMasking                = false
      publicNetworkAccessForIngestion = "Enabled"
      publicNetworkAccessForQuery     = "Enabled"
    }
  }
  response_export_values           = ["properties.ConnectionString"]
  replace_triggers_refs            = ["properties.WorkspaceResourceId"]
  replace_triggers_external_values = { location = var.workspace.location }
}
