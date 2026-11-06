# Incremental infrastructure priorities

Reviewed: 2026-11-06. Source: IaC
`04874fb31d5109a90e91fad5889c66209f8a1c85` and current architecture/ADRs.
This is a risk-based working order, not approval of pending resource choices.

The [messaging assessment](messaging-topology-assessment.md) records the candidate
topic/three subscriptions and unresolved contracts. Its implementation remains
deferred. Continue targeted research on blocked work without making it a dependency
of independent engineering checks.

| Priority | Increment | Gate / risk |
| --- | --- | --- |
| 1 | Test the approved foundations together in each environment root | Existing contracts; fully mocked local checks; no Azure resources or consumption; reversible test changes. Proceed within authorized local verification scope. |
| 2 | Cost visibility / budget configuration | Dedicated USD subscription and one 300 USD monthly email-only budget are now approved; see [subscription controls](subscription-controls.md). Explicit dates, recipients, operational ownership and backend custody remain deployment inputs. Budgets do not stop spending. |
| 3 | Runtime identities and grants | Assignment type, lifecycle, callers and scope must be accepted. Empty identities are not useful progress. |
| 4 | Extract shared network / monitoring modules | ADR 002 is proposed; preserve current addresses/lifecycle until a concrete refactor is approved. |
| 5 | Messaging, applications, models, domains and integration | Each requires its event, runtime, model, identity or domain contracts. Ordering within this group follows contract readiness, not this row number. |

## Selected local increment

Add a fully mocked combined plan for the existing optional foundations in each
root, extending existing native tests and independent caller assertions. Separate
opt-in tests already exist; the gap is simultaneous root composition. Verify
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

References: [Terraform mocking](https://developer.hashicorp.com/terraform/language/tests/mocking),
[budget behavior](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets),
[managed identity lifecycle guidance](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/managed-identity-best-practice-recommendations).
