# MVP foundation cost projection

Reviewed 2026-11-06 against IaC
`0628455535d5f8ab56eca97b779682e4c3fee4ff` and the local subscription-budget
increment. This reconciles the supplied estimate with official pricing; it is
not measured spending, a deployment approval or a complete operating forecast.

## Basis and selected scope

Use the owner-confirmed **single dedicated Pipesor subscription with USD billing**
as the planning layout. East US is illustrative, not a selected deployment region.
Assume PAYG, 730 deployed hours/month, before taxes, discounts and credits, with no
application traffic or billable telemetry. Subscription settings were not inspected.

Checked-in workload defaults enable only resource groups: their projected resource
cost is $0/environment/month. This does not prove the Azure subscription has zero
spending. Optional foundations, state bootstrap and the budget remain opt-in; no
Azure resources or backends have been deployed through this workflow.

| Foundation component | Planning rate / monthly amount |
| --- | --- |
| PostgreSQL B2s | $0.068/hour × 730 = $49.64 |
| PostgreSQL provisioned storage | $0.115/GB-month × 32 = $3.68 |
| Private DNS zone | $0.50/month; queries extra |
| Two Standard static IPv4 addresses | $0.005/hour × 2 × 730 = $7.30 |
| Standard load balancer, first five rules | $0.025/hour × 730 = $18.25, conditional on billable rules |
| Service Bus Standard base | Approximately $10/month once per subscription, not once per namespace |

Microsoft's Retail Prices API supplied these rates. PostgreSQL/IP meters are East
US, LB is published as Global, and private DNS is nonregional. Service Bus includes
both monthly and hourly entries; retain its approximately $10 planning allowance
rather than imply cent-level forecast accuracy.

The current external, custom-VNet workload-profiles ACA environment has only a
Consumption profile. Microsoft documents two public IPs and a Standard load
balancer as managed resources for this configuration. These can be billed even
though they are not explicit Terraform resources. **The $25.55 networking figure
assumes the managed LB has billable rules throughout the month.** A Standard LB
with zero rules has no hourly charge. Inspect managed resources and cost meters
after authorized deployment; management traffic can add data-processing costs.

## Concurrent environment scenarios

The illustrative per-stack subtotal excluding the shared Service Bus base is
`25.55 + 49.64 + 3.68 + 0.50 = $79.37/month`.

| Fully enabled concurrent stacks | Partial fixed projection, rounded | Unallocated portion of $300, before omitted costs |
| --- | ---: | ---: |
| 1 | About $89 | About $211 |
| 2 | About $169 | About $131 |
| 3 | About $248 | About $52 |
| 4 | About $327 | About −$27 |

Using the supplied rounded meters, exact arithmetic gives $89.37, $168.74,
$248.11 and $327.48 respectively. Allocating the shared base equally among four
stacks gives $81.87 each; that is accounting allocation, not namespace pricing.
The four-subscription $357.48 example is a sensitivity case, **not the selected
layout**. Neither scenario supplies a complete application cost estimate.

State-account replication, stored versions/recovery and transactions are excluded,
as are ACA applications, requests, model/embedding usage, telemetry, DNS queries,
messaging overages, excess backups, egress and LB data processing. Foundry,
monitoring and SWA zero-consumption assumptions do not guarantee zero operational
usage. Domain, GitHub and other non-Azure charges are outside this budget scope.

## Budget implications

Keep the approved **$300 monthly budget and notification policy unchanged**.
The estimate informs deployment sequencing, not an automatic target increase.
Four isolated roots/states do not require four continuously funded stacks. Start
with dev; establish cost capacity for later environments as promotion requires
them, without skipping promotion gates or sharing environment states. Concurrent
stack counts remain planning scenarios, not an approved environment schedule.

Do not set an opt-in configuration to null as a stop mechanism: it proposes
deletion. PostgreSQL stop/start is only a future operational option requiring
separate authorization and ownership; storage remains billed and Azure restarts
the server automatically after seven days. No scheduler or claimed savings is
implemented. Telemetry caps and budget notifications are not hard spending caps.

Before deployment, confirm actual regions, eligible meters, managed LB rules,
usage assumptions and state settings. Compare those estimates with protected
Azure billing data after deployment; current local checks cannot measure cost.

## Sources

- [Microsoft Retail Prices API](https://prices.azure.com/api/retail/prices)
- [Service Bus pricing and base-charge FAQ](https://azure.microsoft.com/en-us/pricing/details/service-bus/)
- [PostgreSQL pricing](https://azure.microsoft.com/en-us/pricing/details/postgresql/flexible-server/)
- [ACA managed networking resources](https://learn.microsoft.com/en-us/azure/container-apps/custom-virtual-networks)
- [Load balancer pricing and zero-rule qualification](https://azure.microsoft.com/en-us/pricing/details/load-balancer/)
- [PostgreSQL stop/start behavior](https://learn.microsoft.com/en-us/azure/postgresql/configure-maintain/how-to-stop-server)
- [Subscription budget contract](subscription-controls.md)
