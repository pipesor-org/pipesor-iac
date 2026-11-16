variable "subscription_id" {
  description = "Explicit target subscription UUID; verify against the authenticated provider before real operations."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "Subscription ID must be a UUID."
  }
}
variable "settings" {
  description = "Reviewed state-storage configuration; no Azure deployment values are selected by defaults."
  type = object({
    account_name  = string
    location      = string
    replication   = string
    recovery_days = number
    principal_ids = set(string)
    allowed_ips   = set(string)
  })
  nullable = false
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.settings.account_name))
    error_message = "Account name must contain 3-24 lowercase letters or digits and be globally available."
  }
  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.settings.location))
    error_message = "Location must be a lowercase Azure region code."
  }
  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.settings.replication)
    error_message = "Select a supported Standard storage replication option."
  }
  validation {
    condition     = var.settings.recovery_days >= 1 && var.settings.recovery_days <= 365 && floor(var.settings.recovery_days) == var.settings.recovery_days
    error_message = "Recovery days must be an integer from 1 to 365; state recovery is separate from workload retention."
  }
  validation {
    condition     = length(var.settings.principal_ids) > 0 && alltrue([for id in var.settings.principal_ids : can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", id)) && lower(id) != "00000000-0000-0000-0000-000000000000"])
    error_message = "Provide at least one nonzero Entra principal object UUID, reviewed for this state scope only."
  }
  # shortcut: narrow operator egress ranges only; review validation/tests before admitting broader ranges.
  validation {
    condition = length(var.settings.allowed_ips) > 0 && length(var.settings.allowed_ips) <= 400 && alltrue([
      for ip in var.settings.allowed_ips : try(
        can(cidrnetmask(strcontains(ip, "/") ? ip : "${ip}/32")) &&
        (!strcontains(ip, "/") || (tonumber(split("/", ip)[1]) >= 24 && tonumber(split("/", ip)[1]) <= 30 && cidrhost(ip, 0) == split("/", ip)[0])) &&
        tonumber(split(".", ip)[0]) > 0 && tonumber(split(".", ip)[0]) < 224 &&
        !contains([10, 127], tonumber(split(".", ip)[0])) &&
        !(tonumber(split(".", ip)[0]) == 172 && tonumber(split(".", ip)[1]) >= 16 && tonumber(split(".", ip)[1]) <= 31) &&
        !(tonumber(split(".", ip)[0]) == 192 && tonumber(split(".", ip)[1]) == 168) &&
        !(tonumber(split(".", ip)[0]) == 100 && tonumber(split(".", ip)[1]) >= 64 && tonumber(split(".", ip)[1]) <= 127) &&
      !(tonumber(split(".", ip)[0]) == 169 && tonumber(split(".", ip)[1]) == 254), false)
    ])
    error_message = "Provide 1-400 approved public IPv4 addresses or canonical /24-/30 ranges; no world-open, private, CGNAT, loopback, link-local or IPv6 rules. Use single IPs instead of /31 or /32 CIDRs."
  }
}
variable "environment" {
  description = "Fixed workload environment state scope; administrative state is not supported."
  type        = string
  nullable    = false
  validation {
    condition     = contains(["dev", "qa", "preprod", "prod"], var.environment)
    error_message = "State scope must be dev, qa, preprod or prod."
  }
}
