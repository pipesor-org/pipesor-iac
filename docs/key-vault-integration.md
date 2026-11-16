# Ingestion Key Vault integration

The Key Vault task authorizes this local infrastructure design, implementation,
tests and handoff. Provisioning, permissions, secrets, provider registration,
state access/mutation and live tests with side effects require separate target/action
authorization. Only DEV is selected; future environments retain isolated roots,
subscriptions and states. [ADR 005's retirement addendum](adr-005-academic-mvp-scope-and-cost-governance.md#retirement-addendum-2026-11-16)
governs administrative source retirement, rather than the original PR #20.

## Sources and current behavior

The following clean checkouts matched remote `main` when inspected. Revisions
identify the evidence; cross-repository links follow `main`.

| Source | Inspected revision | Applicable evidence |
| --- | --- | --- |
| IaC | `65f2a790422e63acee61810a91b67ac4524c8c44` | ADR 001/004/005, capability composition, four explicit subscription inputs, separate state bootstrap, system-assigned identity with each future Container App. |
| [Ingestion](https://github.com/pipesor-org/pipesor-ingestion-normalization-service/blob/main/docs/deployment-contract.md) | `1066785908ff4a7f7f20b448df7154138ab093e0` | Accepted machine Secrets choice (2026-11-10), exact App references, pair/PKCE protocol, runtime/admission/cleanup gates. |
| [Docs](https://github.com/pipesor-org/pipesor-docs/blob/main/model/domain_decisions.md) | `174e7993984bed61e7d59b6139da204c1f6025aa` | ADR-019/020, DD-020 ownership, generation/attempt-bound exact references, uncertain refresh and restore guards; backend conventions. |

Ingestion already implements:

- `GitHubMachineConfiguration`: opt-in machine beans and validated settings;
  `githubAppSecretClient` calls the Managed Identity-only factory.
- `KeyVaultAppMaterial`: exact-version reads of two distinct Secrets, validates
  returned vault/name/version, parses GitHub RSA PKCS#1/PKCS#8, and preserves webhook
  UTF-8 bytes. Signing remains in-process; installation tokens stay separate from
  human OAuth credentials.
- `KeyVaultCredentialCustody`: private owner-bound pair/PKCE get/set adapter,
  strict JSON envelopes, size limits, exact-version acknowledgements, no I/O inside
  SQL transactions, zero SecretClient retries, fixed private failures and no HTTP
  logging. Its factory constructs `ManagedIdentityCredential` explicitly.

There is no Azure CLI credential composition, deployed vault or service identity
in this baseline. Human custody is not wired into an active connection/cleanup
executor. A successful vault read cannot supply missing browser binding, admission,
restored-state reconciliation or current GitHub authorization.

Read the later Ingestion contract sections with their dated predecessors: the
early table saying secret storage is unspecified and historical ADR-005's
deferral do not override the later explicit machine-material approval and DD-020
Secrets protocol. Conversely, those approvals did not authorize Azure operations.
Historical documentation snapshots describing pending integration are not current
remote status. This change does not update neighboring repositories or close their
remaining operational decisions.

## Resource and ownership decision

Each environment's nullable `key_vault` creates an environment-owned capability in
its existing workload state. Null creates no vault or grant. No backend, bootstrap,
administrative root, standalone identity or provider version changes are needed.
Names, region, tenant, network ranges and principal object IDs are explicit inputs;
test fixtures and example values are not deployment selections.

The capability creates a Standard App-material vault and, only when `custody` is
supplied, a separate Standard credential-custody vault. Both belong to the existing
environment resource group. Their separate authorization boundary is useful even
with the same future service identity: a token writer cannot replace the machine
signing key or webhook secret. There is no extra state boundary or separate PKCE
vault. Optional custody avoids provisioning unused human-flow infrastructure for
the initial machine pilot.

| Material | Storage and access | Lifecycle |
| --- | --- | --- |
| GitHub App private RSA key | App-material vault Secret; approved runtime/developer gets vault-scoped built-in **Key Vault Secrets User**. | Operator initializes/rotates; exact version pinned. No runtime set/delete. |
| Webhook HMAC secret | Separate object in App-material vault; same reader boundary. | Exact bytes/version; coordinate GitHub configuration and rollout. |
| Human access/refresh pair | Optional custody vault; one object per generation, atomic pair per version. | Trusted Ingestion adapter writes and validates acknowledgement before guarded metadata activation. |
| PKCE verifier | Optional custody vault; distinct attempt-owned object/reference. | Single-use/expiry enforced by application; separately authorized cleanup. |

Custody principals receive a custom role with only
`Microsoft.KeyVault/vaults/secrets/getSecret/action` and
`Microsoft.KeyVault/vaults/secrets/setSecret/action`. Its definition uses Azure's
canonical subscription-level role-definition ID, with `assignableScopes` limited
to the environment resource group and assignment only on the custody vault. It grants
no list, metadata read, delete, recovery, backup, purge, key operations or RBAC
administration. Dynamic generation/attempt object creation prevents provisioning
all per-object grants ahead of time. Built-in Secrets Officer would grant broader
secret management; shared-vault set access would allow overwriting App material.
The SDK adapters still enforce per-object ownership; vault RBAC alone does not
isolate individual application users.

The App reader role also permits secret metadata reads; no custom machine role is
needed for this bounded vault. Principal maps default empty. Supply Entra object
IDs, including a managed identity's **principal ID**, not its application/client
ID or an email. No identity is inferred from the current Terraform operator.
Creating a vault does not authorize that operator to read its Secrets.

All vaults enforce RBAC (empty legacy access policies), no deployment/disk/template
access, soft delete with 30-day recovery and purge protection. Thirty days is a
selected recovery window for this implementation, not a credential TTL or a
365-day evidence-retention policy. Purge protection cannot be disabled after
activation; vault deletion/name reuse and individual secret recovery must account
for the window. Changing a tenant/name/region can require replacement and careful
data recovery. Review the real plan before authorizing such changes.

Terraform manages **no secret objects, values, private keys, tokens, verifiers or
secret versions**, including data sources. Only vault identities, tenant, region
and URI are exported. Never add payloads through AzAPI bodies, Terraform variables,
`external` programs or provisioners. Sensitive Terraform attributes would still
persist in state. See the [operational runbook](key-vault-runbook.md).

## Provider/module alternatives

Use the existing AzAPI **2.9.0** with stable vault ARM API **2024-11-01** and
authorization API **2022-04-01**. This matches the existing direct-resource
capabilities and keeps every operation in the management plane. Narrow
`response_export_values` exposes the vault URI rather than secret data.

The [Key Vault AVM 0.13.1](https://github.com/Azure/terraform-azurerm-avm-res-keyvault-vault/blob/v0.13.1/terraform.tf)
requires AzAPI `~> 2.12`, AzureRM `>= 4.81, < 5`, additional providers and interfaces
0.9.0. The [older 0.10.2](https://github.com/Azure/terraform-azurerm-avm-res-keyvault-vault/blob/v0.10.2/terraform.tf)
supports AzAPI `~> 2.4` but adds AzureRM and other dependencies for a much wider
resource/data-plane surface. Neither gives this small, payload-free composition
enough benefit to justify changing locked dependencies. This is a scoped selection,
not a policy against AVM. Terraform MCP search/details and versioned official
sources were consulted; Context7's current documentation is not proof of exact
older-provider behavior.

References: [vault schema](https://learn.microsoft.com/en-us/azure/templates/microsoft.keyvault/2024-11-01/vaults),
[AzAPI 2.9.0](https://github.com/Azure/terraform-provider-azapi/blob/v2.9.0/docs/resources/resource.md),
[Key Vault RBAC](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide),
[built-in roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/security),
[soft delete](https://learn.microsoft.com/en-us/azure/key-vault/general/soft-delete-overview).

## Network and cost decision

Public HTTPS is enabled with firewall `Deny`, explicit approved public IPv4/CIDRs,
and trusted-services bypass `None`. WSL2 uses the public NAT/VPN egress address,
not its Linux/Windows private address. An address change requires reviewed input
and a separately authorized apply; do not open the firewall to fix connectivity.
IPv6 is unsupported by these IP rules. Allowing a network never grants data access.

When the existing container platform is enabled with Key Vault, the root enables
`Microsoft.KeyVault` on its ACA infrastructure subnet and passes only that subnet
to both vault ACLs. There is no missing-service-endpoint bypass, external subnet,
new VNet, NAT gateway, private endpoint or private DNS. Future apps need real
verification from this subnet; Managed Identity does not bypass the firewall.
The SDK still uses the public vault DNS/HTTPS endpoint. Service endpoints do not
make the public endpoint private.

Alternatives: unrestricted public access is unnecessary; a private endpoint plus
WSL VPN/private routing/DNS adds cost and operational dependencies absent from the
local requirement. Static ACA egress/NAT adds resources solely for firewall IPs.
If policy later requires private-only access, revise the network design and test
operator routing before disabling the public endpoint. A generic trusted-services
exception does not authorize arbitrary ACA application code.

Standard Secrets avoids Premium/HSM and remote-signing dependencies incompatible
with the current RSA supplier. Secret-operation billing applies to reads/writes;
separate Standard vaults do not add a per-vault fixed Secrets charge under the
public pricing model. Repeated RSA/webhook reads, token refreshes, verifier writes,
diagnostic ingestion and accumulating versions need an actual volume estimate.
No telemetry resource or full reference-bearing diagnostic stream is added here;
operators must decide restricted audit collection/access/retention before live
credential operations. Existing evidence-retention rules do not select this policy.

References: [network controls](https://learn.microsoft.com/en-us/azure/key-vault/general/network-security),
[service endpoints](https://learn.microsoft.com/en-us/azure/key-vault/general/overview-vnet-service-endpoints),
[pricing](https://azure.microsoft.com/en-us/pricing/details/key-vault/),
[service limits](https://learn.microsoft.com/en-us/azure/key-vault/general/service-limits).

## Ingestion maintainer handoff

These are required **next-repository changes**, not functionality implemented in
Ingestion by this PR. Preserve azure-identity **1.19.0**, keyvault-secrets **4.13.1**
and the existing validated transport settings unless a separate compatibility
change is needed. Azure CLI is installed/authenticated inside WSL under the same
Linux user that runs Java; Windows CLI login is not proof of a usable Linux cache.

1. Extract the current SecretClient builder's transport/log/retry configuration to
   accept an injected `TokenCredential`; retain its approved-vault validation,
   positive I/O budgets, zero retries and `HttpLogDetailLevel.NONE`. Keep the
   existing `managedIdentityClient` method compatible or update its callers/tests.
2. Select an explicit credential at the Spring configuration boundary:
   `managed-identity` defaults to `new ManagedIdentityCredentialBuilder().build()`;
   `azure-cli` uses `new AzureCliCredentialBuilder().tenantId(tenantId)`
   `.subscription(subscriptionId).processTimeout(timeout).build()` and is allowed
   only in an explicitly selected local profile. Reject unknown modes and local
   mode in ACA/deployed configuration. Do not use `DefaultAzureCredential` or
   catch a Managed Identity failure and try a developer credential. Missing MI
   must fail unavailable even when a developer is signed in.
3. Inject the App-material client by qualifier/name into `githubAppMaterial`.
   A future custody client must have a separate qualifier and vault URL; adding
   another unqualified `SecretClient` bean would make the present injection
   ambiguous. Supply the trusted immutable owner/object catalog to custody;
   Terraform does not create the catalog, object names or metadata records.
4. Retain machine settings/authority-file limits and all existing HTTP/database/
   capture/publication activation gates. Vault success alone must not enable a
   webhook, scheduler or human connection executor.

Use explicit YAML placeholders to avoid ambiguous Spring environment-name
conversion. The following additions are the proposed maintainer contract; actual
values stay in a protected operator configuration, not Git or Terraform state.

```yaml
ingestion:
  key-vault: # new configuration consumed by the credential selection above
    credential-mode: ${PIPESOR_KEY_VAULT_CREDENTIAL_MODE:managed-identity}
    tenant-id: ${PIPESOR_AZURE_TENANT_ID}
    subscription-id: ${PIPESOR_AZURE_SUBSCRIPTION_ID}
  github-machine: # existing settings
    vault-url: ${PIPESOR_GITHUB_APP_VAULT_URL}
    key-secret-name: ${PIPESOR_GITHUB_APP_KEY_SECRET_NAME}
    key-version: ${PIPESOR_GITHUB_APP_KEY_VERSION}
    webhook-secret-name: ${PIPESOR_GITHUB_WEBHOOK_SECRET_NAME}
    webhook-version: ${PIPESOR_GITHUB_WEBHOOK_SECRET_VERSION}
    max-secret-bytes: ${PIPESOR_KEY_VAULT_MAX_SECRET_BYTES}
    vault-timeout: ${PIPESOR_KEY_VAULT_TIMEOUT}
```

`github-machine.enabled` stays false until the complete existing machine handoff
is supplied, including App ID, file authority, numeric limits and scope. Exact
versions must be the actual acknowledgements of authorized initialization;
`latest`, URL authority supplied by a caller and names inferred from webhook
headers remain forbidden. No payload environment variables are needed.
For future private human composition, add a separately validated
`PIPESOR_GITHUB_CUSTODY_VAULT_URL` and timeout/size inputs at that composition
boundary; no current human feature flag or runtime catalog setting exists to set.

Credential builder methods above were checked against the locally installed
azure-identity 1.19.0 API. Its version-tagged public source was unavailable during
lookup; current [Microsoft Java API docs](https://learn.microsoft.com/en-us/java/api/com.azure.identity.azureclicredentialbuilder?view=azure-java-stable)
and official Context7 examples supplement that check. This is API inspection,
not a successful SDK authentication or application build.

Add isolated tests that inject fake credentials/SecretClients: local-only selection,
default/explicit MI, unknown mode rejection, no fallback after MI failure, correct
qualified vaults, exact references, wrong tenant/vault/object/version, denied and
missing Secrets, timeout and private diagnostics. Retain custody's uncertain-write
and no-retry tests; no automated test should require live Azure. Use the service
README's canonical `clean verify` command in its own authorized change.

For ACA, provision the app with its accepted system-assigned identity in a future
authorized app increment, pass the principal ID to the relevant grant maps, and
verify propagation and subnet access before activating the service. App replacement
changes its principal ID and requires a fresh grant. Do not introduce a user-assigned
identity to avoid this lifecycle. Package neither Azure CLI nor a developer cache
in the image. Key Vault SDK reads preserve the application's exact-reference
checks; native ACA secret references are unnecessary for this integration.

References: [local Java authentication](https://learn.microsoft.com/en-us/azure/developer/java/sdk/authentication/local-development-environment),
[ACA Managed Identity](https://learn.microsoft.com/en-us/azure/container-apps/managed-identity),
[Ingestion machine contract](https://github.com/pipesor-org/pipesor-ingestion-normalization-service/blob/main/docs/deployment-contract.md#machine-and-webhook-configuration-handoff).
