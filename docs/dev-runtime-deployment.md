# DEV runtime deployment

Status: MVP runbook for the seven services on the existing DEV foundations (Students subscription
`04f339b7…`, West US 3). Inputs follow the pipesor-docs
[runtime manifest](https://github.com/pipesor-org/pipesor-docs/blob/main/docs/development/runtime-manifest.md)
and [ADR-022](https://github.com/pipesor-org/pipesor-docs/blob/main/docs/architecture/decisions/ADR-022-platform-identity-without-entra-app-registrations.md).
Every `terraform apply`, import and Azure write below needs Jhon's explicit authorization (AGENTS.md).

## What the code adds

| Module | Adds |
|---|---|
| `service-bus` (`topology`) | Topic `workflow-evidence`, subscriptions `pipeline`, `log-event`, `nlp`, each with one SQL rule `event-type` (ARM-created subscriptions have no default rule) |
| `foundry` (`deployments`) | `pipesor-dev-diagnostics-luna` (gpt-6-luna 2026-09-22, the diagnosis model selected by ADR-026 and set as `workloads.chat_deployment`), `pipesor-dev-diagnostics` (gpt-4o 2024-11-20, PD-026 smoke-test baseline) and `pipesor-dev-embeddings` (text-embedding-3-small 1), pinned (`NoAutoUpgrade`), capacity 20. The account also holds the `-terra` and `-sol` variants compared in ADR-026 |
| `key-vault` (existing) | App material vault and OAuth custody vault |
| `workloads` (new) | Nine user-assigned identities (seven workloads, `db-admin`, `dashboard`), eight non-exportable RSA signing keys, least-privilege role assignments, `db-admin` as an extra PostgreSQL Entra administrator, seven service Container Apps, the dashboard Container App (nginx static SPA; Static Web Apps is not offered in the subscription's allowed regions brazilsouth, northcentralus, westus3, southcentralus, mexicocentral) and three manual jobs |

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
as in `environments/dev/terraform.tfvars.example` (`static_web_app = null`); keep `workloads = null`.

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
3 rules, 2 vaults and the subnet's Key Vault service endpoint) and apply.

## Phase 2 — secrets (operator, never in Terraform)

Store in the app material vault and record the returned versions in `workloads.github`:

| Secret | Content |
|---|---|
| `github-app-private-key` | GitHub App private key (PEM) |
| `github-app-client-secret` | GitHub App client secret |
| `ghcr-read-token` | the `read:packages` token |
| `pipesor-authority` | ADR-023 authority document (repository and human admissions), same format as the local `authority.json` |
| `github-webhook-secret` | Optional: random webhook secret shared with the GitHub App (see [GitHub webhook](#github-webhook)) |

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

### Capture domain

`workloads.github.capture_domain` (`PIPESOR_GITHUB_CAPTURE_DOMAIN`) is an internal partition key of
Ingestion's capture ledger, never shown to users. It is part of the immutable identity of capture
receipts, observations and delivery aliases (V2 triggers) and of repository admissions and capture
scopes (V4), and every machine scope in the `pipesor-authority` document repeats it.

Choose it once per environment and do not change it afterwards. A new value does not rename data:
it starts an empty partition, so Ingestion loses its analysis history, the authority document has to
be rewritten and re-imported, and registered pipelines must re-sync their capture scopes. Repository
admissions recover on the next read (ADR-024); Pipeline incidents and Recommendation diagnoses are
not affected.

Dev keeps `pipesor-local-pilot`, inherited from the local pilot, for that reason. A new environment
(for example production) should use its own name, such as `pipesor-prod`.

### GitHub webhook

Without the webhook, a capture starts only when someone requests the analysis of a run from the dashboard
(`POST …/runs/{run}/attempts/{attempt}/analysis`). With it, GitHub delivers signed `workflow_run`
events to `https://ingestion.<domain>/webhooks/v1/github/workflow-runs`. Ingestion verifies the HMAC
signature, selects only `completed` runs, and accepts a run only when its workflow is a registered
capture scope; other workflows are answered `403` and nothing is captured.

The webhook is configured on the GitHub App, so it fires for every installation. Enable it in this order:

1. **Secret (operator).** Generate it on the allowed IPv4 without printing it, store it, and record the
   returned version (last segment of the `id`). Ingestion uses the stored value byte for byte and GitHub
   signs with what is pasted into the App, so the file must not end with a newline (`openssl` adds one):

   ```bash
   umask 077; openssl rand -hex 32 | tr -d '\n' > ~/.local/state/pipesor-dev-bootstrap/webhook-secret
   az keyvault secret set --vault-name kv-pipesor-dev-04f339b7 --name github-webhook-secret \
     --file ~/.local/state/pipesor-dev-bootstrap/webhook-secret --query id -o tsv
   ```

2. **Ingestion.** Set `workloads.github.webhook_secret_version`, plan, review (Ingestion and the authority
   import job gain `PIPESOR_GITHUB_WEBHOOK_*`; one `secrets_user` assignment scoped to that secret) and
   apply. Check that an unsigned `POST` to the webhook path is rejected (`401`/`400`, not `404`).
3. **GitHub App (owner).** In the App settings set the webhook URL above, the same secret, mark it
   active and subscribe to the **Workflow run** event. The first delivery under *Advanced → Recent
   Deliveries* must succeed. Then delete the local secret file (`shred -u`).

To disable it, deactivate the webhook on the App first, then remove `webhook_secret_version` with a new
reviewed plan. Manual analysis from the dashboard keeps working throughout.

## Phase 4 — dashboard

The frontend CI publishes an environment-independent nginx image of the SPA to GHCR; pin its digest as
`workloads.images.dashboard`. The module sets `PIPESOR_INGESTION_URL`, `PIPESOR_PIPELINE_URL` and
`PIPESOR_RECOMMENDATION_URL` (`https://ingestion|pipeline|recommendation.<domain>`) on the container, and
`PIPESOR_GITHUB_APP_INSTALL_URL` when `workloads.github.app_slug` is set; the image renders `/config.js`
and its CSP from them at startup and refuses to start without them. Apply this configuration before
pinning a dashboard digest built after the runtime-configuration change (older digests ignore it). Its
origin `https://dashboard.<domain>` is the CORS origin every human API trusts and the redirect target
after GitHub login.

## Updating, promoting and rolling back images

Application repositories never deploy: this root owns every Container App image. Each successful
`main` CI run of a service records `candidate-<run>-<attempt>/candidate.json` (source SHA, image,
digest, CI run/attempt). To deploy it, set that `image@digest` in `workloads.images`, generate a fresh
plan, review that only the expected Container App changes and apply it with the usual authorization.
Promotion to a later environment reuses the same digest in that environment's root; rollback is a new
reviewed plan with the earlier digest. Record the candidate manifest with the deployment record.

## Cost control

PostgreSQL `Standard_D2s_v3` is the main cost (~USD 4.3/day): stop it whenever DEV is idle
(`az postgres flexible-server stop`; Azure restarts it after seven days). Container Apps run one
replica each (0.25–0.5 vCPU). Delete or scale apps to zero after the evaluation.

## Known limits (MVP)

- RAG runs migrations and queries with one identity; the ADR-021 runtime/import/migration split is
  not modelled yet, and the obsolete `rag_runtime_contract` handoff (Entra app roles) remains to be retired.
- Container Apps read the registry token through a Key Vault reference; if the vault firewall blocks
  the platform's fetch, allow trusted Azure services on the app material vault.
