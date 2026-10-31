# Technical direction

This is a development foundation, not an Azure landing zone. Subscriptions,
regions, networking, compute, identity and service topology remain undecided.
No backend, provider configuration, Terraform root or cloud CI identity exists.
Branching, environment isolation and promotion follow
[ADR 001](adr-001-branching-and-promotion.md).

## Boundaries for the first implementation

Create directories only when they contain a real implementation:

| Path | Responsibility |
| --- | --- |
| `environments/<environment>/` | One initial root for each environment defined in ADR 001, with provider configuration, backend declaration, inputs and dependency lock file. |
| `modules/<capability>/` | Reusable composition with a meaningful shared contract; no environment values, backend or provider credentials. |
| `<root>/tests/*.tftest.hcl` | Plan-only or fully mocked contract tests for that root/module. |
| `docs/` | Infrastructure decisions and their rationale. |
| `.codex/` | Repository-local coordinator settings and specialist agent definitions. |

Use `dev`, `qa`, `preprod` and `prod`, with separate roots and remote states as
defined in ADR 001. Start with one component per environment. Split state only for distinct ownership,
lifecycle, permissions or failure impact. Pass explicit inputs/outputs; avoid
coupling components through broad remote-state access.

Nonsecret environment inputs belong beside their root. Commit example variable
files; keep actual `*.tfvars` local (ignored). Secrets arrive through the execution
environment or an approved secret store, never committed files. Backend location
is separate from resource inputs: use a partial `azurerm` backend and nonsecret
`*.tfbackend.example` templates when a backend is actually established.

The intended state store is Azure Blob Storage with a unique key per environment
and component, locking, recovery protection and scoped Entra ID access. Prefer
OIDC for future automation and developer identity for interactive work; avoid
storage keys and long-lived client secrets. Separate production access from
nonproduction. State can contain secrets even when outputs are marked sensitive.
Backend bootstrap is a separately authorized task, outside the workload state it
will host. No backend creation, migration or credentials are included here.
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
changing names/seeds later can replace resources. No naming wrapper or dependency
is installed yet. A custom generator needs a documented gap in this module.
