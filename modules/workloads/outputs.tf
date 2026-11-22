output "workloads" {
  description = "Service URLs and identity IDs (no secrets) for the dashboard build, GitHub App callback and operators."
  value = {
    urls         = merge(local.url, { dashboard = local.dashboard_origin })
    callback_url = "${local.url["ingestion"]}/api/v1/auth/github/callback"
    identities = { for name, identity in azapi_resource.identity : name => {
      name         = identity.name
      client_id    = identity.output.properties.clientId
      principal_id = identity.output.properties.principalId
    } }
    jobs = {
      database_setup   = azapi_resource.database_setup.name
      authority_import = azapi_resource.authority_import.name
      rag_migrations   = azapi_resource.rag_migrations.name
    }
  }
}
