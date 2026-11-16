# Technical direction

This foundation defines one resource group in each of four Terraform roots and an
optional shared MVP container platform, Service Bus namespace, PostgreSQL server,
Application Insights component, Microsoft Foundry account/project and Static Web Apps Free site per environment; it is not an Azure landing zone. Historical records report no deployment; actual Azure/remote-state inventory remains unverified.
The academic MVP selects only `dev` in Ramiro's temporary Azure for Students
subscription/UPC tenant; [ADR 004](adr-004-mvp-state-and-deployment.md) records the
verified target, custody and deployment gates. No infrastructure may be deployed
until application services are implemented, integrated locally and validated,
followed by explicit deployment authorization. Other environments remain unprovisioned.
[ADR 005](adr-005-academic-mvp-scope-and-cost-governance.md) selects one tenant and one temporary Students subscription for DEV. Each environment retains its explicit subscription input and can later use a different subscription without shared-module redesign. Separate tenants are a future governance choice. Metadata locations are pending.
Workload regions and network allocations require explicit inputs. Service capacity,
identity configuration and delivery contracts remain undecided. The Azure service selections and their limits are
recorded in [architecture consumption](architecture-consumption.md). No cloud CI
identity or deployment workflow exists.
Branching, environment isolation and promotion follow
[ADR 001](adr-001-branching-and-promotion.md).

## Implementation boundaries

Create directories only when they contain a real implementation:

| Path | Responsibility |
| --- | --- |
| `environments/<environment>/` | One initial root for each environment defined in ADR 001, with provider configuration, backend declaration, inputs and dependency lock file. |
| `modules/<capability>/` | Reusable composition with a meaningful shared contract; no environment values, backend or provider credentials. |
| `subscription-controls/` | Deferred root/state for subscription cost notifications, outside the active MVP and workload states; no approved current amount. |
| `<root>/tests/*.tftest.hcl` | Plan-only or fully mocked contract tests for that root/module. |
| `docs/` | Infrastructure decisions and their rationale. |
| `.codex/` | Repository-local coordinator settings and specialist agent definitions. |

Use `dev`, `qa`, `preprod` and `prod`, with separate roots and remote states as
defined in ADR 001. Start with one component per environment. Split state only for
distinct ownership, lifecycle, permissions or failure impact. Pass explicit inputs/outputs; avoid
coupling components through broad remote-state access.

Nonsecret environment inputs belong beside their root. Commit example variable
files; keep actual `*.tfvars` local (ignored). Secrets arrive through the execution
environment or an approved secret store, never committed files. Backend location
is separate from resource inputs: use a partial `azurerm` backend and nonsecret
`*.tfbackend.example` templates for the separately established backend. The
declarations and placeholder templates do not create a backend; only backend-disabled initialization is part of local/CI
verification.

The intended state store is Azure Blob Storage with a unique key per environment
and component, locking, recovery protection and scoped Entra ID access. Target
GitHub Actions OIDC for MVP deployments using ADR 004's proposed Debian VirtualBox
runner and accepted procedural dev approval model. Activation still requires
application readiness, verified access/network/isolation and explicit authorization. Use Jhon's developer identity for authorized WSL bootstrap
and preparation; avoid storage keys and long-lived client secrets. Separate production access from
nonproduction. State can contain secrets even when outputs are marked sensitive.
Backend bootstrap is a separately authorized task, outside the workload state it
will host. [State bootstrap](state-bootstrap.md) defines the separate configuration and custody
contract; credential-free checks neither initialize a remote backend nor establish
actual deployment inventory.
See HashiCorp's [Azure backend reference](https://developer.hashicorp.com/terraform/language/backend/azurerm).

## Terraform and naming

Use conventional `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and root
`providers.tf` files as needed. Declare typed, described and validated inputs.
Follow the [HashiCorp style guide](https://developer.hashicorp.com/terraform/language/style).
The current capability-based composition and proposed separation of shared network,
monitoring and hosting responsibilities are recorded in
[ADR 002](adr-002-terraform-module-composition.md). Module extraction and additional
state boundaries are separate decisions; the proposed split is not implemented.
Pin a tested CLI version when adding Terraform/CI, constrain provider versions,
commit each root's `.terraform.lock.hcl`, and pin registry module versions
explicitly (the provider lock file does not lock modules).

Evaluate [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
before composing local capabilities. Consume a suitable module directly; add a
local module only for useful Pipesor composition or a repeated contract.
Choose providers against actual requirements and the selected module's supported
versions. AzureRM covers stable resources; AzAPI exposes ARM APIs and may be
required by current AVM modules. Do not force a blanket provider choice or manage
the same object through both. Consult [Microsoft's provider overview](https://learn.microsoft.com/en-us/azure/developer/terraform/overview)
and [current AVM specifications](https://azure.github.io/Azure-Verified-Modules/specs/tf/res/).

Naming evaluation (2026-10-30): prefer
[`Azure/avm-utl-naming/azure` 0.3.0](https://registry.terraform.io/modules/Azure/avm-utl-naming/azure/0.3.0)
over a custom generator. Its [versioned documentation](https://github.com/Azure/terraform-azure-avm-utl-naming/tree/v0.3.0)
describes catalog-based names, suffix components, service-specific separators and
bounds, modern `names` outputs and optional uniqueness seeds. It needs Terraform
1.9+ and no Azure credentials. Use `pipesor` and the agreed environment as naming
components; introduce region/instance only when requirements justify them.
Use modern outputs rather than deprecated legacy outputs. Check each selected
resource against [Microsoft's naming rules](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules).
A generated unique name does not reserve it or guarantee availability. Decide a
stable uniqueness strategy and test length/character limits before adoption;
changing names/seeds later can replace resources.

The resource-group composition consumes this version directly with
`suffix = ["pipesor", environment]` and `unique_length = 0`. Its names are
`rg-pipesor-dev`, `rg-pipesor-qa`, `rg-pipesor-preprod` and `rg-pipesor-prod`.
Resource-group uniqueness is subscription-scoped; no random seed is needed.
These names do not establish a strategy for globally named services. A custom
generator needs a documented gap in this module.

## Resource-group foundation

`modules/resource-group` composes naming with
[`Azure/avm-res-resources-resourcegroup/azurerm` 0.4.0](https://github.com/Azure/terraform-azurerm-avm-res-resources-resourcegroup/tree/v0.4.0).
The shared contract validates the four environment names and an explicit lowercase
location code; it exports only ID, name and location. Each environment root fixes
its own environment and requires a subscription UUID and metadata location.
One initial group per environment is an implementation prerequisite, not an
approved workload grouping policy. Nothing is deployed by adding these files.

The suitable resource-group AVM uses **AzAPI**, despite its registry provider
suffix. Roots pin AzAPI 2.9.0 and Terraform 1.17.1. The naming dependency remains
0.3.0. The AVM pins its interfaces dependency to 0.6.0; provider locks include its
transitive Random and ModTM dependencies. AVM telemetry is disabled, and naming
creates no random resources with `unique_length = 0`. No role assignments,
management locks, service resources or data-plane access are requested.

Root providers set `skip_provider_registration = true`, `enable_preflight = false`
and disable Terraform partner attribution, following the
[AzAPI 2.9.0 provider schema](https://github.com/Azure/terraform-provider-azapi/blob/v2.9.0/docs/index.md).
The [AVM source](https://github.com/Azure/terraform-azurerm-avm-res-resources-resourcegroup/blob/v0.4.0/main.tf)
uses the provider's current subscription to parent the resource group. Real plans
still require the target tenant/subscription/backend and read-only credentials to
be reviewed; no autonomous check authenticates to Azure. Module and caller tests
replace the entire AzAPI provider, including client-configuration data sources,
and every run explicitly uses `command = plan`.

Each root has an empty partial `azurerm` backend and a nonsecret example. Before
real use, separately authorize backend bootstrap and establish isolated containers,
environment-scoped Entra RBAC, locking and recovery. Unique keys alone do not
isolate access. Backend authentication and resource-provider authentication are
separate. Do not use the placeholders, initialize real state or supply write
credentials for the credential-free checks.

Resource-group names and metadata locations can be replacement-sensitive. Review
any future change before deployment; deleting a group may also delete resources
placed into it later. No existing resources are imported or adopted by this code.

## State bootstrap

`modules/state-store` and `bootstrap/dev` implement the active remote-state
prerequisite described in [state bootstrap](state-bootstrap.md). Only the DEV
state account is selected for the MVP. The other environment bootstrap roots
retain future isolation contracts. `bootstrap/admin` serves only the deferred
`subscription-controls` state and is outside active MVP scope. Its definitions,
addresses and independent bootstrap custody contract are retained until an
explicitly reviewed inventory establishes whether retirement is safe.
The user selected a public endpoint restricted to approved operator IPs; the
configuration denies other networks and grants explicit container-scoped Entra
access. MVP examples explicitly select LRS and 30-day soft deletion with versioning;
account names, regions, principals and IPs remain pending. Generic inputs retain
parameterization, and no actual backend is initialized.
These infrastructure state controls do not select workload storage, retention,
secret management or network topology.

## Shared MVP container platform

Use ACA native ingress for the MVP under
[ADR 003](adr-003-mvp-native-ingress.md), without dedicated gateway infrastructure.
Expose only required endpoints, keep internal services off public ingress and
retain Entra authentication and application authorization responsibilities. WAF
and centralized rate limiting are absent; corporate policy compliance remains
unverified. Service exposure and delivery contracts are still required.

The [MVP baseline](mvp-resource-baseline.md) records the user-approved Consumption,
custom VNet, external-capable environment and shared workspace choices. Each root
opts in through a nullable `container_platform` object; null adds no platform.
The object requires workload location, private VNet/subnet CIDRs and telemetry
retention/ingestion limits. The platform location is separate from resource-group
metadata location. No service image, application, registry, database, API
perimeter or workload identity is defined by this increment.

## Shared messaging foundation

The [MVP baseline](mvp-resource-baseline.md#shared-messaging-foundation) records the
approved optional Service Bus Standard namespace with a public endpoint, Entra-only
authentication and minimum TLS 1.2. Each environment root opts in independently
through `service_bus`; null adds no namespace. Namespace name and workload location
are explicit inputs. No application delivery contract is required to define this
shared dependency; messaging entities and runtime access remain separately gated.

## Shared PostgreSQL foundation

The [database baseline](mvp-resource-baseline.md#shared-postgresql-foundation)
records the approved private Flexible Server configuration. Nullable `postgresql`
inputs opt in through the existing roots/states and require the platform VNet in
its region. A dedicated delegated subnet/private DNS and explicit Entra admin are
created; no application SQL is executed. Network extraction under proposed ADR 002
was evaluated and deferred to preserve existing replacement/address behavior.

## Shared backend Application Insights

The [MVP baseline](mvp-resource-baseline.md#shared-backend-application-insights)
records one optional workspace-based component per environment. It reuses the
platform workspace and location, with Entra-only authentication and public
endpoints. No application instrumentation or service identity is created.

## Shared Microsoft Foundry foundation

The [Foundry baseline](mvp-resource-baseline.md#shared-microsoft-foundry-foundation)
records the approved account/project composition and public Entra-only boundary.
Each root opts in independently through `foundry`; null adds no account or project.
Explicit names and region are required. No model deployment, service access grant
or application interface is inferred; model and processing-geography contracts
remain separate decisions. Existing roots, state and approval gates are preserved.

## Static Web Apps Free hosting

The [hosting baseline](mvp-resource-baseline.md#static-web-apps-free-hosting) records
approved public static hosting. Nullable `static_web_app` inputs add one Free site
independently of ACA. Only identity and default hostname are exported. No content,
authentication, domain binding, repository integration or delivery workflow is
created. Entra application authentication and ACA API authorization remain required
before real operational use; public assets must contain no sensitive data/secrets.

## Cost governance

[ADR 005](adr-005-academic-mvp-scope-and-cost-governance.md) replaces the old
USD 300/dedicated-subscription assumption. Use native offer-supported usage and
credit visibility, a complete DEV estimate and resource-group attribution first.
[Cost governance](subscription-controls.md) documents feature-eligibility limits,
existing environment tags and future independent-subscription governance.
`subscription-controls` and its admin backend are deferred; neither is a DEV
prerequisite. No control is moved into workload state and no new state boundary
is introduced. Budgets are notifications, not hard spending limits.
