variable "environment" {
  description = "Fixed environment identity; infrastructure is shared only within this environment."
  type        = string
  nullable    = false
  validation {
    condition     = contains(["dev", "qa", "preprod", "prod"], var.environment)
    error_message = "Environment must be dev, qa, preprod or prod."
  }
}
variable "resource_group_id" {
  description = "Explicit resource-group ID owned by this environment root."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+$", var.resource_group_id))
    error_message = "Supply a resource-group ARM ID."
  }
}
variable "configuration" {
  description = "Approved network allocation and telemetry limits; no actual environment values are defaulted."
  type = object({
    location                     = string
    vnet_address_prefix          = string
    infrastructure_subnet_prefix = string
    log_retention_days           = number
    log_daily_cap_gb             = number
  })
  nullable = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.configuration.location))
    error_message = "Location must be an explicit lowercase Azure region code."
  }
  validation {
    condition = alltrue([for prefix in [var.configuration.vnet_address_prefix, var.configuration.infrastructure_subnet_prefix] : try(
      can(cidrnetmask(prefix)) && cidrhost(prefix, 0) == split("/", prefix)[0] && (
        (startswith(prefix, "10.") && tonumber(split("/", prefix)[1]) >= 8) ||
        (can(regex("^172\\.(1[6-9]|2[0-9]|3[01])\\.", prefix)) && tonumber(split("/", prefix)[1]) >= 12) ||
        (startswith(prefix, "192.168.") && tonumber(split("/", prefix)[1]) >= 16)
    ), false)])
    error_message = "Use canonical private RFC1918 IPv4 CIDRs for the VNet and dedicated subnet."
  }
  validation {
    condition = try(
      tonumber(split("/", var.configuration.infrastructure_subnet_prefix)[1]) <= 27 &&
      tonumber(split("/", var.configuration.infrastructure_subnet_prefix)[1]) >= tonumber(split("/", var.configuration.vnet_address_prefix)[1]) &&
      cidrhost("${split("/", var.configuration.infrastructure_subnet_prefix)[0]}/${split("/", var.configuration.vnet_address_prefix)[1]}", 0) == cidrhost(var.configuration.vnet_address_prefix, 0) &&
      cidrhost("${split("/", var.configuration.infrastructure_subnet_prefix)[0]}/15", 0) != "172.30.0.0" &&
    cidrhost("172.30.0.0/${split("/", var.configuration.infrastructure_subnet_prefix)[1]}", 0) != cidrhost(var.configuration.infrastructure_subnet_prefix, 0), false)
    error_message = "The dedicated subnet must be /27 or larger, contained in the VNet, and must not overlap ACA-reserved 172.30.0.0/15."
  }
  validation {
    condition     = try(var.configuration.log_retention_days >= 30 && var.configuration.log_retention_days <= 730 && floor(var.configuration.log_retention_days) == var.configuration.log_retention_days, false)
    error_message = "Workspace retention must be an explicitly selected integer from 30 to 730 days."
  }
  validation {
    condition     = try(var.configuration.log_daily_cap_gb > 0, false)
    error_message = "Supply a positive daily ingestion cap in GB; unlimited ingestion is not the MVP contract."
  }
}
