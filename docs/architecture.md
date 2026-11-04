# Technical direction

This foundation defines one resource group in each of four Terraform roots; it is
not an Azure landing zone. No resources or remote backends have been deployed.
Subscriptions and metadata locations are required inputs, with no selected values.
Workload regions, networking, capacity, identity configuration and service delivery
contracts remain undecided. The Azure service selections and their limits are
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
and component, locking, recovery protection and scoped Entra ID access. Prefer
OIDC for future automation and developer identity for interactive work; avoid
storage keys and long-lived client secrets. Separate production access from
nonproduction. State can contain secrets even when outputs are marked sensitive.
Backend bootstrap is a separately authorized task, outside the workload state it
will host. [State bootstrap](state-bootstrap.md) defines the separate configuration and custody
contract; no backend has been created or migrated.
See HashiCorp's [Azure backend reference](https://developer.hashicorp.com/terraform/language/backend/azurerm).

## Terraform and naming

Use conventional `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and root
`providers.tf` files as needed. Declare typed, described and validated inputs.
Follow the [HashiCorp style guide](https://developer.hashicorp.com/terraform/language/style).
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

`modules/state-store` and four `bootstrap/<environment>` callers implement the
separate state-store prerequisite described in [state bootstrap](state-bootstrap.md).
The user selected a public endpoint restricted to approved operator IPs; the
configuration denies other networks and grants explicit container-scoped Entra
access. Account details, redundancy and recovery windows remain required inputs.
These infrastructure state controls do not select workload storage, retention,
secret management or network topology.
