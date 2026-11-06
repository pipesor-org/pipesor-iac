# Subscription cost notifications

## Approved scope

Accepted 2026-11-06: the project owner confirmed a dedicated Pipesor subscription
with USD billing and approved one unfiltered calendar-month budget of **300 USD**.
Actual cost notifications fire at **50%, 80%, 100%** and a forecast notification at
**100%**, using `GreaterThanOrEqualTo`, email only. These are subscription-wide
controls, not four copies of the whole-solution budget in environment roots.
This approval permits local implementation, not Azure provisioning.

The [foundation cost projection](mvp-cost-projection.md) compares concurrent-stack
scenarios against this target. It does not change the approved amount or alerts.

`subscription-controls/` is the single owner and independent root/state for this
cross-environment control. It creates no resource group, regional service, action
group, automation, filters, role grants or workload resource. A direct AzAPI
resource is sufficient; no reusable wrapper is needed for a single subscription
contract. Terraform 1.17.1 and AzAPI 2.9.0 remain selected. The stable API is
`Microsoft.Consumption/budgets@2024-08-01` at `/subscriptions/<subscription_id>`.

## Inputs and behavior

Supply the dedicated `subscription_id`. `budget = null` is the default and creates
nothing; opting in requires an explicit `name`, `start_date`, `end_date` and 1-5
approved `contact_emails`. Dates use YYYY-MM-DD and are sent as UTC midnight. The
start must be the first day of a month, on/after 2017-06-01; end must be later.
Azure additionally restricts the deployment-time start window: the current monthly
period or up to twelve months ahead. Local date validation does not prove that
the chosen date will remain eligible by deployment time. No clock-based dates or
implicit ten-year expiry are selected. Review renewal before the explicit end date.

Use durable, operator-owned addresses and agree who investigates, verifies delivery
and handles absence/expiry of alerts. Email syntax checks cannot establish mailbox
ownership or delivery. Recipients are configuration held in protected state, not
secret values or exported outputs. Budget output contains only ID and name.
The resource API does not select currency: 300 uses the subscription billing
currency. Verify the confirmed USD currency, offer eligibility and billing scope
before a real plan; do not infer promotional credits or upgrade completion.

Cost reporting and evaluation are delayed; forecast data may be unavailable at
first. Budgets **do not cap spending or stop services**. The unfiltered scope
includes eligible reported subscription costs across all environments and bootstrap;
it is not a per-service cost allocation or an estimate of the complete MVP. Domain,
GitHub and other charges outside this Azure subscription are not included. Review
offer-specific treatment of credits, taxes and non-covered charges before relying
on the amount. No exact invoice equivalence is asserted.

Removing an enabled configuration proposes budget deletion and loss of its alerts;
renaming/changing subscription can replace it. Neither operation reduces workload
spending. Do not create the same named budget in another Terraform state.

## State custody and authorization

The root has a partial Azure backend and nondeployable examples. Establish and
authorize a distinct backend container and scoped Entra permissions for the
subscription-controls operator; a different key alone does not isolate access.
Backend custody/operator ownership remain deployment prerequisites. Reuse an
approved state account only after its owner approves this separate access boundary;
no bootstrap configuration is changed and no state store/migration is performed.

Preserve the four workload roots/states and bootstrap boundaries. This control is
reviewed once for its dedicated subscription, outside the per-environment workload
promotion sequence; it does not bypass workload promotion or grant broader access.
Confirm tenant, subscription, currency, backend, identity, dates and recipients;
review a fresh plan and obtain explicit human approval for its apply. Updating or
deleting a budget and all state operations retain the same authorization gates.
No cloud deployment automation or Azure credentials are added to CI.

## Validation and references

Backend-disabled initialization, validation and filtered fully mocked plan tests
exercise absence, scope, notification policy, date/email validation and safe
outputs. Independent plan assertions reject filters, altered thresholds and
automation. They do not prove offer support, reporting latency or mail delivery.

- [Budget API 2024-08-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.consumption/2024-08-01/budgets)
- [Budget behavior and prerequisites](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets)
- [AzAPI 2.9.0 resource schema](https://github.com/Azure/terraform-provider-azapi/blob/v2.9.0/docs/resources/resource.md)
- [ADR 001](adr-001-branching-and-promotion.md)
