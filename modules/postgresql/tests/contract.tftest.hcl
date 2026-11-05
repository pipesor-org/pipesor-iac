mock_provider "azapi" {}
variables {
  environment       = "dev"
  resource_group_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev"
  network = {
    id                           = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev"
    location                     = "workloadregion"
    address_prefix               = "10.50.0.0/16"
    infrastructure_subnet_prefix = "10.50.1.0/24"
  }
  configuration = {
    server_name   = "test-pipesor-dev-pg"
    location      = "workloadregion"
    subnet_prefix = "10.50.2.0/28"
    tenant_id     = "11111111-1111-1111-1111-111111111111"
    administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" }
  }
}
override_resource {
  target          = azapi_resource.subnet
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev/subnets/snet-pipesor-dev-postgresql" }
}
override_resource {
  target          = azapi_resource.dns
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/privateDnsZones/pipesor-dev.postgres.database.azure.com" }
}
override_resource {
  target          = azapi_resource.server
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-pipesor-dev-pg", output = { properties = { fullyQualifiedDomainName = "test-pipesor-dev-pg.postgres.database.azure.com" } } }
}
run "private_entra_database_contract" {
  command = plan
  assert {
    condition     = azapi_resource.server.body.sku == { name = "Standard_B2s", tier = "Burstable" } && azapi_resource.server.body.properties.version == "17" && azapi_resource.server.body.properties.storage.storageSizeGB == 32 && azapi_resource.server.body.properties.storage.autoGrow == "Disabled"
    error_message = "Preserve the reviewed PG17 B2s fixed initial storage envelope."
  }
  assert {
    condition     = azapi_resource.server.body.properties.authConfig == { activeDirectoryAuth = "Enabled", passwordAuth = "Disabled", tenantId = var.configuration.tenant_id } && !contains(keys(azapi_resource.server.body.properties), "administratorLoginPassword")
    error_message = "Use Entra-only authentication without database password material."
  }
  assert {
    condition     = azapi_resource.server.body.properties.backup == { backupRetentionDays = 7, geoRedundantBackup = "Disabled" } && azapi_resource.server.body.properties.highAvailability == { mode = "Disabled" }
    error_message = "Keep seven-day local backups without HA or geo replicas."
  }
  assert {
    condition     = azapi_resource.server.body.properties.network == { delegatedSubnetResourceId = azapi_resource.subnet.id, privateDnsZoneArmResourceId = azapi_resource.dns.id } && azapi_resource.subnet.parent_id == var.network.id && azapi_resource.subnet.body.properties.addressPrefix == "10.50.2.0/28" && azapi_resource.subnet.body.properties.delegations[0].properties.serviceName == "Microsoft.DBforPostgreSQL/flexibleServers"
    error_message = "Wire a distinct delegated private subnet and private DNS to the server."
  }
  assert {
    condition     = azapi_resource.dns_link.body.properties.virtualNetwork.id == var.network.id && !azapi_resource.dns_link.body.properties.registrationEnabled && azapi_resource.dns.name != "${var.configuration.server_name}.postgres.database.azure.com"
    error_message = "Resolve the database from the VNet without a conflicting DNS zone prefix."
  }
  assert {
    condition     = azapi_resource.administrator.name == var.configuration.administrator.object_id && azapi_resource.administrator.parent_id == azapi_resource.server.id && azapi_resource.administrator.body.properties == { principalName = "test-admins", principalType = "Group", tenantId = var.configuration.tenant_id } && azapi_update_resource.extensions.parent_id == azapi_resource.server.id && azapi_update_resource.extensions.body.properties == { source = "user-override", value = "vector" }
    error_message = "Configure only the explicit Entra administrator and allowlist vector, without executing SQL."
  }
  assert {
    condition     = output.database.id == azapi_resource.server.id && output.database.fqdn == "test-pipesor-dev-pg.postgres.database.azure.com" && output.database.subnet_id == azapi_resource.subnet.id && output.database.private_dns_zone_id == azapi_resource.dns.id
    error_message = "Export each resource's own nonsecret identity and service FQDN."
  }
}
run "reject_overlap" {
  command = plan
  variables {
    configuration = { server_name = "test-pipesor-dev-pg"
      location      = "workloadregion"
      subnet_prefix = "10.50.1.0/28"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
    administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" } }
  }
  expect_failures = [var.configuration]
}
run "track_parent_allocation_with_stable_vnet_identity" {
  command = plan
  variables {
    network = {
      id                           = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Network/virtualNetworks/vnet-pipesor-dev"
      location                     = "workloadregion"
      address_prefix               = "10.50.0.0/15"
      infrastructure_subnet_prefix = "10.50.1.0/24"
    }
  }
  assert {
    condition     = azapi_resource.subnet.replace_triggers_external_values == { vnet_prefix = "10.50.0.0/15", vnet_location = "workloadregion" } && azapi_resource.dns_link.replace_triggers_external_values == { vnet_id = var.network.id, vnet_prefix = "10.50.0.0/15", vnet_location = "workloadregion" } && toset(azapi_resource.subnet.replace_triggers_refs) == toset(["properties.addressPrefix"])
    error_message = "Track parent VNet allocation changes even when its ARM ID and database subnet prefix stay unchanged; mocked plans do not prove provider replacement behavior."
  }
}
run "reject_supernet_overlap" {
  command = plan
  variables {
    configuration = { server_name = "test-pipesor-dev-pg"
      location      = "workloadregion"
      subnet_prefix = "10.50.0.0/23"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
    administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" } }
  }
  expect_failures = [var.configuration]
}
run "reject_outside_vnet" {
  command = plan
  variables {
    configuration = { server_name = "test-pipesor-dev-pg"
      location      = "workloadregion"
      subnet_prefix = "10.51.0.0/28"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
    administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" } }
  }
  expect_failures = [var.configuration]
}
run "reject_too_small" {
  command = plan
  variables {
    configuration = { server_name = "test-pipesor-dev-pg"
      location      = "workloadregion"
      subnet_prefix = "10.50.2.0/29"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
    administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" } }
  }
  expect_failures = [var.configuration]
}
run "reject_noncanonical" {
  command = plan
  variables {
    configuration = { server_name = "test-pipesor-dev-pg"
      location      = "workloadregion"
      subnet_prefix = "10.50.2.1/28"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
    administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" } }
  }
  expect_failures = [var.configuration]
}
run "reject_ipv6" {
  command = plan
  variables {
    configuration = { server_name = "test-pipesor-dev-pg"
      location      = "workloadregion"
      subnet_prefix = "fd00::/64"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
    administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" } }
  }
  expect_failures = [var.configuration]
}
run "reject_public" {
  command = plan
  variables {
    configuration = { server_name = "test-pipesor-dev-pg"
      location      = "workloadregion"
      subnet_prefix = "203.0.113.0/28"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
    administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" } }
  }
  expect_failures = [var.configuration]
}
run "reject_wrong_region" {
  command = plan
  variables {
    configuration = { server_name = "test-pipesor-dev-pg"
      location      = "otherregion"
      subnet_prefix = "10.50.2.0/28"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
    administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" } }
  }
  expect_failures = [var.configuration]
}
run "reject_bad_tenant" {
  command = plan
  variables {
    configuration = { server_name = "test-pipesor-dev-pg"
      location      = "workloadregion"
      subnet_prefix = "10.50.2.0/28"
      tenant_id     = "not-a-tenant"
    administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" } }
  }
  expect_failures = [var.configuration]
}
run "reject_admin_type" {
  command = plan
  variables {
    configuration = { server_name = "test-pipesor-dev-pg"
      location      = "workloadregion"
      subnet_prefix = "10.50.2.0/28"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
    administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Owner" } }
  }
  expect_failures = [var.configuration]
}
run "reject_dns_conflict" {
  command = plan
  variables {
    configuration = { server_name = "pipesor-dev"
      location      = "workloadregion"
      subnet_prefix = "10.50.2.0/28"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
    administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" } }
  }
  expect_failures = [var.configuration]
}
run "reject_server_name" {
  command = plan
  variables {
    configuration = { server_name = "Bad_Server"
      location      = "workloadregion"
      subnet_prefix = "10.50.2.0/28"
      tenant_id     = "11111111-1111-1111-1111-111111111111"
    administrator = { object_id = "22222222-2222-2222-2222-222222222222", principal_name = "test-admins", principal_type = "Group" } }
  }
  expect_failures = [var.configuration]
}
