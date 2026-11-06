# MVP deployment preparation and activation

[ADR 004](adr-004-mvp-state-and-deployment.md) accepts the design, not activation.
The [workflow scaffold](../.github/workflow-templates/terraform-dev.yml.example)
is deliberately inactive and stops before cloud access. Do not register a runner,
create federation, enable workflows, connect state or apply Terraform under this
local-preparation task. `subscription-controls/**` remains with its current owner.

## Acceptance checks before activation

Record results in a non-sensitive private-repository readiness record. The current
VM specification is an input, not proof that these checks passed.

| Check | Required evidence |
| --- | --- |
| Application readiness | Services implemented, integrated locally and validated; immutable source/image references and relevant service contracts accepted. |
| Operational authority | Ramiro's initial approved dev access/scope boundaries, Jhon's actual Entra access and exact scoped plan/apply/backend permissions; no production grants. |
| VM suitability | Existing Debian VirtualBox guest: 2 vCPU, 4 GB RAM, 20 GB disk; supported OS/architecture, patched runner and compatible action runtimes, enough actual free disk/RAM for one Terraform job. |
| Capacity trial | Backend-disabled initialization, validation and reviewed mocked tests succeed without Azure credentials; no OOM, disk exhaustion or overlapping jobs. Record observed peak memory/disk use. Do not run application builds or the CI matrix on this guest. |
| Isolation | Shared folders, clipboard, drag/drop, unnecessary USB and inbound port forwards disabled; no personal CLI credentials, SSH keys, OneDrive or external backup mounts. Restrict reachable host/LAN services; NAT alone is not complete isolation. |
| Network | DNS/TLS and outbound HTTPS reach GitHub/Actions, module/provider sources, Azure login/management and the intended Blob hostname; actual guest public egress matches approved storage rules. Revalidate if the operator's public IP changes. |
| Backend | Later authorized checks establish account/container separation, Entra access, lease locking and recovery. HTTP reachability alone does not verify those controls. |
| Recovery | Jhon and Ramiro independently decrypt a representative encrypted copy using their own keys, verify its digest and can access key recovery material. Store encrypted copies in all agreed destinations and inventory their 90-day expiry. |
| Costs and configuration | Actual Students offer/region/SKU/quota/currency checks, complete dev estimate, backend names, principals, IPs and nonsecret input references reviewed; no placeholder accepted as an actual deployment value. |

Inside the verified guest, basic read-only diagnostics include `cat
/etc/os-release`, `uname -m`, `nproc`, `free -h` and `df -h`. They reveal capacity,
not isolation or Azure access. GitHub documents workload-dependent runner hardware;
2 vCPU/4 GB/20 GB is plausible for a single Terraform job but not guaranteed.
Use a current patched runner meeting every selected action's requirements.

## Disposable VirtualBox lifecycle

1. Prepare a patched dedicated guest with required reviewed tools. Take a clean,
   powered-off baseline snapshot before runner registration, Azure authentication,
   plan data or private keys. Do not capture guest RAM or private host mounts.
2. After separate activation approval, restore the baseline and register a one-job
   ephemeral runner with a dedicated dev label. Registration details/tokens must
   never be baked into the baseline. Serve only trusted manual dev jobs; keep PR
   CI on GitHub-hosted runners.
3. Process one job. Use a restrictive temporary directory/umask for plaintext
   plans and any authorized temporary decryption material. Do not print plan JSON,
   state or keys. Do not put long-term backup keys on the guest.
4. After success or failure, complete evidence/backup handoff, unregister any
   surviving registration and discard guest changes. Restore the clean baseline
   before the next job. Ephemeral registration does not erase the guest.
5. Refresh the baseline for patches while retaining these controls. Never restore
   a snapshot containing a live runner identity, cached Azure login or secrets.

## Dev plan, review and apply contract

The future workflow uses separate manual plan/apply invocations. Jhon explicitly
reviews and authorizes each exact dev plan within Ramiro's initially agreed scope.
No per-deployment credential release by Ramiro is required. Repository records and
manual triggers provide procedural authorization; GitHub Free/private provides no
independent approval enforcement. OIDC is authentication, not human approval.
Administrators and users able to change trusted workflows remain trusted actors.

Select the full immutable commit reachable from `main`, verify that merged commit's
checks and use pinned dependencies. Record immutable application digests instead
of rebuilding artifacts during deployment. Use the dev root, intended tenant,
subscription, state/backend, exact input references and bounded identity.

The plan stage produces a fresh saved plan and a non-sensitive receipt containing
its plaintext SHA-256, source SHA, input references, backend/root, producer
run/attempt, encrypted artifact reference, creation/expiry and cost-estimate
reference. Encrypt before upload; set artifact retention to one day. Keep the full
plan available for secure review by the operator. Do not use an artifact name or
co-located checksum alone as evidence of human review.

The apply stage accepts the reviewed receipt/digest and authorization-record
reference. Check the trusted producer/artifact, expiry, unchanged inputs/SHA/state
and exact plaintext digest after decryption. Reject mismatches and stale plans;
never silently replan. Jhon reviews and authorizes a replacement plan when needed.
Explicit digest checks must fail, rather than relying on artifact-download warnings.
The scaffold does not implement any of these cloud stages yet.

Serialize operations on dev state with cancellation disabled and Terraform's
backend lease. Workflow concurrency serializes running jobs; it does not reserve
state between separate plan and apply runs or guarantee FIFO order. Record the
current deployment candidate and reject superseded plans; coordinate all operators.
Other environment states and subscription-control administration are outside this
workflow. Future production requires stronger approval enforcement and its own
reviewed design before automation.

After an approved apply, verify resources/security/workload health and capture the
current state for independent encrypted backup, including partially changed state
after a failed approved operation. Record outcome and backup verification before
discarding the runner. State access/backup operations require the appropriate later
authorization; none is performed during preparation.

## Established encryption and retention procedure

Use age with separate Jhon/Ramiro private identities, separating plan-transfer
keys from long-term backup keys. Verify both purpose-specific public recipients
out of band before use. Encrypt to both recipients so either custodian can decrypt
independently; neither needs the other's private identity. Agree each person's
secure private-key storage and independent recovery method before activation.
Never commit keys, put them next to encrypted archives or capture them in runner
snapshots. No operational encryption keys are generated by this change.

The following illustrates the file procedure only; paths/recipients are supplied
from approved custody configuration, not repository secrets. Execute only on the
authorized isolated working copy or custodian machine with restrictive permissions:

```sh
age -r "$JHON_RECIPIENT" -r "$RAMIRO_RECIPIENT" -o "$CIPHERTEXT" "$PLAINTEXT"
age --decrypt -i "$RECOVERY_IDENTITY" -o "$RECOVERED_COPY" "$CIPHERTEXT"
sha256sum "$PLAINTEXT" "$RECOVERED_COPY"
```

Both custodians must perform their own decrypt-and-digest check with their own
identity before relying on the recovery design. Do not expose hashes/paths of
sensitive files in public logs. Before apply activation, review how a separate
plan-decryption identity is supplied temporarily to the disposable guest without
placing long-term backup keys in it. The present scaffold does not inject keys or
implement a custom credential-release service.

| Data | Retention and custody |
| --- | --- |
| Encrypted saved plans | One-day artifact retention; restricted plaintext working copies only for the review/apply session. Remove transient plaintext and temporary keys through verified guest disposal and custodian cleanup. Expired plans require a fresh plan/review. |
| Encrypted state backups | Initial 90-day policy in encrypted local custody, Jhon's OneDrive Personal and independent external storage; refresh after approved applies and verify both recipients' recovery access. |
| Backend data | LRS, versioning and 30-day blob/container soft deletion; previous versions do not automatically expire. |
| Evidence | Non-sensitive receipts, authorizations, outcomes and backup verification in the existing private repository; never raw state/plans/logs or keys. |

Inventory each backup's UTC creation/90-day expiry, state lineage/serial/reference
and integrity verification in restricted custody records. Review every destination,
including synchronized/deleted-item histories, when maintaining retention. Before
a needed latest recovery copy expires, create and verify its replacement. The
policy does not create a cloud lifecycle rule or authorize automatic Azure/OneDrive
deletion. Key loss defeats encrypted backup recovery; encrypted-copy availability
alone is insufficient. Recovery target remains 24–48 hours, to be demonstrated by
a later authorized drill. Database and multiregional recovery remain separate.

## References

- [GitHub runner requirements/lifecycle](https://docs.github.com/en/actions/reference/runners/self-hosted-runners).
- [Oracle VirtualBox security](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/Security.html).
- [GitHub environment limitations](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments).
- [GitHub artifact validation/retention](https://docs.github.com/en/actions/tutorials/store-and-share-data).
- [Official age manual](https://github.com/FiloSottile/age/blob/main/doc/age.1.ronn).
- [Terraform saved-plan sensitivity](https://developer.hashicorp.com/terraform/cli/commands/plan).
