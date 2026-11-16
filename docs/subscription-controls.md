# Cost visibility and deferred subscription controls

## Current academic MVP

[ADR 005](adr-005-academic-mvp-scope-and-cost-governance.md) selects DEV only in
one temporary institutional Azure for Students subscription and one Entra tenant.
The USD 300 monthly budget was recorded under a dedicated USD-billed subscription
assumption in `0c00a46` / PR #17. That assumption is superseded; neither the amount
nor billing currency is an approved current operational threshold.

Before provisioning, the owner must verify the actual offer ID, billing currency,
available credit and expiry, eligible services/regions/quotas and a complete DEV
estimate including state storage and usage. Do not infer entitlements or current
balance from public offer descriptions. Use the offer-supported native Education
Hub or Sponsorship balance/usage views available to the account, and record who
reviews usage, at what cadence and how unexpected consumption is handled.

Microsoft's [Cost Management supported offers](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/understand-cost-mgt-data)
currently lists Azure for Students offers as unsupported, while the
[Education Hub cost guidance](https://learn.microsoft.com/en-us/azure/education-hub/navigate-costs)
describes Cost Management views and budgets. Verify actual portal/offer support
and access rather than promising either feature. Where available, native subscription
Cost Analysis provides the overall reported view; no Terraform-managed budget or
administrative backend is needed just to view usage. If supported and subsequently
justified, a portal budget can provide email alerts after amount, dates, recipients
and response ownership are explicitly approved. Never manage the same budget through
both the portal and Terraform without a separately authorized ownership transition.

Budgets **do not cap spending or stop services**. Reporting/alerts can be delayed,
forecast data may be absent, and offer spending-limit/credit exhaustion behavior is
separate from budget notifications. Verify the actual offer's behavior without
assuming it covers every charge or authorizing an upgrade.

## DEV attribution and future environments

Use `rg-pipesor-dev` for workload attribution and `rg-pipesor-state-dev` for the
separate state cost. Include the ACA-created infrastructure group and any
subscription-level/unallocated charges when available; a workload-RG filter alone
is incomplete. Compare those slices with overall subscription usage, which may
include unrelated institutional activity. DEV is the only current project consumer,
not a claim that the subscription contains no other costs.

Existing Service Bus, PostgreSQL server, Application Insights, Foundry account/project
and Static Web Apps definitions carry `environment` tags. The resource-group,
container-platform and state-store compositions do not currently implement universal
tagging. Where tags are supported, preserve consistent environment values; tags do
not automatically inherit from resource groups, cover every meter or retroactively
attribute earlier costs. Do not rely on them as an access boundary or claim complete
tag coverage. [Microsoft's grouping/filtering guidance](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/group-filter)
explains resource-group and tag views; [resource tagging rules](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tag-resources)
confirm that group/subscription tags are not inherited. Existing group boundaries suffice for initial
DEV attribution; no tag-policy engine or additional Terraform resources are required.

QA, preprod and prod remain defined and unprovisioned. When separately funded and
authorized, each may use an independent subscription in the same tenant, with its
own native usage/credit visibility, approved budget policy and accountable owner.
This requires no shared-module redesign, permanent global budget or separate tenant.
Do not duplicate a whole-project spending allowance across environment roots.

## Retained Terraform capability, outside the MVP

`subscription-controls/` retains its own partial Azure backend and one optional
`Microsoft.Consumption/budgets@2024-08-01` resource with Terraform 1.17.1 / AzAPI
2.9.0. `bootstrap/admin` exists only to host that state and is also deferred.
Neither is a DEV prerequisite. No administrative resource is moved into workload
state, and no replacement module/root is introduced. Current deployment/state
inventory is unverified; preserve addresses and custody until an owner-approved
inventory and decision establish whether these roots can be retired safely.

`budget = null` remains the default. A later enabled budget requires explicit
`amount`, `name`, `start_date`, `end_date` and 1–5 approved `contact_emails`.
Amount must be positive and finite in the actual subscription billing currency;
the API does not select currency. There is no default monetary amount. For any
existing non-null input, add a newly reviewed `amount` before validation. Changing
an existing amount requires a reviewed plan and authorization; this compatibility
step does not authorize an apply or reinstate the old 300 threshold.

Dates are explicit YYYY-MM-DD, sent as UTC midnight. Start must be a month's first
day on/after 2017-06-01 and end later. Azure's deployment-time start window and offer
support still require verification. The retained unfiltered calendar-month contract
uses email-only Actual 50/80/100 and Forecasted 100 percent notifications with
`GreaterThanOrEqualTo`; it creates no action groups, automation, filters or grants.
Recipients must be durable approved operator addresses with verified delivery and
response ownership. Outputs expose only budget identity.

Do not set an existing budget to null as a pause: that proposes deletion and loss
of alerts. Renaming or changing subscription can replace it; neither reduces
workload spending. Never create duplicate management of the same named budget.
A later activation requires a justified responsibility, separate backend/container
RBAC and custody, verified tenant/subscription/offer/currency, reviewed inputs/plan
and explicit target/action authorization. All state operations retain their gates.
No current cloud deployment automation or Azure credentials are added to CI.

## Validation and references

Backend-disabled initialization, validation and filtered fully mocked plan tests
check default absence, explicit amount forwarding/rejection, subscription scope,
notification policy, dates/emails and safe outputs. Independent caller assertions
reject altered amounts, filters and automation. Retained admin tests protect recovery
contracts; testing them does not commission the root. Local checks do not prove
actual feature support, reporting latency, permissions, backend access or mail delivery.

- [Budget API 2024-08-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.consumption/2024-08-01/budgets)
- [Budget behavior and prerequisites](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets)
- [AzAPI 2.9.0 resource schema](https://github.com/Azure/terraform-provider-azapi/blob/v2.9.0/docs/resources/resource.md)
- [ADR 001](adr-001-branching-and-promotion.md) and [state bootstrap](state-bootstrap.md)
