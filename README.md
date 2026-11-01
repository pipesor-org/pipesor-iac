# Pipesor infrastructure

The Terraform development foundation for Pipesor's planned Microsoft Azure infrastructure. This repository maintains infrastructure decisions, contribution tooling, and repository-local agent configuration.

## Current state

- No Terraform roots, provider configuration, remote state, or cloud CI identity exist. This foundation provisions nothing.
- Azure subscriptions, regions, networking, compute, identity, and service topology remain undecided.
- Environment isolation and promotion are an accepted target strategy, not implemented deployment automation.
- Azure credentials are unnecessary for working with the current foundation. Future resource and state operations follow the authorization requirements in [AGENTS.md](AGENTS.md#authorization).

## Requirements and setup

Run commands from the repository root.

- Bun: use the version pinned in [package.json](package.json). Commitlint runs directly with Bun; Node.js is not required.
- Standalone [Lefthook 2.2.2](https://github.com/evilmartians/lefthook/releases/tag/v2.2.2): install the binary for your OS/architecture on `PATH`, verify its SHA-256 against the release's `lefthook_checksums.txt`, and check `lefthook version`.
- Terraform CLI: needed for the formatting check below. The repository has no CLI version pin yet; select and pin a tested version when adding the first Terraform implementation.

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

There are currently no Terraform files to format. A successful formatting check does not establish infrastructure validity or Azure deployability. Once roots/modules exist, follow [AGENTS.md verification](AGENTS.md#verification) for backend-disabled initialization, validation, affected callers, and reviewed safe tests.

For hook or Commitlint changes, complete setup above and also run:

```sh
lefthook validate
bun run test
```

The [Commitlint workflow](.github/workflows/commitlint.yml) validates hook configuration, accepted/rejected messages, PR commits, PR titles and prospective squash messages, and the latest commit on pushes to `main`. PR title/body edits rerun validation. These checks do not plan or deploy infrastructure.

## Repository guide

- [Technical direction](docs/architecture.md): current foundation, intended layout, state handling, and provider/module selection criteria.
- [ADR 001](docs/adr-001-branching-and-promotion.md): environment isolation, promotion, approval requirements, and documented GitHub enforcement limitations.
- [Agent and engineering guidance](AGENTS.md): coordination, documentation tools, authorization boundaries, and verification.
- [Optional Codex setup](.codex/README.md): repository-local roles, configuration, and startup checks.
- [lefthook.yml](lefthook.yml), [commitlint.config.js](commitlint.config.js), and [hook tests](tests/commit-msg.sh): local commit validation.

## Optional agent workflow

Codex is optional for editing documentation and running local checks. For infrastructure work with agents, follow [AGENTS.md](AGENTS.md#coordination): the main session coordinates `terraform_engineer` and `infrastructure_reviewer`. See the [Codex guide](.codex/README.md) for setup and diagnostics.

## Promotion and authorization

The target flow promotes the same immutable Git SHA through `dev` → `qa` → `preprod` → `prod`, with separate roots/states and a fresh reviewed plan for each environment. [ADR 001](docs/adr-001-branching-and-promotion.md) defines sequencing, evidence, and independent approvals; no environment roots or deployment workflows exist yet.

Explicit human authorization for the target and action is required before Azure writes, applies, destroys, real-resource tests, or state mutations. PR approval and agent review do not replace environment-specific plan review or deployment approval. Follow [AGENTS.md authorization](AGENTS.md#authorization) before any such operation.

## Contribution

Follow the [Pipesor contribution policy](https://github.com/pipesor-org/.github/blob/main/CONTRIBUTING.md) for short-lived branches from `main`, English Angular-style Conventional Commits, reviewed PRs, and squash merges. [ADR 001](docs/adr-001-branching-and-promotion.md) describes their application to infrastructure; documented GitHub plan limitations remain relevant to enforcing checks and approvals.

### Commit messages

The shared policy defines message types and breaking-change notation. Local [Commitlint configuration](commitlint.config.js) requires lowercase scopes and subjects, no trailing subject period, and a maximum 72-character header. Default ignore rules are disabled, so every message must pass validation.

Enable hooks using [repository setup](#requirements-and-setup). GitHub uses the PR title and body as the default squash message; preserve migration notes and any `BREAKING CHANGE:` footer in the PR body and final squash commit.
