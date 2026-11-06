output "backend" {
  description = "Nonsecret backend configuration for subscription-controls, separate from workload state."
  value       = module.state_store.backend
}
output "resource_group_name" {
  description = "Dedicated state resource group."
  value       = module.state_store.resource_group_name
}
