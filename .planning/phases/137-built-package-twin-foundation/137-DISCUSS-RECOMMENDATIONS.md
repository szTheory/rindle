# Phase 137: recommended built-package twin foundation

Date: 2026-10-21. Research subject: `1741fd8022eb211450c77e0032843a962d0a2a2c`.
Status: researched recommendations for planning; no implementation or acceptance credit.

Build a small external Phoenix consumer that installs the exact locally built Hex
archive, runs real queued work, survives one controlled host restart, and proves its
cleanup. Keep it a recognizable application and a few ordinary maintainer commands.
The twin is maintainer-operated synthetic evidence, never an independent pilot.

The user delegated routine decisions after broad primary-source research. This
synthesis replaces the provisional Cohort-host assumption; it does not reopen the
milestone, change public contracts, or start implementation.

## Evidence and decision process

Three independent research branches examined package/host/DX, runtime/faults/OTP,
and evidence/security/SRE. A fourth reviewed the combined architecture adversarially.
The reports contain the detailed alternatives, examples, code locations and direct
primary sources:

- [Package and host](137-DISCUSS-PACKAGE-RESEARCH.md)
- [Runtime and faults](137-DISCUSS-RUNTIME-RESEARCH.md)
- [Evidence and security](137-DISCUSS-EVIDENCE-RESEARCH.md)
- [Adversarial review](137-DISCUSS-ADVERSARIAL.md)

Applied the repo-truth evidence ladder and research-first, adopter-first, idiomatic
Elixir, least-surprise, automation-first and narrow-then-escalate methodology.
Reviewed all six `prompts/` files. Their API/DX, explicit ownership, bounded work,
metadata allowlist and package-consumer lessons fit the current code. Old roadmap,
package-splitting and UI proposals are not current requirements. For any future UI,
`brandbook/tokens/tokens.json` and `guides/ui_principles.md` supersede older prompt
details. This phase has no visual UI deliverable.

Research stopped when the serious alternatives had a clear winner, each TWIN
requirement had an executable acceptance direction, and adversarial findings no
longer required a different architecture. Actual build/runtime budgets and exact
tool commands remain implementation probes, not claims that the design already
works. Broader framework surveys would not improve these choices.

## Jobs to be done

| Who / when / where | What they do and supply | What they receive / why it matters |
| --- | --- | --- |
| Maintainer, before landing a lifecycle change, local disposable services | Run one documented command against a committed source revision and deterministic media | A reproducible package-consumer result, precise failed stage, and safe evidence; no internal workflow archaeology |
| Phoenix adopter, during onboarding or upgrade | Follow ordinary Repo, migrations, profile and Oban examples | Confidence the documented integration works from the package, independent of monorepo helpers |
| Contributor, reproducing a red scenario | Select the finite registered scenario and use its receipt/run identity | A bounded reproduction and cleanup command; no editing worker internals or bespoke DSL |
| SRE/operator, diagnosing recovery and resource leaks | Inspect committed job transitions and owned DB/storage/temp inventories | Separation of retry, recovery, cleanup and infrastructure disposal; unknown is not zero |
| Security/release reviewer, assessing claims | Check package/source/host identities and redacted observations | An explicit evidence boundary and limitations; synthetic results do not become pilot or release authorization |
| CI automation, guarding changes | Run fast ordinary contract/validator tests initially | Deterministic nonzero failures without new required contexts or an unmeasured system-test matrix |

Inputs flow from a committed source and fixed host/fixtures into one package build;
the external host consumes that archive, receives one public lifecycle stimulus,
and produces observations. The runner observes runtime replacement and resource
ownership. The verifier derives a result from those observations. Cleanup and
resource disposal are separate operations. None of this requires a new public
Rindle API or public-facing service.

## Decision matrix

These are selected recommendations, not equal options for the maintainer to resolve.
Qualitative cost statements are engineering judgments, not measured benchmarks.

| Decision | Selected approach and benefit | Serious alternative / tradeoff | Footgun controlled |
| --- | --- | --- | --- |
| Host | Minimal Phoenix host with ordinary Endpoint/Repo/Oban; copy or share only narrow existing setup conventions | Cohort export offers richer UI but brings path fallback, cassettes, extra dependencies and inline test semantics. Generalizing the entire smoke helper creates mode-heavy coupling | A realistic-looking demo silently exercises the monorepo rather than the package |
| Isolation | One authoritative Docker/Compose-based consumer path, explicit staged inputs, no checkout or Docker-socket mount | Native execution starts cheaply but does not deny same-user checkout reads. A second native acceptance path doubles mechanisms and weakens the claim | `ERL_LIBS`, parent `_build`, generator caches, inherited homes, symlinks and checkout reads mask missing package content |
| Container scope | Reuse existing service/readiness mechanics; build from a small staged context on the supported toolchain | Reusing the whole Cohort image is convenient but currently copies the checkout and uses a different toolchain | An isolated container still contains all repository code through its image layers |
| Package | Build once per run; hash the actual tar bytes; unpack those same bytes and compile fresh externally | Reusing a directory or fetching the same published version is quicker but not evidence of this build | Metadata checksum is mislabeled as package checksum; tar A is checked but unpack B runs |
| Dependencies | Existing libraries and pinned host lock; no new dependency by default | JSON Schema/testing/orchestration packages may be useful later, but add graph and API cost now | Optional/dev dependencies and newer demo locks accidentally become the supported consumer contract |
| Runtime | Host-owned Repo and migrations, default `Oban`, normal queues, no SQL Sandbox | Inline/direct worker calls are fast; manual drain persists jobs but does not prove normal producer scheduling | A helper result is called a persisted autonomous retry |
| Namespace | Unique disposable database, bucket and temp root; supported `rindle`/`public` schemas | Dynamic schema names look lighter but fight existing compiled schema support | Named Oban and unsupported schema prefixes misroute production calls |
| Fault state | One tiny fixed host-owned PostgreSQL table with atomic fail-once consumption | A file is small but needs retention/atomic-consumption rules; ETS resets on restart | Reboot resets the counter or concurrent calls consume the wrong failure |
| Fault boundary | Documented configurable storage adapter; untouched callbacks delegate unchanged | A custom processor fake is attractive but the shipped worker does not expose that configuration seam | A declared behaviour is mistaken for a usable injection hook |
| Restart | Controlled whole-host restart between acknowledged attempts, same resources, one stimulus | Restarting a supervisor child is weaker; killing an executing job needs separate orphan-rescue semantics | A new asset/job after resubmission is called successful restart recovery |
| Public observations | Prefer public lifecycle/status reads plus host-owned Oban rows and actual storage observations | Fixed documented read-only Ecto schema queries are legitimate when needed; private worker/FSM/test calls are not | Blanket schema bans obstruct adopters, while exported private functions get treated as supported API |
| Receipt | Existing Jason, one versioned typed shape and scenario predicates | A new JSON Schema dependency helps interoperability only if another consumer needs it; JUnit alone lacks the required facts | Shape-valid `passed: true` substitutes for observed behavior |
| Redaction | Typed allowlisted projections before publication, private bounded raw capture | Secret-name blacklists preserve more diagnostics but miss signed URLs and errors under innocent keys | The JSON is clean while child stderr or CI artifacts leak credentials |
| Cleanup | Observe domain cleanup and complete owned-resource inventory before disposal | Dropping everything quickly protects the machine but hides failed lifecycle cleanup | A failed/partial inventory or forced deletion is reported as zero residue |
| CI | Maintainer-local real tracer plus fast tests in existing lanes; measure before scheduling a heavy lane | Adding a new required PR job immediately catches drift but adds unmeasured cost and topology | Phase 136's deferred speed work reappears as an expanding PR test matrix |
| DX | One runner, familiar subcommands, bounded stages, safe errors and a receipt path | Raw backend logs and many specialized commands may help authors but burden consumers | Users must understand internal modules or YAML to reproduce a scenario |
| Workflow | Standard discuss → plan → execute → verify; finite plan set | Custom authorization/qualification/journal systems promise control but create new failure modes | Repeated blockers generate recovery-plan cascades rather than a narrower scope |

## The foundational tracer

Use deterministic small image data and real MinIO. Exercise the ordinary supported
upload path, wait for readiness, attach with
`Rindle.attach(asset_or_id, owner, slot)`, then detach the final attachment with
`Rindle.detach(owner, slot)`. Discover the resulting purge job through host-owned
Oban observations; detach does not return a job ID.

The host storage wrapper fails one delete for the exact owned source key, then
delegates. Observe the same persisted job at attempt one in `retryable`, with a
recorded error and retained asset handle. Purge deletes variants before the source,
so record legitimate partial object effects; do not assert that every object
survives the failed attempt (`lib/rindle/workers/purge_storage.ex:27–55`).

Pause the purge queue through public Oban control, verify it is paused with no
running jobs, and re-read that the same job is still retryable at attempt one.
This conjunction is the quiescent restart barrier. If it raced ahead, the probe is
incomplete, not a reason to rewrite job state, enqueue again or retry until green.
Stop the whole host runtime, observe termination, and start a new host against the
same database, bucket, retained temp state and fixed counter. Use normal active
queues and let that existing due job complete at attempt two. Record different
runtime identities, unchanged asset/job identities, one initial stimulus and actual
terminal effects. Then clean up and verify residue.

Use actual scheduled time and shipped backoff under a measured monotonic deadline.
Do not override the worker, force `retry_job`, drain scheduled work, mutate
`scheduled_at`, add fast Lifeline rescue, or claim an in-flight crash test. The
normal-mode versus helper distinction follows pinned
[Oban 2.21.1 execution](https://github.com/oban-bg/oban/blob/v2.21.1/lib/oban/engines/basic.ex)
and [testing modes](https://hexdocs.pm/oban/2.21.1/Oban.html).

This is a foundation demonstration, not completion of Phase 138. The broader tus,
AV repair, provider ordering, interruption and interrupted-cleanup matrix remains
there. Phase 139 owns aggregate exact-head readiness. A small image scenario does
not prove AV correctness, real-provider behavior, every retry schedule or a real
independent adopter.

## Minimum evidence and security contract

One small receipt contains synthetic identity, expected source and package digest,
host/fixture/lock/config identity, actual toolchain/service versions, scenario and
run IDs, executed steps, public transitions, persisted attempts, external effects,
runtime replacement, terminal state, cleanup and complete residue observations.
The expected scenario set and semantic predicates live in source, not in the
submitted receipt. An explicit applicability rule can classify a resource that the
scenario does not use; missing observation cannot invent applicability after the run.

The validator rejects wrong identities, unknown versions/keys, duplicate JSON keys,
unsafe paths, malformed/unbounded fields, missing or skipped required work,
contradictory chronology, false retries/restarts, incomplete inventories and
unapproved residue. Use existing Jason string-key/ordered-object decoding rather
than a new parser or schema library. Acceptance exits nonzero on failure or
incomplete evidence even when a failed receipt is well formed. Re-runs are new runs;
there is no spent-source ledger or ordinary-rerun prohibition.

Do not persist or stream raw URLs, request/response bodies, job error text, environment
dumps, connection strings or unrestricted subprocess output. Generate readable
messages from bounded stage/reason/dependency/exit fields. Test secret canaries
through exported JSON, console errors, stderr, access logs and telemetry capture.
These controls implement the [OWASP logging exclusions](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html);
they do not make the runner resistant to a malicious trusted collector.

Checksums establish byte integrity against trusted expectations. An offline validator
cannot authenticate a fully fabricated but internally consistent run. Trust the
source-controlled runner and its execution environment; use ordinary CI identity
where CI is the authority. Borrow input/artifact separation from
[SLSA provenance](https://slsa.dev/spec/v1.1/provenance), without signing infrastructure,
an attestation service or a SLSA level claim.

## Cleanup and operational guarantees

Allocate only run-owned local resources. A small descriptor records identities before
allocation for crash cleanup; it is not an authorization capsule or event journal.
Validate endpoints and resource ownership, refuse active runs and path escapes,
and never delete a shared/default database or bucket. Stop writers before inventory.

Capture terminal and failed-cleanup facts before disposing infrastructure. Public
maintenance commands must run their intended live action, not an exit-zero dry run.
Inventory database state above explicit bounded bootstrap/infrastructure allowances,
Oban states, fully paginated object listings, multipart state, temp files and owned
processes. A permission error or truncated list is unknown and red. Baseline buckets
have versioning disabled; unsupported versioned cleanup must be rejected rather than
counted as empty. Save evidence before clearing terminal job history or dropping DBs.

An idempotent cleanup subcommand removes an abandoned validated namespace and leaves
unrelated decoy resources alone. Later cleanup success produces a new observation;
it never rewrites the original failed receipt. Phase 137 proves ordinary cleanup and
janitor idempotence; Phase 138 owns deliberate interruption of cleanup and its full
convergence test.

Cross-ecosystem lessons reinforce these boundaries:

- [Rails Active Storage testing](https://guides.rubyonrails.org/active_storage_overview.html#discarding-files-created-during-tests): database rollback does not clean external files. Keep separate owned roots and observe storage.
- [Shrine atomic helpers](https://shrinerb.com/docs/plugins/atomic_helpers): concurrent attachment changes are a distinct race. Observe durable identity and convergent outcomes rather than assuming a job still owns the current attachment.
- [Sidekiq best practices](https://github.com/sidekiq/sidekiq/wiki/Best-Practices): side effects and acknowledgement leave an execution gap. Prove idempotent convergence, not exactly-once execution.
- [AWS multipart documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html): object listing and incomplete multipart state differ; uncompleted parts need explicit handling. Local MinIO evidence is not cloud-provider certification.
- [Testcontainers readiness](https://java.testcontainers.org/features/startup_and_waits/): started is not ready. Borrow bounded health probes using existing tooling rather than importing Testcontainers.

## Developer experience and design pillars

The user of this surface is a maintainer or contributor. Prioritize correctness,
clarity, predictable command behavior, accessibility, security/privacy, bounded
performance, reproducibility, diagnosability, safe recovery and maintainability.
There is no dashboard, theme or animation work in this phase.

One entrypoint offers conceptually `check`, `run`, `verify RECEIPT`, and `cleanup RUN_ID`.
Exact filename is planner discretion. Help and RUNNING documentation explain the
supported prerequisites, disposable resource scope, one-scenario reproduction,
output path, exit meaning and cleanup behavior. No implicit installation, publish,
live provider access or destructive action outside the disposable namespace.

Use plain stage labels and text statuses that work without color or a TTY. Keep
machine-readable output valid when requested; separate safe progress/diagnostics.
Show the actual pending stage, not fake percentages. On failure, say what failed,
the last observed state, safe reason and evidence location; show a bounded next
diagnostic or cleanup command. Do not expose internal workers, schema implementation
details, opaque digests or stacktraces unless needed for a maintainer's diagnosis.

Default to removing raw captures/workspaces; allow only a bounded private interrupted
capture lifetime. Match the repo's existing 14-day CI artifact convention for safe
diagnostics when wired into CI, and retain a compact final receipt with milestone
evidence. Do not add a retention service or a long-lived resource database.

## Plan boundary and stopping rules

Plan a few executable vertical slices, target at most six plans and three tasks per
plan. Each slice must demonstrate observable behavior; avoid a collection of horizontal
framework layers. Exact decomposition belongs to standard `gsd-plan-phase 137`.

Use existing dependencies; a small deliberate copy of stable setup is preferable to
a new dependency or speculative abstraction. A helper is shared only when two callers
have the same actual contract. Runtime scripts/tests must not read `.planning/phases`.
No new required PR context, widened support matrix, product API/schema, release path,
generic scenario/fault DSL, browser UI, new real-provider dependency or custom GSD gate.

At execution time, verify the actual container/toolchain/media versions. The current
Cohort Dockerfile's runtime and whole-checkout copy are not reusable acceptance
defaults. An OS package install or image tag is not proof that FFmpeg meets the
documented floor. Reuse audited provisioning mechanisms and probe actual versions.

If a gate fails twice on the same cause, stop and rescope the existing work rather
than generating another recovery plan or qualification protocol. Escalate only for
a necessary public contract/support change, shared-resource destructive semantics,
new credentials/provider spend, or material CI/release cost with no clear winner.
Implementation uncertainties are ordinary task preconditions with executable probes;
none justifies asking the maintainer to choose routine helper names or schema layout.

Keep all three matched CI/release todos outside Phase 137; they are not dependencies
of this local built-package foundation. Preserve numeric CI speed deferral and older
verification debt. Research and context completion close no TWIN requirement.
