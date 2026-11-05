output "resource_group" {
  description = "Resource-group contract for this environment only."
  value       = module.resource_group.resource_group
}

output "container_platform" {
  description = "Platform contract, or null when this environment has not opted in."
  value       = one(module.container_platform[*].platform)
}

output "service_bus" {
  description = "Nonsecret namespace identity, or null when this environment has not opted in."
  value       = one(module.service_bus[*].namespace)
}

output "postgresql" {
  description = "Private database identity, or null when not provisioned."
  value       = one(module.postgresql[*].database)
}

output "application_insights" {
  description = "Backend telemetry routing, or null when disabled; publishing data still requires approved Entra access."
  value       = one(module.application_insights[*].telemetry)
}
