mock_provider "azapi" {}
variables {
  environment       = "dev"
  resource_group_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev"
  configuration = {
    app_material_name    = "pipesor-dev-app"
    location             = "vaultregion"
    tenant_id            = "44444444-4444-4444-4444-444444444444"
    allowed_public_ipv4s = ["203.0.113.5/32", "198.51.100.0/24"]
  }
}
override_resource {
  target          = azapi_resource.vault["app_material"]
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/pipesor-dev-app", output = { properties = { vaultUri = "https://pipesor-dev-app.vault.azure.net/" } } }
}
run "app_material_security_and_no_payloads" {
  command = plan
  assert {
    condition     = length(azapi_resource.vault) == 1 && length(azapi_resource.app_material_reader) == 0 && length(azapi_resource.custody_writer) == 0 && length(azapi_resource.custody_role) == 0
    error_message = "Only the App material vault is selected; grants and human custody are explicit opt-ins."
  }
  assert {
    condition = azapi_resource.vault["app_material"].body == { properties = {
      tenantId                     = "44444444-4444-4444-4444-444444444444"
      sku                          = { family = "A", name = "standard" }
      accessPolicies               = []
      enableRbacAuthorization      = true
      enableSoftDelete             = true
      enablePurgeProtection        = true
      softDeleteRetentionInDays    = 30
      enabledForDeployment         = false
      enabledForDiskEncryption     = false
      enabledForTemplateDeployment = false
      publicNetworkAccess          = "Enabled"
      networkAcls                  = { bypass = "None", defaultAction = "Deny", ipRules = [{ value = "198.51.100.0/24" }, { value = "203.0.113.5/32" }], virtualNetworkRules = [] }
    } }
    error_message = "Only Standard, Entra RBAC, protected recovery and explicit network rules are configured; no secret payloads or deployment access."
  }
  assert {
    condition     = azapi_resource.vault["app_material"].parent_id == var.resource_group_id && azapi_resource.vault["app_material"].location == "vaultregion" && azapi_resource.vault["app_material"].tags == tomap({ environment = "dev", purpose = "app_material" })
    error_message = "The vault must preserve environment ownership, explicit region and purpose."
  }
  assert {
    condition     = output.vaults == { app_material = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/pipesor-dev-app", name = "pipesor-dev-app", location = "vaultregion", tenant_id = "44444444-4444-4444-4444-444444444444", uri = "https://pipesor-dev-app.vault.azure.net/" } } && azapi_resource.vault["app_material"].response_export_values == ["properties.vaultUri"]
    error_message = "Export only vault identity/endpoint; never material, secret names or versions."
  }
}
run "scoped_readers_and_get_set_custody" {
  command = plan
  variables {
    configuration = {
      app_material_name    = "pipesor-dev-app"
      location             = "vaultregion"
      tenant_id            = "44444444-4444-4444-4444-444444444444"
      allowed_public_ipv4s = ["203.0.113.5/32", "198.51.100.0/24"]
      app_material_readers = { developer = { object_id = "22222222-2222-2222-2222-222222222222", principal_type = "User" } }
      custody              = { name = "pipesor-dev-custody", principals = { ingestion = { object_id = "33333333-3333-3333-3333-333333333333", principal_type = "ServicePrincipal" } } }
    }
  }
  override_resource {
    target          = azapi_resource.vault["custody"]
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/pipesor-dev-custody", output = { properties = { vaultUri = "https://pipesor-dev-custody.vault.azure.net/" } } }
  }
  override_resource {
    target          = azapi_resource.custody_role[0]
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/roleDefinitions/55555555-5555-5555-5555-555555555555" }
  }
  assert {
    condition     = length(azapi_resource.vault) == 2 && azapi_resource.app_material_reader["developer"].parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/pipesor-dev-app" && azapi_resource.app_material_reader["developer"].body.properties == { principalId = "22222222-2222-2222-2222-222222222222", principalType = "User", roleDefinitionId = "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6" }
    error_message = "Machine material grants only built-in Secrets User at the App vault; no writer."
  }
  assert {
    condition     = azapi_resource.custody_writer["ingestion"].parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/pipesor-dev-custody" && azapi_resource.custody_writer["ingestion"].body.properties.principalId == "33333333-3333-3333-3333-333333333333" && azapi_resource.custody_writer["ingestion"].body.properties.roleDefinitionId == azapi_resource.custody_role[0].id && azapi_resource.custody_role[0].body.properties.assignableScopes == [var.resource_group_id] && azapi_resource.custody_role[0].parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111"
    error_message = "The credential role is assignable in the owning RG and granted only at the separate custody vault."
  }
  assert {
    condition     = azapi_resource.custody_role[0].body.properties.permissions == [{ actions = [], notActions = [], notDataActions = [], dataActions = ["Microsoft.KeyVault/vaults/secrets/getSecret/action", "Microsoft.KeyVault/vaults/secrets/setSecret/action"] }] && azapi_resource.custody_writer["ingestion"].response_export_values == [] && azapi_resource.app_material_reader["developer"].response_export_values == []
    error_message = "Custody runtime may only read/create secret versions, with no list, delete, recover, purge or permission management."
  }
  assert {
    condition     = azapi_resource.vault["custody"].body == azapi_resource.vault["app_material"].body && azapi_resource.app_material_reader["developer"].name == uuidv5("url", "${lower(azapi_resource.vault["app_material"].id)}/22222222-2222-2222-2222-222222222222//subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6")
    error_message = "Both vaults enforce identical security; role assignment identities are deterministic."
  }
}
run "subnet_only_access" {
  command = plan
  variables {
    allowed_subnet_ids = ["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet/subnets/aca"]
    configuration = {
      app_material_name    = "pipesor-dev-app"
      location             = "vaultregion"
      tenant_id            = "44444444-4444-4444-4444-444444444444"
      allowed_public_ipv4s = []
    }
  }
  assert {
    condition     = azapi_resource.vault["app_material"].body.properties.networkAcls.virtualNetworkRules == [{ id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourcegroups/rg-pipesor-dev/providers/microsoft.network/virtualnetworks/vnet/subnets/aca", ignoreMissingVnetServiceEndpoint = false }]
    error_message = "Permit only the existing environment subnet with an actual service endpoint."
  }
}

run "reject_blank_name" {
  command = plan
  variables { configuration = {
    app_material_name    = ""
    location             = "vaultregion"
    tenant_id            = "44444444-4444-4444-4444-444444444444"
    allowed_public_ipv4s = ["203.0.113.5/32", "198.51.100.0/24"]
  } }
  expect_failures = [var.configuration]
}

run "reject_consecutive_hyphens" {
  command = plan
  variables { configuration = {
    app_material_name    = "pipesor--dev"
    location             = "vaultregion"
    tenant_id            = "44444444-4444-4444-4444-444444444444"
    allowed_public_ipv4s = ["203.0.113.5/32", "198.51.100.0/24"]
  } }
  expect_failures = [var.configuration]
}

run "reject_invalid_tenant" {
  command = plan
  variables { configuration = {
    app_material_name    = "pipesor-dev-app"
    location             = "vaultregion"
    tenant_id            = "00000000-0000-0000-0000-000000000000"
    allowed_public_ipv4s = ["203.0.113.5/32", "198.51.100.0/24"]
  } }
  expect_failures = [var.configuration]
}

run "reject_world_open" {
  command = plan
  variables { configuration = {
    app_material_name    = "pipesor-dev-app"
    location             = "vaultregion"
    tenant_id            = "44444444-4444-4444-4444-444444444444"
    allowed_public_ipv4s = ["0.0.0.0/0"]
  } }
  expect_failures = [var.configuration]
}

run "reject_private_ip" {
  command = plan
  variables { configuration = {
    app_material_name    = "pipesor-dev-app"
    location             = "vaultregion"
    tenant_id            = "44444444-4444-4444-4444-444444444444"
    allowed_public_ipv4s = ["10.0.0.1"]
  } }
  expect_failures = [var.configuration]
}

run "reject_cgnat" {
  command = plan
  variables { configuration = {
    app_material_name    = "pipesor-dev-app"
    location             = "vaultregion"
    tenant_id            = "44444444-4444-4444-4444-444444444444"
    allowed_public_ipv4s = ["100.64.0.1"]
  } }
  expect_failures = [var.configuration]
}

run "reject_ipv6" {
  command = plan
  variables { configuration = {
    app_material_name    = "pipesor-dev-app"
    location             = "vaultregion"
    tenant_id            = "44444444-4444-4444-4444-444444444444"
    allowed_public_ipv4s = ["2001:db8::1"]
  } }
  expect_failures = [var.configuration]
}

run "reject_noncanonical_range" {
  command = plan
  variables { configuration = {
    app_material_name    = "pipesor-dev-app"
    location             = "vaultregion"
    tenant_id            = "44444444-4444-4444-4444-444444444444"
    allowed_public_ipv4s = ["203.0.113.5/24"]
  } }
  expect_failures = [var.configuration]
}

run "reject_empty_networks" {
  command = plan
  variables { configuration = {
    app_material_name    = "pipesor-dev-app"
    location             = "vaultregion"
    tenant_id            = "44444444-4444-4444-4444-444444444444"
    allowed_public_ipv4s = []
  } }
  expect_failures = [var.configuration]
}

run "reject_same_vault_names" {
  command = plan
  variables { configuration = {
    app_material_name    = "pipesor-dev-app"
    location             = "vaultregion"
    tenant_id            = "44444444-4444-4444-4444-444444444444"
    allowed_public_ipv4s = ["203.0.113.5/32", "198.51.100.0/24"]
    custody              = { name = "pipesor-dev-app" }
  } }
  expect_failures = [var.configuration]
}

run "reject_invalid_principal" {
  command = plan
  variables { configuration = {
    app_material_name    = "pipesor-dev-app"
    location             = "vaultregion"
    tenant_id            = "44444444-4444-4444-4444-444444444444"
    allowed_public_ipv4s = ["203.0.113.5/32", "198.51.100.0/24"]
    app_material_readers = { developer = { object_id = "not-a-uuid", principal_type = "Owner" } }
  } }
  expect_failures = [var.configuration]
}

run "reject_duplicate_principal" {
  command = plan
  variables { configuration = {
    app_material_name    = "pipesor-dev-app"
    location             = "vaultregion"
    tenant_id            = "44444444-4444-4444-4444-444444444444"
    allowed_public_ipv4s = ["203.0.113.5/32", "198.51.100.0/24"]
    app_material_readers = { first = { object_id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", principal_type = "User" }, second = { object_id = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", principal_type = "User" } }
  } }
  expect_failures = [var.configuration]
}

run "reject_cross_environment_subnet" {
  command = plan
  variables { allowed_subnet_ids = ["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-prod/providers/Microsoft.Network/virtualNetworks/vnet/subnets/aca"] }
  expect_failures = [var.allowed_subnet_ids]
}
run "reject_environment" {
  command = plan
  variables { environment = "other" }
  expect_failures = [var.environment]
}
run "reject_group" {
  command = plan
  variables { resource_group_id = "/invalid" }
  expect_failures = [var.resource_group_id]
}

run "custody_without_grants" {
  command = plan
  variables { configuration = {
    app_material_name    = "pipesor-dev-app"
    location             = "vaultregion"
    tenant_id            = "44444444-4444-4444-4444-444444444444"
    allowed_public_ipv4s = ["203.0.113.5/32"]
    custody              = { name = "pipesor-dev-custody" }
  } }
  override_resource {
    target          = azapi_resource.vault["custody"]
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/pipesor-dev-custody", output = { properties = { vaultUri = "https://pipesor-dev-custody.vault.azure.net/" } } }
  }
  assert {
    condition     = length(azapi_resource.vault) == 2 && length(azapi_resource.custody_writer) == 0 && length(azapi_resource.custody_role) == 0
    error_message = "Custody vault creation must not grant access or define a role without explicit principals."
  }
}
run "reject_null_principal" {
  command = plan
  variables { configuration = {
    app_material_name    = "pipesor-dev-app"
    location             = "vaultregion"
    tenant_id            = "44444444-4444-4444-4444-444444444444"
    allowed_public_ipv4s = ["203.0.113.5/32"]
    app_material_readers = { developer = { object_id = null, principal_type = "User" } }
  } }
  expect_failures = [var.configuration]
}

run "trusted_services_only_for_opted_in_app_material" {
  command = plan
  variables {
    configuration = {
      app_material_name      = "pipesor-dev-app"
      location               = "vaultregion"
      tenant_id              = "44444444-4444-4444-4444-444444444444"
      allowed_public_ipv4s   = ["203.0.113.5/32"]
      allow_trusted_services = true
      custody                = { name = "pipesor-dev-usr" }
    }
  }
  assert {
    condition     = azapi_resource.vault["app_material"].body.properties.networkAcls.bypass == "AzureServices" && azapi_resource.vault["custody"].body.properties.networkAcls.bypass == "None"
    error_message = "Only the opted-in app material vault lets trusted Azure services through; custody stays closed."
  }
  assert {
    condition     = azapi_resource.vault["app_material"].body.properties.networkAcls.defaultAction == "Deny"
    error_message = "Public access stays denied by default."
  }
}
