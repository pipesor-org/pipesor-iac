# Architecture consumed by the resource-group foundation

## Source snapshot and authority

Read-only source: `pipesor-org/pipesor-docs`, local checkout
`/home/jhon/code/pipesor/pipesor-docs`, Git revision
[`c0871ac9a62bad62b8c679255fe0a4b9c6574d2e`](https://github.com/pipesor-org/pipesor-docs/tree/c0871ac9a62bad62b8c679255fe0a4b9c6574d2e).
The source repository was not modified by this increment.

Two consulted documents contained local supplements beyond that revision:

| Path | Git status when consulted | SHA-256 of consulted bytes |
| --- | --- | --- |
| `docs/architecture/pending-decisions.md` | Modified tracked file | `3e153d9a467cef72caa937fc2b2e2e7642ebcbee1f98465edc8951df8c799c42` |
| `docs/architecture/stage-5-result.md` | Untracked file | `1a1228c6869cbe602ff78c0ba0c87466db4b6c7cc9d3500f6b6c3e9e7d86d6a0` |

These hashes identify local evidence; neither supplement is represented as part of
the immutable Git revision. The stage-5 report records an original investigation
at `7c0bd1f9eaa47d6e48e5bffb8c1a5d5b49fb405e` and a later local contrast with
`c0871ac9`. Its conclusions are descriptive, not approval of missing contracts.

The consulted scope includes `AGENTS.md`, `model/architecture.yml`,
`model/domain.yml`, `model/domain_decisions.md`, `model/design.yml`,
`model/design_decisions.md`, the ADR index and applicable ADRs, reconciliation,
source-provenance register, pending-decisions register and stage-5 report.
Architecture authority is by subject: Charter for scope; architecture/invariants
and applicable Accepted ADRs for architecture; drift and technology ADRs for
technology. Historical ADRs are read with subsequent partial supersession. README,
reports, generated diagrams/SQL and proposed classes are not independent approval.

## Documented decisions and their limits

| Source/IDs | Consumable decision | Implementation boundary |
| --- | --- | --- |
| `deployment.cloud`, `deployment.container_hosts`; ADR-001/015/018 | Azure; seven backend services on Container Apps. | No region, subscription, SKU, scale or image/configuration contract selected. The resource group is a prerequisite engineering choice, not a new service or approved workload grouping policy. |
| `azure_service_bus`, `deployment.event_broker` | Service Bus, one topic and three modeled subscriptions. | Exact topology approval evidence remains untraced (PD-015); no messaging resources or behavior selected here. |
| `postgresql_operational_store`, `pgvector_knowledge_store`; ADR-018 | One physical PostgreSQL instance with pgvector; schemas/table ownership and logical cross-schema references. | No database service/SKU/version/network or schema migrations selected. IaC does not take ownership of application tables. |
| `object_evidence_store`, DD-006 | Blob references for extensive evidence. | Selection is declared in the model; original approval evidence is missing (PD-016). No storage, access policy or lifecycle rules created. |
| `deployment.observability_platform`; ADR-002 | Monitor and Application Insights. | Does not specify workspace topology, retention for telemetry or sampling. |
| `entra_id`, `api_management`; ADR-003/016 | Entra user identity and APIM perimeter. | No app registrations, role assignments, workflow identity or API policy selected. |
| `github`, `deployment.github_authentication`; ADR-005/016 | Read-only GitHub App with installation tokens; workflow publishes artifacts natively. | Secret storage deliberately unspecified; do not infer Key Vault. |
| `deployment.llm`; ADR-004/007/015 | Azure OpenAI by API; embeddings provider selected. | Concrete LLM variant, embedding model and dimension remain open. |
| ADR-008/018 | React/TypeScript dashboard on Static Web Apps. | Does not supply a build/delivery or API contract. |
| ADR-009/010/011/012/014/017 | No reporting/audit/detector services, LogBERT, independent Privacy Gateway, notifications or direct scanner APIs in the current MVP; diagnostic components remain internal. | No excluded components restored to complete infrastructure. |

The overall architecture is still `draft`; `confirmed` describes documentary
status, not implementation or deployment. ADRs retain their recorded `Accepted`
status; independent approval evidence is not available for their individual acts
(PD-014). Charter/drift provenance and approval gaps (PD-012/013), Blob/topology
(PD-015/016), corporate retention policy (PD-017), cited approval prompts (PD-018)
and absent TI/spreadsheets (PD-019) remain visible. Missing evidence is not proof
that approval never occurred, and does not universally block independent work.

Domain A-001–012 remain assumptions. `pipeline_access_grants` retains its
`inferred`/`ia_only` qualification. Design classes and DC-001–006 remain proposed.
Neither DQ-001–006 nor DCQ-001–003 is closed by infrastructure implementation.
CF-001/PD-002 is preserved as a governance discrepancy; no override is executed.
The technical interval of DD-015 and the Charter's comparative TMD retain their
different purposes and boundaries (PD-001).

## Increment and protected boundaries

The increment creates Terraform definitions for one resource group per environment,
using the already evaluated naming module and a suitable resource-group AVM.
The shared composition enforces the repeated environment/name/location contract.
Four callers fix `dev`, `qa`, `preprod` and `prod` respectively and require explicit
subscription and resource-group metadata location inputs. This original increment
selected no real values. ADR 004 now records an owner-verified temporary dev target;
metadata location remains pending and does not impose future workload locations.

The initial group is a reversible local engineering prerequisite for Azure resource
management. It is not an additional product component, commitment to put all future
resources in one group, or evidence of approved service topology. The four roots
and partial backends preserve the IaC repository's ADR 001 target boundaries;
backend containers, scoped permissions, locking/recovery and actual remote states
must be established separately. No cloud resources are created during validation.

Relevant invariants remain obligations for later increments: INV-001/002 and
CTRL-002 protect evidence before AI; INV-003 requires read-only least privilege;
INV-005/006 preserve probable cause and human review; INV-007/008 exclude autonomous
remediation and model training; INV-009 declares 365-day retention for logs,
diagnoses and evidence only; INV-010/CTRL-006 separate evaluation from RAG.
The resource-group tests cannot establish those runtime properties. No retention
period is extended to telemetry, audit, corpus or configuration.

## Unresolved dependencies and next increment

| Required before the affected work | Pending decisions/contracts |
| --- | --- |
| A real resource-group plan | Confirm tenant, target subscription, metadata location, separately established backend, scoped identity and permissions. Azure writes/state operations require separate explicit human authorization. |
| Service resource configuration | Agree location, capacity/SKUs, network/access requirements and lifecycle for that service; product names alone do not supply them. |
| Integrated backend delivery | PD-035: images/version references, configuration inputs/outputs, accesses, migration execution and promotion responsibilities. |
| Messaging and REST integration | PD-033/034, PD-010/011 and PD-031: versioned event/API contracts, context/read projections, identity/reference availability, duplicate/retry behavior. |
| Real access and credentials | PD-027/036 and DQ-005/006 (PD-007/008): secret mechanism, workflow-to-APIM identity/authorization and functional access policies. |
| Embeddings, RAG and LLM | PD-005/006/023/026: model/dimension, authorized corpus, load/update mechanism and concrete LLM variant. |
| Data operations and evaluation | PD-030 with PD-017 for retention; PD-001/021/022 for comparative measurement/protocol evidence. |

Current sequencing is refined by [ADR 004](adr-004-mvp-state-and-deployment.md):
only dev is selected in temporary Azure for Students/UPC infrastructure, and
implementation, local integration and validation of the application services block
all provisioning. State-bootstrap configuration can be prepared and mocked locally;
Azure bootstrap itself requires later explicit authorization, pending access and
deployment inputs. Actions OIDC dev deployment uses ADR 004's accepted procedural
approval model; verify the Debian VirtualBox runner, network, encryption/recovery
and explicit activation authorization first. No other environment is commissioned.

## Dependency documentation

Versions: Terraform CLI 1.17.1; naming AVM 0.3.0; resource-group AVM 0.4.0;
transitive interfaces AVM 0.6.0; AzAPI 2.9.0. Provider locks record Random and ModTM.

The [official resource-group AVM source](https://github.com/Azure/terraform-azurerm-avm-res-resources-resourcegroup/tree/v0.4.0)
requires AzAPI `~> 2.4`, compatible with the selected 2.9.0;
[its provider schema](https://github.com/Azure/terraform-provider-azapi/blob/v2.9.0/docs/index.md)
defines registration/preflight controls. Native tests follow HashiCorp's
[test](https://developer.hashicorp.com/terraform/language/tests) and
[mocking](https://developer.hashicorp.com/terraform/language/tests/mocking) contracts.
The [naming implementation](https://github.com/Azure/terraform-azure-avm-utl-naming/tree/v0.3.0)
and [Microsoft resource-group naming rules](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftresources)
provide the naming contract: subscription scope, 1–90 allowed characters and no
trailing period. Generated names are not reservations or availability checks.
