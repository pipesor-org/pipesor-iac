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
}

variable "tenant_id" {
  description = "Explicit target tenant UUID; verify against the authenticated provider before real operations."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "Tenant ID must be a UUID."
  }
}
