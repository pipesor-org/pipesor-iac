# Native cost visibility and governance

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

## Source retirement and future decisions

The unused Terraform `subscription-controls/` and `bootstrap/admin` roots are
retired from source after the intended target inventory review, under
[ADR 005's retirement addendum](adr-005-academic-mvp-scope-and-cost-governance.md#retirement-addendum-2026-11-16).
No Azure resource or state is deleted or migrated, and no replacement administrative
state, budget module or workload-state budget is introduced. The four workload
roots and their independent remote-state contracts remain intact.

Future automated cost controls require evidence of operational need, actual offer
support, explicit per-environment scope/subscription, approved currency/amount,
notification ownership and an appropriate lifecycle/access boundary. Native views
and supported portal budgets remain the initial option. Do not restore unused
Terraform roots merely to preserve hypothetical flexibility. If historical external
state is discovered later, reconcile ownership and recovery against its historical
source revision before any separately authorized state operation.

## References

- [Budget behavior and prerequisites](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets)
- [ADR 001](adr-001-branching-and-promotion.md) and [state bootstrap](state-bootstrap.md)
