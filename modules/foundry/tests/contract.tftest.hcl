mock_provider "azapi" {}
variables {
  environment       = "dev"
  resource_group_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev"
  configuration     = { account_name = "test-pipesor-dev-ai", project_name = "pipesor-dev", location = "airegion" }
}
override_resource {
  target          = azapi_resource.account
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.CognitiveServices/accounts/test-pipesor-dev-ai", output = { properties = { endpoint = "https://synthetic.cognitiveservices.azure.com/" } } }
}
override_resource {
  target          = azapi_resource.project
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.CognitiveServices/accounts/test-pipesor-dev-ai/projects/pipesor-dev" }
}
run "public_entra_foundry_contract" {
  command = plan
  assert {
    condition     = azapi_resource.account.body.kind == "AIServices" && azapi_resource.account.body.sku.name == "S0" && azapi_resource.account.body.properties.allowProjectManagement == true
    error_message = "Create a Foundry-enabled account, not a standalone OpenAI account or hub."
  }
  assert {
    condition     = azapi_resource.account.body.properties.disableLocalAuth == true && azapi_resource.account.body.properties.publicNetworkAccess == "Enabled" && azapi_resource.account.body.properties.networkAcls.defaultAction == "Allow" && length(azapi_resource.account.body.properties.networkAcls.ipRules) == 0 && length(azapi_resource.account.body.properties.networkAcls.virtualNetworkRules) == 0
    error_message = "Public access must remain Entra-only, without assuming an operator or ACA IP allowlist."
  }
  assert {
    condition     = azapi_resource.account.parent_id == var.resource_group_id && azapi_resource.account.location == "airegion" && azapi_resource.account.body.properties.customSubDomainName == "test-pipesor-dev-ai" && azapi_resource.project.parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.CognitiveServices/accounts/test-pipesor-dev-ai" && azapi_resource.project.location == "airegion"
    error_message = "Preserve resource group, region, subdomain and account/project ownership."
  }
  assert {
    condition     = one(azapi_resource.account.identity).type == "SystemAssigned" && one(azapi_resource.project.identity).type == "SystemAssigned"
    error_message = "Both resources require their own managed identity; these do not grant caller access."
  }
  assert {
    condition     = output.foundry.account_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.CognitiveServices/accounts/test-pipesor-dev-ai" && output.foundry.project_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.CognitiveServices/accounts/test-pipesor-dev-ai/projects/pipesor-dev" && output.foundry.endpoint == "https://synthetic.cognitiveservices.azure.com/" && length(azapi_resource.account.response_export_values) == 1 && azapi_resource.account.response_export_values[0] == "properties.endpoint"
    error_message = "Export service-reported identity and endpoint only."
  }
}

run "reject_account_short" {
  command = plan
  variables { configuration = { account_name = "a", project_name = "pipesor-dev", location = "airegion" } }
  expect_failures = [var.configuration]
}

run "reject_account_long" {
  command = plan
  variables { configuration = { account_name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", project_name = "pipesor-dev", location = "airegion" } }
  expect_failures = [var.configuration]
}

run "reject_account_invalid" {
  command = plan
  variables { configuration = { account_name = "_bad", project_name = "pipesor-dev", location = "airegion" } }
  expect_failures = [var.configuration]
}

run "reject_account_null" {
  command = plan
  variables { configuration = { account_name = null, project_name = "pipesor-dev", location = "airegion" } }
  expect_failures = [var.configuration]
}

run "reject_project_short" {
  command = plan
  variables { configuration = { account_name = "test-pipesor-dev-ai", project_name = "a", location = "airegion" } }
  expect_failures = [var.configuration]
}

run "reject_project_invalid" {
  command = plan
  variables { configuration = { account_name = "test-pipesor-dev-ai", project_name = "bad/name", location = "airegion" } }
  expect_failures = [var.configuration]
}

run "reject_project_null" {
  command = plan
  variables { configuration = { account_name = "test-pipesor-dev-ai", project_name = null, location = "airegion" } }
  expect_failures = [var.configuration]
}

run "reject_location_blank" {
  command = plan
  variables { configuration = { account_name = "test-pipesor-dev-ai", project_name = "pipesor-dev", location = " " } }
  expect_failures = [var.configuration]
}

run "reject_location_null" {
  command = plan
  variables { configuration = { account_name = "test-pipesor-dev-ai", project_name = "pipesor-dev", location = null } }
  expect_failures = [var.configuration]
}

run "reject_environment" {
  command = plan
  variables { environment = "other" }
  expect_failures = [var.environment]
}

run "reject_resource_group" {
  command = plan
  variables { resource_group_id = "/invalid" }
  expect_failures = [var.resource_group_id]
}
