output "backend" {
  description = "Nonsecret workload-backend configuration for this environment."
  value       = module.state_store.backend
}
output "resource_group_name" {
  description = "Dedicated state resource group."
  value       = module.state_store.resource_group_name
}
