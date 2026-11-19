# First DEV foundation provisioning

This procedure implements ADR 005's infrastructure/application readiness addendum
and retains ADR 004's state custody controls.
It prepares existing foundations, without application containers, broker entities,
SQL migrations, models or secret payloads. Commands are ordered instructions for
an authorized operator; this document itself authorizes no Azure or state change.
Use a reviewed immutable commit from `main`, Terraform 1.17.1, the README's Bun
version, Azure CLI, Python 3, `age` and a private Bash terminal in WSL2.

## Configuration and naming

Use the DEV examples beside their existing roots. The subscription and tenant
come from ADR 004. `westus3` is the approved DEV planning region; each selected resource's
subscription-specific availability must pass the checks below. The candidate enables ACA, PostgreSQL, Service Bus and Foundry. The post-registration
ACA quota checks below must pass before generating its real plan. Static hosting,
Key Vault and Application Insights are deferred for the synthetic core. The region, address
allocation and operator grants must be included in the apply authorization.

| Input | Selected preparation value and reason |
| --- | --- |
| State account | `stpipesordev04f339b7`, Standard LRS; private `tfstate-dev`, key `dev/foundation.tfstate`; 30-day blob/container recovery and versioning. |
| Workload/state groups | Existing AVM names `rg-pipesor-dev` / `rg-pipesor-state-dev`. |
| VNet / ACA subnet | `10.50.0.0/16` / `10.50.1.0/24`; dedicated PostgreSQL subnet `10.50.2.0/28`; check against intended VPN/peering routes before approval. |
| Workspace | Existing platform name; 30-day retention, 0.1 GB/day ingestion cap. Cap is delayed and is not a hard spending limit. |
| Service Bus / PostgreSQL | `sb-pipesor-dev-04f339b7` Standard / `pg-pipesor-dev-04f339b7` PG17 B2s, 32 GiB, Entra-only, seven-day local backups. |
| Foundry | `ai-pipesor-dev-04f339b7` AIServices S0 account, `pipesor-dev` project; no deployment or consumption selected. |
| Deferred Static Web App / Key Vault | `swa-pipesor-dev-04f339b7` Free / `kv-pipesor-dev-04f339b7` Standard, protected 30-day recovery; no credentials initialized. |
| State/operator access | Explicitly approved operator Entra object ID and WSL public egress IPv4; obtain anew below. |
| PostgreSQL administrator | Recommend the approved DEV operator for first creation, then an approved group when one actually exists. Supply its real object ID/name; do not invent a group. |

Naming audit: AVM naming **0.3.0** is retained for group/platform/telemetry names
whose scope already supplies uniqueness. Explicit global-service inputs retain
service constraints and use the first eight subscription hex characters as a
stable collision-reduction suffix. This is not a uniqueness guarantee: check
availability before every initial create. Future subscriptions select different
suffixes/inputs; shared modules have no subscription-specific defaults. Local DNS,
subnets, role assignment UUIDs and child project names keep their existing scope.
No naming-module migration, random suffix, provider upgrade or resource-address
change is needed. AVM resource-group 0.4.0/state-store Storage AVM 0.8.0 and direct
AzAPI 2.9.0 resources preserve their existing ownership.

## Synthetic diagnostic workload sequence

This is the smallest DEV path that retains the local owner checks. The owner
must approve the synthetic publisher and trusted capture-authority input
before they are wired. Start at the existing normalized event boundary.
Defer real GitHub capture, GitHub App credentials, Key Vault, Application
Insights, and non-DEV environments. The ACA module still includes its log
workspace. Use the existing Static Web Apps Free module for the Azure-hosted
React build only after its own location and offer checks pass.

1. **Foundations.** Verify the target, quota, PostgreSQL SKU/storage, Foundry
   model availability, spending and state custody. Under the existing
   bootstrap procedure, review a plan for DEV state storage and the resource
   group, ACA/VNet, PostgreSQL/private DNS, Service Bus Standard and Foundry
   account/project. Set `application_insights_enabled = false` and
   `key_vault = null` for this synthetic path. Review Static Web Apps in the
   foundation plan or approve it separately once eligible.
2. **Data and events.** From the private network, create the database,
   enable `vector`, and apply owner migrations before starting dependents:
   Ingestion V1–V2, Pipeline V1–V5 (`ops`), Log/Event V1–V2 then
   Correlation V1–V4 (`evidence`, separate Flyway histories),
   Recommendation receipts V1 (`diagnosis`), and RAG Alembic head
   (`knowledge`). Review any later diagnostic read-model migration separately.
   Assign distinct runtime and migrator roles. Verify Entra token refresh on
   new pooled database connections. Create one topic and three filtered
   subscriptions for the canonical event path: Pipeline receives
   `execution.snapshot` major 1; Log/Event and NLP each receive
   `protected_workflow_evidence` major 2. Bind the approved synthetic producer
   to Data Sender and consumers to scoped Data Receiver. Verify durable owner
   registration before NLP can complete a message, including redelivery and
   exhausted-message handling.
3. **Internal applications and AI.** Compose and publish immutable internal
   workload images, including the currently missing Log/Event, Correlation,
   and Recommendation runtime compositions. Verify private pull, health
   and rollback inputs. Run Ingestion in machine-scope authority mode only.
   Pipeline asks it for current scope. Log/Event registers protected evidence
   after the Pipeline owner check. NLP sends to Correlation, which verifies
   Pipeline and Log/Event ownership and delivers the durable Recommendation
   receipt. Use approved workload client/principal bindings and app roles at
   each call. Configure RAG PostgreSQL runtime/import/migration access,
   `Rag.Query`, and the managed `text-embedding-3-small` 1536-dimensional
   deployment. Import the authorized synthetic knowledge through the existing
   importer. Recommendation needs the approved diagnostic model, endpoint,
   corresponding inference grant and provider adapter. Check RAG and
   Recommendation before starting Correlation; check all owners before NLP
   and the first scoped event publication.
4. **Dashboard and acceptance.** Approve the versioned diagnostic read and
   result persistence or reconstruction contracts, plus the Entra delegated
   audience/scope, resource access and browser origin. Expose only the approved
   dashboard API over ACA HTTPS and host the React build on the selected site.
   Run one synthetic execution and inspect end-to-end provenance in the browser.
   Keep the existing loopback HTTP test as the separate local regression gate.

This plan preserves all seven backend roles because the existing current-scope
chain reaches Ingestion even when the source event is synthetic. Reducing the
path to pre-registered evidence or a pre-correlated receipt requires an approved
input boundary and verifies less of the chain. Existing Terraform modules create
foundations; the application compositions, messaging children, grants, model
deployments and approved read API are separate readiness work.

## Read-only preflight and remaining decisions

From the repository root, set `PRIVATE_DIR` to a directory **outside this checkout
on encrypted storage**, with encrypted independent backup destinations already
accessible. Do not use `/tmp` for the sole live state. Keep decryption keys separate.

```bash
set -euo pipefail
set +x
export DEV_SUBSCRIPTION=04f339b7-f969-4e17-801c-da6e81e78ffd
export DEV_TENANT=0e0cb060-09ad-49f5-a005-68b9b49aa1f6
: "${PRIVATE_DIR:?Set an encrypted private directory outside Git}"
umask 077
mkdir -p "$PRIVATE_DIR"
chmod 700 "$PRIVATE_DIR"
for tool in terraform bun az python3 age; do command -v "$tool" >/dev/null; done
terraform version
az account show --query '{subscription:id,tenant:tenantId,state:state}' -o json
[[ "$(az account show --query id -o tsv)" == "$DEV_SUBSCRIPTION" ]]
[[ "$(az account show --query tenantId -o tsv)" == "$DEV_TENANT" ]]
[[ "$(az account show --query state -o tsv)" == Enabled ]]
export ARM_SUBSCRIPTION_ID="$DEV_SUBSCRIPTION" ARM_TENANT_ID="$DEV_TENANT"
# Reject competing service-principal and federated credentials before selecting CLI.
for name in ARM_CLIENT_ID ARM_CLIENT_ID_FILE_PATH ARM_CLIENT_SECRET ARM_CLIENT_SECRET_FILE_PATH ARM_CLIENT_CERTIFICATE ARM_CLIENT_CERTIFICATE_PATH ARM_CLIENT_CERTIFICATE_PASSWORD ARM_OIDC_TOKEN ARM_OIDC_TOKEN_FILE_PATH ARM_OIDC_REQUEST_URL ARM_OIDC_REQUEST_TOKEN AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_CLIENT_CERTIFICATE_PATH AZURE_FEDERATED_TOKEN_FILE; do
  [[ -z "${!name:-}" ]] || { echo "Remove competing credential setting: $name" >&2; exit 1; }
done
export ARM_USE_CLI=true ARM_USE_MSI=false ARM_USE_OIDC=false ARM_USE_AKS_WORKLOAD_IDENTITY=false
```

If `age` is absent, install its distribution package with
`sudo apt-get update && sudo apt-get install age`, then rerun the tool check.
Verified recipient keys and protected backup paths must still be supplied by the
custodians. If the context is wrong, deliberately authenticate/select the expected target;
never continue with an arbitrary default. `az login --tenant "$DEV_TENANT"` and
`az account set --subscription "$DEV_SUBSCRIPTION"` configure the local session.

```bash
for provider in Microsoft.Storage Microsoft.Network Microsoft.App Microsoft.OperationalInsights Microsoft.Insights Microsoft.ServiceBus Microsoft.DBforPostgreSQL Microsoft.CognitiveServices Microsoft.Web Microsoft.KeyVault; do
  az provider show --subscription "$DEV_SUBSCRIPTION" --namespace "$provider" \
    --query '{namespace:namespace,state:registrationState}' -o json
 done
az resource list --subscription "$DEV_SUBSCRIPTION" --query '[].{type:type,name:name,location:location}' -o json
az rest --method get --url "https://management.azure.com/subscriptions/$DEV_SUBSCRIPTION/providers/Microsoft.Authorization/permissions?api-version=2022-04-01" --query 'value[].{actions:actions,notActions:notActions}' -o json
az policy assignment list --scope "/subscriptions/$DEV_SUBSCRIPTION" --disable-scope-strict-match --query '[].{name:name,scope:scope,policy:policyDefinitionId}' -o json
az storage account check-name --subscription "$DEV_SUBSCRIPTION" --name stpipesordev04f339b7 --query '{available:nameAvailable,reason:reason}' -o json || echo 'Storage name availability unresolved; retry after registration'
az cognitiveservices account list-skus --subscription "$DEV_SUBSCRIPTION" --kind AIServices --location westus3 -o json > "$PRIVATE_DIR/foundry-skus.json"
```

Inspect inherited deny assignments/policies and expand the actual role definitions;
management `actions` alone does not establish a role's full boundary. Bootstrap
needs resource-group/storage management plus `Microsoft.Authorization/roleAssignments/write`
for container-scoped grants. Workloads need management writes for the selected
resource types and subnet `join/action` / `joinViaServiceEndpoint/action` permissions.
Foundry creation also creates its existing system identities; PostgreSQL's configured
Entra administrator is an explicit permission boundary. Runtime data access is not
implied by subscription management rights. A plan identity must have resource
reads only; backend Blob Data Contributor/lease permissions are a separate scope.

Before planning, confirm B2s/PG17/32-GiB eligibility and ACA managed-environment quota. Before enabling deferred SWA, confirm Free availability in a policy-allowed region. Confirm Foundry AIServices S0/project support before selecting it. Public
provider locations do not prove these. Inspect global names with documented
nonmutating check-name APIs (POST validates a name and creates no object):

```bash
az rest --method post --url "https://management.azure.com/subscriptions/$DEV_SUBSCRIPTION/providers/Microsoft.KeyVault/checkNameAvailability?api-version=2024-11-01" --body '{"name":"kv-pipesor-dev-04f339b7","type":"Microsoft.KeyVault/vaults"}' -o json
az rest --method post --url "https://management.azure.com/subscriptions/$DEV_SUBSCRIPTION/providers/Microsoft.ServiceBus/CheckNameAvailability?api-version=2024-01-01" --body '{"name":"sb-pipesor-dev-04f339b7"}' -o json
```

An absent existing resource is not global availability.
Record an inaccessible/quota API as an unresolved gap rather
than trying a create. An allowed fallback region must still satisfy PG/platform
co-location; regenerate/review inputs instead of changing locations after approval.

Verify credit balance, expiry and billing currency in the actual owner-visible
Students/Education billing portal. UsageDetails or a spending-limit flag is not a
credit balance. Before apply, record the complete DEV estimate and the owner's
funding decision, including idle PostgreSQL, Service Bus and ACA managed networking.
The [cost projection](mvp-cost-projection.md#key-vault-incremental-scenario-2026-11-16)
includes a roughly USD 100/month full-foundation sensitivity before state, Key Vault, telemetry and egress usage. This selected ACA/PostgreSQL profile must use that full sensitivity, not the earlier partial USD 10/month scenario; neither is the actual Students bill.

Resolve actual access inputs privately. For a signed-in user,
`az ad signed-in-user show --query '{id:id,name:userPrincipalName}' -o json` obtains
the candidate user; the owner must approve its state/admin role. Supply the approved
values as shell variables (names/IDs are not passwords):

```bash
: "${STATE_OPERATOR_ID:?Approved state operator object UUID}"
: "${POSTGRES_ADMIN_ID:?Approved PostgreSQL administrator object UUID}"
: "${POSTGRES_ADMIN_NAME:?Exact administrator principal name}"
: "${WSL_PUBLIC_IPV4:?Approved current public IPv4 without CIDR}"
export STATE_OPERATOR_ID POSTGRES_ADMIN_ID POSTGRES_ADMIN_NAME WSL_PUBLIC_IPV4
python3 - "$PRIVATE_DIR" <<'PY'
import ipaddress, json, os, pathlib, sys, uuid
root = pathlib.Path(sys.argv[1])
ip = ipaddress.IPv4Address(os.environ['WSL_PUBLIC_IPV4'])
if not ip.is_global: raise SystemExit('A public WSL egress IPv4 is required')
for key in ('STATE_OPERATOR_ID', 'POSTGRES_ADMIN_ID'):
    if uuid.UUID(os.environ[key]).int == 0: raise SystemExit('Nonzero principal required')
if not os.environ['POSTGRES_ADMIN_NAME'].strip(): raise SystemExit('PostgreSQL administrator name required')
values = {'REPLACE_WITH_STATE_OPERATOR_OBJECT_ID': os.environ['STATE_OPERATOR_ID'],
          'REPLACE_WITH_POSTGRES_ADMIN_OBJECT_ID': os.environ['POSTGRES_ADMIN_ID'],
          'REPLACE_WITH_POSTGRES_ADMIN_PRINCIPAL_NAME': os.environ['POSTGRES_ADMIN_NAME'],
          'REPLACE_WITH_WSL_PUBLIC_IPV4': str(ip)}
for source, target in [('bootstrap/dev/terraform.tfvars.example', 'bootstrap.tfvars'),
                       ('environments/dev/terraform.tfvars.example', 'dev.tfvars')]:
    text = pathlib.Path(source).read_text()
    for marker, value in values.items(): text = text.replace(json.dumps(marker), json.dumps(value))
    if any('REPLACE_WITH_' in line for line in text.splitlines() if not line.lstrip().startswith('#')): raise SystemExit('Unresolved operator input')
    (root / target).write_text(text)
PY
```

Check the actual public NAT/VPN egress, not WSL's private address; validate the
10.50.0.0/16 allocation against `ip route` and intended Windows/VPN routes.
The example selects ACA, PostgreSQL, Service Bus and Foundry and leaves Static Web Apps, Key Vault and Application Insights disabled. If the ACA quota gate fails, set `container_platform` and `postgresql` to null and `application_insights_enabled` to false before the first plan. Do not enable ACA until an allowed region has positive managed-environment quota; PostgreSQL and Insights depend on ACA. Do not enable Static Web Apps until an allowed supported region or an authorized policy change is confirmed. For other blocked capabilities, keep the desired reviewed candidate separately and
set only that capability to null **before its first creation**; account for its
dependents (no platform means no PostgreSQL/Insights). Never null a deployed object
to pause billing. Do not substitute runtime-contract placeholders or create apps.

## Authorized execution sequence

1. **Authorize missing provider registrations**, naming the target subscription
   and exact namespaces. Then run the following only for each approved namespace:

   ```bash
   : "${APPROVED_PROVIDER:?One explicitly authorized namespace}"
   az provider register --subscription "$DEV_SUBSCRIPTION" --namespace "$APPROVED_PROVIDER" --wait
   az provider show --subscription "$DEV_SUBSCRIPTION" --namespace "$APPROVED_PROVIDER" --query registrationState -o tsv
   ```

   Stop unless required registrations report `Registered`. Terraform keeps automatic
   registration/preflight disabled. Registration grants no resource apply authority.

   If all six missing DEV registrations have been explicitly authorized for this
   subscription, the exact batch is:

   ```bash
   for provider in Microsoft.App Microsoft.Storage Microsoft.DBforPostgreSQL Microsoft.ServiceBus Microsoft.CognitiveServices Microsoft.KeyVault; do
     az provider register --subscription "$DEV_SUBSCRIPTION" --namespace "$provider" --wait
     [[ "$(az provider show --subscription "$DEV_SUBSCRIPTION" --namespace "$provider" --query registrationState -o tsv)" == Registered ]]
   done
   ```

   **Recheck ACA after registration before classifying the subscription.** A zero
   value obtained before registration does not prove either permanent offer
   exclusion or that registration will fix it. Read current regional usage:

   ```bash
   export DEV_LOCATION=westus3
   az rest --method get --url "https://management.azure.com/subscriptions/$DEV_SUBSCRIPTION/providers/Microsoft.App/locations/$DEV_LOCATION/usages?api-version=2025-07-01" \
     --query "value[?name.value=='ManagedEnvironmentCount'].{quota:name.value,current:currentValue,limit:limit}" -o json
   ```

   A successful response must contain the expected quota item, and
   `limit - current` must allow at least one environment. An empty list, 403 or
   unsupported API is a verification gap, not a positive quota result. Recheck
   region policy and provider availability too; positive quota does not override
   a location deny policy or prove regional capacity.

   If the post-registration limit remains zero, obtain explicit authorization
   for a **subscription quota request**, then open the
   [Azure Quota Management System](https://ms.portal.azure.com/#view/Microsoft_Azure_Capacity/QuotaMenuBlade/~/myQuotas).
   Select provider **Azure Container Apps**, this DEV subscription,
   **Managed Environment Count** in the approved region and request a new total
   limit of **1**. Record the request ID and result. This subscription quota does
   not require an existing environment; the separate environment-core quota does.
   If unavailable or rejected for the offer, escalate the same subscription,
   region, quota name, registered-provider status and zero-quota response to
   Microsoft Support and request explicit eligibility/remediation confirmation.
   Do not create a dummy environment, request unrelated compute quota or infer
   ACA eligibility from Azure Container Instances restrictions.

   After approval, repeat the read-only quota command. If Microsoft confirms the
   offer cannot receive usable ACA quota, an owner-approved funded subscription
   or offer change is the remaining path; do not replace mandatory ACA or change
   the environment/state architecture to bypass this gate. Registration, quota
   submission and subscription changes are separately authorized actions.

   Once the count gate passes, the selected `container_platform` candidate can
   proceed to plan. PostgreSQL and Insights use its existing VNet/workspace
   after their own SKU/admin checks.
   Keep all dependent locations aligned, regenerate a fresh plan and obtain apply
   authorization. Foundation readiness still does not activate applications.

2. **Authorize bootstrap initialization/local state custody** after verifying two
   age recipients, two independent encrypted backup destinations, and each
   custodian's recovery test. Use a fresh protected Terraform data directory:

   ```bash
   export TF_DATA_DIR="$PRIVATE_DIR/tfdata-bootstrap"
   test ! -e "$PRIVATE_DIR/bootstrap.tfstate"
   test ! -e "$TF_DATA_DIR/terraform.tfstate"
   terraform -chdir=bootstrap/dev init -input=false -lockfile=readonly \
     -backend-config="path=$PRIVATE_DIR/bootstrap.tfstate"
   terraform -chdir=bootstrap/dev validate
   ```

   With a separately authenticated resource-read identity and no existing resources,
   generate a protected plan; otherwise resolve the missing reads before proceeding:

   ```bash
   terraform -chdir=bootstrap/dev plan -input=false -lock-timeout=60s \
     -var-file="$PRIVATE_DIR/bootstrap.tfvars" -out="$PRIVATE_DIR/bootstrap.tfplan" \
     > "$PRIVATE_DIR/bootstrap-plan.log"
   terraform -chdir=bootstrap/dev show -no-color "$PRIVATE_DIR/bootstrap.tfplan" > "$PRIVATE_DIR/bootstrap-review.txt"
   sha256sum "$PRIVATE_DIR/bootstrap.tfplan"
   ```

3. Review exact names, container-only RBAC, LRS, recovery, public firewall deny,
   Entra-only/no keys and the protected plan. **Authorize this saved bootstrap
   plan's apply** and change to the approved apply identity without altering the
   reviewed target/inputs/plan:

   Before applying, repeat the CLI subscription and tenant checks above and
   verify the selected account is the approved apply principal. If changing
   identities changes the computed plan, regenerate and reauthorize.

   ```bash
   terraform -chdir=bootstrap/dev apply -input=false "$PRIVATE_DIR/bootstrap.tfplan"
   ```

   Never retry a saved plan after partial apply. Preserve local state and backups.

4. Verify management properties, then back up state before using the new backend.
   `AGE_RECIPIENTS_FILE` contains both verified public recipients, one per line;
   both backup directories must already be approved and accessible:

   ```bash
   : "${AGE_RECIPIENTS_FILE:?Verified public recipient file}"
   : "${BACKUP_ONE:?Approved independent backup directory}"
   : "${BACKUP_TWO:?Second approved independent backup directory}"
   stamp=$(date -u +%Y%m%dT%H%M%SZ)
   age -R "$AGE_RECIPIENTS_FILE" -o "$PRIVATE_DIR/bootstrap-$stamp.tfstate.age" "$PRIVATE_DIR/bootstrap.tfstate"
   cp "$PRIVATE_DIR/bootstrap-$stamp.tfstate.age" "$BACKUP_ONE/"
   cp "$PRIVATE_DIR/bootstrap-$stamp.tfstate.age" "$BACKUP_TWO/"
   sha256sum "$PRIVATE_DIR/bootstrap-$stamp.tfstate.age"
   terraform -chdir=bootstrap/dev output -json backend > "$PRIVATE_DIR/backend.json"
   python3 - "$PRIVATE_DIR" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1]); config = json.loads((root / 'backend.json').read_text())
assert config['container_name'] == 'tfstate-dev' and config['key'] == 'dev/foundation.tfstate'
assert config['use_azuread_auth'] is True
(root / 'dev.tfbackend').write_text(''.join(f'{k} = {json.dumps(v)}\n' for k, v in config.items()) + 'use_cli = true\n')
PY
   az storage container show --account-name stpipesordev04f339b7 --name tfstate-dev --auth-mode login --query '{name:name,publicAccess:properties.publicAccess}' -o json
   az storage account show --resource-group rg-pipesor-state-dev --name stpipesordev04f339b7 --query '{sku:sku.name,keys:allowSharedKeyAccess,publicBlob:allowBlobPublicAccess,tls:minimumTlsVersion,https:enableHttpsTrafficOnly,network:networkRuleSet}' -o json
   az storage account blob-service-properties show --resource-group rg-pipesor-state-dev --account-name stpipesordev04f339b7 --query '{versioning:isVersioningEnabled,blobRecovery:deleteRetentionPolicy,containerRecovery:containerDeleteRetentionPolicy}' -o json
   ```

   Prove both custodians can decrypt independently, compare plaintext state hashes
   privately, and retain encrypted backups for 90 days per ADR 004. Do not store keys
   beside backups. Wait for scoped RBAC propagation; never enable shared keys or
   widen the firewall to work around a 403.

5. **Authorize first remote-backend initialization and state-locking operations**.
   There is no existing workload state to migrate on a first provisioning; stop if
   one is discovered. Do not use `-migrate-state` or copy bootstrap state into it.
   Switch to the approved resource-read-only planning identity, then repeat the
   tenant/subscription and CLI credential checks above. Before initialization,
   verify that this principal has container-scoped Blob Data Contributor for
   leases. The bootstrap example grants only `STATE_OPERATOR_ID`; if plan and
   apply use distinct principals, include both approved object IDs in
   `settings.principal_ids` before reviewing the bootstrap plan or establish
   their separately authorized container grants. Management Owner alone is not
   proof of data-plane or lease access.

   ```bash
   export TF_DATA_DIR="$PRIVATE_DIR/tfdata-dev"
   test ! -e "$TF_DATA_DIR/terraform.tfstate"
   [[ "$(az storage blob exists --account-name stpipesordev04f339b7 --container-name tfstate-dev --name dev/foundation.tfstate --auth-mode login --query exists -o tsv)" == false ]]
   terraform -chdir=environments/dev init -input=false -lockfile=readonly \
     -backend-config="$PRIVATE_DIR/dev.tfbackend"
   terraform -chdir=environments/dev validate
   terraform -chdir=environments/dev plan -input=false -lock-timeout=60s \
     -var-file="$PRIVATE_DIR/dev.tfvars" -out="$PRIVATE_DIR/dev.tfplan" > "$PRIVATE_DIR/dev-plan.log"
   terraform -chdir=environments/dev show -no-color "$PRIVATE_DIR/dev.tfplan" > "$PRIVATE_DIR/dev-review.txt"
   sha256sum "$PRIVATE_DIR/dev.tfplan"
   ```

6. **Authorize the exact saved DEV foundation plan and apply**. Expect only the
   workload group, selected foundation resources and their existing child resources
   (and any child resources explicitly selected), never apps,
   models, secret payloads or messaging entities:

   Switch to the approved apply identity, repeat the tenant/subscription and
   CLI credential checks, and verify its approved container data/lease grant.

   ```bash
   terraform -chdir=environments/dev apply -input=false "$PRIVATE_DIR/dev.tfplan"
   terraform -chdir=environments/dev state pull > "$PRIVATE_DIR/dev.tfstate"
   stamp=$(date -u +%Y%m%dT%H%M%SZ)
   age -R "$AGE_RECIPIENTS_FILE" -o "$PRIVATE_DIR/dev-$stamp.tfstate.age" "$PRIVATE_DIR/dev.tfstate"
   cp "$PRIVATE_DIR/dev-$stamp.tfstate.age" "$BACKUP_ONE/"
   cp "$PRIVATE_DIR/dev-$stamp.tfstate.age" "$BACKUP_TWO/"
   az resource list --resource-group rg-pipesor-dev --subscription "$DEV_SUBSCRIPTION" --query '[].{name:name,type:type,location:location}' -o json
   # If Key Vault was separately selected and authorized:
   # az resource show --resource-group rg-pipesor-dev --resource-type Microsoft.KeyVault/vaults --name kv-pipesor-dev-04f339b7 --query 'properties.{tenant:tenantId,rbac:enableRbacAuthorization,purge:enablePurgeProtection,recovery:softDeleteRetentionInDays,network:networkAcls}' -o json
   az resource show --resource-group rg-pipesor-dev --resource-type Microsoft.ServiceBus/namespaces --name sb-pipesor-dev-04f339b7 --query '{sku:sku,localAuth:properties.disableLocalAuth,tls:properties.minimumTlsVersion}' -o json
   az postgres flexible-server show --resource-group rg-pipesor-dev --name pg-pipesor-dev-04f339b7 --query '{version:version,sku:sku,storage:storage,auth:authConfig,backup:backup,network:network}' -o json
   az resource show --resource-group rg-pipesor-dev --resource-type Microsoft.CognitiveServices/accounts --name ai-pipesor-dev-04f339b7 --query '{kind:kind,sku:sku,localAuth:properties.disableLocalAuth,projects:properties.allowProjectManagement}' -o json
   ```

   Compare each resource's effective security, SKU, recovery and network metadata
   with the reviewed plan. When ACA is later enabled, inspect its managed resources and billable LB/IP meters.
   A successful apply does not prove PostgreSQL SQL access, private routing, GitHub,
   Key Vault Secrets access or application integration. Keep applications disabled
   until their own runtime/readiness and deployment authorization.

## Failure recovery and cost control

On partial failure, stop and preserve state, current protected logs and encrypted
backups. Compare `terraform state list` with read-only Azure inventory. Correct only
verified input/provider restrictions, generate a fresh plan and obtain a new apply
approval. Never delete a group, import an orphan, force-unlock, restore old state or
retry a refresh credential as an automatic recovery. Unexpected resources require
an explicitly authorized ownership/import decision. Old state is not resource rollback.

Use the actual offer-supported cost portal with filters for `rg-pipesor-dev`,
`rg-pipesor-state-dev` and ACA's managed group; include account-wide Service Bus
base charges. Review daily after first creation and after workload activation.
An empty UsageDetails response is not proof of zero cost. PostgreSQL stop/start
is a separately approved temporary option: storage remains billed and the service
restarts after seven days. ACA min replicas are irrelevant before apps exist;
empty custom-VNet environment networking may still be charged. No universal pause
command exists. Retirement requires a fresh reviewed destroy plan and explicit
scope approval; preserve state/recovery copies and account for Key Vault's purge
protection and database loss before authorizing it.

Sources: [Azure naming rules](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules),
[AVM naming 0.3.0](https://registry.terraform.io/modules/Azure/avm-utl-naming/azure/0.3.0),
[Terraform local backend](https://developer.hashicorp.com/terraform/language/backend/local),
[Azure Blob backend and CLI authentication](https://developer.hashicorp.com/terraform/language/backend/azurerm),
[provider registrations](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types),
[ACA quotas](https://learn.microsoft.com/en-us/azure/container-apps/quotas),
[ACA quota requests](https://learn.microsoft.com/en-us/azure/container-apps/quota-requests),
[Key Vault check-name](https://learn.microsoft.com/en-us/rest/api/keyvault/keyvault/vaults/check-name-availability?view=rest-keyvault-keyvault-2024-11-01),
[PostgreSQL check-name](https://learn.microsoft.com/en-us/rest/api/postgresql/name-availability/execute?view=rest-postgresql-2024-08-01),
[Service Bus check-name](https://learn.microsoft.com/en-us/rest/api/servicebus/controlplane/namespaces/check-name-availability?view=rest-servicebus-controlplane-2024-01-01),
[PostgreSQL stop behavior](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-stop-start-server).
