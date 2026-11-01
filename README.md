# Pipesor infrastructure

Agent-first Terraform development for Pipesor, an AIOps platform for diagnosing
CI/CD pipeline failures on Microsoft Azure. This repository currently contains
development guidance and native Codex agent configuration; it provisions nothing.

Start with [AGENTS.md](AGENTS.md) and the [technical direction](docs/architecture.md).
The [branching and promotion decision](docs/adr-001-branching-and-promotion.md)
defines how a revision progresses through `dev`, `qa`, `preprod` and `prod`.
Follow the organization's [contribution policy](https://github.com/pipesor-org/.github/blob/main/CONTRIBUTING.md).

Run `codex --search` from this repository using your existing authenticated Codex
installation. Trust this repository when Codex asks: project configuration is
loaded only for trusted projects. No global configuration changes are needed.
The main session coordinates `terraform_engineer` and `infrastructure_reviewer`.
For example:

> Implement the agreed Terraform change using terraform_engineer, run the safe
> checks, then have infrastructure_reviewer review the final diff. Resolve
> findings and report evidence. Do not deploy or change Azure resources.

Model and effort settings live in native configuration:

- [Main coordinator](.codex/config.toml)
- [Terraform engineer](.codex/agents/terraform-engineer.toml)
- [Infrastructure reviewer](.codex/agents/infrastructure-reviewer.toml)

Credentials come from the caller. Azure credentials are unnecessary for the current
foundation. Existing Context7 and Terraform MCP tools are used when available;
no additional server installation or external orchestrator is required.

To check configuration loading without a model request, run from a trusted repository:

```bash
codex --version
codex --strict-config app-server --print-startup-config
codex debug prompt-input 'List the repository roles and authorization boundary.'
```

The prompt dump should include repository guidance and both specialist descriptions
in the available roles. Start a fresh session after agent configuration changes.
For a live smoke check, ask the engineer for a no-edit architecture summary, then
ask the reviewer to inspect the foundation and confirm both reports return.
See [verification requirements](AGENTS.md#verification) for Terraform checks.

## Commit messages

Install [Lefthook 2.2.2](https://github.com/evilmartians/lefthook/releases/tag/v2.2.2)
as a standalone binary for your OS/architecture on `PATH`, verifying its SHA-256
against the release's `lefthook_checksums.txt`. Use the Bun version pinned in
`package.json`. Node.js is not required: Commitlint runs explicitly with Bun.
Enable the local `commit-msg` hook once per clone:

```bash
bun install --frozen-lockfile
bun run setup:hooks
bun run test
```

When migrating an existing clone whose `core.hooksPath` is `.githooks`, run
`git config --local --unset core.hooksPath` once before `bun run setup:hooks`.
This removes only that local Git override; it does not change global Git settings.
Inspect any other existing hooks path before changing it. Configuration is
versioned in [lefthook.yml](lefthook.yml); do not
edit the generated hooks. Optional machine-specific overrides belong in the
ignored `lefthook-local.yml`.

The hook rejects messages that fail [Commitlint configuration](commitlint.config.js).
Use `type(scope): subject`, with an optional scope and a header of at most 72
characters. Allowed types are `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`,
`refactor`, `revert`, `style` and `test`, matching the organization contribution policy.
Subjects are lowercase without a trailing period. For example:

```text
feat(infra): add naming module
docs: explain setup
```

Mark breaking changes with `!` in the header and/or a `BREAKING CHANGE:` footer
after a blank line. Explain the migration in the body or footer.
Default ignore rules are disabled, so merge/revert boilerplate and version-only
messages must pass the rules too. Prefer the squash-merge convention in ADR 001.

CI validates the Lefthook configuration, tests accepted/rejected examples through
Lefthook, checks PR titles and the prospective squash title plus body, checks all
commits between a PR's base and head, and checks the latest commit on pushes to
`main`. PR title/body edits rerun validation. GitHub uses the PR title and body
as the default squash message, preserving `BREAKING CHANGE:` footers in the body.
CI validates messages;
it does not deploy. Hook activation is local to each clone, and the GitHub plan
limitations in ADR 001 still apply to enforcing CI before merge.
