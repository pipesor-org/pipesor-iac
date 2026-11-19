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
    sku           = optional(object({ name = string, tier = string }), { name = "Standard_B2s", tier = "Burstable" })
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

variable "foundry" {
  description = "Opt in to one public Entra-only Foundry account/project; no models or runtime grants. Removing deployed configuration proposes destruction."
  type = object({
    account_name = string
    project_name = string
    location     = string
  })
  default = null
}

variable "rag_runtime_contract" {
  description = "Opt in to the approved RAG runtime handoff only; records required identities/configuration but creates no Container App, Entra application, role assignment, model deployment or database grant."
  type = object({
    embedding_deployment_name   = string
    embedding_model_version     = string
    tenant_id                   = string
    rag_audience_client_id      = string
    recommendation_client_id    = string
    recommendation_principal_id = string
    rag_query_app_role_id       = string
    rag_runtime_principal_id    = string
    rag_import_principal_id     = string
    rag_migration_principal_id  = string
  })
  default = null
  validation {
    condition     = var.rag_runtime_contract == null || (var.container_platform != null && var.foundry != null && var.postgresql != null)
    error_message = "The RAG runtime contract requires container_platform, foundry and postgresql foundations."
  }
  validation {
    condition = var.rag_runtime_contract == null ? true : alltrue([
      for value in [var.rag_runtime_contract.tenant_id, var.rag_runtime_contract.rag_audience_client_id, var.rag_runtime_contract.recommendation_client_id, var.rag_runtime_contract.recommendation_principal_id, var.rag_runtime_contract.rag_query_app_role_id, var.rag_runtime_contract.rag_runtime_principal_id, var.rag_runtime_contract.rag_import_principal_id, var.rag_runtime_contract.rag_migration_principal_id] :
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", value))
    ])
    error_message = "RAG tenant, application, app-role and principal identifiers must be UUIDs."
  }
  validation {
    condition     = var.rag_runtime_contract == null ? true : can(regex("^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$", var.rag_runtime_contract.embedding_deployment_name))
    error_message = "The embedding deployment name must be 3-64 lowercase letters, digits or hyphens."
  }
  validation {
    condition     = var.rag_runtime_contract == null ? true : length(trimspace(var.rag_runtime_contract.embedding_model_version)) > 0
    error_message = "An explicit nonempty embedding model version is required."
  }
  validation {
    condition     = var.rag_runtime_contract == null || try(var.rag_runtime_contract.tenant_id == var.postgresql.tenant_id, false)
    error_message = "The RAG and PostgreSQL Entra tenant IDs must match."
  }
  validation {
    condition = var.rag_runtime_contract == null ? true : length(toset([
      var.rag_runtime_contract.recommendation_principal_id,
      var.rag_runtime_contract.rag_runtime_principal_id,
      var.rag_runtime_contract.rag_import_principal_id,
      var.rag_runtime_contract.rag_migration_principal_id,
    ])) == 4
    error_message = "Recommendation, RAG runtime, importer and migrator principals must be distinct."
  }
}

variable "static_web_app" {
  description = "Opt in to Free public static hosting only. Removing deployed configuration proposes destruction."
  type        = object({ name = string, location = string })
  default     = null
}

variable "key_vault" {
  description = "Opt in to environment-owned App material and optional human credential vaults. No secret payloads. Removing deployed configuration proposes destruction."
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
  default = null
}
