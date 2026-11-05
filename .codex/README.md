# Repository-local Codex workflow

This is an optional workflow for using the repository's existing native Codex configuration. Start with the [repository setup](../README.md#requirements-and-setup), [AGENTS.md](../AGENTS.md), and [technical direction](../docs/architecture.md).

## Start a session

Run `codex --search` from this repository using your existing authenticated Codex installation. Project configuration loads only for trusted projects. No global configuration changes, additional MCP server installation, or external orchestrator are required.

The main session coordinates `terraform_engineer` and `infrastructure_reviewer`. For example:

> Implement the agreed Terraform change using terraform_engineer, run the safe
> checks, then have infrastructure_reviewer review the final diff. Resolve
> findings and report evidence. Do not deploy or change Azure resources.

Model and effort settings live in native configuration:

- [Main coordinator](config.toml)
- [Terraform engineer](agents/terraform-engineer.toml)
- [Infrastructure reviewer](agents/infrastructure-reviewer.toml)
- [Cloud researcher](agents/cloud-researcher.toml)

Use `cloud_researcher` for Azure offer eligibility, quotas, pricing and architecture
trade-offs before selecting infrastructure. It returns sourced MVP and longer-term
recommendations with assumptions and decision gaps. For example:

> Have cloud_researcher estimate the proposed MVP's pay-as-you-go costs, including
> idle networking, image registry, database, messaging, telemetry and inference.
> State usage assumptions and uncertainty, then compare actual costs once deployed.
> Research only; report what needs a human decision.

Its no-edit instruction is a role constraint, not a separate OS sandbox; permissions
are inherited from the parent session. Implementation stays with the coordinator
and engineer after the relevant decisions are accepted.

Credentials and effective permissions come from the caller. Azure credentials are unnecessary for the current foundation. Existing Context7 and Terraform MCP tools are used when available, following [AGENTS.md documentation guidance](../AGENTS.md#documentation-tools).

## Configuration checks

To check configuration loading without a model request, run from a trusted repository:

```sh
codex --version
codex --strict-config app-server --print-startup-config
codex debug prompt-input 'List the repository roles and authorization boundary.'
```

The prompt dump should include repository guidance and all three specialist descriptions in the available roles. Start a fresh session after agent configuration changes.

For a live smoke check, ask the engineer for a no-edit architecture summary, then ask the reviewer to inspect the foundation and confirm both reports return. These checks verify agent setup; they do not validate or deploy infrastructure.

Follow [AGENTS.md](../AGENTS.md#authorization) for authorization and [verification requirements](../AGENTS.md#verification) for Terraform checks. Delegation and agent review do not authorize cloud writes or replace human deployment approval.
