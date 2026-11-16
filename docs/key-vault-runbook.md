# Key Vault preparation and verification

Read the [design and Ingestion handoff](key-vault-integration.md) first. Commands
below are staged procedures, **not authorization to execute Azure writes or state
operations**. Use a private terminal without command tracing or SDK/CLI debug
logging. Keep payloads, private references and complete logs outside Git and PRs.

## 1. Credential-free repository verification

Use Terraform 1.17.1 and Bun from the README, with no Azure resource-write
credentials. Inspect providers/tests before running. From this repository:

```bash
git diff --check
terraform fmt -check -recursive
for directory in modules/key-vault modules/container-platform environments/dev environments/qa environments/preprod environments/prod; do
  terraform -chdir="$directory" init -backend=false -input=false -lockfile=readonly
  terraform -chdir="$directory" validate
  bun tests/terraform-contracts.js "$directory"
done
bun test tests/terraform-contracts.test.js tests/deployment-scaffold.test.js
```

Tests use a fully mocked AzAPI provider and explicit plan-only runs. They check
activation, ownership, security and absence of secret resources; they cannot prove
offer eligibility, RBAC propagation, SDK connectivity or deployment readiness.
Backend-disabled initialization neither reads remote state nor tests its access.

## 2. Read-only target and feasibility inspection

Use the separately authenticated operator's WSL Linux Azure CLI. For the current
DEV target obtain the expected IDs from [ADR 004](adr-004-mvp-state-and-deployment.md#deployment-scope-and-temporary-azure-target),
read with ADR 005. For future environments use their independently approved IDs.
Supply `EXPECTED_SUBSCRIPTION`, `EXPECTED_TENANT` and an approved `KV_LOCATION`
before these commands; no region is selected by the example.

```bash
test "$(az account show --query id -o tsv)" = "$EXPECTED_SUBSCRIPTION"
test "$(az account show --query tenantId -o tsv)" = "$EXPECTED_TENANT"
az account show --query '{state:state,name:name,tenantId:tenantId,id:id}' -o json
az rest --method get --url "https://management.azure.com/subscriptions/$EXPECTED_SUBSCRIPTION?api-version=2022-12-01" \
  --query '{state:state,policies:subscriptionPolicies}' -o json
az provider show --namespace Microsoft.KeyVault --subscription "$EXPECTED_SUBSCRIPTION" \
  --query '{registrationState:registrationState,vaults:resourceTypes[?resourceType==`vaults`].{locations:locations,apiVersions:apiVersions}}' -o json
az provider show --namespace Microsoft.Authorization --subscription "$EXPECTED_SUBSCRIPTION" \
  --query '{registrationState:registrationState}' -o json
az resource list --subscription "$EXPECTED_SUBSCRIPTION" \
  --query '[].{type:type,location:location}' -o json
az role definition list --name 'Key Vault Secrets User' --subscription "$EXPECTED_SUBSCRIPTION" \
  --query '[].{name:roleName,id:name,permissions:permissions}' -o json
az provider operation show --namespace Microsoft.KeyVault \
  --query 'resourceTypes[?name==`vaults/secrets`].operations[].{name:name,isDataAction:isDataAction}' -o json
az rest --method get --url "https://management.azure.com/subscriptions/$EXPECTED_SUBSCRIPTION/providers/Microsoft.Consumption/usageDetails?api-version=2023-11-01&\$top=1" \
  --query '{count:length(value),hasNext:nextLink!=null}' -o json
```

Stop on a target mismatch. Do not register providers automatically. Public provider
metadata is not proof of Students SKU/region eligibility, current quota or credit.
A failed/empty usage call is not a balance. Obtain actual remaining credit,
currency, expiry and applicable policy from the offer-supported portal/owner;
record inaccessible APIs as gaps. Inspect inherited deny assignments/policies
and operator privileges before a real plan. No supported preflight guarantees a
successful create without actually attempting the separately authorized operation.

For an existing vault, inspect only its management metadata with
`az keyvault show --name "$APP_VAULT_NAME" --subscription "$EXPECTED_SUBSCRIPTION"`
and a narrow query for tenant/SKU/RBAC/recovery/network fields. Do not list/read
secret values during inventory. Permission inspection must distinguish management
actions from Key Vault data actions and inherited grants from this code's grants.

## 3. Prepare and review explicit inputs

Use `environments/dev/terraform.tfvars.example`; keep the actual ignored tfvars
outside commits. Supply `key_vault` with:

- Globally available `app_material_name`, approved `location`, expected `tenant_id`.
- `allowed_public_ipv4s`: approved public egress addresses/CIDRs (normally each
  WSL operator's `/32`), never WSL RFC1918 addresses or the whole internet. The
  capability accepts single IPv4 addresses or canonical `/24`–`/32` ranges.
- `app_material_readers`: map of stable labels to `object_id` and
  `principal_type` (`User`, `Group` or `ServicePrincipal`). Use a designated
  DEV developer/group, not an arbitrary signed-in identity.
- Optional `custody = { name = ..., principals = {...} }`, only for separately
  approved human credential integration. Its principals get custody-only get/set.

All grants default empty. Avoid adding a custody writer just to test App reads.
The optional platform enables the subnet service endpoint when Key Vault is
present; a KV-only local increment needs no ACA platform. Subnet service endpoint
and vault ACL changes must be reviewed with existing subnet/route behavior. Actual
ACA reachability remains a live verification requirement.

Review two Standard vaults only if custody is selected, operation-volume costs,
30-day irreversible recovery policy, public-IP custody and retention/cleanup
responsibilities. Confirm service readiness, backend/custody, deployment identity,
target policy/eligibility and the exact desired action before asking the owner for
provisioning authorization. KV changes do not require restoring the retired admin
or subscription-controls roots.

## 4. Separately authorized provisioning

Follow [ADR 001](adr-001-branching-and-promotion.md) and the
[DEV deployment runbook](mvp-deployment-runbook.md). After explicit authorization,
an operator may prepare missing provider registrations/permissions, initialize
the real backend, and generate a protected saved plan with reviewed target/input
references. Each Azure write and the exact saved-plan apply needs its own scope
authorization. This document deliberately provides no executable apply shortcut.

The deployment identity needs vault management and network privileges; if grants
are selected it additionally needs scoped role-assignment writes and, for custody,
custom role-definition writes. These are management permissions, not runtime data
permissions. Do not grant subscription Owner to an application. Keep read-only
planning identity/resource permissions separate from apply and state leases.

After apply, inspect vault properties and all effective grants, including inherited
ones, using read-only interfaces. Confirm tenant, Standard, RBAC, empty access
policies, soft delete 30, purge protection, `Deny`/`None`, approved IPs/subnet and
endpoint. Record the nonsecret output identity securely. Management-plane success
does not test the data plane. Name availability and retained deleted vaults may
block recreation; do not purge/recover automatically.

## 5. Separately authorized App-secret initialization

An explicitly authorized secret custodian initializes machine material outside
Terraform. A temporary vault-scoped **Key Vault Secrets Officer** grant can serve
this bounded operation, but includes delete/recovery powers: a permission operator
must separately approve/grant/remove it. It is never a runtime grant in this code.
Use a dedicated operator identity if the developer's subsequent negative write
test must demonstrate read-only behavior. No OAuth pair or PKCE verifier is
prepopulated by this runbook.

After approval of the target vault, two object names, secret writes and GitHub
configuration, supply `APP_VAULT_NAME`, `KEY_SECRET_NAME`, `WEBHOOK_SECRET_NAME`,
`APP_KEY_FILE` and a protected `PRIVATE_HANDOFF_DIR`. The key file is the GitHub
App's RSA private PEM obtained through its authorized administration process.
Names must be distinct and contain no user identity/token material. Never use
command-line `--value`, terminal paste, shell history or Terraform for payloads.

```bash
set -euo pipefail
set +x
: "${EXPECTED_SUBSCRIPTION:?Supply approved subscription}"
: "${EXPECTED_TENANT:?Supply approved tenant}"
: "${APP_VAULT_NAME:?Supply approved App vault}"
: "${KEY_SECRET_NAME:?Supply approved signing object name}"
: "${WEBHOOK_SECRET_NAME:?Supply approved webhook object name}"
: "${APP_KEY_FILE:?Supply protected GitHub RSA PEM file}"
: "${PRIVATE_HANDOFF_DIR:?Supply protected handoff directory}"
test "$(az account show --query id -o tsv)" = "$EXPECTED_SUBSCRIPTION"
test "$(az account show --query tenantId -o tsv)" = "$EXPECTED_TENANT"
[[ "$KEY_SECRET_NAME" =~ ^[A-Za-z0-9-]{1,127}$ ]]
[[ "$WEBHOOK_SECRET_NAME" =~ ^[A-Za-z0-9-]{1,127}$ ]]
[[ "${KEY_SECRET_NAME,,}" != "${WEBHOOK_SECRET_NAME,,}" ]]
umask 077
mkdir -p "$PRIVATE_HANDOFF_DIR"
chmod 700 "$PRIVATE_HANDOFF_DIR"
test -f "$APP_KEY_FILE"
chmod 600 "$APP_KEY_FILE"
openssl rsa -in "$APP_KEY_FILE" -check -noout >/dev/null 2>&1
python3 - "$PRIVATE_HANDOFF_DIR/webhook.txt" <<'PY'
import os, secrets, sys
with open(sys.argv[1], 'x', encoding='utf-8') as target:
    os.chmod(sys.argv[1], 0o600)
    target.write(secrets.token_hex(32))
PY
az keyvault secret set --subscription "$EXPECTED_SUBSCRIPTION" \
  --vault-name "$APP_VAULT_NAME" --name "$KEY_SECRET_NAME" \
  --file "$APP_KEY_FILE" --encoding utf-8 --query id -o tsv \
  > "$PRIVATE_HANDOFF_DIR/signing-reference.txt"
az keyvault secret set --subscription "$EXPECTED_SUBSCRIPTION" \
  --vault-name "$APP_VAULT_NAME" --name "$WEBHOOK_SECRET_NAME" \
  --file "$PRIVATE_HANDOFF_DIR/webhook.txt" --encoding utf-8 --query id -o tsv \
  > "$PRIVATE_HANDOFF_DIR/webhook-reference.txt"
```

Run this sequence once as a Bash script; it stops on any failure. Do not repeat a write after an uncertain response
without reconciling the operation with the custodian. Upload the same exact webhook
bytes to GitHub through the approved secure administrative process. Each returned
ID includes the exact version: validate vault host/object/version and transfer the
name/version into the protected application configuration. Do not print references
to shared logs. Remove the temporary writer grant through a separately authorized
permission operation before read-only runtime verification.

Key rotation: stage a new GitHub key/version, verify in an approved isolated read,
atomically update operator configuration, verify the service, then separately
retire the old GitHub key after its use is excluded. A single pinned webhook version
does not implement dual-secret overlap: coordinate webhook/service cutover and
possible delivery retries rather than claiming zero-loss rotation. No `latest`
lookup or automatic old-version deletion is permitted. Define encrypted key custody
and secure removal of local files/backups with the custodian; filesystem deletion
does not establish erasure from snapshots or Key Vault recovery storage.

## 6. WSL read-only application verification

Once a vault and exact material are initialized under authorization, the developer
logs in **inside WSL** to the expected tenant, selects the approved subscription
and repeats the context checks above. `az login --tenant "$EXPECTED_TENANT"` and
`az account set --subscription "$EXPECTED_SUBSCRIPTION"` change local CLI session
configuration, not Azure resources. Never print `az account get-access-token`.

With a reader identity and allowed egress, a narrow CLI check can retrieve only
metadata in its output (the CLI still obtains the secret in memory):

```bash
az keyvault secret show --subscription "$EXPECTED_SUBSCRIPTION" \
  --vault-name "$APP_VAULT_NAME" --name "$KEY_SECRET_NAME" \
  --version "$KEY_VERSION" --query 'attributes.enabled' -o tsv
az keyvault secret show --subscription "$EXPECTED_SUBSCRIPTION" \
  --vault-name "$APP_VAULT_NAME" --name "$WEBHOOK_SECRET_NAME" \
  --version "$WEBHOOK_VERSION" --query 'attributes.enabled' -o tsv
```

Expected: both enabled reads succeed. A 401/auth failure requires correct tenant/
login; a 403 may be RBAC or firewall; a 404 may be wrong name/version. Diagnose
privately; do not widen grants/networks, select `latest`, or put raw exceptions in
application output. IP/DNS/TLS failures remain unavailable.

For an SDK/application-boundary smoke test, use the current Ingestion checkout and
its built runtime dependency classpath. Build per its README in that repository's
own authorized work; generate a classpath file outside Git with Maven's
`dependency:build-classpath -DincludeScope=runtime -Dmdep.outputFile=/tmp/ingestion-kv-classpath`.
Supply the exact `PIPESOR_*` material variables from the handoff (including an
explicit positive `PIPESOR_KEY_VAULT_TIMEOUT_SECONDS`). Save this source as
`/tmp/KeyVaultReadCheck.java`:

```java
import com.azure.identity.AzureCliCredentialBuilder;
import com.azure.security.keyvault.secrets.SecretClientBuilder;
import com.azure.core.http.HttpClient;
import com.azure.core.util.HttpClientOptions;
import com.azure.core.http.policy.*;
import java.net.URI;
import java.time.Duration;
import java.util.Arrays;
import org.pipesor.ingestion.capture.infrastructure.credentials.KeyVaultAppMaterial;

class KeyVaultReadCheck {
    static String env(String key) {
        var value = System.getenv(key);
        if (value == null || value.isBlank()) throw new IllegalArgumentException();
        return value;
    }
    public static void main(String[] args) {
        try {
            var timeout = Duration.ofSeconds(Long.parseLong(env("PIPESOR_KEY_VAULT_TIMEOUT_SECONDS")));
            if (timeout.isZero() || timeout.isNegative()) throw new IllegalArgumentException();
            var vault = URI.create(env("PIPESOR_GITHUB_APP_VAULT_URL"));
            var client = new SecretClientBuilder().vaultUrl(vault.toString())
                .credential(new AzureCliCredentialBuilder()
                    .tenantId(env("PIPESOR_AZURE_TENANT_ID"))
                    .subscription(env("PIPESOR_AZURE_SUBSCRIPTION_ID"))
                    .processTimeout(timeout).build())
                .httpClient(HttpClient.createDefault(new HttpClientOptions()
                    .setConnectTimeout(timeout).setReadTimeout(timeout)
                    .setResponseTimeout(timeout).setWriteTimeout(timeout)))
                .retryOptions(new RetryOptions(new FixedDelayOptions(0, Duration.ZERO)))
                .httpLogOptions(new HttpLogOptions().setLogLevel(HttpLogDetailLevel.NONE))
                .buildClient();
            var material = new KeyVaultAppMaterial(client, vault, env("PIPESOR_GITHUB_APP_ID"),
                new KeyVaultAppMaterial.Reference(env("PIPESOR_GITHUB_APP_KEY_SECRET_NAME"),
                    env("PIPESOR_GITHUB_APP_KEY_VERSION")),
                new KeyVaultAppMaterial.Reference(env("PIPESOR_GITHUB_WEBHOOK_SECRET_NAME"),
                    env("PIPESOR_GITHUB_WEBHOOK_SECRET_VERSION")), 25000);
            if (!"RSA".equals(material.signingKey().getAlgorithm())) throw new IllegalStateException();
            var webhook = material.webhookSecret();
            try { if (webhook.length == 0) throw new IllegalStateException(); }
            finally { Arrays.fill(webhook, (byte) 0); }
            System.out.println("Exact-version App material read and validation passed");
        } catch (Exception failure) {
            System.err.println("Key Vault check unavailable; inspect context and permissions privately");
            System.exit(1);
        }
    }
}
```

From Ingestion's root, execute with Java 25:

```bash
java --class-path "target/classes:$(cat /tmp/ingestion-kv-classpath)" /tmp/KeyVaultReadCheck.java
```

This one-shot test uses explicit CLI authentication and the real material adapter;
it does not contact GitHub, serve HTTP, write Key Vault or activate custody. Avoid
SDK debug logging/heap dumps and keep the terminal private. It does not fix the
current application wiring: apply the [maintainer handoff](key-vault-integration.md#ingestion-maintainer-handoff)
before expecting the normal WSL application to authenticate this way.

An authorized negative read of a deliberately nonexistent version must fail without
payload/reference disclosure. Use effective-role inspection to verify no machine
set/delete/purge grant; a live negative write test could actually modify Azure if
the permissions are wrong, so requires separate authorization and is excluded from
this read-only procedure. Test denied and timeout behavior with mocks first.

## 7. Human custody, recovery and future ACA gates

Do not seed user tokens/verifiers manually. The trusted Ingestion executor owns
generation/attempt catalogs, writes complete envelopes once, validates the exact
acknowledgement and activates metadata with the accepted fences. Lost write
responses remain uncertain: no retry, `latest` search or expired-pair fallback.
PKCE expiry/single-use and provider token expirations are application checks;
Key Vault expiry does not prevent reading the value.

Before enabling human custody, assign operators and review concrete cleanup/
revocation/backup/retention rules, terminal reconciliation and restore gates. Runtime
get/set has no cleanup permission. A separate authorized custodian handles deletion
and recovery only after proving no live/late write or newer generation can be
affected. Deletion targets the secret object/all versions, not one old version;
soft delete/purge protection preserves recoverable material. Neither disconnect
nor a successful cleanup RPC proves physical erasure. Restored metadata never
reactivates credentials automatically. These unresolved operating inputs block
human activation, not local Terraform validation or the machine read pilot.

For future ACA: use its system-assigned principal ID in the approved maps, preserve
MI-only credential selection and qualified clients, and test from the actual app
subnet with its service endpoint/ACL. Do not inject personal CLI credentials or
export raw secret values into ACA configuration. Record propagation, successful
exact reads and blocked cross-vault writes separately; mocked tests do not prove
these outcomes. Future subscription/tenant choices require new inputs/grants and
their own promotion/deployment approval, never state copying by inference.
