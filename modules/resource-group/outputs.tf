output "resource_group" {
  description = "Resource-group ID, name and metadata location for explicit downstream wiring."
  value = {
    id       = module.resource_group.resource_id
    name     = module.resource_group.name
    location = module.resource_group.location
  }
}
