locals {
  subscription   = "/subscriptions/${split("/", var.resource_group_id)[2]}"
  workloads      = ["ingestion", "pipeline", "log-event", "nlp", "correlation", "recommendation", "rag"]
  external       = ["ingestion", "pipeline", "recommendation"]
  java           = ["ingestion", "pipeline", "log-event", "correlation", "recommendation"]
  human_apis     = ["ingestion", "pipeline", "log-event", "recommendation"]
  with_database  = ["ingestion", "pipeline", "log-event", "correlation", "recommendation", "rag"]
  domain         = data.azapi_resource.environment.output.properties.defaultDomain
  service_bus    = "${var.configuration.service_bus.namespace_name}.servicebus.windows.net"
  foundry_origin = "https://${var.configuration.foundry.account_name}.services.ai.azure.com"

  # Platform identity contract v1 route catalog: target => caller => roles (same as pipesor-workspace local_stack).
  trust = {
    ingestion      = { pipeline = ["Pipeline.MachineScope.Check", "Pipeline.GitHubFacts.Read", "Pipeline.CaptureScope.Write"] }
    pipeline       = { correlation = ["Correlation.OperationalReferences.Check"], log-event = ["Evidence.Check"], recommendation = ["Recommendation.DiagnosisEntitlements.Resolve"] }
    log-event      = { correlation = ["Correlation.EvidenceMembership.Check"] }
    nlp            = {}
    correlation    = { nlp = ["Nlp.ProcessedEvidence.Send"] }
    recommendation = { correlation = ["Correlation.Contexts.Deliver"] }
    rag            = { recommendation = ["Rag.Query"] }
  }
  outbound = {
    ingestion   = [], pipeline = ["ingestion"], log-event = ["pipeline"], nlp = ["correlation"],
    correlation = ["pipeline", "log-event", "recommendation"], recommendation = ["rag", "pipeline"], rag = []
  }
  subscriptions = { pipeline = "pipeline", log-event = "log-event", nlp = "nlp" }

  url      = { for w in local.workloads : w => contains(local.external, w) ? "https://${w}.${local.domain}" : "https://${w}.internal.${local.domain}" }
  identity = { for w in concat(local.workloads, ["db-admin", "dashboard"]) : w => "id-pipesor-${var.environment}-${w}" }
  # The dashboard is a static SPA served by its own Container App (Static Web Apps is not offered in the allowed regions).
  dashboard_origin = "https://dashboard.${local.domain}"
  key_name         = { for k in concat(local.workloads, ["session"]) : k => "pipesor-${k}-signing" }
  # Versioned key identifiers: services pin the key they sign with (NLP requires it); rotation is a redeploy.
  key_uri = { for k, key in azapi_resource.signing_key : k => key.output.properties.keyUriWithVersion }
  vault   = trimsuffix(var.configuration.key_vault.uri, "/")

  roles = {
    crypto_user     = "12338af0-0e69-4776-bea7-57ae8d297424"
    secrets_user    = "4633458b-17de-408a-b874-0445c86b69e6"
    secrets_officer = "b86a8fe4-44ce-4948-aee5-eccb2c155cd7"
    bus_sender      = "69a216fc-b8fb-44d8-bc22-1f3c2cd27a39"
    bus_receiver    = "4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0"
    openai_user     = "5e0bd9bd-7b93-4f28-af87-19fc36ad61bd"
  }
  # Least-privilege scopes from the runtime manifest "Azure identities and roles" table.
  assignments = merge(
    { for w in local.workloads : "${w}-signing" => { principal = w, role = "crypto_user", scope = "${var.configuration.key_vault.id}/keys/${local.key_name[w]}" } },
    { for w in concat(local.workloads, ["dashboard"]) : "${w}-registry" => { principal = w, role = "secrets_user", scope = "${var.configuration.key_vault.id}/secrets/${var.configuration.registry.password_secret_name}" } },
    { for w, subscription in local.subscriptions : "${w}-receive" => { principal = w, role = "bus_receiver", scope = var.configuration.service_bus.subscription_ids[subscription] } },
    { for w in ["recommendation", "rag"] : "${w}-foundry" => { principal = w, role = "openai_user", scope = var.configuration.foundry.account_id } },
    { for name in [var.configuration.github.private_key_secret_name, var.configuration.github.client_secret_name, var.configuration.github.authority_secret_name] :
    "ingestion-secret-${name}" => { principal = "ingestion", role = "secrets_user", scope = "${var.configuration.key_vault.id}/secrets/${name}" } },
    {
      ingestion-session = { principal = "ingestion", role = "crypto_user", scope = "${var.configuration.key_vault.id}/keys/${local.key_name["session"]}" }
      ingestion-send    = { principal = "ingestion", role = "bus_sender", scope = var.configuration.service_bus.topic_id }
      ingestion-custody = { principal = "ingestion", role = "secrets_officer", scope = var.configuration.custody_vault.id }
    },
  )

  jdbc = { for w in local.java : w => join("", [
    "jdbc:postgresql://${var.configuration.postgresql.fqdn}:5432/${var.configuration.postgresql.database}?sslmode=require",
    "&authenticationPluginClassName=com.azure.identity.extensions.jdbc.postgresql.AzurePostgresqlAuthenticationPlugin",
    "&azure.clientId=${azapi_resource.identity[w].output.properties.clientId}",
  ]) }

  env = { for w in local.workloads : w => concat(
    [
      { name = "PIPESOR_ENVIRONMENT", value = "azure" },
      { name = "SERVER_ADDRESS", value = "0.0.0.0" },
      { name = "SERVER_PORT", value = "8080" },
      { name = "AZURE_CLIENT_ID", value = azapi_resource.identity[w].output.properties.clientId },
      { name = "PIPESOR_TENANT_ID", value = var.configuration.platform_tenant_id },
      { name = "PIPESOR_WORKLOAD_ID", value = w },
      { name = "PIPESOR_SIGNING_KEY_ID", value = local.key_uri[w] },
      { name = "PIPESOR_SECURITY_AUDIENCE", value = "urn:pipesor:api:${w}" },
    ],
    contains(local.java, w) ? [{ name = "SPRING_PROFILES_ACTIVE", value = "azure" }] : [],
    flatten([for index, caller in sort(keys(local.trust[w])) : [
      { name = "PIPESOR_SECURITY_TRUSTEDWORKLOADS_${index}_ID", value = caller },
      { name = "PIPESOR_SECURITY_TRUSTEDWORKLOADS_${index}_JWKSURI", value = "${local.url[caller]}/.well-known/jwks.json" },
      { name = "PIPESOR_SECURITY_TRUSTEDWORKLOADS_${index}_ROLES", value = join(",", local.trust[w][caller]) },
    ]]),
    [for target in local.outbound[w] : { name = "PIPESOR_ENDPOINTS_${upper(replace(target, "-", ""))}", value = local.url[target] }],
    contains(local.human_apis, w) ? [
      { name = "PIPESOR_SECURITY_SESSION_JWKSURI", value = "${local.url["ingestion"]}/.well-known/jwks.json" },
      { name = "PIPESOR_DASHBOARD_ORIGIN", value = local.dashboard_origin },
    ] : [],
    contains(local.java, w) ? [
      { name = "PIPESOR_DATABASE_URL", value = local.jdbc[w] },
      { name = "PIPESOR_DATABASE_USERNAME", value = local.identity[w] },
    ] : [],
    contains(keys(local.subscriptions), w) || w == "ingestion" ? [
      { name = "PIPESOR_SERVICE_BUS_NAMESPACE", value = local.service_bus },
      { name = "PIPESOR_SERVICE_BUS_TOPIC", value = var.configuration.service_bus.topic_name },
    ] : [],
    contains(keys(local.subscriptions), w) ? [{ name = "PIPESOR_SERVICE_BUS_SUBSCRIPTION", value = local.subscriptions[w] }] : [],
    w == "ingestion" ? [
      { name = "PIPESOR_SESSION_SIGNING_KEY_ID", value = local.key_uri["session"] },
      { name = "PIPESOR_GITHUB_APP_ID", value = var.configuration.github.app_id },
      { name = "PIPESOR_GITHUB_CAPTURE_DOMAIN", value = var.configuration.github.capture_domain },
      { name = "PIPESOR_GITHUB_CALLBACK_URL", value = "${local.url["ingestion"]}/api/v1/auth/github/callback" },
      { name = "PIPESOR_GITHUB_KEY_VAULT_URL", value = local.vault },
      { name = "PIPESOR_GITHUB_PRIVATE_KEY_SECRET_NAME", value = var.configuration.github.private_key_secret_name },
      { name = "PIPESOR_GITHUB_PRIVATE_KEY_SECRET_VERSION", value = var.configuration.github.private_key_version },
      { name = "PIPESOR_GITHUB_CLIENT_SECRET_NAME", value = var.configuration.github.client_secret_name },
      { name = "PIPESOR_GITHUB_CLIENT_SECRET_VERSION", value = var.configuration.github.client_secret_version },
      { name = "PIPESOR_GITHUB_CUSTODY_VAULT_URL", value = trimsuffix(var.configuration.custody_vault.uri, "/") },
    ] : [],
    w == "recommendation" ? [
      { name = "PIPESOR_INFERENCE_ENDPOINT", value = local.foundry_origin },
      { name = "PIPESOR_INFERENCE_DEPLOYMENT", value = var.configuration.foundry.chat_deployment },
    ] : [],
    w == "rag" ? [
      # RAG's azure profile rejects configured usernames/passwords: the Entra principal travels in the URL.
      { name = "PIPESOR_DATABASE_URL", value = "postgresql+psycopg://${local.identity["rag"]}@${var.configuration.postgresql.fqdn}:5432/${var.configuration.postgresql.database}?sslmode=require" },
      { name = "PIPESOR_RAG_AUTHENTICATION_MODE", value = "platform" },
      { name = "PIPESOR_RAG_STORAGE_BACKEND", value = "postgresql" },
      { name = "PIPESOR_RAG_EMBEDDING_BACKEND", value = "azure_openai" },
      { name = "PIPESOR_RAG_AZURE_OPENAI_ENDPOINT", value = local.foundry_origin },
      { name = "PIPESOR_RAG_AZURE_OPENAI_DEPLOYMENT", value = var.configuration.foundry.embedding_deployment },
      { name = "PIPESOR_RAG_EMBEDDING_MODEL_VERSION", value = var.configuration.foundry.embedding_model_version },
    ] : [],
  ) }

  health = { for w in local.workloads : w => contains(local.java, w) ?
    { live = "/actuator/health/liveness", ready = "/actuator/health/readiness" } :
  { live = "/health/live", ready = "/health/ready" } }

  registry = [{ server = var.configuration.registry.server, username = var.configuration.registry.username, passwordSecretRef = "registry-token" }]
}

data "azapi_resource" "environment" {
  type                   = "Microsoft.App/managedEnvironments@2025-07-01"
  resource_id            = var.configuration.container_environment_id
  response_export_values = ["properties.defaultDomain"]
}

resource "azapi_resource" "identity" {
  for_each               = local.identity
  type                   = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  name                   = each.value
  parent_id              = var.resource_group_id
  location               = var.configuration.location
  tags                   = { environment = var.environment, workload = each.key }
  response_export_values = ["properties.principalId", "properties.clientId"]
}

# Non-exportable RSA keys (ADR-022): services sign with them through Key Vault and publish the public part as JWKS.
resource "azapi_resource" "signing_key" {
  for_each  = local.key_name
  type      = "Microsoft.KeyVault/vaults/keys@2024-11-01"
  name      = each.value
  parent_id = var.configuration.key_vault.id
  body = { properties = {
    kty     = "RSA"
    keySize = 2048
    keyOps  = ["sign", "verify"]
  } }
  response_export_values = ["properties.keyUriWithVersion"]
  lifecycle { ignore_changes = [body] }
}

resource "azapi_resource" "role" {
  for_each  = local.assignments
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${lower(each.value.scope)}/${local.identity[each.value.principal]}/${local.roles[each.value.role]}")
  parent_id = each.value.scope
  body = { properties = {
    principalId      = azapi_resource.identity[each.value.principal].output.properties.principalId
    principalType    = "ServicePrincipal"
    roleDefinitionId = "${local.subscription}/providers/Microsoft.Authorization/roleDefinitions/${local.roles[each.value.role]}"
  } }
  depends_on = [azapi_resource.signing_key]
}

# The db-admin identity is an additional Entra administrator that only the database setup job uses.
resource "azapi_resource" "database_administrator" {
  type      = "Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-08-01"
  name      = azapi_resource.identity["db-admin"].output.properties.principalId
  parent_id = var.configuration.postgresql.server_id
  body = { properties = {
    principalName = local.identity["db-admin"]
    principalType = "ServicePrincipal"
    tenantId      = var.configuration.postgresql.tenant_id
  } }
}

resource "azapi_resource" "app" {
  for_each  = toset(local.workloads)
  type      = "Microsoft.App/containerApps@2025-07-01"
  name      = each.key
  parent_id = var.resource_group_id
  location  = var.configuration.location
  tags      = { environment = var.environment, workload = each.key }
  identity {
    type         = "UserAssigned"
    identity_ids = [azapi_resource.identity[each.key].id]
  }
  body = { properties = {
    environmentId       = var.configuration.container_environment_id
    workloadProfileName = "Consumption"
    configuration = {
      activeRevisionsMode = "Single"
      ingress = {
        external      = contains(local.external, each.key)
        targetPort    = 8080
        transport     = "Auto" # ARM's stored casing (avoids a perpetual diff)
        allowInsecure = false
        traffic       = [{ latestRevision = true, weight = 100 }]
      }
      registries = local.registry
      secrets = [{
        name        = "registry-token"
        keyVaultUrl = "${local.vault}/secrets/${var.configuration.registry.password_secret_name}"
        identity    = azapi_resource.identity[each.key].id
      }]
    }
    template = {
      containers = [{
        name      = each.key
        image     = var.configuration.images[each.key]
        resources = contains(local.java, each.key) ? { cpu = 0.5, memory = "1Gi" } : { cpu = 0.25, memory = "0.5Gi" }
        env       = local.env[each.key]
        # Listed in ARM's stored order (Liveness, Readiness, Startup) to avoid a perpetual diff.
        probes = [
          { type = "Liveness", httpGet = { path = local.health[each.key].live, port = 8080 }, periodSeconds = 15, failureThreshold = 3 },
          { type = "Readiness", httpGet = { path = local.health[each.key].ready, port = 8080 }, periodSeconds = 10, failureThreshold = 3 },
          { type = "Startup", httpGet = { path = local.health[each.key].live, port = 8080 }, periodSeconds = 5, failureThreshold = 36 },
        ]
      }]
      # One replica each for the MVP: consumers and workers stay up; leases already guard concurrency.
      scale = { minReplicas = 1, maxReplicas = 1 }
    }
  } }
  response_export_values = ["properties.configuration.ingress.fqdn"]
  depends_on             = [azapi_resource.role]
}

# Static dashboard (nginx, unprivileged, port 8080); its API URLs are baked into the image at build time.
resource "azapi_resource" "dashboard" {
  type      = "Microsoft.App/containerApps@2025-07-01"
  name      = "dashboard"
  parent_id = var.resource_group_id
  location  = var.configuration.location
  tags      = { environment = var.environment, workload = "dashboard" }
  identity {
    type         = "UserAssigned"
    identity_ids = [azapi_resource.identity["dashboard"].id]
  }
  body = { properties = {
    environmentId       = var.configuration.container_environment_id
    workloadProfileName = "Consumption"
    configuration = {
      activeRevisionsMode = "Single"
      ingress = {
        external      = true
        targetPort    = 8080
        transport     = "Auto" # ARM's stored casing (avoids a perpetual diff)
        allowInsecure = false
        traffic       = [{ latestRevision = true, weight = 100 }]
      }
      registries = local.registry
      secrets = [{
        name        = "registry-token"
        keyVaultUrl = "${local.vault}/secrets/${var.configuration.registry.password_secret_name}"
        identity    = azapi_resource.identity["dashboard"].id
      }]
    }
    template = {
      containers = [{
        name      = "dashboard"
        image     = var.configuration.images["dashboard"]
        resources = { cpu = 0.25, memory = "0.5Gi" }
        probes = [
          { type = "Liveness", httpGet = { path = "/", port = 8080 }, periodSeconds = 30, failureThreshold = 3 },
          { type = "Readiness", httpGet = { path = "/", port = 8080 }, periodSeconds = 10, failureThreshold = 3 },
        ]
      }]
      scale = { minReplicas = 1, maxReplicas = 1 }
    }
  } }
  depends_on = [azapi_resource.role]
}

locals {
  job_base = {
    environmentId       = var.configuration.container_environment_id
    workloadProfileName = "Consumption"
  }
  job_configuration = {
    triggerType         = "Manual"
    replicaTimeout      = 900
    replicaRetryLimit   = 0
    manualTriggerConfig = { parallelism = 1, replicaCompletionCount = 1 }
  }
  database_setup_sql = join("\n", concat(
    # Plain idempotent SELECTs: no dollar-quoted blocks, whose "$$" does not survive the job's shell arguments.
    [for w in local.with_database : join("", [
      "SELECT pgaadauth_create_principal_with_oid('${local.identity[w]}', '${azapi_resource.identity[w].output.properties.principalId}', 'service', false, false)",
      " WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${local.identity[w]}');",
    ])],
    [
      "SELECT 'CREATE DATABASE ${var.configuration.postgresql.database}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${var.configuration.postgresql.database}')\\gexec",
      "\\connect ${var.configuration.postgresql.database}",
      "CREATE EXTENSION IF NOT EXISTS vector;",
      # Each service creates and owns its schema through its migrations; log-event and correlation share evidence.
      "GRANT CONNECT, CREATE ON DATABASE ${var.configuration.postgresql.database} TO ${join(", ", [for w in local.with_database : "\"${local.identity[w]}\""])};",
      "CREATE SCHEMA IF NOT EXISTS evidence;",
      "GRANT USAGE, CREATE ON SCHEMA evidence TO \"${local.identity["log-event"]}\", \"${local.identity["correlation"]}\";",
      # Alembic keeps RAG's version table in public, where PostgreSQL 15+ grants no CREATE by default.
      "GRANT USAGE, CREATE ON SCHEMA public TO \"${local.identity["rag"]}\";",
    ],
  ))
  token = "$IDENTITY_ENDPOINT?api-version=2019-08-01&resource=https://ossrdbms-aad.database.windows.net&client_id=$AZURE_CLIENT_ID"
}

# Manual job: Entra principals per workload, the database, the vector extension and schema grants (idempotent).
resource "azapi_resource" "database_setup" {
  type      = "Microsoft.App/jobs@2025-07-01"
  name      = "job-database-setup"
  parent_id = var.resource_group_id
  location  = var.configuration.location
  identity {
    type         = "UserAssigned"
    identity_ids = [azapi_resource.identity["db-admin"].id]
  }
  body = { properties = merge(local.job_base, {
    configuration = local.job_configuration
    template = { containers = [{
      name      = "database-setup"
      image     = "docker.io/library/postgres:17-alpine"
      resources = { cpu = 0.25, memory = "0.5Gi" }
      command   = ["/bin/sh", "-ec"]
      # Built line by line: the SQL heredoc delimiter must start its own line for /bin/sh.
      args = [join("\n", [
        "apk add --no-cache curl jq >/dev/null",
        "export PGPASSWORD=\"$(curl -sf -H \"X-IDENTITY-HEADER: $IDENTITY_HEADER\" \"${local.token}\" | jq -r .access_token)\"",
        "psql \"host=$PGHOST port=5432 dbname=postgres user=$PGUSER sslmode=require\" -v ON_ERROR_STOP=1 <<'SQL'",
        local.database_setup_sql,
        "SQL",
      ])]
      env = [
        { name = "AZURE_CLIENT_ID", value = azapi_resource.identity["db-admin"].output.properties.clientId },
        { name = "PGHOST", value = var.configuration.postgresql.fqdn },
        { name = "PGUSER", value = local.identity["db-admin"] },
      ]
    }] }
  }) }
  depends_on = [azapi_resource.database_administrator]
}

# Manual job: ADR-023 operator import of repository and human admissions from a Key Vault document.
resource "azapi_resource" "authority_import" {
  type      = "Microsoft.App/jobs@2025-07-01"
  name      = "job-ingestion-authority-import"
  parent_id = var.resource_group_id
  location  = var.configuration.location
  identity {
    type         = "UserAssigned"
    identity_ids = [azapi_resource.identity["ingestion"].id]
  }
  body = { properties = merge(local.job_base, {
    configuration = merge(local.job_configuration, {
      registries = local.registry
      secrets = [
        { name = "registry-token", keyVaultUrl = "${local.vault}/secrets/${var.configuration.registry.password_secret_name}", identity = azapi_resource.identity["ingestion"].id },
        { name = "authority", keyVaultUrl = "${local.vault}/secrets/${var.configuration.github.authority_secret_name}", identity = azapi_resource.identity["ingestion"].id },
      ]
    })
    template = {
      containers = [{
        name         = "authority-import"
        image        = var.configuration.images["ingestion"]
        resources    = { cpu = 0.5, memory = "1Gi" }
        args         = ["--spring.main.web-application-type=none", "--pipesor.admin.import-authority=/mnt/authority/authority"]
        env          = local.env["ingestion"]
        volumeMounts = [{ volumeName = "authority", mountPath = "/mnt/authority" }]
      }]
      volumes = [{ name = "authority", storageType = "Secret", secrets = [{ secretRef = "authority", path = "authority" }] }]
    }
  }) }
  depends_on = [azapi_resource.role]
}

# Manual job: RAG Alembic migrations with the RAG identity's Entra token as the database password.
resource "azapi_resource" "rag_migrations" {
  type      = "Microsoft.App/jobs@2025-07-01"
  name      = "job-rag-migrations"
  parent_id = var.resource_group_id
  location  = var.configuration.location
  identity {
    type         = "UserAssigned"
    identity_ids = [azapi_resource.identity["rag"].id]
  }
  body = { properties = merge(local.job_base, {
    configuration = merge(local.job_configuration, {
      registries = local.registry
      secrets    = [{ name = "registry-token", keyVaultUrl = "${local.vault}/secrets/${var.configuration.registry.password_secret_name}", identity = azapi_resource.identity["rag"].id }]
    })
    template = { containers = [{
      name      = "rag-migrations"
      image     = var.configuration.images["rag"]
      resources = { cpu = 0.25, memory = "0.5Gi" }
      command   = ["/bin/sh", "-ec"]
      args = [<<-SCRIPT
        export PIPESOR_DATABASE_PASSWORD="$(python -c "import os; from azure.identity import ManagedIdentityCredential as C; print(C(client_id=os.environ['AZURE_CLIENT_ID']).get_token('https://ossrdbms-aad.database.windows.net/.default').token)")"
        alembic upgrade head
      SCRIPT
      ]
      env = local.env["rag"]
    }] }
  }) }
  depends_on = [azapi_resource.role]
}
