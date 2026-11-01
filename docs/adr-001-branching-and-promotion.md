# ADR 001: Trunk-based development and Terraform promotion

Status: Accepted. Date: 2026-10-30. Scope: Pipesor infrastructure (`pipesor-infra`;
the current checkout's GitHub repository is `pipesor-org/pipesor-iac`).
This records the target strategy; it creates no roots, state stores, identities,
repository protections or deployment workflows.

## Source and integration

`main` is the single source of truth. Use small, short-lived `feature/<topic>` or
`fix/<topic>` branches from `main`, reviewed PRs back into `main`, then delete the
branch. No environment branches, long-lived `develop` or routine release branches.
Follow [Pipesor's contribution policy](https://github.com/pipesor-org/.github/blob/main/CONTRIBUTING.md):
English Angular-style Conventional Commits, `type(scope): imperative summary`
(scope optional), with `!` and/or a `BREAKING CHANGE:` footer for incompatible
changes. Document the migration in the body or footer. PR titles
follow the same format; prefer squash merge. Example: `docs(infra): define promotion strategy`.

PR validation checks commit messages, PR titles and the prospective squash title
plus body as documented in [README](../README.md#commit-messages),
plus formatting, backend-disabled initialization, validation,
reviewed safe tests and infrastructure review for affected roots/modules and their
callers, following [AGENTS.md](../AGENTS.md#verification). No PR receives apply
credentials or deploys resources. Before selecting a deployment candidate, verify
the merged commit too: PR checks on a different head or merge revision are not
evidence that the final squash commit passed. Require review/checks before merge;
enforcement limitations are documented below.

## Environment and state isolation

Use four separate Terraform roots, all present at the same Git revision:

| Environment | Initial root | Promotion prerequisite |
| --- | --- | --- |
| `dev` | `environments/dev/` | Reviewed, validated commit reachable from `main` |
| `qa` | `environments/qa/` | Same revision successfully applied and verified in `dev` |
| `preprod` | `environments/preprod/` | Same revision verified in `qa`; independent QA approval |
| `prod` | `environments/prod/` | Same revision verified in `preprod`; independent production approval |

Each root has its own inputs, provider configuration, lock file and Azure Blob
remote state. Reuse local modules for shared behavior; environment differences
are configuration, not source branches. Start with one state per environment;
split components only for concrete lifecycle/access needs. Use separate state
containers and environment-scoped RBAC; nonproduction identities cannot access
production state/resources. Different blob keys alone are not an access boundary.
Keep backend bootstrap separate from workload state and retain locking/recovery
controls described in [architecture](architecture.md).
HashiCorp documents [Azure Blob locking and Entra/OIDC authentication](https://developer.hashicorp.com/terraform/language/backend/azurerm)
and cautions that [CLI workspaces do not provide separate credentials/access controls](https://developer.hashicorp.com/terraform/language/state/workspaces).

## Promotion contract

Promote an immutable full Git commit SHA through `dev` → `qa` → `preprod` → `prod`.
The same SHA includes every environment root and shared module; do not copy code
between roots or resolve a moving `main`/tag during promotion. Pin module versions
and use committed provider locks plus a fixed Terraform version. Record nonsecret
input versions and secret version references without recording secret values.

For each environment, check out that SHA in a clean directory, select that root,
confirm subscription/backend/identity, and generate a fresh saved plan against its
current state and inputs. Independently review the actual plan and obtain explicit
human authorization for that environment's apply. Apply only that reviewed plan;
never regenerate it silently after approval, reuse another environment's plan, or
apply a PR's speculative plan. If the SHA, inputs, dependencies, plan or relevant
state/drift changes, regenerate and obtain new review/authorization.
This follows HashiCorp's distinction between [speculative and saved plans](https://developer.hashicorp.com/terraform/cli/commands/plan).

After apply, verify the intended resources, security settings and workload health;
plan success and apply success alone do not prove readiness. A human reviewer
independent of the implementer verifies the evidence before the next promotion.
QA signs off before `preprod`; a product owner/authorized production approver who
did not initiate the deployment signs off before `prod`. Source PR approval and
agent review do not replace environment-specific plan review or deployment approval.
All applies, including `dev`, retain the explicit human authorization requirement.

Record SHA, environment/root, subscription and backend identity, tool/dependency
versions, input references, plan digest, reviewer/approver identities and timestamps,
execution/run link, apply outcome and verification evidence in a deployment record
(a restricted change record or future deployment system). Protect plans/logs as
sensitive; never commit plans or state. Serialize operations per state and prevent
concurrent promotion of competing revisions. Failed verification stops promotion;
new fixes start again at `dev`. Recovery is a fresh reviewed plan, not blindly
reapplying an old plan or assuming a Git revert reverses infrastructure safely.

## Authentication and approval enforcement

For future automation, use GitHub OIDC federation to environment-specific Entra
identities, avoiding long-lived client secrets/storage keys. Restrict issuer,
audience and the actual repository/ref or protected-environment subject claims;
account for GitHub's immutable subject format when applicable. Grant `id-token:
write` only to trusted deployment jobs and never expose resource-write identities
to PR code. Separate plan resource-read permissions from apply resource-write
permissions; state access/lease permissions are scoped separately to its container.
See [GitHub's Azure OIDC guidance](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure)
and [Microsoft's federation setup](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect).

Current constraint (checked 2026-10-30): `pipesor-org` reports GitHub Free and this
repository is private. [Branch protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
is unavailable for private repositories on Free. [GitHub Environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
are also unavailable here; Team enables private environments, but private required
reviewers/wait timers require Enterprise. A manual workflow trigger or PR comment
does not provide an enforced deployment gate. Where native reviewer gates become
available, prevent self-review and bypass; only one listed required reviewer needs
to approve, so distinct QA/product approvals must be modeled explicitly.

Until enforceable gates exist, reviews/checks are procedural requirements: limit
merge access to maintainers, record approvals and use a designated human operator
with controlled Azure access for authorized deployments. Production stays manual;
do not give Actions a production apply identity on branch trust alone. Before
automating production, require Enterprise environment approvals or a separately
enforced external approval/credential-release control. OIDC authenticates a job;
it does not prove approval, enforce promotion order or compensate for missing
branch protection. Recheck plan entitlements and test gates before automation.
