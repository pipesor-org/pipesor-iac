mock_provider "azapi" {}

variables {
  environment       = "dev"
  resource_group_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev"
  configuration = {
    location                 = "workloadregion"
    platform_tenant_id       = "24c96be0-50f3-4064-b5e4-643088141ae8"
    container_environment_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.App/managedEnvironments/caepipesordev"
    images = {
      ingestion      = "ghcr.io/pipesor-org/ingestion@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      pipeline       = "ghcr.io/pipesor-org/pipeline@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      log-event      = "ghcr.io/pipesor-org/log-event@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      nlp            = "ghcr.io/pipesor-org/nlp@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      correlation    = "ghcr.io/pipesor-org/correlation@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      recommendation = "ghcr.io/pipesor-org/recommendation@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      rag            = "ghcr.io/pipesor-org/rag@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      dashboard      = "ghcr.io/pipesor-org/dashboard@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
    registry      = { server = "ghcr.io", username = "fixture-user", password_secret_name = "ghcr-read-token" }
    key_vault     = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/kv-app", uri = "https://kv-app.vault.azure.net/" }
    custody_vault = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/kv-usr", uri = "https://kv-usr.vault.azure.net/" }
    service_bus = {
      namespace_name = "sb-fixture"
      topic_id       = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ServiceBus/namespaces/sb-fixture/topics/workflow-evidence"
      topic_name     = "workflow-evidence"
      subscription_ids = {
        pipeline  = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ServiceBus/namespaces/sb-fixture/topics/workflow-evidence/subscriptions/pipeline"
        log-event = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ServiceBus/namespaces/sb-fixture/topics/workflow-evidence/subscriptions/log-event"
        nlp       = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ServiceBus/namespaces/sb-fixture/topics/workflow-evidence/subscriptions/nlp"
      }
    }
    foundry = {
      account_id              = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.CognitiveServices/accounts/ai-fixture"
      account_name            = "ai-fixture"
      chat_deployment         = "pipesor-dev-diagnostics"
      embedding_deployment    = "pipesor-dev-embeddings"
      embedding_model_version = "1"
    }
    postgresql = {
      server_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.DBforPostgreSQL/flexibleServers/pg-fixture"
      fqdn      = "pg-fixture.postgres.database.azure.com"
      database  = "pipesor"
      tenant_id = "11111111-1111-1111-1111-111111111111"
    }
    github = {
      app_id                  = "123456"
      capture_domain          = "pipesor-dev"
      private_key_secret_name = "github-app-private-key"
      private_key_version     = "0123456789abcdef0123456789abcdef"
      client_secret_name      = "github-app-client-secret"
      client_secret_version   = "fedcba9876543210fedcba9876543210"
      authority_secret_name   = "pipesor-authority"
    }
  }
}

run "runtime_manifest_contract" {
  command = plan
  override_resource {
    target          = azapi_resource.identity
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ManagedIdentity/userAssignedIdentities/fixture", output = { properties = { principalId = "55555555-5555-5555-5555-555555555555", clientId = "66666666-6666-6666-6666-666666666666" } } }
  }
  override_resource {
    target          = azapi_resource.signing_key
    override_during = plan
    values          = { output = { properties = { keyUriWithVersion = "https://kv-app.vault.azure.net/keys/fixture/0123456789abcdef0123456789abcdef" } } }
  }
  override_data {
    target = data.azapi_resource.environment
    values = { output = { properties = { defaultDomain = "fixture.workloadregion.azurecontainerapps.io" } } }
  }

  assert {
    condition     = length(azapi_resource.app) == 7 && length(azapi_resource.signing_key) == 8 && length(azapi_resource.identity) == 9
    error_message = "Seven apps, eight signing keys (workloads plus sessions) and nine identities (workloads, db-admin and dashboard) are expected."
  }
  assert {
    condition     = alltrue([for name, app in azapi_resource.app : app.body.properties.configuration.ingress.external == contains(["ingestion", "pipeline", "recommendation"], name)])
    error_message = "Only ingestion, pipeline and recommendation have external ingress."
  }
  assert {
    condition     = contains(azapi_resource.app["pipeline"].body.properties.template.containers[0].env, { name = "PIPESOR_SECURITY_TRUSTEDWORKLOADS_2_ROLES", value = "Recommendation.DiagnosisEntitlements.Resolve" })
    error_message = "Pipeline must trust recommendation with the entitlement role (route catalog)."
  }
  assert {
    condition     = contains(azapi_resource.app["nlp"].body.properties.template.containers[0].env, { name = "PIPESOR_SIGNING_KEY_ID", value = "https://kv-app.vault.azure.net/keys/fixture/0123456789abcdef0123456789abcdef" })
    error_message = "Services receive a versioned signing key identifier."
  }
  assert {
    condition     = contains(azapi_resource.app["rag"].body.properties.template.containers[0].env, { name = "PIPESOR_DATABASE_URL", value = "postgresql+psycopg://id-pipesor-dev-rag@pg-fixture.postgres.database.azure.com:5432/pipesor" }) && !contains([for variable in azapi_resource.app["rag"].body.properties.template.containers[0].env : variable.name], "PIPESOR_DATABASE_USERNAME")
    error_message = "RAG takes its Entra principal from the URL and receives no separate username."
  }
  assert {
    condition     = contains(azapi_resource.app["correlation"].body.properties.template.containers[0].env, { name = "PIPESOR_ENDPOINTS_LOGEVENT", value = "https://log-event.internal.fixture.workloadregion.azurecontainerapps.io" })
    error_message = "Outbound endpoints use the target's internal HTTPS FQDN."
  }
  assert {
    condition = !anytrue([for app in azapi_resource.app : anytrue([for variable in app.body.properties.template.containers[0].env :
    contains(["PIPESOR_DATABASE_PASSWORD", "PIPESOR_SIGNING_KEY_FILE", "PIPESOR_SERVICE_BUS_CONNECTION_STRING"], variable.name)])])
    error_message = "Local-only settings must never reach the azure profile."
  }
  assert {
    condition     = contains(azapi_resource.app["nlp"].body.properties.template.containers[0].env, { name = "PIPESOR_SERVICE_BUS_SUBSCRIPTION", value = "nlp" }) && !contains([for variable in azapi_resource.app["nlp"].body.properties.template.containers[0].env : variable.name], "PIPESOR_DATABASE_URL")
    error_message = "NLP consumes its own subscription and has no database."
  }
  assert {
    condition     = azapi_resource.role["ingestion-send"].parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ServiceBus/namespaces/sb-fixture/topics/workflow-evidence" && azapi_resource.role["nlp-receive"].parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ServiceBus/namespaces/sb-fixture/topics/workflow-evidence/subscriptions/nlp"
    error_message = "Service Bus roles are scoped to the topic (sender) and to each consumer's own subscription (receiver)."
  }
  assert {
    condition     = azapi_resource.role["pipeline-signing"].parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/kv-app/keys/pipesor-pipeline-signing" && !contains(keys(azapi_resource.role), "pipeline-foundry")
    error_message = "Each workload may use only its own signing key; only recommendation and rag reach Foundry."
  }
  assert {
    condition     = strcontains(azapi_resource.database_setup.body.properties.template.containers[0].args[0], "pgaadauth_create_principal_with_oid('id-pipesor-dev-rag'") && strcontains(azapi_resource.database_setup.body.properties.template.containers[0].args[0], "\nSQL") && !strcontains(azapi_resource.database_setup.body.properties.template.containers[0].args[0], "$$")
    error_message = "The database setup job creates one Entra principal per database workload and closes its SQL heredoc on its own line."
  }
  assert {
    condition     = !anytrue([for variable in azapi_resource.app["ingestion"].body.properties.template.containers[0].env : startswith(variable.name, "PIPESOR_GITHUB_WEBHOOK")]) && !contains(keys(azapi_resource.role), "ingestion-secret-github-webhook-secret")
    error_message = "Without a pinned webhook secret version Ingestion keeps the webhook disabled and cannot read the secret."
  }
}

run "webhook_enabled_with_pinned_secret" {
  command = plan
  variables {
    configuration = merge(var.configuration, { github = merge(var.configuration.github, { webhook_secret_version = "00112233445566778899aabbccddeeff" }) })
  }
  override_resource {
    target          = azapi_resource.identity
    override_during = plan
    values          = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.ManagedIdentity/userAssignedIdentities/fixture", output = { properties = { principalId = "55555555-5555-5555-5555-555555555555", clientId = "66666666-6666-6666-6666-666666666666" } } }
  }
  override_resource {
    target          = azapi_resource.signing_key
    override_during = plan
    values          = { output = { properties = { keyUriWithVersion = "https://kv-app.vault.azure.net/keys/fixture/0123456789abcdef0123456789abcdef" } } }
  }
  override_data {
    target = data.azapi_resource.environment
    values = { output = { properties = { defaultDomain = "fixture.workloadregion.azurecontainerapps.io" } } }
  }

  assert {
    condition = alltrue([for variable in [
      { name = "PIPESOR_GITHUB_WEBHOOK_ENABLED", value = "true" },
      { name = "PIPESOR_GITHUB_WEBHOOK_SECRET_NAME", value = "github-webhook-secret" },
      { name = "PIPESOR_GITHUB_WEBHOOK_SECRET_VERSION", value = "00112233445566778899aabbccddeeff" },
    ] : contains(azapi_resource.app["ingestion"].body.properties.template.containers[0].env, variable)])
    error_message = "A pinned webhook secret version enables the webhook with that exact secret."
  }
  assert {
    condition     = azapi_resource.role["ingestion-secret-github-webhook-secret"].parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-pipesor-dev/providers/Microsoft.KeyVault/vaults/kv-app/secrets/github-webhook-secret" && !anytrue([for name, app in azapi_resource.app : name != "ingestion" && anytrue([for variable in app.body.properties.template.containers[0].env : startswith(variable.name, "PIPESOR_GITHUB_WEBHOOK")])])
    error_message = "Only Ingestion receives the webhook settings and may read only the webhook secret."
  }
}

run "webhook_secret_version_must_be_pinned" {
  command = plan
  variables {
    configuration = merge(var.configuration, { github = merge(var.configuration.github, { webhook_secret_version = "latest" }) })
  }
  expect_failures = [var.configuration]
}
