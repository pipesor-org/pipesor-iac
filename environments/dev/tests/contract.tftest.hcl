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

run "dev_root_contract" {
  command = plan

  assert {
    condition     = output.key_vault == null && length(module.key_vault) == 0 && output.static_web_app == null && length(module.static_web_app) == 0 && output.foundry == null && length(module.foundry) == 0 && output.application_insights == null && length(module.application_insights) == 0 && output.resource_group.name == "rg-pipesor-dev" && output.container_platform == null && length(module.container_platform) == 0 && output.service_bus == null && output.postgresql == null && length(module.postgresql) == 0 && length(module.service_bus) == 0
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
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.network
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.subnet
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev/subnets/snet-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.workspace
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.OperationalInsights/workspaces/log-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.environment
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.App/managedEnvironments/caepipesordev" }
  }
  assert {
    condition     = output.container_platform.environment_name == "caepipesordev" && output.container_platform.workspace_name == "log-pipesor-dev" && output.container_platform.network_name == "vnet-pipesor-dev" && length(module.container_platform) == 1
    error_message = "Opt-in must create exactly this environment platform and preserve distinct environment names."
  }
}

run "opt_in_service_bus_contract" {
  command = plan
  variables {
    service_bus = {
      namespace_name = "test-pipesor-dev-bus"
      location       = "messagingregion"
    }
  }
  override_resource {
    target          = module.resource_group.module.resource_group.azapi_resource.this
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev" }
  }
  override_resource {
    target          = module.service_bus[0].azapi_resource.namespace
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ServiceBus/namespaces/test-pipesor-dev-bus" }
  }
  assert {
    condition     = length(module.service_bus) == 1 && output.service_bus.name == "test-pipesor-dev-bus" && output.service_bus.location == "messagingregion" && output.container_platform == null
    error_message = "Messaging must opt in independently, preserving the supplied namespace name and workload region."
  }
  assert {
    condition     = output.service_bus.id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ServiceBus/namespaces/test-pipesor-dev-bus"
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
      server_name   = "test-pipesor-dev-pg"
      location      = "workloadregion"
      subnet_prefix = "10.50.2.0/28"
      sku           = { name = "Standard_D2s_v3", tier = "GeneralPurpose" }
      tenant_id     = "11111111-1111-1111-1111-111111111111"
      administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" }
    }

  }
  override_resource {
    target          = module.resource_group.module.resource_group.azapi_resource.this
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.network
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.subnet
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev/subnets/snet-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.workspace
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.OperationalInsights/workspaces/log-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.environment
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.App/managedEnvironments/caepipesordev" }
  }
  assert {
    condition     = output.container_platform.environment_name == "caepipesordev" && output.container_platform.workspace_name == "log-pipesor-dev" && output.container_platform.network_name == "vnet-pipesor-dev" && length(module.container_platform) == 1
    error_message = "Opt-in must create exactly this environment platform and preserve distinct environment names."
  }

  override_resource {
    target          = module.postgresql[0].azapi_resource.subnet
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev/subnets/snet-pipesor-dev-postgresql" }
  }

  override_resource {
    target          = module.postgresql[0].azapi_resource.dns
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/privateDnsZones/pipesor-dev.postgres.database.azure.com" }
  }

  override_resource {
    target          = module.postgresql[0].azapi_resource.server
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-pipesor-dev-pg", output = { properties = { fullyQualifiedDomainName = "fixture.postgres.database.azure.com" } } }
  }

  assert {
    condition     = length(module.postgresql) == 1 && output.postgresql.name == "test-pipesor-dev-pg" && output.postgresql.fqdn == "fixture.postgres.database.azure.com" && output.postgresql.id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-pipesor-dev-pg"
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
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.network
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.subnet
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev/subnets/snet-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.workspace
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.OperationalInsights/workspaces/log-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.environment
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.App/managedEnvironments/caepipesordev" }
  }
  assert {
    condition     = output.container_platform.environment_name == "caepipesordev" && output.container_platform.workspace_name == "log-pipesor-dev" && output.container_platform.network_name == "vnet-pipesor-dev" && length(module.container_platform) == 1
    error_message = "Opt-in must create exactly this environment platform and preserve distinct environment names."
  }
  override_resource {
    target          = module.application_insights[0].azapi_resource.component
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Insights/components/appipipesordev", output = { properties = { ConnectionString = "synthetic-routing-fixture" } } }
  }
  assert {
    condition     = length(module.application_insights) == 1 && output.application_insights.name == "appipipesordev" && output.application_insights.connection_string == "synthetic-routing-fixture"
    error_message = "Create exactly one component for this environment with the service-reported routing output."
  }
}
run "reject_insights_without_workspace" {
  command = plan
  variables { application_insights_enabled = true }
  expect_failures = [var.application_insights_enabled]
}

run "opt_in_foundry_contract" {
  command = plan
  variables {
    foundry = { account_name = "test-pipesor-dev-ai", project_name = "pipesor-dev", location = "airegion" }
  }
  override_resource {
    target          = module.resource_group.module.resource_group.azapi_resource.this
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev" }
  }
  override_resource {
    target          = module.foundry[0].azapi_resource.account
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.CognitiveServices/accounts/test-pipesor-dev-ai", output = { properties = { endpoint = "https://synthetic.cognitiveservices.azure.com/" } } }
  }
  override_resource {
    target          = module.foundry[0].azapi_resource.project
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.CognitiveServices/accounts/test-pipesor-dev-ai/projects/pipesor-dev" }
  }
  assert {
    condition     = length(module.foundry) == 1 && output.foundry.account_name == "test-pipesor-dev-ai" && output.foundry.project_name == "pipesor-dev" && output.foundry.location == "airegion" && output.container_platform == null
    error_message = "Foundry must opt in independently with the explicit names and region."
  }
}

run "opt_in_static_web_app_contract" {
  command = plan
  variables { static_web_app = { name = "test-pipesor-dev-web", location = "webregion" } }
  override_resource {
    target          = module.resource_group.module.resource_group.azapi_resource.this
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev" }
  }
  override_resource {
    target          = module.static_web_app[0].azapi_resource.site
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Web/staticSites/test-pipesor-dev-web", output = { properties = { defaultHostname = "synthetic.azurestaticapps.net" } } }
  }
  assert {
    condition     = length(module.static_web_app) == 1 && output.static_web_app.name == "test-pipesor-dev-web" && output.static_web_app.location == "webregion" && output.static_web_app.default_hostname == "synthetic.azurestaticapps.net" && output.container_platform == null
    error_message = "Static hosting must opt in independently with explicit inputs and service-reported hostname."
  }
}

run "combined_foundations_contract" {
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
      server_name   = "test-pipesor-dev-pg"
      location      = "workloadregion"
      subnet_prefix = "10.50.2.0/28"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
      administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" }
    }
    service_bus = {
      namespace_name = "test-pipesor-dev-bus"
      location       = "messagingregion"
    }
    key_vault = {
      app_material_name    = "test-pipesor-dev-app"
      location             = "vaultregion"
      tenant_id            = "44444444-4444-4444-4444-444444444444"
      allowed_public_ipv4s = ["203.0.113.5/32"]
      app_material_readers = { developer = { object_id = "22222222-2222-2222-2222-222222222222", principal_type = "User" } }
      custody              = { name = "test-pipesor-dev-usr", principals = { ingestion = { object_id = "33333333-3333-3333-3333-333333333333", principal_type = "ServicePrincipal" } } }
    }
    application_insights_enabled = true
    foundry                      = { account_name = "test-pipesor-dev-ai", project_name = "pipesor-dev", location = "airegion" }
    static_web_app               = { name = "test-pipesor-dev-web", location = "webregion" }
    rag_runtime_contract = {
      embedding_deployment_name   = "test-dev-embeddings"
      embedding_model_version     = "test-model-version"
      tenant_id                   = "11111111-1111-1111-1111-111111111111"
      rag_audience_client_id      = "20000000-0000-4000-8000-000000000001"
      recommendation_client_id    = "20000000-0000-4000-8000-000000000002"
      recommendation_principal_id = "20000000-0000-4000-8000-000000000003"
      rag_query_app_role_id       = "20000000-0000-4000-8000-000000000004"
      rag_runtime_principal_id    = "20000000-0000-4000-8000-000000000005"
      rag_import_principal_id     = "20000000-0000-4000-8000-000000000006"
      rag_migration_principal_id  = "20000000-0000-4000-8000-000000000007"
    }
  }
  override_resource {
    target          = module.resource_group.module.resource_group.azapi_resource.this
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.network
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.subnet
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev/subnets/snet-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.workspace
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.OperationalInsights/workspaces/log-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.environment
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.App/managedEnvironments/caepipesordev" }
  }
  override_resource {
    target          = module.postgresql[0].azapi_resource.subnet
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev/subnets/snet-pipesor-dev-postgresql" }
  }
  override_resource {
    target          = module.postgresql[0].azapi_resource.dns
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/privateDnsZones/pipesor-dev.postgres.database.azure.com" }
  }
  override_resource {
    target          = module.postgresql[0].azapi_resource.server
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-pipesor-dev-pg", output = { properties = { fullyQualifiedDomainName = "fixture.postgres.database.azure.com" } } }
  }
  override_resource {
    target          = module.service_bus[0].azapi_resource.namespace
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ServiceBus/namespaces/test-pipesor-dev-bus" }
  }
  override_resource {
    target          = module.application_insights[0].azapi_resource.component
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Insights/components/appipipesordev", output = { properties = { ConnectionString = "synthetic-routing-fixture" } } }
  }
  override_resource {
    target          = module.foundry[0].azapi_resource.account
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.CognitiveServices/accounts/test-pipesor-dev-ai", output = { properties = { endpoint = "https://synthetic.cognitiveservices.azure.com/" } } }
  }
  override_resource {
    target          = module.foundry[0].azapi_resource.project
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.CognitiveServices/accounts/test-pipesor-dev-ai/projects/pipesor-dev" }
  }
  override_resource {
    target          = module.static_web_app[0].azapi_resource.site
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Web/staticSites/test-pipesor-dev-web", output = { properties = { defaultHostname = "synthetic.azurestaticapps.net" } } }
  }
  override_resource {
    target          = module.key_vault[0].azapi_resource.vault["app_material"]
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/test-pipesor-dev-app", output = { properties = { vaultUri = "https://test-pipesor-dev-app.vault.azure.net/" } } }
  }
  override_resource {
    target          = module.key_vault[0].azapi_resource.vault["custody"]
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/test-pipesor-dev-usr", output = { properties = { vaultUri = "https://test-pipesor-dev-usr.vault.azure.net/" } } }
  }
  override_resource {
    target          = module.key_vault[0].azapi_resource.custody_role[0]
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/roleDefinitions/55555555-5555-5555-5555-555555555555" }
  }
  assert {
    condition     = output.postgresql.subnet_id != output.container_platform.infrastructure_subnet_id && output.postgresql.name == "test-pipesor-dev-pg" && output.application_insights.workspace_id == output.container_platform.workspace_id
    error_message = "Database and ACA must use distinct subnets while telemetry shares this environment's workspace."
  }
  assert {
    condition     = output.service_bus.name == "test-pipesor-dev-bus" && output.foundry.account_name == "test-pipesor-dev-ai" && output.static_web_app.name == "test-pipesor-dev-web" && output.container_platform.environment_name == "caepipesordev"
    error_message = "All approved foundations must coexist without losing environment identity."
  }

  assert {
    condition     = output.rag_runtime_contract.embedding.model == "text-embedding-3-small" && output.rag_runtime_contract.embedding.dimensions == 1536 && output.rag_runtime_contract.embedding.api == "v1" && output.rag_runtime_contract.embedding.endpoint == output.foundry.endpoint && output.rag_runtime_contract.embedding.deployment_name == var.rag_runtime_contract.embedding_deployment_name
    error_message = "The RAG handoff must bind the approved embedding contract to the DEV Foundry endpoint."
  }

  assert {
    condition     = output.rag_runtime_contract.authorization.app_role_name == "Rag.Query" && output.rag_runtime_contract.authorization.recommendation_client_id == var.rag_runtime_contract.recommendation_client_id && output.rag_runtime_contract.identity.recommendation_principal_id == var.rag_runtime_contract.recommendation_principal_id && output.rag_runtime_contract.postgresql.host == output.postgresql.fqdn && output.rag_runtime_contract.postgresql.runtime_access == "knowledge_read" && output.rag_runtime_contract.postgresql.import_access == "knowledge_read_write" && output.rag_runtime_contract.postgresql.migration_access == "knowledge_ddl"
    error_message = "The handoff must retain the Recommendation caller and the distinct RAG database access boundaries."
  }
}

run "opt_in_key_vault_contract" {
  command = plan
  variables {
    key_vault = {
      app_material_name    = "test-pipesor-dev-app"
      location             = "vaultregion"
      tenant_id            = "44444444-4444-4444-4444-444444444444"
      allowed_public_ipv4s = ["203.0.113.5/32"]
      app_material_readers = { developer = { object_id = "22222222-2222-2222-2222-222222222222", principal_type = "User" } }
      custody              = { name = "test-pipesor-dev-usr", principals = { ingestion = { object_id = "33333333-3333-3333-3333-333333333333", principal_type = "ServicePrincipal" } } }
    }
  }
  override_resource {
    target          = module.resource_group.module.resource_group.azapi_resource.this
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev" }
  }
  override_resource {
    target          = module.key_vault[0].azapi_resource.vault["app_material"]
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/test-pipesor-dev-app", output = { properties = { vaultUri = "https://test-pipesor-dev-app.vault.azure.net/" } } }
  }
  override_resource {
    target          = module.key_vault[0].azapi_resource.vault["custody"]
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/test-pipesor-dev-usr", output = { properties = { vaultUri = "https://test-pipesor-dev-usr.vault.azure.net/" } } }
  }
  override_resource {
    target          = module.key_vault[0].azapi_resource.custody_role[0]
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/roleDefinitions/55555555-5555-5555-5555-555555555555" }
  }

  assert {
    condition     = length(module.key_vault) == 1 && output.container_platform == null && output.key_vault.app_material.name == "test-pipesor-dev-app" && output.key_vault.custody.name == "test-pipesor-dev-usr" && output.key_vault.app_material.tenant_id == "44444444-4444-4444-4444-444444444444"
    error_message = "Vaults opt in independently of ACA and retain this environment's explicit names/tenant."
  }
}
run "app_material_only_key_vault_contract" {
  command = plan
  variables {
    key_vault = {
      app_material_name    = "test-pipesor-dev-app"
      location             = "vaultregion"
      tenant_id            = "44444444-4444-4444-4444-444444444444"
      allowed_public_ipv4s = ["203.0.113.5/32"]
    }
  }
  override_resource {
    target          = module.resource_group.module.resource_group.azapi_resource.this
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev" }
  }
  override_resource {
    target          = module.key_vault[0].azapi_resource.vault["app_material"]
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/test-pipesor-dev-app", output = { properties = { vaultUri = "https://test-pipesor-dev-app.vault.azure.net/" } } }
  }
  assert {
    condition     = keys(output.key_vault) == ["app_material"]
    error_message = "Machine integration must not implicitly enable human credential custody."
  }
}

# Runtime manifest contract for the seven service Container Apps (plan-only, fully mocked).
run "workloads_runtime_contract" {
  command = plan
  variables {
    container_platform = {
      location                     = "workloadregion"
      vnet_address_prefix          = "10.50.0.0/16"
      infrastructure_subnet_prefix = "10.50.1.0/24"
      log_retention_days           = 30
      log_daily_cap_gb             = 0.1
    }
    postgresql = {
      server_name   = "test-pipesor-dev-pg"
      location      = "workloadregion"
      subnet_prefix = "10.50.2.0/28"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
      administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" }
    }
    service_bus = {
      namespace_name = "test-pipesor-dev-bus"
      location       = "workloadregion"
      topology = {
        topic_name                 = "workflow-evidence"
        message_ttl                = "P14D"
        duplicate_detection_window = "PT10M"
        subscriptions = {
          pipeline  = { sql_filter = "eventType = 'execution.snapshot'", lock_duration = "PT1M", max_delivery_count = 10 }
          log-event = { sql_filter = "eventType = 'protected_workflow_evidence'", lock_duration = "PT1M", max_delivery_count = 10 }
          nlp       = { sql_filter = "eventType = 'protected_workflow_evidence'", lock_duration = "PT2M", max_delivery_count = 10 }
        }
      }
    }
    key_vault = {
      app_material_name    = "test-pipesor-dev-app"
      location             = "workloadregion"
      tenant_id            = "11111111-1111-1111-1111-111111111111"
      allowed_public_ipv4s = ["203.0.113.5/32"]
      custody              = { name = "test-pipesor-dev-usr" }
    }
    foundry = {
      account_name = "test-pipesor-dev-ai"
      project_name = "pipesor-dev"
      location     = "workloadregion"
      deployments = {
        pipesor-dev-diagnostics = { model_name = "gpt-4o", model_version = "2024-11-20", sku_name = "DataZoneStandard", capacity = 20 }
        pipesor-dev-embeddings  = { model_name = "text-embedding-3-small", model_version = "1", sku_name = "DataZoneStandard", capacity = 20 }
      }
    }
    static_web_app = { name = "test-pipesor-dev-web", location = "workloadregion" }
    workloads = {
      platform_tenant_id      = "24c96be0-50f3-4064-b5e4-643088141ae8"
      database                = "pipesor"
      chat_deployment         = "pipesor-dev-diagnostics"
      embedding_deployment    = "pipesor-dev-embeddings"
      embedding_model_version = "1"
      images = {
        ingestion      = "ghcr.io/pipesor-org/ingestion@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        pipeline       = "ghcr.io/pipesor-org/pipeline@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        log-event      = "ghcr.io/pipesor-org/log-event@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        nlp            = "ghcr.io/pipesor-org/nlp@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        correlation    = "ghcr.io/pipesor-org/correlation@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        recommendation = "ghcr.io/pipesor-org/recommendation@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        rag            = "ghcr.io/pipesor-org/rag@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        dashboard      = "ghcr.io/pipesor-org/dashboard@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      }
      registry = { server = "ghcr.io", username = "fixture-user", password_secret_name = "ghcr-read-token" }
      github = {
        app_id                  = "123456"
        capture_domain          = "pipesor-dev"
        private_key_secret_name = "github-app-private-key"
        private_key_version     = "0123456789abcdef0123456789abcdef"
        client_secret_name      = "github-app-client-secret"
        client_secret_version   = "fedcba9876543210fedcba9876543210"
        authority_secret_name   = "pipesor-authority"
      }
    }
  }
  override_resource {
    target          = module.resource_group.module.resource_group.azapi_resource.this
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.network
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.subnet
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev/subnets/snet-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.workspace
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.OperationalInsights/workspaces/log-pipesor-dev" }
  }
  override_resource {
    target          = module.container_platform[0].azapi_resource.environment
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.App/managedEnvironments/caepipesordev" }
  }
  override_resource {
    target          = module.postgresql[0].azapi_resource.subnet
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev/subnets/snet-pipesor-dev-postgresql" }
  }
  override_resource {
    target          = module.postgresql[0].azapi_resource.dns
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/privateDnsZones/pipesor-dev.postgres.database.azure.com" }
  }
  override_resource {
    target          = module.postgresql[0].azapi_resource.server
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-pipesor-dev-pg", output = { properties = { fullyQualifiedDomainName = "fixture.postgres.database.azure.com" } } }
  }
  override_resource {
    target          = module.service_bus[0].azapi_resource.namespace
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ServiceBus/namespaces/test-pipesor-dev-bus" }
  }
  override_resource {
    target          = module.application_insights[0].azapi_resource.component
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Insights/components/appipipesordev", output = { properties = { ConnectionString = "synthetic-routing-fixture" } } }
  }
  override_resource {
    target          = module.foundry[0].azapi_resource.account
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.CognitiveServices/accounts/test-pipesor-dev-ai", output = { properties = { endpoint = "https://synthetic.cognitiveservices.azure.com/" } } }
  }
  override_resource {
    target          = module.foundry[0].azapi_resource.project
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.CognitiveServices/accounts/test-pipesor-dev-ai/projects/pipesor-dev" }
  }
  override_resource {
    target          = module.static_web_app[0].azapi_resource.site
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Web/staticSites/test-pipesor-dev-web", output = { properties = { defaultHostname = "synthetic.azurestaticapps.net" } } }
  }
  override_resource {
    target          = module.key_vault[0].azapi_resource.vault["app_material"]
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/test-pipesor-dev-app", output = { properties = { vaultUri = "https://test-pipesor-dev-app.vault.azure.net/" } } }
  }
  override_resource {
    target          = module.key_vault[0].azapi_resource.vault["custody"]
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/test-pipesor-dev-usr", output = { properties = { vaultUri = "https://test-pipesor-dev-usr.vault.azure.net/" } } }
  }
  override_resource {
    target          = module.key_vault[0].azapi_resource.custody_role[0]
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/roleDefinitions/55555555-5555-5555-5555-555555555555" }
  }
  override_resource {
    target          = module.service_bus[0].azapi_resource.topic
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ServiceBus/namespaces/test-pipesor-dev-bus/topics/workflow-evidence", name = "workflow-evidence" }
  }
  override_resource {
    target          = module.service_bus[0].azapi_resource.subscription
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ServiceBus/namespaces/test-pipesor-dev-bus/topics/workflow-evidence/subscriptions/fixture" }
  }
  override_resource {
    target          = module.workloads[0].azapi_resource.identity
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ManagedIdentity/userAssignedIdentities/fixture", output = { properties = { principalId = "55555555-5555-5555-5555-555555555555", clientId = "66666666-6666-6666-6666-666666666666" } } }
  }
  override_data {
    target = module.workloads[0].data.azapi_resource.environment
    values = { output = { properties = { defaultDomain = "fixture.workloadregion.azurecontainerapps.io" } } }
  }

  assert {
    condition     = output.workloads.callback_url == "https://ingestion.fixture.workloadregion.azurecontainerapps.io/api/v1/auth/github/callback"
    error_message = "The GitHub App callback is the Ingestion external URL."
  }
  assert {
    condition     = output.workloads.urls["log-event"] == "https://log-event.internal.fixture.workloadregion.azurecontainerapps.io"
    error_message = "Internal workloads are reached through their internal HTTPS FQDN."
  }
}
