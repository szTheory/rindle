# Phase 38: Resumable Persistence + FSM - Context

**Gathered:** 2026-05-07 (research-first discuss mode; 4 parallel advisor subagents)
**Status:** Ready for planning

<domain>
## Phase Boundary

Land the additive `media_upload_sessions` persistence changes and the minimal
runtime/operator surface needed to support resumable uploads later:

- packaged migration template under `priv/repo/migrations`
- new `MediaUploadSession` fields: `session_uri`, `session_uri_expires_at`,
  `last_known_offset`, `region_hint`
- widened `upload_strategy` vocabulary to include `"resumable"`
- new FSM state `"resuming"`
- custom `Inspect` redaction for `session_uri`
- two new public resumable telemetry events
- `mix rindle.doctor` schema drift check for the new resumable columns/index

This phase does **not** ship adapter resumable callbacks, broker resumable
entrypoints, GCS session initiation/status/cancel behavior, or resumable-aware
runtime-status/CORS diagnostics. Those land in Phases 39-41.

</domain>

<decisions>
## Implementation Decisions

### Migration Posture

- **D-01:** Ship the Phase 38 schema change as the normal packaged Rindle
  migration template under `priv/repo/migrations`, consistent with the
  existing adopter-owned Repo/migration handoff.
- **D-02:** `session_uri` uses `:text` in the packaged migration template, not
  `:string`, because GCS resumable session URIs can exceed 255 characters.
- **D-03:** Add `session_uri_expires_at :utc_datetime_usec`,
  `last_known_offset :bigint, default: 0, null: false`, and
  `region_hint :string, size: 64, null: true`.
- **D-04:** Add the partial expiry index filtered to
  `upload_strategy = 'resumable'` for maintenance/expiry sweeps.
- **D-05:** Widen `upload_strategy` to include `"resumable"` in the schema and
  migration posture, but Phase 38 does **not** add resumable runtime semantics
  beyond persistence/FSM groundwork.

### Secret Handling And At-Rest Posture

- **D-06:** `session_uri` is a bearer credential, not routine metadata. Treat
  it as a secret in logs, telemetry, inspect output, and persistence
  discussions.
- **D-07:** Rindle does **not** force `cloak_ecto`, a Vault, or an encrypted
  column type into the packaged migration. The install-default path stays plain
  and dependency-light.
- **D-08:** Phase 38 context must explicitly call out the adopter off-ramp:
  teams with stricter at-rest requirements may replace the packaged
  `session_uri` column with an app-local encrypted-field posture
  (`:binary` column plus `Cloak.Ecto.Binary` or equivalent) before rollout.
- **D-09:** Phase 41 docs must include the full optional encrypted-at-rest
  recipe and the caveat that switching from plain `:text` to encrypted
  `:binary` later is a deliberate follow-on migration/backfill.

### FSM Semantics

- **D-10:** `Rindle.Domain.UploadSessionFSM` gains a new durable state
  `"resuming"` with the locked lane:
  `"signed" -> "resuming" -> "uploading"`.
- **D-11:** `"resuming"` has a **narrow** meaning: the session has entered an
  explicit recovery/resume path after interruption or uncertain completion. It
  is **not** a generic "someone asked for status" state.
- **D-12:** Status polling and offset discovery alone must not mutate durable
  lifecycle state. The explicit footgun to avoid is: harmless status probes
  must not make rows look more progressed than they are.
- **D-13:** Maintenance and operator surfaces should treat `"resuming"` as a
  real in-flight state only when recovery is actually underway, not whenever a
  client or operator checks offset/status.

### MediaUploadSession Schema And Inspect

- **D-14:** `Rindle.Domain.MediaUploadSession.changeset/2` casts the four new
  fields and preserves the coarse durable-session posture already used by the
  broker and maintenance layers.
- **D-15:** Add a custom `Inspect` implementation for
  `Rindle.Domain.MediaUploadSession` that always redacts populated
  `session_uri` values to `"[REDACTED]"`.
- **D-16:** The redaction rule is absolute across operator surfaces:
  `inspect/2`, logger metadata, test failures, and telemetry metadata must
  never contain raw `session_uri`.

### Telemetry Contract

- **D-17:** Phase 38 freezes exactly two new **public** resumable telemetry
  events:
  - `[:rindle, :upload, :resumable, :status]`
  - `[:rindle, :upload, :resumable, :cancel]`
- **D-18:** Do **not** publish a broader resumable public family in Phase 38.
  `:start`, `:stop`, or richer GCS-specific events can be added later only if
  they are truly needed and only additively.
- **D-19:** Required metadata follows Rindle's existing telemetry posture:
  `:profile` and `:adapter` are required. Allowed low-cardinality metadata keys
  for resumable events are `:state`, `:outcome`, `:reason`, and `:source`.
  `:session_id` may be present as correlation metadata but is not the public
  contract focus.
- **D-20:** Measurements stay numeric and boring:
  - `:status` uses `:committed_bytes`, optional `:offset_delta`, and
    `:system_time`
  - `:cancel` uses `:duration_us` and `:system_time`
- **D-21:** `session_uri`, raw GCS session identifiers, headers, storage keys,
  and response bodies are forbidden in telemetry metadata and failure strings.
- **D-22:** Add a parity/redaction test mirroring the Phase 34 Mux pattern:
  every resumable emit site must prove that `session_uri` never crosses the
  telemetry boundary.
- **D-23:** Phase 39 may extend the resumable telemetry family only
  additively, reusing the same metadata vocabulary rather than renaming it.

### Doctor Check Style

- **D-24:** Phase 38 adds one narrow schema-drift check to
  `mix rindle.doctor`, e.g. `doctor.resumable_session_schema`, implemented via
  direct DB introspection against the adopter-owned table.
- **D-25:** This check confirms the presence of:
  - `session_uri`
  - `session_uri_expires_at`
  - `last_known_offset`
  - `region_hint`
  - the resumable expiry partial index
- **D-26:** One extra structural guard is acceptable if cheap and stable:
  verify `last_known_offset` is `NOT NULL DEFAULT 0`.
- **D-27:** Phase 38 doctor stays **schema-only**. It must not inspect
  profile capability advertisement, GCS runtime config, CORS posture, or
  resumable usage semantics yet.
- **D-28:** More opinionated resumable/GCS checks remain Phase 41 work and
  must be profile-gated so unrelated adopters see zero new noise.

### Decision-Making Preference (Carried Forward, Tightened)

- **D-29:** Carry forward and tighten the standing project preference:
  downstream researchers, planners, and executors should front-load research,
  produce coherent one-shot recommendation sets, decide by default, and avoid
  escalating low-blast-radius design choices back to the user.
- **D-30:** Escalate only for genuinely high-blast-radius decisions such as
  semver-significant public API reshapes, destructive or irreversible
  operations, security/compliance boundary changes, real-cost surprises, or
  milestone/scope reshapes. Phase 38 has no unresolved item that crosses that
  bar.

### Claude's Discretion (Planner / Executor)

- Exact migration filename timestamp and whether the Phase 38 artifact is a
  literal migration file or a generator-template-styled packaged migration file,
  so long as it preserves the adopter-owned migration handoff.
- Whether the doctor schema check validates index name exactly or validates the
  effective partial-index shape through catalog introspection.
- Exact helper organization for resumable redaction and telemetry emit helpers,
  so long as the redaction invariant remains centralized and parity-tested.
- Exact phrasing of doctor PASS/FAIL summaries and fix text.

</decisions>

<specifics>
## Specific Ideas

- Think of `resuming` the same way Rindle already treats coarse durable states:
  it is an operator-meaningful lifecycle milestone, not a transcript of every
  adapter RPC.
- The winning split is:
  - status query without entering recovery: telemetry only, no state mutation
  - explicit recovery request: `"signed" -> "resuming"`
  - actual byte transfer continuation: `"resuming" -> "uploading"`
- Keep the public telemetry surface intentionally small. If deeper GCS protocol
  debugging is ever needed, prefer a separate non-public/internal observability
  family over bloating the public contract.
- The migration handoff should be explicit that plaintext `session_uri` storage
  is the default packaged path, not the only acceptable posture for adopters.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone source of truth
- `.planning/ROADMAP.md` — Phase 38 goal, success criteria, and Phase 39-41
  boundaries that this phase must not blur
- `.planning/REQUIREMENTS.md` — `RESUMABLE-01..03`
- `.planning/PROJECT.md` — current milestone posture, adopter-owned runtime
  constraints, and security invariant 14
- `.planning/STATE.md` — standing decision-making preference

### Locked research
- `.planning/research/v1.6-CANDIDATE-GCS.md` — locked candidate plan, public
  API shape for later phases, migration sketch, telemetry/redaction rules,
  and one-week session-expiry semantics

### Prior phase context that constrains this phase
- `.planning/phases/37-gcs-adapter-foundation/37-CONTEXT.md` — GCS foundation
  decisions, doctor posture, optional-dep/runtime-ownership stance, and
  security posture carried into resumable work

### Existing code seams
- `lib/rindle/domain/media_upload_session.ex` — current upload-session schema
- `lib/rindle/domain/upload_session_fsm.ex` — current durable upload-session
  state machine
- `lib/rindle/upload/broker.ex` — current coarse upload lifecycle and telemetry
  shape
- `lib/rindle/ops/upload_maintenance.ex` — current incomplete-upload expiry and
  cleanup posture
- `lib/rindle/ops/runtime_checks.ex` — existing `mix rindle.doctor` check style
- `lib/rindle/ops/runtime_status.ex` — operator/status separation from doctor
- `lib/rindle/domain/media_provider_asset.ex` — precedent for custom `Inspect`
  redaction and centralized redaction helper design

### Existing tests and docs to mirror
- `test/rindle/contracts/telemetry_contract_test.exs` — frozen public telemetry
  contract style
- `test/rindle/streaming/provider/mux/telemetry_test.exs` — parity/redaction
  test pattern to mirror for `session_uri`
- `test/rindle/domain/migration_test.exs` — direct schema-introspection test
  style
- `test/rindle/doctor_test.exs` — stable doctor output/check ordering
- `guides/getting_started.md` — packaged migration handoff via
  `Application.app_dir(:rindle, "priv/repo/migrations")`
- `guides/upgrading.md` — explicit host-app + packaged migration upgrade path
- `guides/operations.md` — operator split between doctor and runtime status
- `guides/troubleshooting.md` — operator-facing runtime posture

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Rindle.Domain.MediaUploadSession` already models direct-upload persistence and
  is the obvious home for the new resumable columns and `Inspect` redaction.
- `Rindle.Domain.UploadSessionFSM` already enforces coarse durable lifecycle
  transitions; Phase 38 should extend that style rather than inventing a
  protocol-chatty FSM.
- `Rindle.Ops.RuntimeChecks` already implements profile-aware, low-noise doctor
  checks and is the correct place for the new schema drift check.
- `Rindle.Domain.MediaProviderAsset` provides the precedent for custom
  `Inspect` redaction plus parity-tested secret handling.

### Established Patterns

- Public telemetry in Rindle is intentionally small, explicitly documented, and
  protected by a contract test.
- Security-sensitive identifiers are redacted at the domain boundary and then
  parity-tested across all emit sites.
- Doctor checks validate setup/drift; `runtime_status` reports degraded or
  stuck work. Do not collapse those roles.
- Rindle keeps host-app Repo ownership explicit. Packaged migrations are
  shipped for adopters to run, not applied implicitly by the library.

### Integration Points

- Phase 38 persistence/FSM decisions are the substrate Phase 39 will consume
  for resumable initiation/status/cancel broker entrypoints.
- Maintenance and expiry logic in `Rindle.Ops.UploadMaintenance` will later
  need to recognize `"resuming"` and resumable-specific cancel semantics.
- The doctor schema check introduced here becomes the base that Phase 41 can
  layer richer, profile-gated resumable/GCS checks on top of.

</code_context>

<deferred>
## Deferred Ideas

- GCS resumable adapter callbacks and broker entrypoints — Phase 39
- Resumable-aware maintenance cancel contract and runtime-status counters —
  Phase 40
- CORS-suspected doctor check, GCS resumable onboarding guide, optional
  `cloak_ecto` recipe details, and package-consumer proof lane — Phase 41
- Any broader public resumable telemetry family beyond `:status` and `:cancel`
  unless later phases prove the need additively

</deferred>

---

*Phase: 38-resumable-persistence-fsm*
*Context gathered: 2026-05-07*
