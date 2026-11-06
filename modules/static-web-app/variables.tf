variable "environment" {
  description = "Fixed environment identity; the Static Web Apps capability is shared only within this environment."
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
  description = "Explicit hosting resource name and region; no authentication, domains or delivery configuration."
  type        = object({ name = string, location = string })
  nullable    = false
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{1,60}$", var.configuration.name))
    error_message = "Name must be 1-60 alphanumeric characters or hyphens."
  }
  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.configuration.location))
    error_message = "Supply an explicit lowercase Azure region code."
  }
}
