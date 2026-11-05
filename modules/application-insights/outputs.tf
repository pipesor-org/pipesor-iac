output "telemetry" {
  description = "Component identity and routing connection string for approved backend deployment contracts; Entra credentials and permissions are still required."
  value = {
    id                = azapi_resource.component.id
    name              = azapi_resource.component.name
    location          = azapi_resource.component.location
    workspace_id      = var.workspace.id
    connection_string = azapi_resource.component.output.properties.ConnectionString
  }
}
