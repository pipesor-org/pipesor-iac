# Pipesor infrastructure

Terraform foundation for Pipesor's planned Microsoft Azure infrastructure, with isolated environment roots, safe validation and documented architecture boundaries.

## Current state

- [MVP container platform](docs/mvp-resource-baseline.md) is opt-in per environment: a shared Consumption environment, VNet/delegated subnet and monitoring workspace. No service applications are defined.
- [State bootstrap](docs/state-bootstrap.md) defines isolated state accounts and containers using required deployment inputs. No state store has been created; bootstrap state custody and real operations require separate authorization.
- Four roots define one resource group each: `dev`, `qa`, `preprod` and `prod`. No Azure resources or remote backends have been deployed.
- Subscription IDs and resource-group metadata locations are required inputs without defaults. Service apps, data services, workload identities and secrets remain outside this increment; the optional platform requires explicit network allocation and telemetry limits.
- Environment isolation and promotion are an accepted target strategy, not implemented deployment automation.
- Azure credentials are unnecessary for working with the current foundation. Future resource and state operations follow the authorization requirements in [AGENTS.md](AGENTS.md#authorization).

## Requirements and setup

Run commands from the repository root.

- Bun: use the version pinned in [package.json](package.json). Commitlint runs directly with Bun; Node.js is not required.
- Standalone [Lefthook 2.2.2](https://github.com/evilmartians/lefthook/releases/tag/v2.2.2): install the binary for your OS/architecture on `PATH`, verify its SHA-256 against the release's `lefthook_checksums.txt`, and check `lefthook version`.
- Terraform CLI **1.17.1**, pinned in [.terraform-version](.terraform-version) and each root. Registry/GitHub access is required to initialize the pinned AVM modules and locked providers; Azure credentials are unnecessary.

```sh
bun install --frozen-lockfile
bun run setup:hooks
```

Hook activation is required once per clone. For existing clones, inspect `git config --show-origin --get-all core.hooksPath`. If the local value is the former `.githooks`, remove only that value with `git config --local --unset core.hooksPath`, then rerun hook setup. Resolve other hooks-path configurations deliberately; do not change global Git settings or edit generated hooks. Optional `lefthook-local.yml` overrides are ignored by Git.

## Verification

Run the repository's baseline checks:

```sh
git diff --check
terraform fmt -check -recursive
```

Initialize and validate every module/root, then run the explicitly selected native
test file. All tests replace AzAPI with a mock and use plan-only runs; `testregion`
and the UUID in tests are synthetic fixtures, not selected Azure inputs.

```sh
for directory in modules/resource-group modules/state-store modules/container-platform environments/dev environments/qa environments/preprod environments/prod bootstrap/dev bootstrap/qa bootstrap/preprod bootstrap/prod; do
  terraform -chdir="$directory" init -backend=false -input=false -lockfile=readonly
  terraform -chdir="$directory" validate
  bun tests/terraform-contracts.js "$directory"
done
```

Run these checks without Azure write credentials. Backend-disabled initialization
does not connect to remote state. Validation and mocked plans do not prove Azure
deployability, permissions, region availability, backend access or workload health.
The [Terraform workflow](.github/workflows/terraform.yml) runs these credential-free
checks for all eleven directories on PRs and pushes to `main`; it has no Azure login,
OIDC permission, plan artifact or deployment job.

The test runner also inspects the effective mocked plans for environment and
bootstrap callers, checking network/telemetry inputs and state recovery/access
inputs at the resource boundary. It requires the expected successful plans and
does not save or print plan JSON. Mocked provider outputs do not verify provider
authentication or the target subscription selected by the real provider.

`terraform.tfvars.example` and `backend.tfbackend.example` beside each workload root document
required inputs with placeholders. Backend creation and access setup are a separate
authorized task; no state store exists here. Do not run a real plan until tenant,
subscription, environment, backend and side effects have been reviewed under
[AGENTS.md](AGENTS.md#authorization).

For hook or Commitlint changes, complete setup above and also run:

```sh
lefthook validate
bun run test
```

The [Commitlint workflow](.github/workflows/commitlint.yml) validates hook configuration, accepted/rejected messages, PR commits, PR titles and prospective squash messages, and the latest commit on pushes to `main`. PR title/body edits rerun validation. These checks do not plan or deploy infrastructure.

## Repository guide

- [Technical direction](docs/architecture.md): current foundation, intended layout, state handling, and provider/module selection criteria.
- [Consumed architecture](docs/architecture-consumption.md): consulted documentation revision, evidence limits, supported scope and unresolved contracts.
- [ADR 001](docs/adr-001-branching-and-promotion.md): environment isolation, promotion, approval requirements, and documented GitHub enforcement limitations.
- [ADR 002 (proposed)](docs/adr-002-terraform-module-composition.md): module composition, capability boundaries and their distinction from state isolation.
- [Agent and engineering guidance](AGENTS.md): coordination, documentation tools, authorization boundaries, and verification.
- [Optional Codex setup](.codex/README.md): repository-local roles, configuration, and startup checks.
- [lefthook.yml](lefthook.yml), [commitlint.config.js](commitlint.config.js), and [hook tests](tests/commit-msg.sh): local commit validation.

## Optional agent workflow

Codex is optional for editing documentation and running local checks. For infrastructure work with agents, follow [AGENTS.md](AGENTS.md#coordination): the main session coordinates `terraform_engineer` and `infrastructure_reviewer`. See the [Codex guide](.codex/README.md) for setup and diagnostics.

## Promotion and authorization

The target flow promotes the same immutable Git SHA through `dev` → `qa` → `preprod` → `prod`, with separate roots/states and a fresh reviewed plan for each environment. [ADR 001](docs/adr-001-branching-and-promotion.md) defines sequencing, evidence, and independent approvals; the roots are present, while state isolation and deployment automation still require separate implementation and authorization.

Explicit human authorization for the target and action is required before Azure writes, applies, destroys, real-resource tests, or state mutations. PR approval and agent review do not replace environment-specific plan review or deployment approval. Follow [AGENTS.md authorization](AGENTS.md#authorization) before any such operation.

## Contribution

Follow the [Pipesor contribution policy](https://github.com/pipesor-org/.github/blob/main/CONTRIBUTING.md) for short-lived branches from `main`, English Angular-style Conventional Commits, reviewed PRs, and squash merges. [ADR 001](docs/adr-001-branching-and-promotion.md) describes their application to infrastructure; documented GitHub plan limitations remain relevant to enforcing checks and approvals.

### Commit messages

The shared policy defines message types and breaking-change notation. Local [Commitlint configuration](commitlint.config.js) requires lowercase scopes and subjects, no trailing subject period, and a maximum 72-character header. Default ignore rules are disabled, so every message must pass validation.

Enable hooks using [repository setup](#requirements-and-setup). GitHub uses the PR title and body as the default squash message; preserve migration notes and any `BREAKING CHANGE:` footer in the PR body and final squash commit.
