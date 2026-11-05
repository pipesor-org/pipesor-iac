output "platform" {
  description = "Nonsecret resource IDs and names for later explicitly approved service deployment."
  value = {
    environment_id           = azapi_resource.environment.id
    environment_name         = azapi_resource.environment.name
    infrastructure_subnet_id = azapi_resource.subnet.id
    workspace_id             = azapi_resource.workspace.id
    workspace_name           = azapi_resource.workspace.name
    network_id               = azapi_resource.network.id
    network_name             = azapi_resource.network.name
  }
}
