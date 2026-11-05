mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults        = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-state-dev/providers/Microsoft.Storage/storageAccounts/fixture" }
    override_during = plan
  }
  mock_data "azapi_client_config" {
    defaults = { subscription_id = "11111111-1111-1111-1111-111111111111" }
  }
}

variables {
  subscription_id = "11111111-1111-1111-1111-111111111111"
  environment     = "dev"
  settings = {
    account_name  = "pipesorstatefixture"
    location      = "testregion"
    replication   = "ZRS"
    recovery_days = 17
    principal_ids = ["22222222-2222-2222-2222-222222222222", "33333333-3333-3333-3333-333333333333"]
    allowed_ips   = ["198.51.100.5", "203.0.113.0/24"]
  }
}
run "security_recovery_and_access_contract" {
  command = plan
  assert {
    condition     = module.storage.resource.parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-state-dev" && module.blob_service.resource.resource_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-state-dev/providers/Microsoft.Storage/storageAccounts/fixture/blobServices/default" && module.container.resource.parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-state-dev/providers/Microsoft.Storage/storageAccounts/fixture/blobServices/default"
    error_message = "Account, Blob service and container must retain the real ARM parent hierarchy."
  }
  assert {
    condition     = module.storage.resource.body.properties.allowSharedKeyAccess == false && module.storage.resource.body.properties.allowBlobPublicAccess == false && module.storage.resource.body.properties.defaultToOAuthAuthentication == true && module.storage.resource.body.properties.isLocalUserEnabled == false
    error_message = "State must require Entra authentication and prohibit shared keys, anonymous blobs and local users."
  }
  assert {
    condition     = module.storage.resource.body.properties.supportsHttpsTrafficOnly == true && module.storage.resource.body.properties.minimumTlsVersion == "TLS1_2"
    error_message = "State traffic must require HTTPS and TLS 1.2."
  }
  assert {
    condition     = module.storage.resource.body.properties.publicNetworkAccess == "Enabled" && module.storage.resource.body.properties.networkAcls.defaultAction == "Deny" && module.storage.resource.body.properties.networkAcls.bypass == "None"
    error_message = "The approved public endpoint must deny unmatched networks with no trusted-service bypass."
  }
  assert {
    condition     = toset([for rule in module.storage.resource.body.properties.networkAcls.ipRules : rule.value]) == toset(["198.51.100.5", "203.0.113.0/24"])
    error_message = "Only the explicitly approved operator addresses may be admitted."
  }
  assert {
    condition     = module.storage.resource.body.kind == "StorageV2" && module.storage.resource.body.sku.name == "Standard_ZRS" && module.storage.resource.location == "testregion"
    error_message = "Explicit redundancy and location must reach the planned account."
  }
  assert {
    condition     = module.blob_service.resource.body.properties.isVersioningEnabled == true && module.blob_service.resource.body.properties.deleteRetentionPolicy.allowPermanentDelete == false && module.blob_service.resource.body.properties.deleteRetentionPolicy.enabled == true && module.blob_service.resource.body.properties.deleteRetentionPolicy.days == 17 && module.blob_service.resource.body.properties.containerDeleteRetentionPolicy.allowPermanentDelete == false && module.blob_service.resource.body.properties.containerDeleteRetentionPolicy.enabled == true && module.blob_service.resource.body.properties.containerDeleteRetentionPolicy.days == 17
    error_message = "State versioning and both soft-delete policies must retain the explicitly selected recovery window."
  }
  assert {
    condition     = module.container.resource.body.properties.publicAccess == "None" && module.container.resource.name == "tfstate-dev"
    error_message = "The environment container must remain private."
  }
  assert {
    condition     = length(module.container.role_assignments) == 2 && alltrue([for grant in module.container.role_assignments : grant.scope == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-state-dev/providers/Microsoft.Storage/storageAccounts/fixture/blobServices/default/containers/tfstate-dev" && grant.role_definition_id == "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe"]) && toset([for grant in module.container.role_assignments : grant.principal_id]) == toset(["22222222-2222-2222-2222-222222222222", "33333333-3333-3333-3333-333333333333"])
    error_message = "Grant exactly the requested principals Blob Data Contributor at this container only."
  }
  assert {
    condition     = output.backend.storage_account_name == "pipesorstatefixture" && output.backend.container_name == "tfstate-dev" && output.backend.key == "dev/foundation.tfstate" && output.backend.use_azuread_auth == true && output.resource_group_name == "rg-pipesor-state-dev"
    error_message = "Backend output must preserve environment identity and Entra authentication without colliding with workload groups."
  }
}
run "reject_no_principals" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { principal_ids = [] })
  }
  expect_failures = [var.settings]
}
run "reject_invalid_principal" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { principal_ids = ["not-a-uuid"] })
  }
  expect_failures = [var.settings]
}
run "reject_no_networks" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { allowed_ips = [] })
  }
  expect_failures = [var.settings]
}
run "reject_world_open" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { allowed_ips = ["0.0.0.0/0"] })
  }
  expect_failures = [var.settings]
}
run "reject_invalid_ip" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { allowed_ips = ["999.5.1.1"] })
  }
  expect_failures = [var.settings]
}
run "reject_private_ip" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { allowed_ips = ["10.1.2.3"] })
  }
  expect_failures = [var.settings]
}
run "reject_unsupported_small_cidr" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { allowed_ips = ["198.51.100.5/32"] })
  }
  expect_failures = [var.settings]
}
run "reject_ipv6" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { allowed_ips = ["2001:db8::1"] })
  }
  expect_failures = [var.settings]
}
run "reject_noncanonical_cidr" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { allowed_ips = ["203.0.113.5/24"] })
  }
  expect_failures = [var.settings]
}
run "reject_no_recovery" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { recovery_days = 0 })
  }
  expect_failures = [var.settings]
}
run "reject_fractional_recovery" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { recovery_days = 1.5 })
  }
  expect_failures = [var.settings]
}
run "reject_excess_recovery" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { recovery_days = 366 })
  }
  expect_failures = [var.settings]
}
run "reject_invalid_name" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { account_name = "Invalid_Name" })
  }
  expect_failures = [var.settings]
}
run "reject_invalid_replication" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { replication = "UNKNOWN" })
  }
  expect_failures = [var.settings]
}

override_resource {
  target          = module.resource_group.azapi_resource.this
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-state-dev" }
}

run "reject_overbroad_cidr" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { allowed_ips = ["128.0.0.0/1"] })
  }
  expect_failures = [var.settings]
}
run "reject_broader_egress_range" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { allowed_ips = ["203.0.112.0/23"] })
  }
  expect_failures = [var.settings]
}
run "reject_cgnat" {
  command = plan
  variables {
    settings = merge({
      account_name  = "pipesorstatefixture"
      location      = "testregion"
      replication   = "ZRS"
      recovery_days = 17
      principal_ids = ["22222222-2222-2222-2222-222222222222"]
      allowed_ips   = ["198.51.100.5"]
    }, { allowed_ips = ["100.64.1.2"] })
  }
  expect_failures = [var.settings]
}

override_resource {
  target          = module.container.azapi_resource.this
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-state-dev/providers/Microsoft.Storage/storageAccounts/fixture/blobServices/default/containers/tfstate-dev" }
}

run "reject_loopback" {
  command = plan
  variables {
    settings = merge(var.settings, { allowed_ips = ["127.0.0.1"] })
  }
  expect_failures = [var.settings]
}

run "reject_private_172" {
  command = plan
  variables {
    settings = merge(var.settings, { allowed_ips = ["172.16.1.2"] })
  }
  expect_failures = [var.settings]
}

run "reject_private_192" {
  command = plan
  variables {
    settings = merge(var.settings, { allowed_ips = ["192.168.1.2"] })
  }
  expect_failures = [var.settings]
}

run "reject_link_local" {
  command = plan
  variables {
    settings = merge(var.settings, { allowed_ips = ["169.254.1.2"] })
  }
  expect_failures = [var.settings]
}

run "reject_unsupported_slash31" {
  command = plan
  variables {
    settings = merge(var.settings, { allowed_ips = ["198.51.100.0/31"] })
  }
  expect_failures = [var.settings]
}

run "accept_recovery_1_and_smallest_egress_range" {
  command = plan
  variables {
    settings = merge(var.settings, { recovery_days = 1, allowed_ips = ["198.51.100.0/30"] })
  }
  assert {
    condition     = module.blob_service.resource.body.properties.deleteRetentionPolicy.days == 1 && module.blob_service.resource.body.properties.containerDeleteRetentionPolicy.days == 1 && toset([for rule in module.storage.resource.body.properties.networkAcls.ipRules : rule.value]) == toset(["198.51.100.0/30"])
    error_message = "Supported recovery and operator CIDR boundaries must reach the effective resources."
  }
}

run "accept_recovery_365_and_smallest_egress_range" {
  command = plan
  variables {
    settings = merge(var.settings, { recovery_days = 365, allowed_ips = ["198.51.100.0/30"] })
  }
  assert {
    condition     = module.blob_service.resource.body.properties.deleteRetentionPolicy.days == 365 && module.blob_service.resource.body.properties.containerDeleteRetentionPolicy.days == 365 && toset([for rule in module.storage.resource.body.properties.networkAcls.ipRules : rule.value]) == toset(["198.51.100.0/30"])
    error_message = "Supported recovery and operator CIDR boundaries must reach the effective resources."
  }
}
