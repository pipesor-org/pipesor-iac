variable "environment" {
  type        = string
  description = "Fixed isolated environment identity."
  nullable    = false
  validation {
    condition     = contains(["dev", "qa", "preprod", "prod"], var.environment)
    error_message = "Select dev, qa, preprod or prod."
  }
}
variable "resource_group_id" {
  type        = string
  description = "Resource group owned by this environment."
  nullable    = false
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+$", var.resource_group_id))
    error_message = "Supply a resource-group ARM ID."
  }
}
variable "network" {
  description = "Existing platform VNet and allocation contract; database must use its region and a nonoverlapping subnet."
  type        = object({ id = string, location = string, address_prefix = string, infrastructure_subnet_prefix = string })
  nullable    = false
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+$", var.network.id))
    error_message = "Supply the platform VNet ARM ID."
  }
}
variable "configuration" {
  description = "Explicit server identity, location, subnet and Entra administrator; no credentials or defaults."
  type = object({
    server_name   = string
    location      = string
    subnet_prefix = string
    tenant_id     = string
    administrator = object({ object_id = string, principal_name = string, principal_type = string })
  })
  nullable = false
  validation {
    condition     = try(length(var.configuration.server_name) >= 3 && length(var.configuration.server_name) <= 63 && can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.configuration.server_name)) && var.configuration.server_name != "pipesor-${var.environment}", false)
    error_message = "Use a 3-63 character lowercase server name with single separating hyphens; it must differ from the private DNS zone prefix."
  }
  validation {
    condition     = try(can(regex("^[a-z][a-z0-9]+$", var.configuration.location)) && var.configuration.location == var.network.location, false)
    error_message = "Server location must match the existing VNet's explicit lowercase region."
  }
  validation {
    condition     = alltrue([for id in [var.configuration.tenant_id, var.configuration.administrator.object_id] : can(regex("(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))])
    error_message = "Tenant and administrator object IDs must be UUIDs."
  }
  validation {
    condition     = try(contains(["Group", "User", "ServicePrincipal"], var.configuration.administrator.principal_type) && length(trimspace(var.configuration.administrator.principal_name)) > 0, false)
    error_message = "Supply the administrator principal name and Group, User or ServicePrincipal type."
  }
  validation {
    condition = try(
      can(cidrnetmask(var.configuration.subnet_prefix)) && cidrhost(var.configuration.subnet_prefix, 0) == split("/", var.configuration.subnet_prefix)[0] &&
      tonumber(split("/", var.configuration.subnet_prefix)[1]) <= 28 &&
      tonumber(split("/", var.configuration.subnet_prefix)[1]) >= tonumber(split("/", var.network.address_prefix)[1]) &&
      cidrhost("${split("/", var.configuration.subnet_prefix)[0]}/${split("/", var.network.address_prefix)[1]}", 0) == cidrhost(var.network.address_prefix, 0) &&
      ((startswith(var.configuration.subnet_prefix, "10.") && tonumber(split("/", var.configuration.subnet_prefix)[1]) >= 8) ||
        (can(regex("^172\\.(1[6-9]|2[0-9]|3[01])\\.", var.configuration.subnet_prefix)) && tonumber(split("/", var.configuration.subnet_prefix)[1]) >= 12) ||
      (startswith(var.configuration.subnet_prefix, "192.168.") && tonumber(split("/", var.configuration.subnet_prefix)[1]) >= 16)) &&
      cidrhost("${split("/", var.configuration.subnet_prefix)[0]}/${min(tonumber(split("/", var.configuration.subnet_prefix)[1]), tonumber(split("/", var.network.infrastructure_subnet_prefix)[1]))}", 0) !=
    cidrhost("${split("/", var.network.infrastructure_subnet_prefix)[0]}/${min(tonumber(split("/", var.configuration.subnet_prefix)[1]), tonumber(split("/", var.network.infrastructure_subnet_prefix)[1]))}", 0), false)
    error_message = "Use a canonical private IPv4 subnet /28 or larger, inside the VNet and disjoint from the dedicated ACA subnet."
  }
}
