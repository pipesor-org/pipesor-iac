output "foundry" {
  description = "Account/project identity and service-reported account endpoint; no keys or runtime access grants."
  value = {
    account_id   = azapi_resource.account.id
    account_name = azapi_resource.account.name
    project_id   = azapi_resource.project.id
    project_name = azapi_resource.project.name
    location     = azapi_resource.account.location
    endpoint     = azapi_resource.account.output.properties.endpoint
  }
}
