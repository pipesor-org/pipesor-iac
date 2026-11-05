variable "subscription_id" {
  description = "Explicit target Azure subscription UUID; confirm it before any real plan."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "Subscription ID must be a UUID."
  }
}

variable "location" {
  description = "Explicit Azure region code for resource-group metadata; no default region."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.location))
    error_message = "Location must be a nonempty lowercase Azure region code without whitespace."
  }
}

variable "container_platform" {
  description = "Opt in to the shared Consumption platform with approved allocation and telemetry limits; null provisions no platform. Removing a deployed configuration proposes destruction."
  type = object({
    location                     = string
    vnet_address_prefix          = string
    infrastructure_subnet_prefix = string
    log_retention_days           = number
    log_daily_cap_gb             = number
  })
  default = null
}

variable "service_bus" {
  description = "Opt in to the approved public, Entra-only Standard namespace; null provisions none. Removing a deployed configuration proposes destruction."
  type = object({
    namespace_name = string
    location       = string
  })
  default = null
}

variable "postgresql" {
  description = "Opt in to the private Entra-only PostgreSQL MVP; requires the platform VNet. Removing deployed configuration proposes destruction."
  type = object({
    server_name   = string
    location      = string
    subnet_prefix = string
    tenant_id     = string
    administrator = object({ object_id = string, principal_name = string, principal_type = string })
  })
  default = null
  validation {
    condition     = var.postgresql == null || var.container_platform != null
    error_message = "PostgreSQL requires the existing container platform VNet; opt in to container_platform first."
  }
}

variable "application_insights_enabled" {
  type        = bool
  nullable    = false
  default     = false
  description = "Opt in to shared backend Application Insights using the existing platform workspace. Disabling after deployment proposes destruction."
  validation {
    condition     = !var.application_insights_enabled || var.container_platform != null
    error_message = "Application Insights requires the existing container platform workspace."
  }
}
