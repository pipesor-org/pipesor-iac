# ADR 004: MVP state custody and deployment readiness

Status: Accepted for local preparation, 2026-11-06. No Azure writes, identity
creation, Terraform applies, state migrations or provisioning are authorized.
This refines ADR 001's execution direction and supersedes earlier MVP funding and
deployment-scope assumptions. The MVP runner, procedural dev approval model and
retention policies below are accepted for local scaffolding; activation and Azure
access remain separately authorized prerequisites.

## Supersession notice (2026-11-16)

ADR 005's DEV foundation readiness addendum also supersedes the historical
application-readiness prerequisite for provisioning infrastructure. Application
deployment remains gated on local integration and validation. All Azure writes
and state operations still need explicit target/action authorization.

[ADR 005](adr-005-academic-mvp-scope-and-cost-governance.md) supersedes this
record's administrative-state prerequisite, unchanged USD 300 budget, mandatory
future tenant transition and workstream-specific ownership restrictions. Only DEV
bootstrap is in current MVP scope; unused administrative bootstrap/subscription
control source is retired under ADR 005's subsequent retirement addendum. Future independent subscriptions need not use separate tenants.
The historical text below preserves the 2026-11-06 decision provenance; its
superseded statements are not current instructions. All other readiness, custody,
security and human authorization gates remain in force.

## Deployment scope and temporary Azure target

Only `dev` is selected for the academic MVP. Preserve all four workload roots and
their isolated states; do not provision `qa`, `preprod`, `prod` or their state
accounts. The administrative state account is a separate prerequisite for
subscription controls, not a fifth workload environment.

Do not deploy any infrastructure, including state bootstrap or subscription
controls, until the application services are implemented, integrated locally and
validated. That readiness evidence is necessary but does not itself authorize a
deployment. Every Azure write still requires explicit target/action approval.

The project owner supplied these verified details on 2026-11-06; this record is
not an independent Azure access or billing check:

| Field | Verified value |
| --- | --- |
| Subscription | Azure for Students; Active |
| Subscription ID | `04f339b7-f969-4e17-801c-da6e81e78ffd` |
| Tenant ID | `0e0cb060-09ad-49f5-a005-68b9b49aa1f6` |
| Tenant | Universidad Peruana de Ciencias (`upc.edu.pe`) |
| Subscription owner and initial access/boundary authorizer | Ramiro |
| Primary Terraform operator | Jhon; Entra access pending |

Institutional addresses confirmed directly by the project owner on 2026-11-06:
Jhon, `u202323270@upc.edu.pe`; Ramiro, `u202217062@upc.edu.pe`. The inspected GitHub
profiles/organization information did not expose these addresses; their source is
the owner's confirmation, not independent GitHub verification. Keep them as
contact metadata, not Terraform principal IDs or automatic budget recipients.

This is Ramiro's temporary academic subscription, not project-controlled hosting.
Plan a future rebuild under a project-controlled subscription and tenant. Keep
target IDs as explicit inputs; do not copy state or identity assignments across
tenants implicitly. Data transfer, cutover, replacement identities, costs and
retirement of temporary resources need a separately reviewed plan.

Earlier dedicated-subscription/PAYG estimates remain illustrative only. Do not
assume an upgrade, available credits, supported SKUs, USD billing or the absence of
other subscription costs from the verified details above. Revalidate offer,
currency, quotas, region/SKU availability and a complete dev estimate, including
both state accounts and runner costs, before deployment. The existing $300 budget
and notification policy are unchanged; they do not grant spending authority or
guarantee Students credit coverage.

## State, custody and recovery

Use Azure Blob state with Entra authentication and separate accounts/containers
for the dev workload and subscription controls. Bootstrap owns these stores;
`subscription-controls` continues to own only its budget resource in its own
state. The administrative store must not be the sole custodian of its own
bootstrap state. The workload evidence-storage exclusion remains unchanged.

For the MVP, explicitly select LRS, blob versioning and 30-day blob/container soft
deletion. Keep generic Terraform inputs parameterized; production redundancy and
automated version cleanup are deferred. Soft-delete retention does not expire old
blob versions. Review accumulated storage cost rather than assuming 30-day total
retention. Do not weaken the deny-by-default public-IP firewall, Entra-only access
or container-scoped state grants to accommodate automation.

Under the original DEV procedure, superseded below, Jhon was the primary bootstrap-state custodian and Terraform operator; Ramiro was
the backup custodian and subscription owner/initial access authorizer, not the
routine Terraform executor. Bootstrap state stays on encrypted local storage outside Git, with
restricted permissions and encrypted backups in Jhon's OneDrive Personal and
independent external storage. Encrypt before copying to either backup location;
OneDrive synchronization alone is not independent backup or client-side
encryption. Agree key custody, Ramiro's recovery access, actual paths and backup
verification before use; never put decryption material alongside ciphertext.

Target state recovery is 24–48 hours, not a tested guarantee. After every approved
apply, preserve an encrypted independent state backup in the agreed destinations,
including changed bootstrap state. Verify backup integrity and document the
corresponding SHA/state version and custody handoff without recording secrets.
Retain encrypted state backups for an initial 90 days in the agreed destinations,
with independent recovery access for both custodians. Key recovery and a restore
drill remain operational prerequisites. This does not add automatic cloud deletion.
Database recovery is separate; multiregional recovery is deferred. Restoring state
must reconcile actual resources, lineage and serial; it is not resource rollback.

### Owner-directed DEV custody update (2026-11-19)

This update supersedes the original DEV dual-custodian procedure above.
Jhon is the authorized DEV Terraform operator and state custodian. He may
use his existing Azure Owner session for the initial local-state DEV bootstrap
plan. Owner retains Azure write capability; limit the session to the authorized
planning commands. The initial DEV bootstrap requires no separate planning
principal. Existing Azure Policy and least-privilege runtime identities remain
in force. Future OIDC permission separation is outside this update.

Keep local state, Terraform data and saved plans on BitLocker-protected storage,
outside Git with restricted permissions. Jhon controls the encryption identity
and verifies recovery from at least one independently stored encrypted backup.
Record ciphertext and restored plaintext SHA-256 checks. Retain the approved
backup retention period. Keep the private identity separate from backup copies.
A second recipient, a second backup destination and another person's recovery
test are optional. Apply, RBAC modifications and Azure resource creation still
require explicit authorization. Preserve immutable source, private full-plan
inspection and saved-plan SHA-256 evidence.

## Execution and approval contract

Azure CLI from Jhon's WSL environment is acceptable for separately authorized
initial bootstrap and preparation. GitHub Actions with OIDC is the target for MVP
workload deployments after readiness/access checks and separate activation
approval. The proposed dedicated runner is Jhon's existing Debian VirtualBox VM
with 2 vCPU, 4 GB RAM and 20 GB disk. Its capacity and network path must be verified
before activation; the hardware specification alone is not acceptance evidence.

Ramiro authorizes the initial Azure access and operational boundaries. Jhon then
manages subsequent dev deployments through manually triggered Actions, reviewing
and explicitly authorizing the exact environment-specific saved plan and cost
estimate. Ramiro need not release credentials or approve every dev deployment.
Initial access authorization is not blanket authorization for arbitrary targets,
destructive changes, bootstrap changes or subscription-wide controls. Those remain
separately reviewed operations; `subscription-controls/**` remains with its owner.

This is an explicit MVP refinement of ADR 001: GitHub Free/private does not enforce
independent deployment approvals or protected-branch checks. Dev uses procedural
human authorization by Jhon, not an independently enforced reviewer/credential
release gate. No custom credential-release service or per-run federation changes
are planned. A manual trigger records operator intent; it does not prevent another
sufficiently privileged repository user or modified workflow from requesting an
OIDC token. Limit repository/runner administration and review trusted workflow
changes. The project accepts this limitation for dev only; stronger enforceable
approvals remain required before future production automation. Do not extend this
MVP exception to other environments implicitly.

Retain trunk-based development, immutable full SHA, locked dependencies, a reviewed
saved plan for the selected state and explicit human apply authorization. Build
Once, Deploy Many reuses source and application artifact digests, not Terraform
plans across states. Only dev is currently eligible; later environments retain
ADR 001's sequential promotion and independent QA/production approvals when
separately commissioned.

Record non-sensitive evidence in the existing private GitHub repository: source
SHA, state/root/backend reference, input versions, complete cost estimate reference,
plaintext saved-plan digest, encrypted artifact/producer-run reference, operator
review/authorization, timestamps, outcome, verification and backup confirmation.
Never commit state, saved plans, raw plan JSON, private keys or sensitive logs.
Jhon must review the full plan through a restricted local process rather than
relying only on a redacted summary.

Future OIDC identities separate plan resource-read permissions from bounded dev
apply permissions; scope state/lease access separately to the relevant container.
A locking plan needs lease permissions. Restrict federation to the actual immutable
repository subject/ref and trusted main execution context; give no production,
bootstrap-administration or subscription-control access to the dev apply identity.
PR validation receives no cloud credentials and stays on GitHub-hosted runners.
Institutional email ownership does not establish Entra access, principal IDs or
permissions. Exact RBAC, federation claims and Jhon's access remain prerequisites;
no identity or trust is configured by this decision.

## Runner isolation and readiness

Use a patched, powered-off clean VM snapshot taken before runner registration,
Azure authentication, private keys or plans. For each trusted deployment job,
restore that baseline, register a one-job ephemeral runner, execute, unregister if
necessary and discard guest changes before reuse. Ephemeral registration alone
only unregisters the runner; it does not wipe the disk. Do not restore snapshots
containing a registered runner, credentials, decrypted plans or saved guest memory.

Disable shared folders, clipboard, drag/drop, unnecessary USB and inbound port
forwarding. Keep OneDrive, external backups, host home/SSH/Azure credentials and
recovery private keys off the guest and its baseline. NAT is a proposed simple
outbound path, not a host/LAN isolation guarantee; verify its actual public egress
against the existing narrow storage allowlist. No firewall broadening, hosted
runner range allowlisting, private endpoints or extra Azure runner resources are
introduced. Apply necessary host/LAN restrictions before accepting the VM.

Verify supported Debian/architecture, current runner/action compatibility, available
disk, RAM and successful credential-free Terraform validation at one job at a time.
The VM is for deployment execution, not concurrent application builds or the CI
matrix. Verify DNS/TLS and outbound HTTPS to GitHub, Terraform registries/provider
sources, Azure identity/management endpoints and the specific backend. Actual
backend authorization and leases require later authorized checks. See the
[deployment runbook](mvp-deployment-runbook.md) for the activation checklist.

## Encryption and retention

For DEV, use Jhon's verified public age recipient and retain the private
identity outside the repository, runner snapshots and backup destinations.
Verify that Jhon can recover and decrypt an independently stored encrypted
copy. If transferring plans, keep plan-transfer and long-term backup identities
separate. The original procedure required both custodians' recipients and
recovery tests, with copies in OneDrive Personal and external storage.

Encrypted plans have one-day artifact retention. DEV state backups have an
initial 90-day retention and at least one independently stored encrypted copy.
These policies are separate from the 30-day backend soft deletion; old backend
versions do not automatically expire. Keep a creation/expiry inventory and
verify replacement backups before a needed recovery copy expires.

Terraform must read plaintext while planning/reviewing/applying. Keep plaintext in
restricted temporary storage; no terminal/JSON plan dumps in Actions logs. Any
plan-decryption identity needed for apply must use a separately protected temporary
injection mechanism and be removed by guest disposal; never put the long-term
backup identities in runner images. The activation review must establish this key
handling without a custom credential-release service. Verify the exact reviewed
plaintext plan SHA-256 after decryption, trusted producer run/artifact, immutable
SHA/inputs and freshness. Explicitly fail on mismatch; GitHub's artifact-download
warning is insufficient. Changes require a new plan and fresh human authorization.

## Inactive workflow scaffold

The [dev workflow example](../.github/workflow-templates/terraform-dev.yml.example)
is outside `.github/workflows`, has a non-workflow extension, hard-disabled jobs
and a fail-closed preparation stop. It grants no OIDC permission and runs no Azure,
Terraform plan/apply, artifact upload or state operation. It documents separate
manual plan/apply stages, immutable input/digest checks and serialized dev execution.
It must not be copied into the active workflow directory or enabled without a
separate activation approval. Existing credential-free CI remains active on
GitHub-hosted runners.

## Implementation sequence

1. Reconcile documentation and nondeployable dev/admin examples; add a separate
   administrative bootstrap caller with credential-free tests. Keep
   `subscription-controls/**` under its existing orchestrator's ownership.
2. Verify the Debian VM capacity/isolation/network, independent age recovery,
   key-handling/retention procedures and pending deployment inputs. Coordinate
   subscription-controls backend wiring with its owner; do not edit that root.
3. Review the inactive scaffold and complete workflow implementation locally,
   with no cloud access or activation. Keep existing PR CI credential-free.
4. Obtain evidence of application implementation, local integration/validation,
   a complete cost estimate and explicit authorization before any Azure setup.
5. Under separate target/action approvals, establish identities/access and
   bootstrap, verify network/RBAC/locking/recovery, initialize the remote backends,
   then separately authorize workflow activation. Jhon reviews and authorizes exact
   dev plans within the accepted boundaries; subscription-control operations remain
   separately coordinated. Record verification and encrypted 90-day state backups
   after every approved apply.
6. Rebuild in project-controlled Azure through a future approved transition plan.

## References

- [ADR 001](adr-001-branching-and-promotion.md) and [state bootstrap](state-bootstrap.md).
- [HashiCorp Azure backend](https://developer.hashicorp.com/terraform/language/backend/azurerm).
- [GitHub deployment environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments).
- [GitHub Azure OIDC](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure).
- [GitHub runner networking](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
- [GitHub OIDC claims](https://docs.github.com/en/actions/reference/security/oidc).
- [GitHub artifact validation and retention](https://docs.github.com/en/actions/tutorials/store-and-share-data).
- [Microsoft storage data protection](https://learn.microsoft.com/en-us/azure/storage/blobs/data-protection-overview).
- [GitHub self-hosted runner requirements and lifecycle](https://docs.github.com/en/actions/reference/runners/self-hosted-runners).
- [Oracle VirtualBox security](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/Security.html).
- [Official age manual](https://github.com/FiloSottile/age/blob/main/doc/age.1.ronn).
