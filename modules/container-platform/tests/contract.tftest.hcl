mock_provider "azapi" {
  mock_data "azapi_client_config" { defaults = { subscription_id = "11111111-1111-1111-1111-111111111111" } }
}
variables {
  environment       = "dev"
  resource_group_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev"
  configuration = {
    location                     = "workloadregion"
    vnet_address_prefix          = "10.50.0.0/16"
    infrastructure_subnet_prefix = "10.50.1.0/24"
    log_retention_days           = 45
    log_daily_cap_gb             = 0.5
  }
}
override_resource {
  target          = azapi_resource.network
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev" }
}
override_resource {
  target          = azapi_resource.subnet
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev/subnets/snet-pipesor-dev" }
}
override_resource {
  target          = azapi_resource.workspace
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.OperationalInsights/workspaces/log-pipesor-dev" }
}
override_resource {
  target          = azapi_resource.environment
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.App/managedEnvironments/caepipesordev" }
}
run "consumption_network_and_logs_contract" {
  command = plan
  assert {
    condition     = !contains(keys(azapi_resource.subnet.body.properties), "serviceEndpoints")
    error_message = "Existing platform-only callers must retain their subnet contract without an endpoint."
  }
  assert {
    condition = alltrue([
      for resource in [azapi_resource.network, azapi_resource.workspace, azapi_resource.environment] :
      resource.parent_id == var.resource_group_id && resource.location == var.configuration.location
    ])
    error_message = "Every top-level platform resource must use the caller's resource group and workload location."
  }
  assert {
    condition     = output.platform.environment_id == azapi_resource.environment.id && output.platform.infrastructure_subnet_id == azapi_resource.subnet.id && output.platform.workspace_id == azapi_resource.workspace.id && output.platform.network_id == azapi_resource.network.id
    error_message = "Export each resource's own ID for downstream service wiring."
  }
  assert {
    condition     = toset(azapi_resource.network.replace_triggers_refs) == toset(["properties.addressSpace.addressPrefixes"]) && toset(azapi_resource.subnet.replace_triggers_refs) == toset(["properties.addressPrefix"]) && toset(azapi_resource.environment.replace_triggers_refs) == toset(["properties.vnetConfiguration", "properties.zoneRedundant", "properties.workloadProfiles"]) && azapi_resource.environment.replace_triggers_external_values == { vnet_prefix = var.configuration.vnet_address_prefix, subnet_prefix = var.configuration.infrastructure_subnet_prefix }
    error_message = "Keep the declared allocation replacement triggers; mocked plans do not establish provider replacement behavior."
  }
  assert {
    condition     = azapi_resource.environment.body.properties.workloadProfiles == [{ name = "Consumption", workloadProfileType = "Consumption" }] && azapi_resource.environment.body.properties.zoneRedundant == false
    error_message = "Use exactly one Consumption profile without Dedicated capacity or zone redundancy."
  }
  assert {
    condition     = azapi_resource.environment.body.properties.vnetConfiguration.internal == false && azapi_resource.environment.body.properties.publicNetworkAccess == "Enabled" && azapi_resource.environment.body.properties.vnetConfiguration.infrastructureSubnetId == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev/subnets/snet-pipesor-dev"
    error_message = "The external-capable environment must use the dedicated subnet, without selecting per-app ingress."
  }
  assert {
    condition     = azapi_resource.network.body.properties.addressSpace.addressPrefixes == ["10.50.0.0/16"] && azapi_resource.subnet.body.properties.addressPrefix == "10.50.1.0/24" && azapi_resource.subnet.parent_id == azapi_resource.network.id && azapi_resource.subnet.body.properties.delegations == [{ name = "container-apps", properties = { serviceName = "Microsoft.App/environments" } }]
    error_message = "Preserve the approved allocation and delegate the child subnet exclusively to Container Apps."
  }
  assert {
    condition     = azapi_resource.workspace.body.properties.retentionInDays == 45 && azapi_resource.workspace.body.properties.workspaceCapping.dailyQuotaGb == 0.5 && azapi_resource.workspace.body.properties.sku.name == "PerGB2018"
    error_message = "Explicit retention and ingestion limits must reach the shared pay-as-you-go workspace."
  }
  assert {
    condition     = azapi_resource.workspace.body.properties.features.disableLocalAuth == true && azapi_resource.workspace.body.properties.features.enableLogAccessUsingOnlyResourcePermissions == false
    error_message = "Disable workspace key authentication and require workspace permissions for queries."
  }
  assert {
    condition     = azapi_resource.environment.body.properties.appLogsConfiguration == { destination = "azure-monitor" } && azapi_resource.logs.parent_id == azapi_resource.environment.id && azapi_resource.logs.body.properties.workspaceId == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.OperationalInsights/workspaces/log-pipesor-dev" && azapi_resource.logs.body.properties.logs == [{ category = "ContainerAppSystemLogs", enabled = true }, { category = "ContainerAppConsoleLogs", enabled = true }]
    error_message = "Route both platform and console logs through Azure Monitor to the intended workspace without shared keys."
  }
  assert {
    condition     = output.platform.environment_name == "caepipesordev" && output.platform.network_name == "vnet-pipesor-dev" && output.platform.workspace_name == "log-pipesor-dev" && azapi_resource.environment.location == "workloadregion"
    error_message = "Names must retain environment identity and resources must use the explicit workload region."
  }
}
run "smallest_subnet_and_alternate_private_range" {
  command = plan
  variables {
    configuration = {
      location                     = "workloadregion"
      vnet_address_prefix          = "172.16.0.0/16"
      infrastructure_subnet_prefix = "172.16.0.0/27"
      log_retention_days           = 45
      log_daily_cap_gb             = 0.5
    }
  }
  assert {
    condition     = azapi_resource.subnet.body.properties.addressPrefix == "172.16.0.0/27"
    error_message = "An allocated canonical /27 in another RFC1918 block must remain supported."
  }
}
run "reject_small_subnet" {
  command = plan
  variables {
    configuration = {
      location                     = "workloadregion"
      vnet_address_prefix          = "10.50.0.0/16"
      infrastructure_subnet_prefix = "10.50.1.0/28"
      log_retention_days           = 45
      log_daily_cap_gb             = 0.5
    }
  }
  expect_failures = [var.configuration]
}
run "reject_outside_subnet" {
  command = plan
  variables {
    configuration = {
      location                     = "workloadregion"
      vnet_address_prefix          = "10.50.0.0/16"
      infrastructure_subnet_prefix = "10.51.0.0/24"
      log_retention_days           = 45
      log_daily_cap_gb             = 0.5
    }
  }
  expect_failures = [var.configuration]
}
run "reject_noncanonical" {
  command = plan
  variables {
    configuration = {
      location                     = "workloadregion"
      vnet_address_prefix          = "10.50.0.0/16"
      infrastructure_subnet_prefix = "10.50.1.5/24"
      log_retention_days           = 45
      log_daily_cap_gb             = 0.5
    }
  }
  expect_failures = [var.configuration]
}
run "reject_reserved_aca_range" {
  command = plan
  variables {
    configuration = {
      location                     = "workloadregion"
      vnet_address_prefix          = "172.16.0.0/12"
      infrastructure_subnet_prefix = "172.30.0.0/16"
      log_retention_days           = 45
      log_daily_cap_gb             = 0.5
    }
  }
  expect_failures = [var.configuration]
}
run "reject_public_network" {
  command = plan
  variables {
    configuration = {
      location                     = "workloadregion"
      vnet_address_prefix          = "203.0.113.0/24"
      infrastructure_subnet_prefix = "203.0.113.0/27"
      log_retention_days           = 45
      log_daily_cap_gb             = 0.5
    }
  }
  expect_failures = [var.configuration]
}
run "reject_ipv6" {
  command = plan
  variables {
    configuration = {
      location                     = "workloadregion"
      vnet_address_prefix          = "fd00::/48"
      infrastructure_subnet_prefix = "10.50.1.0/24"
      log_retention_days           = 45
      log_daily_cap_gb             = 0.5
    }
  }
  expect_failures = [var.configuration]
}
run "reject_unlimited_ingestion" {
  command = plan
  variables {
    configuration = {
      location                     = "workloadregion"
      vnet_address_prefix          = "10.50.0.0/16"
      infrastructure_subnet_prefix = "10.50.1.0/24"
      log_retention_days           = 45
      log_daily_cap_gb             = -1
    }
  }
  expect_failures = [var.configuration]
}
run "reject_zero_ingestion" {
  command = plan
  variables {
    configuration = {
      location                     = "workloadregion"
      vnet_address_prefix          = "10.50.0.0/16"
      infrastructure_subnet_prefix = "10.50.1.0/24"
      log_retention_days           = 45
      log_daily_cap_gb             = 0
    }
  }
  expect_failures = [var.configuration]
}
run "reject_fractional_retention" {
  command = plan
  variables {
    configuration = {
      location                     = "workloadregion"
      vnet_address_prefix          = "10.50.0.0/16"
      infrastructure_subnet_prefix = "10.50.1.0/24"
      log_retention_days           = 30.5
      log_daily_cap_gb             = 0.5
    }
  }
  expect_failures = [var.configuration]
}
run "reject_low_retention" {
  command = plan
  variables {
    configuration = {
      location                     = "workloadregion"
      vnet_address_prefix          = "10.50.0.0/16"
      infrastructure_subnet_prefix = "10.50.1.0/24"
      log_retention_days           = 29
      log_daily_cap_gb             = 0.5
    }
  }
  expect_failures = [var.configuration]
}

run "key_vault_service_endpoint" {
  command = plan
  variables { key_vault_service_endpoint_enabled = true }
  assert {
    condition     = azapi_resource.subnet.body.properties.serviceEndpoints == [{ service = "Microsoft.KeyVault" }] && azapi_resource.subnet.body.properties.delegations == [{ name = "container-apps", properties = { serviceName = "Microsoft.App/environments" } }]
    error_message = "Key Vault access must add only its service endpoint without losing ACA delegation."
  }
}
