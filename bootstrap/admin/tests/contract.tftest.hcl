mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults        = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-state-admin/providers/Microsoft.Storage/storageAccounts/fixture" }
    override_during = plan
  }
  mock_data "azapi_client_config" {
    defaults = { subscription_id = "11111111-1111-1111-1111-111111111111" }
  }
}

variables {
  subscription_id = "11111111-1111-1111-1111-111111111111"
  tenant_id       = "44444444-4444-4444-4444-444444444444"
  settings = {
    account_name  = "pipesorstatefixtureadmin"
    location      = "testregion"
    replication   = "LRS"
    recovery_days = 30
    principal_ids = ["22222222-2222-2222-2222-222222222222", "33333333-3333-3333-3333-333333333333"]
    allowed_ips   = ["198.51.100.5", "203.0.113.0/24"]
  }
}
run "admin_bootstrap_isolation" {
  command = plan
  assert {
    condition     = output.backend.storage_account_name == "pipesorstatefixtureadmin" && output.backend.container_name == "tfstate-admin" && output.backend.key == "subscription-controls/budget.tfstate" && output.backend.use_azuread_auth == true
    error_message = "The administrative backend must have its own account/container and subscription-controls key."
  }
  assert {
    condition     = output.resource_group_name == "rg-pipesor-state-admin"
    error_message = "Administrative state resources must have a group separate from workload and environment state groups."
  }

}

override_resource {
  target          = module.state_store.module.resource_group.azapi_resource.this
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-state-admin" }
}

override_resource {
  target          = module.state_store.module.container.azapi_resource.this
  override_during = plan
  values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-state-admin/providers/Microsoft.Storage/storageAccounts/fixture/blobServices/default/containers/tfstate-admin" }
}
