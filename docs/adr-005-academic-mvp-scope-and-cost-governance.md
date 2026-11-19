# ADR 005: Academic MVP scope and cost governance

Status: Accepted for repository reconciliation, 2026-11-16. This records the
project owner's current task direction; it authorizes no Azure or state operation.
It supersedes ADR 004's administrative-state prerequisite, retained USD 300 budget,
mandatory future tenant transition and session-specific workstream restrictions.
ADR 001 promotion and ADR 004 readiness, security, custody and authorization gates
otherwise remain in force.

## DEV foundation readiness addendum

The project owner now directs that DEV infrastructure foundations may be
provisioned before application services are integrated locally. This supersedes
the application-readiness prerequisite for infrastructure in ADR 004 and the
historical text below. It does not authorize Azure writes or state operations.
Confirm the target, required permissions, provider registrations, network,
cost and credit evidence, state custody and recovery; review a fresh plan and
obtain explicit human authorization for each target and action before execution.
Application deployment and activation remain a separate milestone requiring
implemented, locally integrated and validated services and their delivery,
identity and security contracts. Preserve DEV-only scope, separate state roots,
ADR 001 promotion, recovery and approval requirements. No administrative root
or new approval mechanism is introduced.

## DEV bootstrap governance addendum (2026-11-19)

The project owner supersedes the dual-custodian prerequisite for academic DEV
and authorizes Jhon as its Terraform operator and state custodian. The existing
DEV Owner session may generate the initial local-state bootstrap plan. Retain
BitLocker-protected local custody, one independently stored encrypted and tested
backup, immutable source and saved-plan SHA-256 review, and separate explicit
authorization for apply, RBAC changes and Azure resource creation.
See [ADR 004](adr-004-mvp-state-and-deployment.md#owner-directed-dev-custody-update-2026-11-19).
This change is limited to DEV.

## Retirement addendum (2026-11-16)

The project owner subsequently authorized read-only inventory of the intended
Students target and source retirement if no active objects were found. The
review confirmed the intended subscription/tenant context and no active Pipesor
resources, storage accounts or subscription budgets there. This satisfies the
source-retirement condition below; it does not prove that these roots were never
deployed elsewhere or inspect historical external Terraform state. Command/results
evidence belongs to the retirement PR rather than permanent operating instructions.

Retire `bootstrap/admin` and Terraform `subscription-controls` from source, including
their examples, locks, CI entries and obsolete tests. Remove the admin-only state-store
scope/backend branch; preserve the four workload scopes and their existing state
keys, security and recovery contracts. No Azure object, state or identity is deleted,
migrated or changed, and no replacement resource/root is created. If external state
is later discovered, use the historical source revision for a separately reviewed
recovery/ownership decision. Source removal is not authorization to destroy anything.

This addendum supersedes the initial deferral, retained-admin-contract and optional
Terraform-budget-input instructions in the historical decision text below. Current
cost governance uses native offer-supported views; future independent-subscription
controls require an actual need and explicit approval, not placeholder infrastructure.
All DEV-only deployment, future environment isolation, state custody and authorization
requirements remain in force.

## Initial reconciliation decision (preserved history)

The following sections record the initial reconciliation before the target inventory
and source-retirement decision. Read their deferral/retention statements with the
superseding retirement addendum above.

## Evidence and root cause

Pipesor is a two-engineer academic prototype with approximately seven months of
expected academic life remaining at this decision. Operational simplicity,
reproducibility, security and verified affordability take priority over imitating
an enterprise landing zone.

| Provenance | What it establishes | Current disposition |
| --- | --- | --- |
| `abd0551` / PR #5 | Separate environment bootstrap and secure state-store contracts preceded cost controls. | Retain DEV state storage and future environment contracts. |
| `5b538a3` / PR #11 | Accepted exclusion of workload Blob Storage; GitHub Actions logs and PostgreSQL sanitized evidence remain the workload direction. | Retain. Terraform state storage is a separate concern. |
| `0c00a46` / PR #17 | Recorded owner approval of a dedicated USD-billed subscription and one optional hardcoded 300 monthly budget in separate state. | Historical recorded approval conditional on the earlier assumptions; not evidence of the current offer, currency, credit or spending authority. |
| `6666fb8` / PR #18, ADR 004 | Selected temporary Azure for Students/UPC hosting and DEV only, yet retained the 300 budget and added `bootstrap/admin` solely to host its state. | Retain readiness/custody controls; supersede the admin dependency and budget assumption. |
| Current owner task | One temporary Students subscription/tenant, DEV only; future isolated environments and independent subscriptions; justified minimal governance. | Current accepted baseline. |

The implementation made the subscription budget a fixed contract, then treated its
backend as a necessary MVP prerequisite. ADR 004 corrected funding and environment
scope without removing that dependency. Prior PR bodies repeat the approval claim;
no independent original owner directive was recovered from those records. Historical
implementation and its test assertions do not make superseded assumptions permanent.

Repository records report no deployments and no local/committed state was found
during reconciliation. These are limited evidence: no Azure or remote-state inventory
has established whether any root has ever been applied elsewhere. Consequently this
decision removes administrative infrastructure from active scope, not from Azure or
Terraform state. It neither authorizes deletion nor asserts that deletion is safe.

## Environment and state decision

- Current target: one Microsoft Entra tenant (UPC) and Ramiro's temporary Azure for
  Students subscription, with only `dev` selected for eventual deployment after
  application readiness and explicit target/action authorization.
- Preserve `dev`, `qa`, `preprod`, `prod` roots, variables, provider locks, backend
  keys/containers and sequential immutable-SHA promotion with fresh plans and human
  approvals. QA, preprod, prod and their state stores remain unprovisioned.
- Each root keeps an explicit subscription input. Future environments can use
  independent subscriptions in the same tenant without shared-module redesign.
  Separate tenants require a future governance decision, not an assumed rebuild.
- Retain `bootstrap/dev` and `modules/state-store`: one separate state group,
  account and private container, Entra backend authentication, container-scoped RBAC,
  leases, LRS, versioning and 30-day blob/container soft deletion. Initial bootstrap
  state remains in protected local custody with independent encrypted backups under
  ADR 004; no self-hosted sole copy or workload Blob dependency is introduced.
- Defer `bootstrap/admin` and `subscription-controls` outside the MVP. The only
  current admin responsibility is state for the deferred budget, so it has no
  independent active operational need. Preserve root/resource addresses, backend
  contracts and recovery tests until an owner-approved inventory establishes state
  and resource ownership. Existing deployments, if discovered, require their own
  reviewed retirement or continued-operation decision. Do not null existing inputs,
  move administrative objects into DEV state or create replacement state boundaries.

DEV state storage is appropriately bounded: its group separates lifecycle from the
workload, the account controls firewall/recovery, the private container scopes access,
and grants support Entra authentication. No additional state root, replication tier,
policy engine or enterprise landing-zone structure is justified for this MVP.
`Microsoft.Storage` registration remains separately authorized subscription preparation;
follow the [read-only verification procedure](state-bootstrap.md#resource-provider-preparation)
and retain AzAPI 2.9.0 `skip_provider_registration = true`.

## Financial decision

Use the actual offer-supported native balance/usage views and a complete DEV cost
estimate first. Verify offer ID, billing currency, available credit/expiry, relevant
quotas/SKUs and cost-feature support; no numeric credit or spending threshold follows
from the label "Azure for Students". [Cost governance](subscription-controls.md)
defines DEV group attribution and tagging/reporting limits. An automated Terraform
budget is not a current MVP prerequisite. A supported portal budget may be selected
later after explicit amount/recipient/response decisions; budget alerts never impose
a hard spending limit.

The retained Terraform control defaults to null. Any later opt-in requires an explicit
positive finite `budget.amount` in the verified billing currency, plus reviewed dates,
recipients, scope, backend and authorization. Existing non-null inputs must add that
amount before validation; no value is inferred from the historical 300. Resource
addresses and notification percentages remain compatible. Do not apply null to an
existing budget merely to follow the deferred-scope example: that proposes deletion.
Future environments will govern their own funded subscriptions independently; this
legacy root does not mandate one global budget or permanent subscription sharing.

## Deferred decisions and external consistency

Before provisioning: obtain application-readiness evidence; verify actual Azure
access, offer/credit/expiry/currency and a complete DEV estimate; agree cost-review
ownership/cadence; confirm regions, names, network, principals and provider registration;
verify state custody, independent recovery and approved runner access; obtain each
required target/action authorization. Workflow activation is a separate decision.

Before future environments: obtain funding, subscriptions, access/approval design and
explicit provisioning authorization; retain ADR 001 promotion prerequisites. Decide
on tenants only when governance requirements justify it. Reassess automated budgets
and safe administrative-root retirement using actual operational evidence.

`pipesor-docs` may still describe workload Blob, enterprise capacity, four simultaneous
environments or earlier funding/governance assumptions; its consumed revision and
unresolved supplements are recorded in [architecture consumption](architecture-consumption.md).
Those contracts, workload log/evidence retention, runtime service delivery and identity
records require their owners' later reconciliation. No neighboring repository changes
or unverified upstream alignment are implied by this ADR.
