mock_provider "azapi" {}
variables {
  environment       = "dev"
  resource_group_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev"
  configuration     = { name = "pipesor-dev-web", location = "webregion" }
}
override_resource {
  target          = azapi_resource.site
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.Web/staticSites/pipesor-dev-web", output = { properties = { defaultHostname = "synthetic.azurestaticapps.net" } } }
}
run "free_public_hosting_only" {
  command = plan
  assert {
    condition     = azapi_resource.site.body.sku.name == "Free" && azapi_resource.site.body.sku.tier == "Free" && azapi_resource.site.body.properties.publicNetworkAccess == "Enabled"
    error_message = "Only the approved Free public hosting boundary is allowed."
  }
  assert {
    condition     = azapi_resource.site.body.properties.enterpriseGradeCdnStatus == "Disabled" && azapi_resource.site.body.properties.stagingEnvironmentPolicy == "Disabled" && azapi_resource.site.body.properties.buildProperties.skipGithubActionWorkflowGeneration == true
    error_message = "No enterprise CDN, preview environments or generated delivery workflow."
  }
  assert {
    condition     = length(keys(azapi_resource.site.body.properties)) == 4 && length(keys(azapi_resource.site.body.properties.buildProperties)) == 1 && length(keys(azapi_resource.site.body)) == 2
    error_message = "Hosting must not add repository credentials, integrations, authentication or build settings."
  }
  assert {
    condition     = azapi_resource.site.parent_id == var.resource_group_id && azapi_resource.site.name == "pipesor-dev-web" && azapi_resource.site.location == "webregion" && azapi_resource.site.tags.environment == "dev"
    error_message = "Preserve the environment resource group, identity and explicit region."
  }
  assert {
    condition     = output.site.id == azapi_resource.site.id && output.site.default_hostname == "synthetic.azurestaticapps.net" && length(azapi_resource.site.response_export_values) == 1 && azapi_resource.site.response_export_values[0] == "properties.defaultHostname" && length(keys(output.site)) == 4
    error_message = "Export hosting identity and default hostname only, never deployment credentials."
  }
}

run "reject_blank" {
  command = plan
  variables { configuration = { name = "", location = "webregion" } }
  expect_failures = [var.configuration]
}

run "reject_long" {
  command = plan
  variables { configuration = { name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", location = "webregion" } }
  expect_failures = [var.configuration]
}

run "reject_invalid" {
  command = plan
  variables { configuration = { name = "bad/name", location = "webregion" } }
  expect_failures = [var.configuration]
}

run "reject_null_name" {
  command = plan
  variables { configuration = { name = null, location = "webregion" } }
  expect_failures = [var.configuration]
}

run "reject_blank_location" {
  command = plan
  variables { configuration = { name = "pipesor-dev-web", location = " " } }
  expect_failures = [var.configuration]
}

run "reject_null_location" {
  command = plan
  variables { configuration = { name = "pipesor-dev-web", location = null } }
  expect_failures = [var.configuration]
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
