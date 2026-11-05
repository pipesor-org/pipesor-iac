mock_provider "azapi" {}

variables {
  environment       = "dev"
  resource_group_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev"
  configuration = {
    namespace_name = "test-pipesor-dev-bus"
    location       = "messagingregion"
  }
}

override_resource {
  target          = azapi_resource.namespace
  override_during = plan
  values = {
    id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ServiceBus/namespaces/test-pipesor-dev-bus"
  }
}

run "standard_public_entra_only_contract" {
  command = plan
  assert {
    condition     = azapi_resource.namespace.body.sku == { name = "Standard", tier = "Standard" }
    error_message = "Use the approved Standard tier, with no Premium capacity."
  }
  assert {
    condition     = azapi_resource.namespace.body.properties == { disableLocalAuth = true, publicNetworkAccess = "Enabled", minimumTlsVersion = "1.2" }
    error_message = "Keep public access authenticated through Entra only, disable SAS and require TLS 1.2."
  }
  assert {
    condition     = azapi_resource.namespace.parent_id == var.resource_group_id && azapi_resource.namespace.location == "messagingregion" && azapi_resource.namespace.tags.environment == "dev"
    error_message = "The namespace must use the caller's resource group, distinct workload region and environment."
  }
  assert {
    condition     = output.namespace.name == "test-pipesor-dev-bus" && output.namespace.location == "messagingregion" && output.namespace.id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ServiceBus/namespaces/test-pipesor-dev-bus"
    error_message = "Export the namespace's resource identity without credentials."
  }
}

run "accept_minimum_length" {
  command = plan
  variables {
    configuration = { namespace_name = "a12345", location = "messagingregion" }
  }
  assert {
    condition     = output.namespace.name == "a12345"
    error_message = "Accept a valid Azure name at the length boundary without rewriting it."
  }
}

run "accept_maximum_length" {
  command = plan
  variables {
    configuration = { namespace_name = "a1111111111111111111111111111111111111111111111111", location = "messagingregion" }
  }
  assert {
    condition     = output.namespace.name == "a1111111111111111111111111111111111111111111111111"
    error_message = "Accept a valid Azure name at the length boundary without rewriting it."
  }
}

run "reject_short_name" {
  command = plan
  variables {
    configuration = { namespace_name = "abcde", location = "messagingregion" }
  }
  expect_failures = [var.configuration]
}

run "reject_long_name" {
  command = plan
  variables {
    configuration = { namespace_name = "a11111111111111111111111111111111111111111111111111", location = "messagingregion" }
  }
  expect_failures = [var.configuration]
}

run "reject_digit_start" {
  command = plan
  variables {
    configuration = { namespace_name = "1pipesor", location = "messagingregion" }
  }
  expect_failures = [var.configuration]
}

run "reject_trailing_hyphen" {
  command = plan
  variables {
    configuration = { namespace_name = "pipesor-", location = "messagingregion" }
  }
  expect_failures = [var.configuration]
}

run "reject_underscore" {
  command = plan
  variables {
    configuration = { namespace_name = "pipesor_bus", location = "messagingregion" }
  }
  expect_failures = [var.configuration]
}

run "reject_null_name" {
  command = plan
  variables {
    configuration = { namespace_name = null, location = "messagingregion" }
  }
  expect_failures = [var.configuration]
}

run "reject_blank_location" {
  command = plan
  variables { configuration = { namespace_name = "test-pipesor-dev-bus", location = " " } }
  expect_failures = [var.configuration]
}

run "reject_null_location" {
  command = plan
  variables { configuration = { namespace_name = "test-pipesor-dev-bus", location = null } }
  expect_failures = [var.configuration]
}

run "reject_environment" {
  command = plan
  variables { environment = "other" }
  expect_failures = [var.environment]
}

run "reject_resource_group" {
  command = plan
  variables { resource_group_id = "/subscriptions/not-a-uuid/resourceGroups/rg-pipesor-dev" }
  expect_failures = [var.resource_group_id]
}
