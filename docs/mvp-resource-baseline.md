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

## Decision: exclude workload Blob Storage from the MVP

Accepted by the project owner on 2026-11-05: Azure Blob Storage is excluded from
the MVP workload infrastructure. GitHub Actions remains the original workflow-log
source; PostgreSQL holds operational data, sanitized diagnostic evidence and RAG
knowledge through pgvector. Current functional requirements do not demonstrate a
need to duplicate complete workflow logs in separate object storage. RAG does not
justify adding a Blob dependency.

Canonical architecture in `pipesor-docs` will be reconciled separately; this entry
records the authorized IaC scope without modifying that repository. Retention,
source-log deletion/access changes and the required evidence-retrieval guarantees
remain unresolved. Configurable GitHub retention does not guarantee independent
preservation of original logs. These open questions do not authorize Blob Storage.
The separate Azure Blob backend for Terraform state remains in scope.

## Decisions still required for the affected resources

| Area | Remaining decision or evidence |
| --- | --- |
| Container Apps network | Custom VNet, dedicated delegated subnet and external-capable environment are selected. Actual address allocation, region and connectivity to later dependencies remain explicit inputs/decisions. |
| Monitoring | One shared workspace per provisioned environment and Azure Monitor log routing are selected. One shared backend Application Insights component per environment is approved, linked to the existing workspace with Entra-only authentication and public endpoints. Actual limits, effective table retention and instrumentation remain deployment inputs/contracts. |
| Database | Flexible Server / PostgreSQL 17 / B2s / 32 GiB / private VNet / Entra-only / seven-day local backups / no HA are approved for local implementation. Region, names, administrator and subnet allocation remain required inputs; operational access and SQL contracts remain open. |
| Messaging | A public, Entra-only Standard namespace is approved for local implementation. Exact entities/topology evidence (PD-015), runtime access and delivery contracts remain open. |
| API perimeter | Prove the selected APIM tier can reach protected backends and prevent authorization bypass. Consumption remains a candidate pending that proof. |
| Evidence retention | Workload Blob Storage is excluded by the decision above; evidence-retention and retrieval guarantees remain open. Terraform state storage is separate. |
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

## Shared PostgreSQL foundation

The approved MVP database is one optional Flexible Server per provisioned
environment: PostgreSQL 17, Burstable Standard_B2s, 32 GiB Premium SSD with storage
auto-growth disabled, seven-day local backups and no HA, geo-redundant backup or
replicas. This is a controlled-validation sizing hypothesis, not an availability,
throughput, RPO or RTO commitment. Watch CPU credits, memory, connection pools,
storage/WAL and index growth before sizing later environments. Backup retention
is unrelated to the application's 365-day evidence-retention requirement.

Each root defaults `postgresql` to null. Opt-in requires `container_platform`,
because its existing VNet is the approved network; database and VNet regions must
match. Names, region, tenant/admin identity and subnet prefix are explicit inputs.
The module creates a distinct delegated subnet, private DNS zone and VNet link,
server and explicit Entra administrator. The subnet must be canonical RFC1918 IPv4,
/28 or larger, contained in the VNet and disjoint from the dedicated ACA subnet.
Names are reviewed explicit globally available server names, like state storage
and messaging; no random naming or availability guarantee is introduced.

Private VNet integration provides no public database endpoint. The ARM
`publicNetworkAccess` field is omitted because Microsoft documents it for servers
outside customer VNet integration. No private endpoint, firewall, VPN, runner,
route/NSG, new identity or secret store is created. An approved private operator/
migration access path and real DNS/Entra connectivity must be verified before use.
Entra-only disables password authentication; the named administrator has database
administrative privileges and is not a runtime application identity. Tenant,
principal existence/authority, driver token refresh, SQL roles and least-privilege
service grants remain outside local validation.

`azure.extensions` is set to `vector` using `azapi_update_resource`, configuring
an existing server parameter rather than creating an SQL extension. Removing
that update alone leaves the parameter unchanged; resetting it requires a reviewed
update. SQL `CREATE EXTENSION`, target database/schema, migrations and grants
remain with the accepted database owners. No connection strings or passwords are
read/exported. Outputs are server ID/name/service-reported FQDN and network IDs.

ADR 002 extraction was evaluated as PostgreSQL becomes a second network consumer.
The existing network/subnet/environment replacement chain uses direct resource
lifecycle references. This increment retains those resource addresses and behavior
and passes the VNet ID to the root's PostgreSQL peer. It deliberately accepts a
temporary dependency on platform ownership; extraction needs its own tested
address/lifecycle migration. No moved blocks or state operations are needed here.
Removing the platform while keeping PostgreSQL configured fails validation;
removing both can propose destruction of the database and its recovery data.
Subnet allocation changes or server name/location changes can replace the server.
Changes to the parent VNet allocation or location also trigger replacement of the
database subnet, DNS link and server; server replacement reapplies the administrator
and extension setting. These replacements can cause downtime and data loss. Review
a data-preservation and migration plan; neither a Git revert nor backups guarantee
recovery after resource deletion. Mocked tests check the declared triggers, not
actual Azure replacement behavior.

Terraform 1.17.1 and AzAPI 2.9.0 are retained. Stable APIs are PostgreSQL/server,
administrators and configurations `2024-08-01`, subnet `2024-05-01` and private DNS
`2020-06-01`; embedded schema validation remains enabled. AVM 0.2.3 was evaluated
through Terraform MCP and tagged source. It supports AzAPI `~> 2.4` but also requires
AzureRM `~> 4.12` (plus Random/ModTM), so this narrow repeated security composition
preserves the selected provider set. Context7 AVM guidance was supplemented with
versioned ARM and networking references; main-branch examples do not authorize
dependency upgrades.

Provisioned compute, storage, backup excess and private DNS can incur charges.
There is no automatic stop/start scheduler or budget enforcement. Null removes
configuration rather than pausing billing. Safe validation and mocked tests do
not establish actual SKU/region availability, name uniqueness, extension builds,
authentication, DNS, recovery or production readiness. Real plans, Azure writes
and state operations retain the existing authorization gates.

Sources (consulted 2026-11-05):

- [AVM 0.2.3 dependencies](https://github.com/Azure/terraform-azurerm-avm-res-dbforpostgresql-flexibleserver/blob/v0.2.3/terraform.tf)
- [Server ARM API](https://learn.microsoft.com/en-us/azure/templates/microsoft.dbforpostgresql/2024-08-01/flexibleservers)
- [Administrator ARM API](https://learn.microsoft.com/en-us/azure/templates/microsoft.dbforpostgresql/2024-08-01/flexibleservers/administrators)
- [Configuration ARM API](https://learn.microsoft.com/en-us/azure/templates/microsoft.dbforpostgresql/2024-08-01/flexibleservers/configurations)
- [Private network/subnet/DNS requirements](https://learn.microsoft.com/en-us/azure/postgresql/network/concepts-networking-private)
- [AzAPI 2.9.0 update lifecycle](https://github.com/Azure/terraform-provider-azapi/blob/v2.9.0/docs/resources/update_resource.md)

## Shared backend Application Insights

The user approved one optional workspace-based backend component per provisioned
environment, using the existing Log Analytics workspace in the same region.
`application_insights_enabled = false` is the default; enabling it requires
`container_platform`. No new workspace, workload storage, network resources or
state boundary is added. Naming uses AVM 0.3.0 modern `names.component`, producing
`appipipesor<environment>`; this retains the catalog's no-dash format.

The component disables local authentication, retains IP masking and enables public
ingestion/query endpoints. A connection string supplies routing, not Entra access;
backend identity and scoped ingestion permissions are still required. The output
exports only component identity, workspace ID and the service-provided connection
string, not standalone API keys. Shared telemetry does not grant isolation between
services: define resource/role attributes and review access before operating it.

Java and Python instrumentation must implement and test supported Entra token
handling. Older Java SDKs and direct browser ingestion are not assumed compatible.
No runtime identities, role grants, instrumentation, alerts, browser telemetry or
sampling percentages are selected here. Applications must sanitize telemetry at
source; IP masking alone does not remove sensitive messages or attributes. Avoid
exporting the same application logs through both ACA console logs and an SDK
without an intentional filtering design.

Telemetry ingestion and storage are billed through the existing workspace. Its cap
is a visibility/cost backstop, not a hard spend limit. Effective Application Insights
table retention must be reviewed independently: linking a workspace does not prove
that its default retention applies identically to all tables. No component/table
retention setting is introduced or inferred from the 365-day evidence policy.

The existing platform keeps ownership of the shared workspace to preserve resource
addresses and lifecycle. Workspace extraction under proposed ADR 002 remains a
separate refactor. Reassigning the linked workspace or changing its location is
marked for component replacement; review telemetry continuity and deployment
connection strings before applying. Removing an enabled component proposes
resource deletion, not a pause. Historical workspace data and its retention need
independent review; this module does not purge it.

Terraform 1.17.1 and AzAPI 2.9.0 remain selected. The stable component API is
`Microsoft.Insights/components@2020-02-02`, with embedded schema validation enabled.
AVM 0.5.0 was evaluated through Terraform MCP: it requires AzAPI `~> 2.12` and Time,
so the focused local security/routing contract preserves existing provider pins.
No sampling, daily cap, linked profiler storage or AVM default retention is copied.

Sources consulted 2026-11-05:

- [Versioned ARM component schema](https://learn.microsoft.com/en-us/azure/templates/microsoft.insights/2020-02-02/components)
- [AVM component 0.5.0](https://registry.terraform.io/modules/Azure/avm-res-insights-component/azurerm/0.5.0)
- [Entra authentication and SDK support](https://learn.microsoft.com/en-us/azure/azure-monitor/app/azure-ad-authentication)
- [Workspace-based Application Insights](https://learn.microsoft.com/en-us/azure/azure-monitor/app/create-workspace-resource)

Local validation and mocked tests cannot establish actual ingestion, SDK behavior,
identity access, effective retention, regional availability or deployed cost.
