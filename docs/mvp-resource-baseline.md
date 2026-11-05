# MVP resource baseline

## Direction accepted for local implementation

The user selected the cost-optimized MVP research supplied in the implementation
session as the immediate development direction: preserve the seven approved
backend service boundaries, share workload infrastructure and provision capacity
incrementally. To-Be capacity and resilience require measured demand and approved
reliability requirements. This record does not amend upstream models or ADRs.

Share infrastructure among services within an environment. Preserve separate
`dev`, `qa`, `preprod` and `prod` roots, states and access boundaries under
[ADR 001](adr-001-branching-and-promotion.md). Four roots do not require four
continuously provisioned workload stacks; promotion prerequisites still apply.

Resource decisions follow this cost-optimized MVP direction without a $100 Azure
for Students ceiling. Pay-as-you-go is the expected funding model, not a verified
subscription upgrade. Use `cloud_researcher` to estimate the complete footprint
before provisioning and compare forecasts with actual costs once deployed. This
does not select remaining resource options or authorize spending or Azure writes.

The user also explicitly selected a customer-managed VNet with a dedicated ACA
subnet, an **external-capable** environment, and creation of a shared Log Analytics
workspace for each provisioned environment. `modules/container-platform` implements
that independent foundation. It creates no service applications or Dedicated
profiles. Per-app ingress and authorization still require approved service
contracts; external-capable infrastructure does not approve public application
exposure.

## Decisions still required for the affected resources

| Area | Remaining decision or evidence |
| --- | --- |
| Container Apps network | Custom VNet, dedicated delegated subnet and external-capable environment are selected. Actual address allocation, region and connectivity to later dependencies remain explicit inputs/decisions. |
| Monitoring | One shared workspace per provisioned environment and Azure Monitor log routing are selected. Actual retention and ingestion limits require explicit inputs; application telemetry remains part of service delivery. |
| Database | Accept hosting service/tier, region, connectivity and capacity. PostgreSQL/pgvector and existing data ownership remain established; managed HA is not assumed. |
| Messaging | A public, Entra-only Standard namespace is approved for local implementation. Exact entities/topology evidence (PD-015), runtime access and delivery contracts remain open. |
| API perimeter | Prove the selected APIM tier can reach protected backends and prevent authorization bypass. Consumption remains a candidate pending that proof. |
| Evidence storage | Agree workload access, recovery and retention mechanics; Terraform state storage is separate. |
| Images and credentials | GHCR is selected for the MVP; no ACR is needed. Image delivery, private-pull credential ownership/rotation and secret handling remain open without inferring Key Vault. |
| AI | Resolve concrete model deployments, embedding ownership/dimensions and authorized corpus lifecycle. |

Account identifiers, region and environment-specific values can remain required
inputs with nondeployable examples during local development. Unknown security
requirements and architectural choices must not become implicit defaults.

## Service delivery and source limits

All seven service repositories currently provide deployment-readiness records,
not approved executable contracts. PD-035 remains open for the relevant service
increment: images, ports, probes, configuration, access, scaling and migration
ownership must be accepted before service resources consume those contracts.
Event/API and workflow-access decisions block their affected integrations rather
than every independent platform resource.

The research inspected `pipesor-docs` at
`c0871ac9a62bad62b8c679255fe0a4b9c6574d2e` and IaC at
`abd0551644744be3a0d416119d5f163708136ea5`. The upstream PD-033–036/stage-5
supplements remain outside the pinned docs revision; see
[architecture consumption](architecture-consumption.md). A retrievable reviewed
revision is still needed for cross-repository reliance on those supplements.

No region, price estimate, sample replica/resource envelope or To-Be tier from the
research is a deployment input. Real plans, Azure writes and state operations
retain the authorization requirements in [AGENTS.md](../AGENTS.md#authorization).

## Implemented foundation contract

The four existing roots retain their resource-group behavior and state boundaries.
`container_platform = null` is the default and adds no workload platform resources.
To opt in, supply the required object documented in each root's variable example:
workload `location`, `vnet_address_prefix`, `infrastructure_subnet_prefix`,
`log_retention_days` and `log_daily_cap_gb`. No real region or address is selected
by an example. Start with `dev`; later provisioning still follows ADR 001.
Removing a previously deployed object proposes deletion of its platform resources;
it is not a pause or cost-free way to stop applications. Review the plan and obtain
explicit target/action authorization before applying any change.

Each opt-in creates a VNet, dedicated delegated subnet, managed environment,
workspace and diagnostic setting in that root's workload resource group. The
managed environment has exactly one Consumption workload profile, no zone
redundancy, an external load balancer and public network access. No ingress rules
for individual apps, NAT gateway, network firewall, private endpoints, DNS zones or
extra capacity are created. Private data-service connectivity is a later approved
increment, not an implemented guarantee of the VNet alone.

The address contract accepts canonical RFC1918 IPv4 CIDRs. The ACA subnet must
fit inside its VNet, be /27 or larger, and avoid reserved 172.30.0.0/16 and
172.31.0.0/16. Restricting inputs to RFC1918 also excludes ACA's other documented
reserved ranges. The subnet is delegated to `Microsoft.App/environments` and must
not be used by another service. Review overlap with corporate/peered networks and
capacity for revisions/replicas before deployment; local checks cannot know those
external allocations.

Network type and subnet sizing are creation-time choices. VNet address-space and subnet prefix changes
are marked for replacement, and replacement cascades through subnet to environment.
All allocation changes require a recreate/migration plan with downtime assessment. Replacement may interrupt or remove deployed apps; later migrations need
an explicit plan. Azure creates a separate managed infrastructure resource group;
do not import, edit or delete its resources independently.

## Telemetry, access and cost boundaries

The workspace uses pay-as-you-go `PerGB2018`, explicit 30–730 day integer retention
and a positive daily ingestion cap. Retention is independent of application
365-day evidence policy. Shared-key authentication is disabled; querying requires
workspace RBAC. Public ingestion/query endpoints remain enabled with authentication;
private monitoring connectivity and explicit user grants are outside this increment.

Environment logs use Azure Monitor diagnostic routing to the workspace, selecting
`ContainerAppSystemLogs` and `ContainerAppConsoleLogs`. No workspace keys are read
or supplied, and no Dapr, application instrumentation or Application Insights
resource is added. Apps must sanitize log content at source; routing does not
implement privacy controls. Treat logs and access as sensitive. A daily cap is a
backstop, not a hard monetary ceiling: ingestion may exceed it and reaching it
reduces visibility. Review sampling/filtering, alert ownership and spend before
operating real evidence.

Consumption-only workload capacity does not eliminate all fixed costs. Custom
VNet integration creates platform-managed load-balancer/public-IP resources with
associated charges even before service compute demand. No price estimate, NAT
capacity, premium tier or To-Be reliability feature is selected by this module.

## Dependencies and implementation choices

Terraform 1.17.1, AzAPI 2.9.0 and naming AVM 0.3.0 remain selected. Modern naming
outputs supply deterministic resource names with `pipesor` and environment suffixes;
no random name resources or uniqueness promises are introduced.

AVM was evaluated before this small local composition. Managed-environment AVM
0.6.0 and VNet AVM 0.23.0 require AzAPI 2.12; compatible environment 0.3.0 and
workspace 0.5.1 add AzureRM and other dependencies, while the former disables
embedded schema validation. The older environment modules also include mechanisms
for workspace shared-key lookup or preview environment APIs. The narrow composition
therefore uses direct AzAPI resources while preserving provider pins and embedded
schema validation. It is not a general replacement for those AVMs.

Stable resource APIs are used for VNet/subnet (`2024-05-01`), workspace
(`2023-09-01`) and managed environment (`2025-07-01`). Diagnostic settings use the
current documented `2021-05-01-preview` API; this does not enable a preview
Container Apps feature. Provider registration and preflight remain disabled in
root provider configurations. There are no provisioners, external programs or
cloud data-source lookups in the platform composition. Tests mock AzAPI and inspect
planned profiles, delegation, wiring, telemetry and opt-in behavior; they cannot
prove region availability, network connectivity, privacy, leases or deployability.

References: [ACA networking](https://learn.microsoft.com/en-us/azure/container-apps/networking),
[custom VNet restrictions and managed-resource charges](https://learn.microsoft.com/en-us/azure/container-apps/custom-virtual-networks),
[log routing](https://learn.microsoft.com/en-us/azure/container-apps/log-options),
[workspace daily cap](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/daily-cap),
[managed environment API](https://learn.microsoft.com/en-us/azure/templates/microsoft.app/2025-07-01/managedenvironments),
[workspace API](https://learn.microsoft.com/en-us/azure/templates/microsoft.operationalinsights/2023-09-01/workspaces),
[diagnostic settings API](https://learn.microsoft.com/en-us/azure/templates/microsoft.insights/2021-05-01-preview/diagnosticsettings),
[environment AVM 0.3.0](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/tree/v0.3.0),
[VNet AVM 0.23.0](https://github.com/Azure/terraform-azurerm-avm-res-network-virtualnetwork/tree/v0.23.0)
and [workspace AVM 0.5.1](https://github.com/Azure/terraform-azurerm-avm-res-operationalinsights-workspace/tree/v0.5.1).

## Shared messaging foundation

The user approved one optional Service Bus Standard namespace per provisioned
environment with a public endpoint and Entra-only authentication. The existing
roots/states remain isolated. `service_bus = null` adds no namespace; opting in
requires `namespace_name` and `location` as shown in each root's placeholder file.
Names must be distinct across environments and globally available. The contract
accepts 6–50 lowercase letters, digits and hyphens, starting with a letter and
ending with a letter or digit. As with state storage, explicit reviewed names are
used instead of generated names or new randomness; local validation cannot reserve
names or prove regional availability. The workload location need not match the
resource-group metadata location.

`modules/service-bus` fixes the SKU to Standard, disables SAS/local authentication
and explicitly requires TLS 1.2. Public access means an internet-reachable endpoint,
not anonymous access or an IP allowlist. No network rule set, trusted-service bypass,
private endpoint, service identity or data-plane grant is configured. Authorized
Entra identities and their scoped permissions must be agreed before message flow.
No keys or connection strings are read or exported. Azure may create default
service-managed authorization rules; disabling local authentication prevents SAS
use rather than proving that no server-side key material exists.

Topics, subscriptions, delivery settings and event contracts remain outside this
increment. The modeled topology's PD-015 approval-provenance gap remains open; this
namespace approval does not resolve it. The existing shared network/workspace are
not consumed by this namespace, so no proposed ADR 002 extraction is needed here.
GHCR remains the chosen MVP image registry and does not select a credential store.

A provisioned Standard namespace incurs base charges even without message traffic;
null is a provisioning choice, not a runtime pause. Removing an opted-in object
proposes deletion, and changing a namespace name or location can replace it and
remove future messaging entities/messages. Review plans, downtime/data preservation
and explicit target/action authorization before any real operation. No resources
have been deployed or imported by this implementation.

Terraform 1.17.1 and AzAPI 2.9.0 remain selected; the stable namespace API is
`Microsoft.ServiceBus/namespaces@2024-01-01`. Embedded schema validation remains
enabled. The Service Bus AVM 0.5.0 was evaluated through Terraform MCP and its tagged
source: it requires AzAPI `~> 2.12` plus AzureRM `~> 4.14`. Introducing it would require
an intentional provider/dependency change. The small local composition preserves
the selected provider and enforces the repeated Standard/public/Entra/TLS contract;
no AzureRM provider or dependency upgrade is introduced. Context7's official AVM
coverage was supplemented with the tagged source and Microsoft ARM/authentication
references. The versioned ARM reference below supplies the resource contract.

Sources checked 2026-11-05:

- [Service Bus AVM 0.5.0 provider requirements](https://github.com/Azure/terraform-azurerm-avm-res-servicebus-namespace/blob/v0.5.0/terraform.tf)
- [Namespace ARM API 2024-01-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.servicebus/2024-01-01/namespaces)
- [Disable local authentication](https://learn.microsoft.com/en-us/azure/service-bus-messaging/disable-local-authentication)
- [Minimum TLS configuration](https://learn.microsoft.com/en-us/azure/service-bus-messaging/transport-layer-security-configure-minimum-version)
- [Azure resource naming rules](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftservicebus)
