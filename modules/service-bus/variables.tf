variable "environment" {
  description = "Fixed environment identity; the namespace is shared only within this environment."
  type        = string
  nullable    = false
  validation {
    condition     = contains(["dev", "qa", "preprod", "prod"], var.environment)
    error_message = "Environment must be dev, qa, preprod or prod."
  }
}
variable "resource_group_id" {
  description = "Resource-group ARM ID owned by the isolated environment root."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/resourceGroups/[^/]+$", var.resource_group_id))
    error_message = "Supply a resource-group ARM ID with a subscription UUID."
  }
}
variable "configuration" {
  description = "Explicit globally available namespace name and approved workload location; no deployment values are defaulted."
  type = object({
    namespace_name = string
    location       = string
  })
  nullable = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,48}[a-z0-9]$", var.configuration.namespace_name))
    error_message = "Namespace name must be 6-50 lowercase letters, digits or hyphens, start with a letter and end with a letter or digit; verify global availability separately."
  }
  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.configuration.location))
    error_message = "Location must be an explicit lowercase Azure region code."
  }
}
