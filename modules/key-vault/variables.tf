variable "environment" {
  description = "Fixed environment identity; these vaults belong only to this environment."
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

variable "allowed_subnet_ids" {
  description = "Existing environment-owned subnets with Microsoft.KeyVault service endpoints; no missing-endpoint bypass."
  type        = set(string)
  default     = []
  nullable    = false
  validation {
    condition = try(alltrue([for id in var.allowed_subnet_ids :
      can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$", id)) &&
      startswith(lower(id), "${lower(var.resource_group_id)}/providers/microsoft.network/virtualnetworks/")
    ]), false)
    error_message = "Allow only service-endpoint subnet IDs in this environment's resource group and subscription."
  }
}

variable "configuration" {
  description = "Explicit vault names, tenant, region, approved egress IPv4s and optional scoped grants. Secret payloads are initialized outside Terraform."
  type = object({
    app_material_name    = string
    location             = string
    tenant_id            = string
    allowed_public_ipv4s = set(string)
    app_material_readers = optional(map(object({ object_id = string, principal_type = string })), {})
    custody = optional(object({
      name       = string
      principals = optional(map(object({ object_id = string, principal_type = string })), {})
    }))
  })
  nullable = false
  validation {
    condition = alltrue([for name in concat([var.configuration.app_material_name], var.configuration.custody == null ? [] : [var.configuration.custody.name]) :
      can(regex("^[a-z][a-z0-9-]{1,22}[a-z0-9]$", name)) && !strcontains(coalesce(name, " "), "--")
    ]) && (var.configuration.custody == null ? true : var.configuration.app_material_name != var.configuration.custody.name)
    error_message = "Vault names must be distinct, globally available, 3-24 lowercase alphanumeric/hyphen characters, start with a letter, end with a letter/digit and contain no consecutive hyphens."
  }
  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.configuration.location))
    error_message = "Supply an explicit lowercase Azure region code."
  }
  validation {
    condition     = can(regex("(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.configuration.tenant_id)) && var.configuration.tenant_id != "00000000-0000-0000-0000-000000000000"
    error_message = "Supply the nonzero UUID of the approved vault tenant."
  }
  # shortcut: allow only narrow public egress ranges; review this contract before admitting broader networks.
  validation {
    condition = try((length(var.configuration.allowed_public_ipv4s) > 0 || length(var.allowed_subnet_ids) > 0) && length(var.configuration.allowed_public_ipv4s) <= 1000 && alltrue([
      for ip in var.configuration.allowed_public_ipv4s : try(
        can(cidrnetmask(strcontains(ip, "/") ? ip : "${ip}/32")) &&
        (!strcontains(ip, "/") || (tonumber(split("/", ip)[1]) >= 24 && tonumber(split("/", ip)[1]) <= 32 && cidrhost(ip, 0) == split("/", ip)[0])) &&
        tonumber(split(".", ip)[0]) > 0 && tonumber(split(".", ip)[0]) < 224 &&
        !contains([10, 127], tonumber(split(".", ip)[0])) &&
        !(tonumber(split(".", ip)[0]) == 172 && tonumber(split(".", ip)[1]) >= 16 && tonumber(split(".", ip)[1]) <= 31) &&
        !(tonumber(split(".", ip)[0]) == 192 && tonumber(split(".", ip)[1]) == 168) &&
        !(tonumber(split(".", ip)[0]) == 100 && tonumber(split(".", ip)[1]) >= 64 && tonumber(split(".", ip)[1]) <= 127) &&
      !(tonumber(split(".", ip)[0]) == 169 && tonumber(split(".", ip)[1]) == 254), false)
    ]), false)
    error_message = "Provide an approved public IPv4 address/canonical /24-/32 range or an environment subnet; no world-open, private, CGNAT, loopback, link-local or IPv6 rules."
  }
  validation {
    condition = try(alltrue([for principals in [var.configuration.app_material_readers, var.configuration.custody == null ? {} : var.configuration.custody.principals] :
      alltrue([for principal in values(principals) :
        can(regex("(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", principal.object_id)) &&
        principal.object_id != "00000000-0000-0000-0000-000000000000" && contains(["User", "Group", "ServicePrincipal"], principal.principal_type)
      ]) && length(distinct([for principal in values(principals) : lower(principal.object_id)])) == length(principals)
    ]), false)
    error_message = "Each grant needs a unique nonzero object UUID and User, Group or ServicePrincipal type; no duplicate principal aliases."
  }
}
