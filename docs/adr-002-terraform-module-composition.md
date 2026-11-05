# ADR 002: Terraform module composition and boundaries

Status: Proposed. Date: 2026-11-04. Scope: Pipesor infrastructure.
This records the rationale for the current composition and a proposed evolution;
it does not authorize a module refactor, state migration or Azure operation.

## Context

Pipesor has separate environment roots and a separate state-bootstrap lifecycle
under [ADR 001](adr-001-branching-and-promotion.md). The current reusable modules
express capabilities: `resource-group` combines naming and resource creation;
`state-store` combines storage, recovery and scoped access; `container-platform`
combines networking, the Container Apps environment and monitoring.

The initial container platform is one complete MVP increment. Its network and
workspace are currently created with the hosting environment, but later resources
such as PostgreSQL connectivity and Application Insights may also consume them.
Leaving shared infrastructure owned by a hosting module would couple those
consumers to the hosting module's configuration and lifecycle.

One module per Azure resource is another common structure. A module can usefully
enforce a repeated resource contract, but wrapping every resource mechanically
does not necessarily improve reuse or ownership. Module boundaries should follow
the responsibility and contract they express rather than resource count.

## Proposed decision

Use capability-oriented module composition with relatively flat environment
roots. Roots supply environment inputs and connect module outputs to explicit
inputs. Prefer suitable Azure Verified Modules under the existing
[selection guidance](architecture.md#terraform-and-naming); local modules should
add useful Pipesor composition or repeated policy rather than duplicate provider
interfaces.

Before adding consumers that share the platform's network or monitoring, evaluate
extracting the following boundaries:

| Module capability | Responsibility | Interface to other capabilities |
| --- | --- | --- |
| Network | VNet and approved subnet allocations/delegations | Network and subnet IDs |
| Monitoring | Shared workspace and its access, retention and ingestion controls | Workspace ID |
| Container environment | Container Apps environment and its diagnostic routing | Consume subnet/workspace IDs; export environment ID |

The environment root would compose these peers. The container-environment module
would not create the shared VNet or workspace. These are proposed responsibilities,
not directories or interfaces already implemented. The current `container-platform`
composition remains the implementation until a separately scoped refactor.

Split a module when independent consumers, ownership, lifecycle or testing needs
justify it. Keep related resources together when they form one useful contract.
Do not introduce a generic module for every provider resource or create deeply
nested local stacks merely to classify files.

## Module boundaries and state boundaries

A module is a code and interface boundary, not an independent deployment, state
or access boundary. Network, monitoring and hosting modules can remain in the
same environment root and state. Their resources still participate in the same
plan and apply, subject to the provider's permissions.

Retain the four isolated environment roots/states and separate bootstrap roots.
Consider additional states only for concrete ownership, permission, lifecycle or
failure-impact requirements under ADR 001. Creating a module alone does not
justify another backend, and separate state does not itself grant least privilege.

## Alternatives and consequences

- **Thin resource wrappers everywhere:** consistent file organization, but can
  duplicate provider interfaces without adding a useful contract. Use a wrapper
  where it enforces meaningful repeated behavior, not as a universal rule.
- **A growing platform module owning every dependency:** initially simple, but
  couples shared networking and monitoring to one consumer. Retain the small MVP
  composition now; review extraction as independent consumers are introduced.
- **A state per module:** allows independent execution, but adds state access,
  dependency and operational coordination. Require an actual isolation need.

Explicit inputs and outputs should make dependencies and tests easier to reason
about. More modules also add interfaces, wiring and maintenance. These are design
trade-offs, not measured improvements in cost, reliability or delivery speed.

Any future extraction must preserve security, validation, naming and replacement
behavior. Review Terraform resource-address changes and use appropriate `moved`
blocks when preserving existing objects. Moving code must not accidentally replace
infrastructure. State mutations retain explicit authorization requirements; an ADR
or refactor approval does not authorize them.

## Evidence and academic use

This ADR records an engineering rationale for later thesis/capstone discussion.
It does not establish production readiness, experimental results or improved
maintainability by itself. A later evaluation should identify the implemented
revision and assess the claimed trade-offs against actual changes and operations.

References:

- [HashiCorp: module composition](https://developer.hashicorp.com/terraform/language/modules/develop/composition)
- [HashiCorp: when to write a module](https://developer.hashicorp.com/terraform/language/modules/develop)
- [ADR 001: roots, state isolation and promotion](adr-001-branching-and-promotion.md)
- [MVP resource baseline](mvp-resource-baseline.md)
