mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "11111111-1111-1111-1111-111111111111"
    }
  }
}

variables {
  environment = "dev"
  location    = "testregion"
}

run "dev_contract" {
  command = plan

  variables {
    environment = "dev"
  }

  assert {
    condition     = output.resource_group.name == "rg-pipesor-dev"
    error_message = "Resource-group names must be stable and distinguish environments."
  }

  assert {
    condition     = output.resource_group.location == "testregion"
    error_message = "The explicit metadata location must pass through unchanged."
  }

  assert {
    condition     = module.resource_group.resource.parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111" && module.resource_group.resource.type == "Microsoft.Resources/resourceGroups@2025-04-01"
    error_message = "Only the resource group belongs under the provider's selected subscription."
  }
}

run "qa_contract" {
  command = plan

  variables {
    environment = "qa"
  }

  assert {
    condition     = output.resource_group.name == "rg-pipesor-qa"
    error_message = "Resource-group names must be stable and distinguish environments."
  }

  assert {
    condition     = output.resource_group.location == "testregion"
    error_message = "The explicit metadata location must pass through unchanged."
  }

  assert {
    condition     = module.resource_group.resource.parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111" && module.resource_group.resource.type == "Microsoft.Resources/resourceGroups@2025-04-01"
    error_message = "Only the resource group belongs under the provider's selected subscription."
  }
}

run "preprod_contract" {
  command = plan

  variables {
    environment = "preprod"
  }

  assert {
    condition     = output.resource_group.name == "rg-pipesor-preprod"
    error_message = "Resource-group names must be stable and distinguish environments."
  }

  assert {
    condition     = output.resource_group.location == "testregion"
    error_message = "The explicit metadata location must pass through unchanged."
  }

  assert {
    condition     = module.resource_group.resource.parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111" && module.resource_group.resource.type == "Microsoft.Resources/resourceGroups@2025-04-01"
    error_message = "Only the resource group belongs under the provider's selected subscription."
  }
}

run "prod_contract" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = output.resource_group.name == "rg-pipesor-prod"
    error_message = "Resource-group names must be stable and distinguish environments."
  }

  assert {
    condition     = output.resource_group.location == "testregion"
    error_message = "The explicit metadata location must pass through unchanged."
  }

  assert {
    condition     = module.resource_group.resource.parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111" && module.resource_group.resource.type == "Microsoft.Resources/resourceGroups@2025-04-01"
    error_message = "Only the resource group belongs under the provider's selected subscription."
  }
}

run "reject_unknown_environment" {
  command = plan

  variables {
    environment = "staging"
  }

  expect_failures = [var.environment]
}

run "reject_blank_location" {
  command = plan

  variables {
    location = " "
  }

  expect_failures = [var.location]
}
