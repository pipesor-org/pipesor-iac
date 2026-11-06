# MVP messaging topology assessment

Status: Candidate; implementation deferred. Reviewed: 2026-11-06.
The project owner explicitly deferred topology implementation pending contracts
and approval evidence. Existing namespace approval is unchanged.

## Evidence

Reviewed IaC `04874fb31d5109a90e91fad5889c66209f8a1c85` and read-only
`pipesor-docs@c0871ac9a62bad62b8c679255fe0a4b9c6574d2e`, including architecture,
domain/design models, ADR-010/013/015/018 and the decision register. Relevant
service readiness revisions: ingestion `3265657`, Pipeline `9bba9ba`, Log/Event
`ef6cf56`, NLP `661ca0f`. Their deployment records explicitly are not approved
contracts for IaC consumption.

The docs overlay is outside that pinned Git revision: `pending-decisions.md`
SHA-256 `3e153d9a467cef72caa937fc2b2e2e7642ebcbee1f98465edc8951df8c799c42`;
`stage-5-result.md` SHA-256
`1a1228c6869cbe602ff78c0ba0c87466db4b6c7cc9d3500f6b6c3e9e7d86d6a0`.
Reported approver names do not establish a retrievable approval or its acceptance
rule. PD-015 exact-topology provenance remains unresolved.

## Supported candidate and missing contracts

| Participant | Documented broker responsibility |
| --- | --- |
| Ingestion/Normalization | Sole declared publisher of normalized, protected events. GitHub sends to ingestion, not directly to Service Bus. |
| Pipeline | Consumes execution events to register pipeline context. |
| Log/Event | Consumes events to register diagnostic evidence. Workload Blob remains excluded. |
| NLP | Consumes eligible normalized events, then calls Correlation synchronously. |
| Correlation, Recommendation, RAG | No broker subscription/publication path declared. |

One topic with three service-specific subscriptions is the minimum modeled
candidate. Reuse the existing Standard namespace. Do not introduce queues, retry
topics or forwarding chains. Subscription DLQs are built-in, not separate Azure
resources. No entity names, event catalogue, schemas, property mappings or filter
expressions are approved. Conceptual context fields are not an executable schema.
All-pass fan-out requires explicit confirmation that every consumer needs every
published event. Restrictive rules must not retain an unintended true/default rule.

Preserve these decisions for a versioned messaging contract (PD-033):

- Event types/versioning, stable message/context identifiers and property mapping;
  a consumer eligibility matrix before choosing filters. Filters inspect properties,
  not message bodies.
- Explicit entity names and TTL based on useful diagnostic age and tolerated
  backlog/outage. ADR-013 evidence retention is not a broker TTL requirement.
- Peek-Lock settlement, completion point, lock/renewal budget, delivery count,
  bounded SDK retries versus broker redelivery and consumer idempotency. These are
  proposals/contracts, not guarantees provided by Terraform.
- Expiry dead-lettering and an inspection/replay/disposal owner. DLQ messages do not
  expire automatically. Duplicate detection, sessions and partitioning remain
  unselected without supporting requirements.
- Bounded sanitized payloads within Standard's 256 KB message limit, including
  properties; oversized events do not authorize restoring Blob.
- Caller identities and scoped access: propose topic Data Sender for ingestion
  and subscription Data Receiver per consumer, with deployers/operators separate.
  Do not grant runtime namespace administration or assume scaler permissions.

PD-031 remains an integration blocker: three subscriptions progress independently.
NLP can reach Correlation before Pipeline/Log/Event have persisted referenced data.
Define missing-reference handling and safe retries; no persistence barrier, new
orchestrator or cross-owner database write is implied by this candidate.

## Future implementation gate

Require reviewable topology approval and accepted names, event-to-consumer rules,
delivery/retention settings and race behavior before implementing affected entities.
Defer grants until caller identities are known. Existing roots/states and provider
versions can be preserved using stable Service Bus 2024-01-01 APIs; this assessment
does not authorize an implementation or dependency upgrade. Traffic/cost inputs
and actual deployability remain unverified. Continue independent work separately.

## References

- [Filter semantics](https://learn.microsoft.com/en-us/azure/service-bus-messaging/topic-filters)
- [Settlement and locks](https://learn.microsoft.com/en-us/azure/service-bus-messaging/message-transfers-locks-settlement)
- [Expiration](https://learn.microsoft.com/en-us/azure/service-bus-messaging/message-expiration) and [DLQs](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-dead-letter-queues)
- [Entra authorization](https://learn.microsoft.com/en-us/azure/service-bus-messaging/authenticate-application) and [quotas](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-quotas)
- [Topic API](https://learn.microsoft.com/en-us/azure/templates/microsoft.servicebus/2024-01-01/namespaces/topics)
- [MVP baseline](mvp-resource-baseline.md#shared-messaging-foundation)
