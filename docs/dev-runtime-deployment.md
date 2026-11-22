# DEV runtime deployment

Status: MVP runbook for the seven services on the existing DEV foundations (Students subscription
`04f339b7…`, West US 3). Inputs follow the pipesor-docs
[runtime manifest](https://github.com/pipesor-org/pipesor-docs/blob/main/docs/development/runtime-manifest.md)
and [ADR-022](https://github.com/pipesor-org/pipesor-docs/blob/main/docs/architecture/decisions/ADR-022-platform-identity-without-entra-app-registrations.md).
Every `terraform apply`, import and Azure write below needs Jhon's explicit authorization (AGENTS.md).

## What the code adds

| Module | Adds |
|---|---|
| `service-bus` (`topology`) | Topic `workflow-evidence`, subscriptions `pipeline`, `log-event`, `nlp`; each `$Default` rule is replaced by its SQL filter |
| `foundry` (`deployments`) | `pipesor-dev-diagnostics` (gpt-4o 2024-11-20) and `pipesor-dev-embeddings` (text-embedding-3-small 1), pinned (`NoAutoUpgrade`), capacity 20 |
| `key-vault` (existing) | App material vault and OAuth custody vault |
| `static-web-app` (existing) | Dashboard hosting (West US 2: Static Web Apps is not offered in West US 3) |
| `workloads` (new) | Eight user-assigned identities (seven workloads + `db-admin`), eight non-exportable RSA signing keys, least-privilege role assignments, `db-admin` as an extra PostgreSQL Entra administrator, seven Container Apps and three manual jobs |

Container Apps are named after their workload, so URLs are
`https://<workload>.<domain>` (ingestion, pipeline, recommendation) and
`https://<workload>.internal.<domain>` (log-event, nlp, correlation, rag); the DEV domain is
`bravepond-f9f279f5.westus3.azurecontainerapps.io`. The GitHub App callback is therefore
`https://ingestion.bravepond-f9f279f5.westus3.azurecontainerapps.io/api/v1/auth/github/callback`.

## Phase 0 — prerequisites (operator)

1. Every service image published to GHCR and pinned by digest (`ghcr.io/pipesor-org/<repo>@sha256:…`).
2. A fine-grained GitHub token with only `read:packages` on the organization, for image pulls.
3. The GitHub App callback above added to the App (keep the local one).
4. `az login` into the Students tenant; PostgreSQL started (`az postgres flexible-server start …`):
   administrator changes fail on a stopped server.

## Phase 1 — vaults, topology, models and hosting

In the private working directory, set `service_bus.topology`, `foundry.deployments`, `key_vault`
(with your current public IPv4 in `allowed_public_ipv4s` and `custody`) and `static_web_app`
as in `environments/dev/terraform.tfvars.example`; keep `workloads = null`.

The two model deployments already exist outside Terraform; import them in the same reviewed plan
by adding, only for this run, an `imports.tf` (not committed) in `environments/dev`:

```hcl
import {
  to = module.foundry[0].azapi_resource.deployment["pipesor-dev-diagnostics"]
  id = "/subscriptions/04f339b7-f969-4e17-801c-da6e81e78ffd/resourceGroups/rg-pipesor-dev/providers/Microsoft.CognitiveServices/accounts/ai-pipesor-dev-04f339b7/deployments/pipesor-dev-diagnostics"
}
import {
  to = module.foundry[0].azapi_resource.deployment["pipesor-dev-embeddings"]
  id = "/subscriptions/04f339b7-f969-4e17-801c-da6e81e78ffd/resourceGroups/rg-pipesor-dev/providers/Microsoft.CognitiveServices/accounts/ai-pipesor-dev-04f339b7/deployments/pipesor-dev-embeddings"
}
```

Plan, review (expect: 2 imports updated to capacity 20 and `NoAutoUpgrade`, topic, 3 subscriptions,
3 rules, 2 vaults, the subnet's Key Vault service endpoint, the Static Web App) and apply.

## Phase 2 — secrets (operator, never in Terraform)

Store in the app material vault and record the returned versions in `workloads.github`:

| Secret | Content |
|---|---|
| `github-app-private-key` | GitHub App private key (PEM) |
| `github-app-client-secret` | GitHub App client secret |
| `ghcr-read-token` | the `read:packages` token |
| `pipesor-authority` | ADR-023 authority document (repository and human admissions), same format as the local `authority.json` |

Use `az keyvault secret set --vault-name kv-pipesor-dev-04f339b7 --name <name> --file <path>`
from the allowed IPv4 and delete local copies you created for the upload.

## Phase 3 — workloads

Fill `workloads` (images by digest, registry user, platform tenant UUID, GitHub App id, capture
domain, secret versions), plan, review and apply. Then run the jobs once, in order, and wait for
each to succeed (`az containerapp job start -g rg-pipesor-dev -n <job>`;
`az containerapp job execution list …`):

1. `job-database-setup` — Entra principals per workload, database `pipesor`, `vector`, grants.
2. `job-rag-migrations` — RAG Alembic migrations.
3. `job-ingestion-authority-import` — repository and human admissions.

Services that started before step 1 restart on their failing probes and become ready afterwards.

## Phase 4 — dashboard

Build `pipesor-frontend` with the three external URLs from the `workloads` output and deploy the
`dist/` folder to the Static Web App with its deployment token (`swa deploy`). The Static Web App
origin is the CORS origin every human API already trusts.

## Cost control

PostgreSQL `Standard_D2s_v3` is the main cost (~USD 4.3/day): stop it whenever DEV is idle
(`az postgres flexible-server stop`; Azure restarts it after seven days). Container Apps run one
replica each (0.25–0.5 vCPU). Delete or scale apps to zero after the evaluation.

## Known limits (MVP)

- RAG runs migrations and queries with one identity; the ADR-021 runtime/import/migration split is
  not modelled yet, and the obsolete `rag_runtime_contract` handoff (Entra app roles) remains to be retired.
- Container Apps read the registry token through a Key Vault reference; if the vault firewall blocks
  the platform's fetch, allow trusted Azure services on the app material vault.
