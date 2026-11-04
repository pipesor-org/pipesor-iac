# Terraform state bootstrap

## Scope and choices

`bootstrap/dev`, `bootstrap/qa`, `bootstrap/preprod` and `bootstrap/prod` are
independent roots. Each defines a dedicated `rg-pipesor-state-<environment>` group,
one Standard StorageV2 account and one private `tfstate-<environment>` container.
Workload groups and their existing roots remain separate. Account names are
explicit inputs because they are globally unique; names are never reservations.
Choose distinct names and identities for all four environments.

The requested operator access is a public endpoint restricted to approved IPs.
The firewall defaults to Deny with no trusted-service bypass. Anonymous blob access,
shared-key authentication and local users are disabled; HTTPS and TLS 1.2 are
required. Explicit principal object IDs receive Storage Blob Data Contributor at
the environment container only. No identity, OIDC federation or workload permissions
are created. The bootstrap operator separately needs resource creation and role
assignment permissions; workload state users need neither management privilege.

Blob versioning and blob/container soft deletion protect previous state versions
and deleted data. Recovery days and replication are required reviewed inputs.
They are not derived from the application's 365-day retention policy. No lifecycle
rule deletes previous state versions automatically. Version retention can incur
storage costs and requires a later reviewed maintenance policy.

## Inputs still required

No real deployment values are committed. Copy the root's `terraform.tfvars.example`
to a local ignored variable file only after reviewing:

- Target tenant/subscription, region and globally available storage-account name.
- Supported regional replication and its cost/recovery tradeoff. LRS is the least
  redundant option; ZRS distributes across availability zones where supported;
  geo-replication adds regional recovery considerations. No default is selected.
- An explicit 1–365 day soft-delete recovery window, separate from workload policy.
- Environment-specific Entra principal object IDs, including operator access where
  needed, and approved public egress IP addresses/ranges.

Review all four configurations together. Input validation within one root cannot
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
Before any real initialization/plan/apply, the authorized operator must choose a
protected state path outside the checkout on encrypted storage with restricted file
permissions, secure backup and a named custodian. Set restrictive permissions before
initialization and retain the local backup state too. Never put bootstrap state,
plans, backend metadata or credentials in Git or PR artifacts. Do not rely on an
unbacked-up laptop directory or temporary CI runner for long-term custody.

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
for the corresponding workload root, with tenant/identity supplied by the approved
execution environment. Keep `use_azuread_auth = true`; never add storage keys.

The azurerm backend uses Blob leases for state locking. This implementation does
not test real leases, access propagation or restoration. Recovery of a prior blob
version must reconcile actual Azure resources and Terraform lineage/serial; copying
an old state version is not an automatic rollback. Deleting the account/group can
remove all versions and soft-deleted data. Recovery features do not prevent a
privileged account deletion; deletion controls require an operational decision.

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
identity and backend wiring. They establish Terraform contracts, not Azure API
acceptance, network reachability, authorization or successful recovery.

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
