# Pipesor infrastructure agents

## Coordination

- Read [architecture](docs/architecture.md) and
  [ADR 001](docs/adr-001-branching-and-promotion.md) before Terraform work. Add infrastructure
  only for an agreed requirement; the current implementation is limited to the
  resource-group foundation, separate state-bootstrap configuration and optional
  shared MVP container platform.
- The main session scopes the task, delegates implementation to `terraform_engineer`,
  verifies results, then asks `infrastructure_reviewer` to review the final diff.
  Resolve findings and repeat affected checks/review. Handle small documentation-only
  tasks directly. Specialists do not delegate.
- Give specialists the objective, owned files, constraints and acceptance checks.
  Allow only one writer per file. Use model/effort settings in native configuration;
  do not pass model overrides during delegation.
- Follow ADR 001 for branching, Angular-style Conventional Commits, PR validation
  and promotion. Preserve separate roots/states for `dev`, `qa`, `preprod`, `prod`;
  promote the same SHA sequentially with a fresh reviewed plan per environment.
  Never substitute environment branches, cross-environment plans or agent review
  for human approval. Do not assume GitHub plan limitations are enforced controls.
- Report changed behavior, commands/results, findings and skipped verification in
  the PR. Keep session-specific check results out of permanent repository guidance.

## Documentation tools

- Use the existing Terraform MCP Server for module/provider documentation at the
  versions selected in code and lock files. Search first, then fetch details using
  the returned identifier. A latest-version lookup does not authorize upgrades.
- Use Context7 for broader Terraform, Azure and SDK documentation questions: resolve
  the library ID, select official sources, then query the specific behavior/version.
  These are documentation lookups, not a replacement for inspecting the diff.
- When tools are unavailable or coverage is stale, ambiguous or missing, open
  official HashiCorp, Microsoft Learn or AVM documentation. Cite sources and relevant
  versions; report lookup gaps. Never send secrets, state or proprietary code in queries.
- Specialists inherit available tools from the parent. Check availability; do not
  duplicate MCP registrations or change global configuration.

## Authorization

- Work autonomously on local implementation, documentation lookup and safe checks.
  **Explicit human authorization for the target and action is required before
  `terraform apply`, `terraform destroy`, real-resource tests or any Azure write**,
  via CLI, SDK, MCP or CI. Delegation and automatic approval are not human authorization.
- State migration/mutation, import, force-unlock, remote run creation and HCP Terraform
  workspace/variable changes also require authorization. Never enable auto-apply or
  work around these gates with alternative tools.
- Inspect providers, data sources, provisioners, external programs and tests before
  execution. A plan can have side effects; disable automatic Azure provider registration
  using the selected provider version's documented setting. Use no Azure resource-write
  credentials for autonomous checks; scope state-locking permissions separately.
  Never commit secrets, state or plans.
- Do not modify neighboring repositories or global Codex configuration. A reviewer's
  no-edit instruction does not create a separate OS sandbox.

## Verification

- For hook or Commitlint changes, run `bun install --frozen-lockfile`,
  `lefthook validate` and `bun run test` with the Lefthook version in the README.
  Follow [README](README.md#commit-messages) for message rules and local hook setup.
- Run from the repository root:

  ```bash
  git diff --check
  terraform fmt -check -recursive
  ```

- Once Terraform exists, run in each affected root/module and affected callers:

  ```bash
  terraform init -backend=false -input=false
  terraform validate
  ```

  Use trusted provider/module sources. Add `-lockfile=readonly` once a root's lock
  file exists; change dependencies intentionally. Backend-disabled initialization
  does not connect to remote state or prove deployability.
- Test nontrivial behavior with native `*.tftest.hcl` assertions. Inspect all run
  blocks, setup modules and providers first: `terraform test` defaults to apply.
  Only plan-only runs without write side effects or fully mocked Azure providers
  may run autonomously. Select reviewed files with
  `terraform test -filter=tests/<safe-file>.tftest.hcl`. See HashiCorp's
  [mocking](https://developer.hashicorp.com/terraform/language/tests/mocking) and
  [test command](https://developer.hashicorp.com/terraform/cli/commands/test) references.
- A real Azure plan is a separate check after validation: confirm tenant,
  subscription, environment and backend, inspect side effects and protect output
  as sensitive. Validation and mocked tests do not establish Azure deployability.
- Add credential-free CI checks with the first Terraform roots. Report what ran
  and what remains unverified; do not create empty validation/deployment workflows.
