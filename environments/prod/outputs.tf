output "resource_group" {
  description = "Resource-group contract for this environment only."
  value       = module.resource_group.resource_group
}

output "container_platform" {
  description = "Platform contract, or null when this environment has not opted in."
  value       = one(module.container_platform[*].platform)
}

output "service_bus" {
  description = "Nonsecret namespace identity, or null when this environment has not opted in."
  value       = one(module.service_bus[*].namespace)
}

output "postgresql" {
  description = "Private database identity, or null when not provisioned."
  value       = one(module.postgresql[*].database)
}

output "application_insights" {
  description = "Backend telemetry routing, or null when disabled; publishing data still requires approved Entra access."
  value       = one(module.application_insights[*].telemetry)
}

output "foundry" {
  description = "Nonsecret Foundry interface, or null when disabled; inference requires later model and access contracts."
  value       = one(module.foundry[*].foundry)
}

output "rag_runtime_contract" {
  description = "Approved nonsecret RAG handoff, or null when disabled; actual grants, model deployment and database roles remain separate authorized actions."
  value = var.rag_runtime_contract == null ? null : {
    embedding = {
      model           = "text-embedding-3-small"
      dimensions      = 1536
      api             = "v1"
      deployment_name = var.rag_runtime_contract.embedding_deployment_name
      model_version   = var.rag_runtime_contract.embedding_model_version
      endpoint        = module.foundry[0].foundry.endpoint
      timeout_seconds = 15
      max_retries     = 2
    }
    identity = {
      rag_type                    = "SystemAssigned"
      rag_principal_id            = var.rag_runtime_contract.rag_runtime_principal_id
      recommendation_type         = "SystemAssigned"
      recommendation_principal_id = var.rag_runtime_contract.recommendation_principal_id
      azure_openai_role_name      = "Cognitive Services OpenAI User"
      azure_openai_role_id        = "5e0bd9bd-7b93-4f28-af87-19fc36ad61bd"
    }
    authorization = {
      tenant_id                = var.rag_runtime_contract.tenant_id
      audience_client_id       = var.rag_runtime_contract.rag_audience_client_id
      recommendation_client_id = var.rag_runtime_contract.recommendation_client_id
      app_role_name            = "Rag.Query"
      app_role_id              = var.rag_runtime_contract.rag_query_app_role_id
    }
    postgresql = {
      host                   = module.postgresql[0].database.fqdn
      runtime_principal_id   = var.rag_runtime_contract.rag_runtime_principal_id
      import_principal_id    = var.rag_runtime_contract.rag_import_principal_id
      migration_principal_id = var.rag_runtime_contract.rag_migration_principal_id
      runtime_access         = "knowledge_read"
      import_access          = "knowledge_read_write"
      migration_access       = "knowledge_ddl"
    }
  }
}

output "static_web_app" {
  description = "Optional static hosting identity and default hostname; no credentials."
  value       = try(module.static_web_app[0].site, null)
}

output "key_vault" {
  description = "Environment-owned vault identities/endpoints, or null when disabled; no secret references or payloads."
  value       = one(module.key_vault[*].vaults)
}
