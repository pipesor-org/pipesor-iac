mock_provider "azapi" {}
variables {
  environment       = "dev"
  resource_group_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev"
  workspace         = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.OperationalInsights/workspaces/log-pipesor-dev", location = "workloadregion" }
}
override_resource {
  target          = azapi_resource.component
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Insights/components/appipipesordev", output = { properties = { ConnectionString = "synthetic-routing-fixture" } } }
}
run "workspace_auth_privacy_contract" {
  command = plan
  assert {
    condition     = azapi_resource.component.body.properties == { Application_Type = "web", Flow_Type = "Bluefield", WorkspaceResourceId = var.workspace.id, DisableLocalAuth = true, DisableIpMasking = false, publicNetworkAccessForIngestion = "Enabled", publicNetworkAccessForQuery = "Enabled" }
    error_message = "Keep workspace-based Entra-only ingestion and public endpoints with IP masking; do not invent sampling, retention or storage."
  }
  assert {
    condition     = azapi_resource.component.parent_id == var.resource_group_id && azapi_resource.component.location == var.workspace.location && azapi_resource.component.name == "appipipesordev" && azapi_resource.component.tags.environment == "dev"
    error_message = "Use this environment's resource group, existing workspace location and naming contract."
  }
  assert {
    condition     = output.telemetry.id == azapi_resource.component.id && output.telemetry.connection_string == "synthetic-routing-fixture" && output.telemetry.workspace_id == var.workspace.id && azapi_resource.component.response_export_values == ["properties.ConnectionString"]
    error_message = "Export only the component routing contract without additional API keys or response data."
  }
  assert {
    condition     = toset(azapi_resource.component.replace_triggers_refs) == toset(["properties.WorkspaceResourceId"]) && azapi_resource.component.replace_triggers_external_values == { location = var.workspace.location }
    error_message = "Workspace reassignment and location changes must retain their declared replacement contract."
  }
}

run "reject_environment" {
  command = plan
  variables { environment = "other" }
  expect_failures = [var.environment]
}

run "reject_resource_group" {
  command = plan
  variables { resource_group_id = "not-an-arm-id" }
  expect_failures = [var.resource_group_id]
}

run "reject_workspace" {
  command = plan
  variables { workspace = { id = "not-a-workspace", location = "workloadregion" } }
  expect_failures = [var.workspace]
}

run "reject_region" {
  command = plan
  variables { workspace = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.OperationalInsights/workspaces/log-pipesor-dev", location = " " } }
  expect_failures = [var.workspace]
}
