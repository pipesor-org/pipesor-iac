output "backend" {
  description = "Nonsecret workload-backend settings; does not initialize or migrate state."
  value = {
    storage_account_name = module.storage.name
    container_name       = module.container.name
    key                  = "${var.environment}/foundation.tfstate"
    use_azuread_auth     = true
  }
}
output "resource_group_name" {
  description = "Dedicated state resource group, separate from workload resources."
  value       = module.resource_group.name
}
