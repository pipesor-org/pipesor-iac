# ADR 003: ACA native ingress for the MVP

Status: Accepted. Date: 2026-11-05. Scope: Pipesor MVP infrastructure.
Authority: explicit project-owner approval in the infrastructure implementation
session. This decision authorizes the design direction, not Azure provisioning.

## Context

The architectural review of the Project Charter v1.3 and research thesis found
requirements for secure access, confidentiality, traceability, auditing and
controlled exposure, without a Charter mandate for dedicated gateway infrastructure.
The thesis previously prescribed an API Gateway and mentioned APIM, Application
Gateway and WAF in its logical and physical architectures. These were proposed
solutions; the review did not establish an independent MVP requirement for them.
This records the supplied review conclusion, not a new audit of academic documents.

## Decision

Use Azure Container Apps native ingress for the controlled MVP. Do not introduce
APIM, Application Gateway, Azure Front Door, a custom API gateway or a reverse
proxy solely to consolidate routes. Preserve the seven approved service boundaries.
Reconcile the canonical architecture in `pipesor-docs` separately; this local
decision does not edit or imply reconciliation of that source or the thesis.

Expose only endpoints required by authorized external consumers. Configure
internal-only services without public ingress. Use HTTPS/TLS and Microsoft Entra
ID for applicable authentication flows, with roles, permissions, scopes and
resource-level authorization enforced by the responsible application services.
Preserve least privilege, auditability, traceability and Privacy by Design.
An external-capable ACA environment does not itself authorize public app exposure.

## Alternatives and consequences

- **APIM:** rejected for the current MVP because dedicated centralized API
  governance is not a demonstrated requirement; its configuration and operation
  would add scope.
- **Application Gateway, including WAF:** rejected for the current MVP because a
  dedicated routing/WAF requirement has not been established. This decision does
  not claim security equivalence between ACA ingress and a WAF-enabled gateway.
- **Custom gateway or routing proxy:** rejected because route consolidation alone
  does not justify another service and its implementation/operational burden.

The absence of WAF and centralized rate limiting is an accepted MVP design
limitation. ACA ingress does not provide APIM-equivalent centralized API
governance. Reassess if mandatory corporate security policies or deployment
requirements demand these capabilities; corporate policy compliance is unverified.
Report a conflicting mandatory requirement explicitly before changing this scope.

Ingress does not establish application authorization, a unified API hostname or
approved service delivery contracts. Endpoint exposure, Entra audiences and caller
flows, application access checks, sanitized audit/trace propagation and any required
application throttling remain implementation and validation dependencies. Do not
infer ports, probes, routes or identity grants from this decision.

No gateway resources have been implemented, so no resource removal, migration or
Terraform state reconciliation is required. Keep existing environment/state
boundaries and all plan, apply and promotion approval gates under
[ADR 001](adr-001-branching-and-promotion.md).

## References

- [MVP resource baseline](mvp-resource-baseline.md)
- [Infrastructure architecture](architecture.md)
- Project-owner architectural review and approval supplied on 2026-11-05;
  canonical and academic source reconciliation remains separate.
