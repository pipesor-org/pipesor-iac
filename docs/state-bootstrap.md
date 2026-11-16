# Terraform state bootstrap

## Scope and choices

`bootstrap/dev`, `bootstrap/qa`, `bootstrap/preprod` and `bootstrap/prod` are
independent roots. Each defines a dedicated `rg-pipesor-state-<environment>` group,
one Standard StorageV2 account and one private `tfstate-<environment>` container.
Workload groups and their existing roots remain separate. Account names are
explicit inputs because they are globally unique; names are never reservations.
Choose distinct names and identities for all four environments when commissioned.

[ADR 005](adr-005-academic-mvp-scope-and-cost-governance.md) selects only
`bootstrap/dev` for the MVP; do not provision the other environment stores.
The unused `bootstrap/admin` and Terraform `subscription-controls` roots have been
retired from source after the intended target inventory review; see ADR 005's
retirement addendum. The state-store module accepts only the four workload
environments. No Azure resource or state is deleted, migrated or reassigned. Any
historical external state discovered later requires its own reviewed ownership and
recovery decision using the historical source revision, not a recreated admin
boundary in DEV state.

[ADR 004](adr-004-mvp-state-and-deployment.md) otherwise retains the custody and
readiness gates.
All provisioning waits for implemented, locally integrated and validated services
and explicit target/action authorization. WSL Azure CLI is acceptable for Jhon's
bootstrap/preparation; Actions OIDC on the proposed dedicated Debian VirtualBox
runner is the target for later MVP workload execution. Jhon reviews/authorizes dev
plans procedurally within Ramiro's initial access/scope boundaries; there is no
independent GitHub Free deployment gate or per-run credential release. Activation
still requires application readiness, access and verified runner/network isolation.

The requested operator access is a public endpoint restricted to approved IPs.
The firewall defaults to Deny with no trusted-service bypass. Anonymous blob access,
shared-key authentication and local users are disabled; HTTPS and TLS 1.2 are
required. Explicit principal object IDs receive Storage Blob Data Contributor at
the environment container only. No identity, OIDC federation or workload permissions
are created. The bootstrap operator separately needs resource creation and role
assignment permissions; workload state users need neither management privilege.

Blob versioning and blob/container soft deletion protect previous state versions
and deleted data. The DEV MVP example explicitly selects LRS and 30-day
blob/container soft deletion. Reusable modules still require explicit values;
production redundancy remains deferred. These choices are independent of the
application's 365-day evidence policy. Soft-delete days do not expire old blob
versions. No lifecycle cleanup rule is introduced; accumulated versions can incur
cost and require later reviewed maintenance.

## Inputs still required

The DEV example includes the owner-supplied temporary subscription and tenant
from ADR 004 plus the agreed LRS/30-day choices. They remain nondeployable examples,
not default inputs or evidence of Jhon's access. Other environments retain generic
placeholders. Before creating any ignored local variable file, review:

- Active target context, pending region and globally available account names.
- Actual offer/region support and complete costs for DEV workload and its state store; no admin store is required.
- Pending Entra principal object IDs and exact approved role scopes; institutional
  email ownership is not an access grant or a principal identifier.
- Pending approved public egress IPs/ranges and the execution network. Jhon's WSL
  preparation path does not establish a supported Actions runner path.
- Custody paths, verified age public recipients/private-key recovery and restore
  procedure. Independent encrypted backup retention is now an initial 90 days;
  the backend's separate 30-day soft deletion remains unchanged.

Before commissioning a future environment, review its configuration against the existing ones. Subscription IDs remain explicit per root; distinct subscriptions can share an Entra tenant. Input validation within one root cannot
prove that a nonproduction principal has not also been granted production access.
Subscription/RG Owners and other privileged control-plane operators remain able to
change storage/RBAC configuration; container RBAC does not constrain those admins.

The initial input contract accepts individual IPv4 addresses and canonical /24–/30
ranges. Broader approved egress blocks require a review and extension of validation
and tests; this is a deliberate local restriction, not an Azure limitation. Common
private, CGNAT, loopback and link-local forms are rejected. This is not an exhaustive
IANA routability check: operators must verify the actual approved public egress.
Use bare individual IPs instead of /31 or /32 CIDRs, which Azure does not support.

IP allowlisting protects the storage data plane. It is not a restriction on ARM
management calls. Azure same-region service traffic cannot be admitted using its
public outbound IP in the same way as an internet operator. Do not widen the
firewall for a private runner or same-region workload: agree its supported network
path separately. VPNs, private endpoints, private DNS and virtual networks are
outside this increment. Terraform backend access must later be tested from the
actual approved execution network; successful ARM provisioning is insufficient.

## Bootstrap state custody and authorization

These roots explicitly use the local backend because the store does not exist yet.
Jhon is the primary custodian/operator; Ramiro is backup custodian and subscription
owner/initial access authorizer, not the routine executor. Before real initialization,
choose a protected state path outside the checkout on encrypted storage with
restricted file permissions. Maintain encrypted backups in Jhon's OneDrive Personal
and independent external storage. Encrypt before upload/copy; keep decryption
material separate. Use age encryption to both verified public recipients for
independent Jhon/Ramiro recovery and retain encrypted backups for an initial 90 days;
verify both custodians' decryption and integrity checks. Retain local backup state too. Never put bootstrap state, saved plans,
backend metadata or credentials in Git. An unbacked-up laptop or temporary runner
is insufficient custody.

After each approved apply, back up the corresponding current state independently
and record non-sensitive verification evidence. Target recovery is 24–48 hours;
it remains untested until an explicitly authorized restore drill. Database recovery
is separate and multiregional recovery is deferred. The existing private repository
holds non-sensitive approvals/digests and backup confirmation, never state, saved
plans, decryption material or sensitive plan/log output.

The bootstrap state must remain outside the workload state it manages. Moving it
to an independently established administrative backend is a separate authorized
migration; do not make this store the sole custodian of its own bootstrap state.
No automatic migration or cloud operation is part of local checks or CI.

For actual deployment, confirm the target/environment/identity and data path, prepare
a fresh plan, review it and obtain explicit human authorization for that target and
apply. Provision/register the required Azure resource providers separately if
necessary; registration is disabled here. Verify the configured network rules,
Entra-only access, role scopes and recovery behavior against Azure before use.
A later authorized backend operation uses this root's nonsecret `backend` output
for the corresponding workload root, with tenant/identity
supplied by the approved execution environment. Keep `use_azuread_auth = true`; never add storage keys.

The azurerm backend uses Blob leases for state locking. This implementation does
not test real leases, access propagation or restoration. Recovery of a prior blob
version must reconcile actual Azure resources and Terraform lineage/serial; copying
an old state version is not an automatic rollback. Deleting the account/group can
remove all versions and soft-deleted data. Recovery features do not prevent a
privileged account deletion; deletion controls require an operational decision.

## Resource-provider preparation

AzAPI **2.9.0** keeps `skip_provider_registration = true` and preflight disabled.
`Microsoft.Storage` must be registered in the selected subscription before storage
bootstrap. Registration changes the subscription and is a separately authorized
preparation operation, not a Terraform resource or another state/root.

During a later approved read-only readiness check, use an authenticated context
with no resource-write permissions and compare its tenant/subscription to the
reviewed DEV inputs. These commands are documentation only and do not register anything:

```sh
az account show --subscription "$SUBSCRIPTION_ID" --query '{subscription:id,tenant:tenantId,state:state}'
az provider show --subscription "$SUBSCRIPTION_ID" --namespace Microsoft.Storage --query '{namespace:namespace,state:registrationState}'
```

Require the intended tenant/subscription, an enabled subscription and registration
state `Registered`. If absent, inaccessible or still registering, stop bootstrap.
Obtain explicit human authorization naming the subscription and registration action
before a privileged operator performs registration outside Terraform. Re-run the
read-only check afterwards and record non-sensitive evidence of `Registered`;
registration alone does not establish storage eligibility, RBAC or backend access.
Other selected workload providers need the same preparation review before real use.
Never enable implicit registration to bypass this boundary.

Sources: [AzAPI 2.9.0 provider settings](https://github.com/Azure/terraform-provider-azapi/blob/v2.9.0/docs/index.md),
[Azure resource-provider registration](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types),
[Azure CLI provider show](https://learn.microsoft.com/en-us/cli/azure/provider#az-provider-show).

## Local verification and test boundaries

Run the existing formatting checks from the repository root. For
`modules/state-store` and each `bootstrap/<environment>` directory, use:

```sh
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
terraform test -filter=tests/contract.tftest.hcl
```

Run checks without Azure write credentials. All cloud providers are mocked and all
native test runs explicitly plan. Tests examine effective planned resource bodies
for authentication, transport, firewall, recovery and private containers, and
resource-backed grant outputs for role/principal scope. Synthetic computed IDs
bridge provider-only values; no security body values are supplied by mocks.
Negative cases reject malformed/insecure inputs; caller tests guard environment
identity/backend wiring. The DEV MVP module contract also checks LRS/30-day recovery,
private containers and Entra-only access; caller assertions retain container-scoped grants.
They establish Terraform contracts, not Azure API acceptance, network reachability, authorization or successful recovery.

## Dependencies and references

The composition retains Terraform 1.17.1, AzAPI 2.9.0 and naming AVM 0.3.0.
[Storage AVM 0.8.0](https://github.com/Azure/terraform-azurerm-avm-res-storage-storageaccount/tree/v0.8.0)
supports AzAPI 2.9 and supplies the account and its blob-service/container submodules.
The composition owns each object exactly once; the account module's automatic
blob-service and container children are disabled. Public child modules expose the
planned resource contracts directly. AVM telemetry is disabled throughout.
Later storage AVM versions requiring AzAPI 2.11 are not adopted by this increment.
Provider lock files retain the selected dependencies, including the inactive
transitive Time provider used by optional AVM table-service functionality.

See HashiCorp's [Azure backend](https://developer.hashicorp.com/terraform/language/backend/azurerm),
Microsoft's [network restrictions](https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security-limitations),
[redundancy choices](https://learn.microsoft.com/en-us/azure/storage/common/storage-redundancy),
[blob versioning](https://learn.microsoft.com/en-us/azure/storage/blobs/versioning-overview)
and [data protection](https://learn.microsoft.com/en-us/azure/storage/blobs/data-protection-overview).
