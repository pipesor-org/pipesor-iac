mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "11111111-1111-1111-1111-111111111111"
    }
  }
}

variables {
  subscription_id = "11111111-1111-1111-1111-111111111111"
  location        = "testregion"
}

run "preprod_root_contract" {
  command = plan

  assert {
    condition     = output.application_insights == null && length(module.application_insights) == 0 && output.resource_group.name == "rg-pipesor-preprod" && output.container_platform == null && length(module.container_platform) == 0 && output.service_bus == null && output.postgresql == null && length(module.postgresql) == 0 && length(module.service_bus) == 0
    error_message = "This root must retain its own environment identity."
  }

  assert {
    condition     = output.resource_group.location == "testregion"
    error_message = "This root must forward the explicit metadata location."
  }
}

run "reject_invalid_subscription" {
  command = plan

  variables {
    subscription_id = "not-a-subscription"
  }

  expect_failures = [var.subscription_id]
}

run "reject_blank_location" {
  command = plan

  variables {
    location = " "
  }

  expect_failures = [var.location]
}

run "opt_in_platform_contract" {
  command = plan
  variables {
    container_platform = {
      location                     = "workloadregion"
      vnet_address_prefix          = "10.50.0.0/16"
      infrastructure_subnet_prefix = "10.50.1.0/24"
      log_retention_days           = 45
      log_daily_cap_gb             = 0.5
    }
  }
  override_resource {
    target          = module.resource_group.module.resource_group.azapi_resource.this
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.network
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-preprod" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.subnet
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-preprod/subnets/snet-pipesor-preprod" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.workspace
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.OperationalInsights/workspaces/log-pipesor-preprod" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.environment
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.App/managedEnvironments/caepipesorpreprod" }
  }
  assert {
    condition     = output.container_platform.environment_name == "caepipesorpreprod" && output.container_platform.workspace_name == "log-pipesor-preprod" && output.container_platform.network_name == "vnet-pipesor-preprod" && length(module.container_platform) == 1
    error_message = "Opt-in must create exactly this environment platform and preserve distinct environment names."
  }
}

run "opt_in_service_bus_contract" {
  command = plan
  variables {
    service_bus = {
      namespace_name = "test-pipesor-preprod-bus"
      location       = "messagingregion"
    }
  }
  override_resource {
    target          = module.resource_group.module.resource_group.azapi_resource.this
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod" }
  }
  override_resource {
    target          = module.service_bus[0].azapi_resource.namespace
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.ServiceBus/namespaces/test-pipesor-preprod-bus" }
  }
  assert {
    condition     = length(module.service_bus) == 1 && output.service_bus.name == "test-pipesor-preprod-bus" && output.service_bus.location == "messagingregion" && output.container_platform == null
    error_message = "Messaging must opt in independently, preserving the supplied namespace name and workload region."
  }
  assert {
    condition     = output.service_bus.id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.ServiceBus/namespaces/test-pipesor-preprod-bus"
    error_message = "The caller must expose the nonsecret namespace identity."
  }
}

run "opt_in_postgresql_contract" {
  command = plan
  variables {
    container_platform = {
      location                     = "workloadregion"
      vnet_address_prefix          = "10.50.0.0/16"
      infrastructure_subnet_prefix = "10.50.1.0/24"
      log_retention_days           = 45
      log_daily_cap_gb             = 0.5
    }
    postgresql = {
      server_name   = "test-pipesor-preprod-pg"
      location      = "workloadregion"
      subnet_prefix = "10.50.2.0/28"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
      administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" }
    }

  }
  override_resource {
    target          = module.resource_group.module.resource_group.azapi_resource.this
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.network
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-preprod" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.subnet
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-preprod/subnets/snet-pipesor-preprod" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.workspace
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.OperationalInsights/workspaces/log-pipesor-preprod" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.environment
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.App/managedEnvironments/caepipesorpreprod" }
  }
  assert {
    condition     = output.container_platform.environment_name == "caepipesorpreprod" && output.container_platform.workspace_name == "log-pipesor-preprod" && output.container_platform.network_name == "vnet-pipesor-preprod" && length(module.container_platform) == 1
    error_message = "Opt-in must create exactly this environment platform and preserve distinct environment names."
  }

  override_resource {
    target          = module.postgresql[0].azapi_resource.subnet
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-preprod/subnets/snet-pipesor-preprod-postgresql" }
  }

  override_resource {
    target          = module.postgresql[0].azapi_resource.dns
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.Network/privateDnsZones/pipesor-preprod.postgres.database.azure.com" }
  }

  override_resource {
    target          = module.postgresql[0].azapi_resource.server
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-pipesor-preprod-pg", output = { properties = { fullyQualifiedDomainName = "fixture.postgres.database.azure.com" } } }
  }

  assert {
    condition     = length(module.postgresql) == 1 && output.postgresql.name == "test-pipesor-preprod-pg" && output.postgresql.fqdn == "fixture.postgres.database.azure.com" && output.postgresql.id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-pipesor-preprod-pg"
    error_message = "Wire this environment's private database and export its nonsecret identity."
  }

}

run "reject_postgresql_without_platform" {
  command = plan
  variables {
    postgresql = { server_name = "test-pipesor-dev-pg"
      location      = "workloadregion"
      subnet_prefix = "10.50.2.0/28"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
    administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" } }
  }
  expect_failures = [var.postgresql]
}

run "opt_in_application_insights_contract" {
  command = plan
  variables {
    application_insights_enabled = true
    container_platform = {
      location                     = "workloadregion"
      vnet_address_prefix          = "10.50.0.0/16"
      infrastructure_subnet_prefix = "10.50.1.0/24"
      log_retention_days           = 45
      log_daily_cap_gb             = 0.5
    }
  }
  override_resource {
    target          = module.resource_group.module.resource_group.azapi_resource.this
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.network
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-preprod" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.subnet
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-preprod/subnets/snet-pipesor-preprod" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.workspace
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.OperationalInsights/workspaces/log-pipesor-preprod" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.environment
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.App/managedEnvironments/caepipesorpreprod" }
  }
  assert {
    condition     = output.container_platform.environment_name == "caepipesorpreprod" && output.container_platform.workspace_name == "log-pipesor-preprod" && output.container_platform.network_name == "vnet-pipesor-preprod" && length(module.container_platform) == 1
    error_message = "Opt-in must create exactly this environment platform and preserve distinct environment names."
  }
  override_resource {
    target          = module.application_insights[0].azapi_resource.component
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-preprod/providers/Microsoft.Insights/components/appipipesorpreprod", output = { properties = { ConnectionString = "synthetic-routing-fixture" } } }
  }
  assert {
    condition     = length(module.application_insights) == 1 && output.application_insights.name == "appipipesorpreprod" && output.application_insights.connection_string == "synthetic-routing-fixture"
    error_message = "Create exactly one component for this environment with the service-reported routing output."
  }
}
run "reject_insights_without_workspace" {
  command = plan
  variables { application_insights_enabled = true }
  expect_failures = [var.application_insights_enabled]
}
