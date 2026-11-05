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
