# Incremental infrastructure priorities

Reconciled: 2026-11-16 under [ADR 005](adr-005-academic-mvp-scope-and-cost-governance.md). Earlier review: 2026-11-06, IaC
`6666fb8cc3bc2fcce370c2cdc93c3348bdc64e8d` and current architecture/ADRs.
This is a risk-based working order, not approval of pending resource choices.

The [messaging assessment](messaging-topology-assessment.md) records the candidate
topic/three subscriptions and unresolved contracts. Its implementation remains
deferred. Continue targeted research on blocked work without making it a dependency
of independent engineering checks.

| Priority | Increment | Gate / risk |
| --- | --- | --- |
| 1 | Test the approved foundations together in each environment root | Implemented and merged; retain existing checks rather than create another test-only increment. |
| 2 | Native cost visibility and DEV attribution | [ADR 005](adr-005-academic-mvp-scope-and-cost-governance.md) supersedes the dedicated-subscription/USD 300 assumptions. Verify actual offer, credit/expiry, currency and supported native usage views; review a complete DEV estimate. Terraform budgets and admin bootstrap are deferred, not DEV prerequisites. |
| 3 | Runtime identities and grants | System-assigned identities with future Container Apps are approved. First-service execution/access contracts remain pending; no standalone identity resource is needed. |
| 4 | Extract shared network / monitoring modules | ADR 002 is proposed; preserve current addresses/lifecycle until a concrete refactor is approved. |
| 5 | Messaging, applications, models, domains and integration | Each requires its event, runtime, model, identity or domain contracts. Ordering within this group follows contract readiness, not this row number. |

## Completed local composition increment

The implemented checks add a fully mocked combined plan for the existing optional
foundations in each root, extending existing native tests and independent caller
assertions. They close the gap in simultaneous root composition and verify
PostgreSQL's actual platform network and distinct subnet, the shared Insights
workspace, resource-group/environment and explicit location forwarding, safe
outputs and approved security boundaries. Detect unapproved resource classes
without freezing every transitive AVM object into a brittle count assertion.

This changes no resource configuration, dependencies, state or architecture. It
does not enable all foundations by default or require funding four environments.
Keep filtered mocked tests, backend-disabled read-only initialization, validation
and independent review. Passing checks establish local contract consistency, not
Azure deployability. Local and CI execution still consume runner time; no runtime
or GitHub billing estimate is claimed.

## Approved identity lifecycle; pending deployment contract

No further Azure resource in this workstream is ready for an independent increment
without resolving a decision or contract. Do not create unused identities or placeholder
applications to increase the resource count. Existing Foundry account/project
identities do not establish the identity type for future ACA callers.

1. **Identity lifecycle (accepted 2026-11-06):** the project owner approved the
   recommended system-assigned identities with each future Container App for the
   current MVP. They follow the app lifecycle and cannot be granted access before
   their principal exists. No standalone identity resource or runtime grant is
   authorized by this policy alone. Per-service/per-environment user-assigned identities enable
   preauthorization and independent lifecycle, with explicit assignment, ownership
   and cleanup responsibilities. Do not share one runtime identity among unrelated
   services. That alternative is not selected and needs a separate decision if
   preauthorization or survival across app replacement becomes necessary.
2. **First deployable service contract (still pending):** identity policy approval
   does not supply an image, execution settings or accepted access scopes. Require
   the relevant PD-035 runtime/access slice before app deployment or runtime grants.
   The checked service readiness records still explicitly state that they are not
   approved for IaC consumption. Reconcile identity policy there through the
   respective service owners; this repository does not modify those records.

Managed identities have no additional charge, but attached workloads still incur
their normal charges. Caller permissions, identity propagation and deployment
readiness remain unverified. Identity approval closes only the lifecycle choice;
it does not close PD-035 or authorize a placeholder application.

## Boundary with the state/bootstrap workstream

Under [ADR 004](adr-004-mvp-state-and-deployment.md), only dev is selected for the
academic MVP. No infrastructure deployment, including bootstrap or subscription
controls, may proceed before application implementation and local integration/
validation evidence, followed by explicit target/action authorization. The other
roots remain available for future commissioning, not current provisioning.

Leave bootstrap/state-store code, backend declarations, state custody/access and
all migrations to the separate workstream. No parallel ownership of those files
or operations is established by this priority review. ADR 002 extraction remains
proposed and deferred: it is not needed to create another independent increment
and can affect addresses/lifecycle. Coordinate explicit file ownership before any
future change intersects that boundary. Retain all existing human approval gates.

Identity references reviewed 2026-11-06:
[ACA managed identities](https://learn.microsoft.com/en-us/azure/container-apps/managed-identity),
[identity selection guidance](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/managed-identity-best-practice-recommendations),
[identity overview](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview).

References: [Terraform mocking](https://developer.hashicorp.com/terraform/language/tests/mocking),
[budget behavior](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets),
[managed identity lifecycle guidance](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/managed-identity-best-practice-recommendations).
