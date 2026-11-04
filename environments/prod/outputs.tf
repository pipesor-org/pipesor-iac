output "resource_group" {
  description = "Resource-group contract for this environment only."
  value       = module.resource_group.resource_group
}
