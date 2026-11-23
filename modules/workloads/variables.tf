variable "environment" {
  description = "Fixed environment identity; these workloads belong only to this environment."
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
  description = <<-EOT
    Runtime manifest inputs for the seven services (pipesor-docs runtime-manifest.md and ADR-022). Secret payloads
    (registry token, GitHub App material, authority document) are created by the operator in Key Vault; only their
    names and exact versions appear here.
  EOT
  type = object({
    location                 = string
    platform_tenant_id       = string
    container_environment_id = string
    images                   = map(string)
    registry = object({
      server               = string
      username             = string
      password_secret_name = string
    })
    key_vault = object({
      id  = string
      uri = string
    })
    custody_vault = object({
      id  = string
      uri = string
    })
    service_bus = object({
      namespace_name   = string
      topic_id         = string
      topic_name       = string
      subscription_ids = map(string)
    })
    foundry = object({
      account_id              = string
      account_name            = string
      chat_deployment         = string
      embedding_deployment    = string
      embedding_model_version = string
    })
    postgresql = object({
      server_id = string
      fqdn      = string
      database  = string
      tenant_id = string
    })
    github = object({
      app_id                  = string
      capture_domain          = string
      private_key_secret_name = string
      private_key_version     = string
      client_secret_name      = string
      client_secret_version   = string
      authority_secret_name   = string
      # Optional GitHub App slug; the dashboard links to its installation page when set.
      app_slug = optional(string)
      # Optional pinned version of the webhook secret; when set, Ingestion accepts signed workflow_run deliveries.
      webhook_secret_name    = optional(string, "github-webhook-secret")
      webhook_secret_version = optional(string)
    })
  })
  nullable = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.configuration.location))
    error_message = "Supply an explicit lowercase Azure region code."
  }
  validation {
    condition     = can(regex("(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.configuration.platform_tenant_id))
    error_message = "The Pipesor platform tenant (ADR-022 tid) must be a UUID."
  }
  validation {
    condition = length(setsubtract(["ingestion", "pipeline", "log-event", "nlp", "correlation", "recommendation", "rag", "dashboard"], keys(var.configuration.images))) == 0 && alltrue([
      for image in values(var.configuration.images) : can(regex("^[a-z0-9.-]+/[a-z0-9._/-]+@sha256:[0-9a-f]{64}$", image))
    ])
    error_message = "Every workload and the dashboard need an image pinned by digest (registry/repository@sha256:...)."
  }
  validation {
    condition     = var.configuration.github.app_slug == null || can(regex("^[a-z0-9][a-z0-9-]*$", var.configuration.github.app_slug))
    error_message = "github.app_slug must be a GitHub App slug (lowercase letters, digits and hyphens)."
  }

  validation {
    condition     = alltrue([for version in compact([var.configuration.github.private_key_version, var.configuration.github.client_secret_version, var.configuration.github.webhook_secret_version]) : can(regex("^[0-9a-f]{32}$", version))])
    error_message = "GitHub App material must be pinned to exact Key Vault secret versions."
  }
  validation {
    condition     = length(setsubtract(["pipeline", "log-event", "nlp"], keys(var.configuration.service_bus.subscription_ids))) == 0
    error_message = "The pipeline, log-event and nlp subscriptions are required."
  }
}
