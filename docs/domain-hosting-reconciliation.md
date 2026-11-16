# Domain and hosting reconciliation

Status: Research findings and pending proposals. Reviewed: 2026-11-05.
Update 2026-11-06: [Free hosting is approved](mvp-resource-baseline.md#static-web-apps-free-hosting);
references below to the tier awaiting approval describe the earlier assessment.
Authentication implementation, domains, routing and delivery remain separate stages.
This reconciles the supplied handoff with the completed Static Web Apps (SWA)
assessment; it does not approve a hosting tier, domains, routing or deployment.

## Evidence and confirmed boundaries

Consulted IaC `0d9c3558208861b63a434fa93282da7295841968`, frontend
`3c0ccd31d66d9b71fc58453b513faaa5ffa56def` and read-only architecture source
`pipesor-docs@c0871ac9a62bad62b8c679255fe0a4b9c6574d2e`.
Uncommitted architecture supplements are not reproducible from that source SHA.
The handoff reports an already-deployed Cloudflare Workers landing page; preserve
it. Its live deployment, ownership and bindings were not independently verified.

ACA, the seven service boundaries, Entra/application authorization and
[ADR 003](adr-003-mvp-native-ingress.md) remain approved. No APIM, Application
Gateway, Front Door, custom gateway or routing proxy is introduced. DNS naming
does not authorize exposing internal services. SWA is the documented frontend
hosting selection; Free versus Standard and the authentication contract remain
pending. Domain registration, Cloudflare DNS and custom-domain bindings are
proposals, not verified configuration. This review changes no neighboring source.

## Compatibility and targeted corrections

| Handoff item | Finding / pending adjustment |
| --- | --- |
| `pipesor.com` | Preserve the reported Workers landing page. No reason to migrate it to SWA. An active owned Cloudflare zone and custom-domain binding still require verification. |
| `www.pipesor.com` | A separate HTTPS-capable redirect is required; an apex binding or CNAME alone does not redirect a URL. Do not alter existing Worker routing during IaC work. |
| `app.pipesor.com` | Compatible with SWA external DNS and managed TLS on either tier. Custom domains alone do not require Standard. Ownership validation and Azure binding precede use. |
| `api.pipesor.com` | Pending routing contract. Binding to one ACA app reaches that app; DNS cannot distribute URL paths among services. Native ACA environment rule-based routing supports custom domains, but is an additional design choice, not an implemented consequence of ADR 003. Per-service public hostnames are another candidate. Neither requires a new gateway. |
| `docs` and email | Optional/future; no documentation hosting, mailbox, mail DNS or domain purchase is authorized by this handoff. |

If native environment routing is selected, explicitly allow only externally
authorized services/routes. Such routing can expose a target with internal app
ingress; `external: false` alone is insufficient protection when an environment
route targets it. Review route-management permissions, avoid accidental catch-all
routes and require negative access tests. Microsoft documentation includes a
preview API in its example; do not infer current feature support or compatibility
with selected provider/API versions from that example alone.

Use Cloudflare **DNS-only** records for Azure hosts as a proposal. Enabling its
proxy would introduce a separate HTTP intermediary, TLS/caching and origin-security
choice; it is not implied by using Cloudflare DNS and supplies no approved WAF
claim. Keep the Workers apex configuration separate. For subdomains bound to
individual ACA apps, managed certificates require direct CNAME resolution to the app, certificate
authority reachability and compatible CAA records if present. Environment-route
custom domains use their own A/TXT validation and binding procedure. Do not mix
these flows. SWA also requires public validation/renewal DNS and its own binding.
Azure origin TLS remains required.

## Integration and promotion dependencies

`VITE_API_BASE_URL` is illustrative, not an accepted endpoint contract. Vite embeds
`VITE_*` values into the built JavaScript; they are public, and SWA application
settings cannot rewrite an already-built bundle. Rebuilding or patching it per
environment would undermine immutable artifact promotion. Propose a separately
versioned public runtime configuration, or another reviewed hostname mapping,
while promoting the same frontend artifact. This requires frontend/delivery
agreement and is not an implicit Terraform change. Never place secrets in it.

Define a dev/qa/preprod/prod hostname matrix and configuration ownership before
binding domains. Reserving unprefixed `app`/`api` for production and names such as
`app-dev.pipesor.com` are proposals only. Each frontend must reach its own backend
environment and identity configuration. Preserve isolated roots/states and do not
provision four stacks merely to reserve their names.

`app` and `api` are different browser origins. Accept exact CORS origins,
methods/headers and credential behavior; CORS does not replace authentication.
Accept exact Entra redirect/logout URLs, API audiences/scopes and service-level
resource authorization. Generated Azure hostnames can remain reachable after
adding custom domains, so enforce authorization independently of hostname.
TLS and a shared parent domain establish none of these application contracts.

The frontend already builds a verified Vite `dist/` artifact in GitHub CI. Later
deployment should reuse that artifact with application build skipped. Delivery
credentials, operator ownership and approval enforcement remain unresolved; private
GitHub Free repositories do not provide the assumed protected-environment gate.
No workflow or credential creation is authorized here.

## Next decision and implementation boundary

Retain the proposed optional SWA **hosting-only** increment in the existing roots,
default absent, without repository linkage, secret outputs, API proxy or domain
bindings. First approve Free with a public static shell and frontend-managed Entra
authentication, or Standard with platform-enforced tenant-specific authentication.
The existing frontend implements neither authentication nor backend integration.
Then delegate the accepted hosting scope through the established engineering,
mocked-test, credential-free CI and independent-review workflow.

Handle domain bindings later, after ownership, environment names, DNS/TLS operator
responsibilities and the API routing contract are accepted. Existing plan/apply
approval gates remain. No registration, DNS, Azure or Worker writes were performed.

Retain the previous dated hosting estimate ($0 within Free quotas or $9 per
Standard app/month, illustrative East US 2). Custom domains/managed certificates
do not themselves force Standard. Domain registration, Workers/DNS usage, GitHub,
email and optional docs costs are separate unknowns. A complete current MVP cost estimate,
live TLS, corporate compliance and end-to-end authentication remain unverified.

## Focused verification sources

- [Workers custom domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)
- [Cloudflare DNS proxy distinction](https://developers.cloudflare.com/dns/proxy-status/)
- [SWA external DNS](https://learn.microsoft.com/en-us/azure/static-web-apps/custom-domain-external), [domain lifecycle](https://learn.microsoft.com/en-us/azure/static-web-apps/custom-domain) and [quotas](https://learn.microsoft.com/en-us/azure/static-web-apps/quotas)
- [ACA native routing](https://learn.microsoft.com/en-us/azure/container-apps/rule-based-routing) and [route custom domains](https://learn.microsoft.com/en-us/azure/container-apps/rule-based-routing-custom-domain)
- [ACA managed certificate requirements](https://learn.microsoft.com/en-us/azure/container-apps/custom-domains-managed-certificates)
- [Vite 6 environment configuration](https://v6.vite.dev/guide/env-and-mode)
- [ACA CORS](https://learn.microsoft.com/en-us/azure/container-apps/cors) and [Entra redirect URIs](https://learn.microsoft.com/en-us/entra/identity-platform/reply-url)
- [SWA plans](https://learn.microsoft.com/en-us/azure/static-web-apps/plans) and [GitHub environment limits](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
