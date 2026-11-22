variable "environment" {
  description = "Fixed environment identity; the Foundry capability is shared only within this environment."
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
  description = "Explicit account/custom-subdomain name, project name and workload region; verify availability and residency before deployment."
  type = object({
    account_name = string
    project_name = string
    location     = string
    deployments = optional(map(object({
      model_name    = string
      model_version = string
      sku_name      = string
      capacity      = number
    })), {})
  })
  nullable = false
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]$", var.configuration.account_name))
    error_message = "Account/custom-subdomain name must be 2-64 lowercase letters, digits or hyphens, beginning and ending with a letter or digit."
  }
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]{1,63}$", var.configuration.project_name))
    error_message = "Project name must be 2-64 letters, digits, underscores, dots or hyphens and start with a letter or digit."
  }
  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.configuration.location))
    error_message = "Supply an explicit lowercase Azure region code."
  }
  validation {
    condition = alltrue([for name, deployment in var.configuration.deployments :
      can(regex("^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$", name)) && length(trimspace(deployment.model_version)) > 0 &&
      contains(["Standard", "GlobalStandard", "DataZoneStandard"], deployment.sku_name) &&
      deployment.capacity >= 1 && floor(deployment.capacity) == deployment.capacity
    ])
    error_message = "Each deployment needs a 3-64 character lowercase name, a pinned model version, a Standard, GlobalStandard or DataZoneStandard SKU and a positive integer capacity (thousands of tokens per minute)."
  }
}
