variable "environment" {
  type        = string
  nullable    = false
  description = "Fixed environment identity; backend services share one component only within this environment."
  validation {
    condition     = contains(["dev", "qa", "preprod", "prod"], var.environment)
    error_message = "Environment must be dev, qa, preprod or prod."
  }
}
variable "resource_group_id" {
  type        = string
  nullable    = false
  description = "Resource group owned by the isolated environment root."
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/resourceGroups/[^/]+$", var.resource_group_id))
    error_message = "Supply a resource-group ARM ID with a subscription UUID."
  }
}
variable "workspace" {
  type        = object({ id = string, location = string })
  nullable    = false
  description = "Existing environment workspace identity and approved location; no additional workspace is created."
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/resourceGroups/[^/]+/providers/Microsoft[.]OperationalInsights/workspaces/[^/]+$", var.workspace.id))
    error_message = "Supply a Log Analytics workspace ARM ID."
  }
  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.workspace.location))
    error_message = "Supply an explicit lowercase Azure region code for the existing workspace."
  }
}
