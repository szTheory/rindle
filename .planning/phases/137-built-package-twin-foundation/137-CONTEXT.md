# Phase 137: Built-Package Twin Foundation - Context

**Gathered:** 2026-10-21 (research-first assumptions mode)
**Status:** Ready for planning
**Decision authority:** The user requested broad subagent research, adversarial review,
one coherent recommendation set, and automatic adoption of routine recommendations.

<domain>
## Phase Boundary

Deliver a production-faithful, maintainer-operated synthetic adopter foundation
against a freshly built external Hex artifact. Cover TWIN-01 through TWIN-06 with
executable package isolation, host ownership, documented faults, durable job/restart
observations, safe receipts and cleanup. Demonstrate one image lifecycle plus a
controlled storage retry/restart tracer. The complete six-scenario recovery matrix
belongs to Phase 138; aggregate exact-head readiness belongs to Phase 139.

Synthetic evidence never satisfies the named independent Phoenix pilot or implies
1.0 readiness. No implementation or TWIN acceptance credit is granted by this context.
</domain>

<decisions>
## Implementation Decisions

### Host and package boundary

- **D-137-01:** Use a dedicated minimal external Phoenix host, with ordinary application
  supervision, Endpoint, adopter-owned Repo, migrations and Oban. Reuse/copy narrow
  generated-consumer package/migration conventions. Keep Cohort and existing smoke
  semantics intact; do not export the full demo or generalize the smoke helper into
  a fault platform. No HTML/LiveView/assets are needed for this foundation.
- **D-137-02:** Use one authoritative Docker/Compose consumer execution path with a
  small staged input context. No checkout, user home, Docker socket, inherited
  repository code paths or prebuilt Rindle BEAMs enter the consumer. Reuse service
  and readiness mechanics, not the current Cohort image or whole-checkout `COPY`.
  The parent may build/stage from the source checkout. Do not introduce a second
  native acceptance path or a custom macOS sandbox framework.
- **D-137-03:** Build one fresh local Hex archive per run, compute SHA-256 over its
  actual tar bytes, and unpack/compile that exact archive. Distinguish archive,
  metadata and extracted-content digests. An explicit dependency path to the
  attested external unpack is valid; a repository path, preexisting arbitrary
  package directory, second build or same-version registry fetch is not a substitute.
  Validate extracted paths/material, fresh build roots and loaded code origin.
- **D-137-04:** Bind the host's actual lock, fixture/host/contract inputs and runtime
  versions. Start with the accepted Elixir 1.17.3 / OTP 27.3.4.15 cell and researched
  Oban 2.21.1; do not inherit Cohort's different lock or upgrade support silently.
  Probe actual database/storage/media capabilities; image tags or an installed
  `ffmpeg` package do not prove the documented version floor. Image-only execution
  grants no AV acceptance. Preserve user-owned `.tool-versions`.

### Public contracts and durable execution

- **D-137-05:** Use supported Rindle facade/configuration/behaviour and HTTP surfaces.
  Reject unsupported workers/FSM/config owners, test overrides, source introspection,
  BEAM inspection and direct lifecycle-row mutation. Public returned structs and
  documented read-only Ecto schema queries are legitimate adopter contracts; do
  not ban them by namespace. Prefer facade/status reads for the bounded one-asset
  tracer. Host-owned `Oban.Job` queries and infrastructure inventory have distinct
  legitimate roles. Static call guards support the boundary; they are not a sandbox.
- **D-137-06:** Run the default `Oban` instance with normal queues/testing disabled,
  an ordinary Repo pool and committed state. No SQL Sandbox, inline/direct
  `perform_job`, scheduled drain or forced retry can serve as retry authority.
  Use a unique disposable database, a dedicated MinIO bucket and retained temp
  root; preserve supported Rindle `rindle` and host/Oban `public` schema ownership.
  No arbitrary run-specific schema prefix or unsupported named Oban routing.
- **D-137-07:** Implement one fixed host-owned storage fault wrapper through the
  actually configurable profile storage adapter. Fail the exact run-owned source
  key's delete once, then delegate with unchanged callback/capability semantics.
  Persist an atomic counter in one tiny host-owned PostgreSQL fixture table,
  initialized once per run and retained across restart. No ETS-only/file-lock
  protocol, generic fault DSL, new database framework or production fault seam.
  The existing processor behaviour does not imply configurable worker injection.
- **D-137-08:** The tracer uses public upload/readiness,
  `Rindle.attach(asset_or_id, owner, slot)` and final `Rindle.detach(owner, slot)`.
  Discover its purge job through Oban observations. Require committed retryable
  attempt one with error and retained asset handle; record any legitimate earlier
  variant deletions. Pause the local purge queue, confirm paused/no running jobs,
  and re-read that the same job remains retryable at attempt one before stopping
  the whole host. Restart a new runtime with the same package/resources/counter;
  ordinary scheduling must complete that same job at attempt two without repeating
  stimulus. Record the intentional pause and actual old-runtime termination.
  A raced boundary is incomplete, never permission to rewrite or resubmit.
- **D-137-09:** Use shipped retry cadence and bounded observable readiness/deadlines.
  No worker backoff patch, `scheduled_at` update, fast Lifeline, rerun-until-green,
  or exactly-once claim. This is controlled restart **between attempts**, not
  executing-job crash rescue, disk-loss recovery, controller crash recovery or
  the full Phase 138 interruption matrix.

### Evidence, privacy and cleanup

- **D-137-10:** Use existing Jason and one small versioned typed receipt contract
  with source-owned scenario predicates. Derive the result from expected identities,
  public states, committed job attempts, actual effects, runtime replacement,
  terminal state, cleanup and complete inventories. Expected scenarios cannot
  come solely from the submitted receipt. Reject malformed/duplicate/unknown keys,
  wrong identities, missing/skipped required work, contradictory observations,
  unknown inventory and unapproved residue. Acceptance exits nonzero for failed
  or incomplete evidence, even if a failed receipt is structurally valid.
  Every artifact/summary carries synthetic identity and zero independent-pilot credit.
- **D-137-11:** Project observations into bounded allowlisted fields before export.
  Never publish raw signed URLs, bodies, credentials, environment dumps, arbitrary
  job errors or unrestricted subprocess output. Capture privately with limits;
  generate safe stage/reason/dependency diagnostics. Test canaries across receipts,
  console/stderr, access logs and captured telemetry. A checksum/semantic verifier
  does not authenticate a wholly fabricated trusted-runner observation set; do
  not introduce signing, witness/spent-source registries or attestation machinery.
- **D-137-12:** Separate domain cleanup from infrastructure disposal. Observe terminal
  and cleanup facts before dropping resources; failed cleanup remains failed after
  emergency disposal. Stop writers and require complete successful DB/job/object/
  multipart/temp/process inventories against explicit bounded infrastructure/history
  allowances. Unknown/denied/truncated is not zero; exit-zero dry-run is not cleanup.
  Disable versioning on the baseline disposable bucket or reject unsupported
  cleanup configuration. Provide a small idempotent janitor using a validated
  pre-allocation resource descriptor, preserving decoy/unrelated resources and
  original failed receipts. No event journal or authorization capsule.

### Developer experience, dependencies and normal workflow

- **D-137-13:** Prefer the existing small dependency graph. A deliberate small copy
  of stable setup is preferable to a new dependency or speculative abstraction;
  share helpers only when callers have the same actual contract. No new JSON
  Schema/testing/orchestration library, frontend UI, or twin-only production API.
  Keep live code at stable script/test paths with no `.planning/phases` runtime reads.
- **D-137-14:** Give maintainers one documented entrypoint with familiar check/run/
  verify/cleanup operations, plain statuses, bounded stages, valid optional machine
  output, safe errors, evidence locations and a useful reproduction/cleanup command.
  No secret-bearing backend details or fake progress. Use text as well as any color;
  preserve the calm, precise brand voice. Start with local disposable execution and
  fast behavioral/contract tests in existing CI lanes. Measure real runtime before
  adding heavy recurring execution; preserve required contexts and release coupling.
- **D-137-15:** Return to ordinary OpenGSD discuss → plan → execute → verify. Target
  a few vertical slices, at most six plans and three tasks per plan. If the same
  gate blocks twice, rescope instead of creating another recovery-plan cascade.
  No bespoke qualification, authorization or journal framework. Keep all three
  unrelated CI/release todos in backlog and numeric speed acceptance deferred.

### Codex's Discretion

Exact host/template and runner filenames, small module boundaries, receipt layout,
supported container image/build details, bounded polling values, input-manifest
representation and plan decomposition are routine implementation decisions. Validate
them with ordinary automated probes. Do not add abstractions solely for hypothetical
Phase 138 reuse. Preserve a compact final receipt and bounded safe diagnostics.

Escalate only when evidence demonstrates a necessary public API/schema/telemetry or
support change, shared-resource destructive behavior, new live credentials/provider
spend, or material CI/release cost without a clear winner. No such choice remains
unresolved in this discussion.
</decisions>

<canonical_refs>
## Canonical References

Downstream agents must read these before planning or implementing. Current source
and active requirements outrank historical prompts. The discussion log is audit
only and must not be used as a decision authority.

### Scope and recommended boundary

- `.planning/PROJECT.md` — active milestone vision, boundaries and synthetic/pilot truth.
- `.planning/REQUIREMENTS.md` — TWIN-01–06; separate RECOV and READY ownership.
- `.planning/ROADMAP.md` — Phase 137, 138 and 139 boundaries.
- `.planning/METHODOLOGY.md` — research-first, repo-truth and automation-first lenses.
- `.planning/phases/137-built-package-twin-foundation/137-DISCUSS-RECOMMENDATIONS.md` — coherent synthesis, JTBD, alternatives, acceptance directions and limits.
- `.planning/phases/137-built-package-twin-foundation/137-DISCUSS-PACKAGE-RESEARCH.md` — package/host provenance and primary references.
- `.planning/phases/137-built-package-twin-foundation/137-DISCUSS-RUNTIME-RESEARCH.md` — pinned Oban/OTP/Ecto semantics and tracer.
- `.planning/phases/137-built-package-twin-foundation/137-DISCUSS-EVIDENCE-RESEARCH.md` — receipt, redaction, cleanup and primary references.
- `.planning/phases/137-built-package-twin-foundation/137-DISCUSS-ADVERSARIAL.md` — resolved claim/boundary corrections and limits.

### Shipped consumer and operations contracts

- `RUNNING.md` — supported toolchains, prerequisites and CI lanes.
- `guides/getting_started.md` — adopter-owned Repo, default Oban and migrations.
- `guides/core_concepts.md` — public lifecycle and documented schema surface.
- `guides/background_processing.md` — background jobs and public telemetry.
- `guides/operations.md` — supported cleanup and maintenance semantics.
- `guides/troubleshooting.md` — documented diagnostic/read-only queries.
- `guides/release_publish.md` — preserve existing release authority.
- `.planning/DEVELOPMENT-TRAIN.md` — PR-first development and GSD command handoffs.
- `.planning/phases/134-dependency-security-and-inbox-disposition/134-CONTEXT.md` — no-framework and repeated-blocker scope lessons; respect later explicit decisions.

### Relevant product and UX framing

- `prompts/gsd-rindle-research-index.md` — research provenance and useful source classes.
- `prompts/gsd-rindle-elixir-oss-dna.md` — explicit contracts, dependency and DX principles.
- `prompts/gsd-rindle-gsd-bootstrap-brief.md` — research-first delegated routine choices.
- `prompts/phoenix-media-uploads-lib-deep-research.md` — personas, lifecycle and cleanup lessons; historical suggestions are not shipped support.
- `prompts/rindle-brand-book.md` — calm technical voice and documentation principles.
- `guides/ui_principles.md` — applicable copy/status principles; no UI work authorized.
- `brandbook/tokens/tokens.json` — current visual authority if later scope includes UI.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `test/install_smoke/support/generated_app/workspace.ex`, `contracts.ex`, `migrations.ex`,
  and `patcher.ex`: narrow workspace/package/host migration conventions; retain
  their existing smoke semantics and do not import manual worker execution.
- `test/install_smoke/support/generated_app_helper.ex`: package-consumer precedent;
  its historical metadata checksum is not the new tar-byte checksum authority.
- `scripts/ci/ensure_phx_new.sh`, `scripts/ci/install_ffmpeg.sh`, existing Compose/service
  definitions: audited provisioning/readiness ideas, with actual version checks.
- `examples/adoption_demo/lib/adoption_demo/application.ex` and canonical adopter
  examples: ordinary host wiring/public lifecycle ideas, not whole-app reuse.

### Established Patterns

- Public `Rindle.Profile` storage selection and `Rindle.Storage` delegation are usable
  fault seams. `Rindle.Processor` behaviour alone does not expose worker configuration.
- Default `Oban` and host migrations are the documented integration path. Existing
  inline/manual/Sandbox tests are useful tests but not retry/restart authorities.
- Existing Jason, ordinary ExUnit and shell probes suffice; public observations and
  behavioral mutations are stronger than tests mirroring source literals.

### Integration Points

- `lib/rindle.ex`: upload, attach/detach, status/read and repair contracts.
- `lib/rindle/storage.ex`, `profile.ex`, `storage/s3.ex`: documented storage callbacks,
  selected adapter, real MinIO effects and retained temp semantics.
- `lib/rindle/workers/purge_storage.ex`: source-review evidence for partial-delete
  behavior only; the twin must never call this private worker directly.
- Public `Oban.Job`, queue control and host Repo: committed attempt/state observations.
- `.github/workflows/ci.yml`, `RUNNING.md`: existing fast-test lanes and exact-SHA release coupling.
</code_context>

<specifics>
## Specific Ideas

- User: research breadth and depth through relevant expert lenses, use reputable
  primary sources, perform an adversarial pass, synthesize one cohesive recommendation
  set and follow routine recommendations without another option-selection exercise.
- User: prefer a small deliberate copy to another dependency; retain a smaller,
  flatter graph unless a dependency has a demonstrated need.
- User: return to normal OpenGSD rather than custom one-off workflow machinery.
- The revised minimal-host recommendation supersedes the earlier provisional
  Cohort assumption after concrete source and version findings.
</specifics>

<deferred>
## Deferred Ideas

- Phase 138 owns the full six recovery scenarios, including AV/provider/tus and
  deliberately interrupted cleanup; Phase 139 owns aggregate exact-head readiness.
- Numeric CI speed target remains unfinished in `SEED-261021-918`, with zero credit.
- No independent-adopter credit, new UI, second provider, optional framework,
  generic scenario DSL, native acceptance path, signatures or attestation service.
- Existing older-phase verification debt stays visible; do not replay consumed
  historical actions or rewrite old evidence merely to clear fingerprints.

### Reviewed Todos (not folded)

- `.planning/todos/pending/2026-10-15-hygiene-baseline-publish-race.md` — release/hygiene timing, not a dependency of the local twin.
- `.planning/todos/pending/2026-10-15-replace-release-pats-with-github-app.md` — separate release credential migration.
- `.planning/todos/pending/2026-10-16-ledger-landing-record-and-collector-gaps.md` — dependency ledger/CI classification, not foundation scope.
</deferred>
