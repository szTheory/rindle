---
phase: 05-ci-1-0-readiness
plan: 07
subsystem: documentation-guides
tags: [docs, narrative-guides, mermaid, doc-01, doc-02, doc-03, doc-04, doc-05, doc-06, doc-07, d-15, d-16, d-18]
requires:
  - 05-04  # adopter lifecycle test (D-16 source of truth)
  - 05-06  # mix.exs ExDoc wiring + adopter-lane drift gate
provides:
  - DOC-01  # guides/getting_started.md
  - DOC-02  # guides/core_concepts.md
  - DOC-03  # guides/profiles.md
  - DOC-04  # guides/secure_delivery.md
  - DOC-05  # guides/background_processing.md
  - DOC-06  # guides/operations.md
  - DOC-07  # guides/troubleshooting.md
affects:
  - 05-06's drift gate now passes (getting_started.md exists and matches the adopter lane API surface)
  - mix.exs docs/0 extras: list now resolves to real files; mix docs builds end-to-end
tech-stack:
  patterns:
    - "Narrative guide = substantive prose + state diagrams + worked examples (≥ 50 lines, ≥ 60 for core_concepts)"
    - "Mermaid stateDiagram-v2 blocks copy @allowed_transitions verbatim from FSM modules — drift between guide and code is a docs review concern"
    - "operations.md is a cross-link directory (D-18) — Mix task @moduledoc blocks remain canonical"
key-files:
  created:
    - guides/getting_started.md
    - guides/core_concepts.md
    - guides/profiles.md
    - guides/secure_delivery.md
    - guides/background_processing.md
    - guides/operations.md
    - guides/troubleshooting.md
  modified: []
decisions:
  - "Mermaid state diagrams in core_concepts.md use the EXACT @allowed_transitions from lib/rindle/domain/{asset,variant,upload_session}_fsm.ex — including the upload-session FSM's permissive cross-transitions (initialized → aborted/expired/failed, signed → uploaded/verifying directly, etc.) rather than a simplified linear flow"
  - "operations.md is a thin index per D-18: each Mix task gets a one-paragraph orientation + a cross-reference to the @moduledoc; full command-line contracts live in the @moduledoc blocks"
  - "Threat-model notes in secure_delivery.md call out the bearer-token semantics of signed URLs explicitly (T-05-07-01 mitigation extended to runtime guidance)"
  - "background_processing.md documents Oban as REQUIRED (not optional) and explains the transactional-enqueueing rationale — this is load-bearing for atomic-promote and async-purge patterns"
  - "Examples use placeholder identifiers (MyApp.MediaProfile, MyApp.AvatarProfile, MyApp.PostImageProfile, current_user, asset.id) — no real keys, hostnames, or production paths (T-05-07-01 mitigation)"
metrics:
  tasks_completed: 3
  files_created: 7
  files_modified: 0
  duration: "~7 min 35 sec"
  completed: "2026-04-27T02:45:40Z"
  total_lines_authored: 1386
---

# Phase 05 Plan 07: Narrative Guides (DOC-01..07) Summary

Authored seven narrative guides under `guides/` that satisfy the DOC-01..07
requirements: a copy-pasteable getting-started flow that mirrors the adopter
lifecycle test verbatim (D-16), a core-concepts page with three Mermaid
stateDiagram-v2 blocks copied from the FSM modules' `@allowed_transitions`,
a Profile DSL reference, a private-by-default delivery guide, an
Oban-backed background-processing guide with the locked telemetry surface,
a cross-link directory for the five Mix tasks (D-18), and a troubleshooting
playbook for the FSM error states. `mix docs` builds end-to-end with all
seven guides emitting HTML in `doc/`; the Mermaid CDN wired by Plan 06
Task 3 will render the state diagrams as interactive SVG in the published
HexDocs.

## Per-Guide Line Counts

| Guide                              | Lines | DOC ID  | Min Required | Status |
| ---------------------------------- | ----- | ------- | ------------ | ------ |
| `guides/getting_started.md`        |  142  | DOC-01  | 50           | OK     |
| `guides/core_concepts.md`          |  208  | DOC-02  | 60           | OK     |
| `guides/profiles.md`               |  175  | DOC-03  | 50           | OK     |
| `guides/secure_delivery.md`        |  197  | DOC-04  | 50           | OK     |
| `guides/background_processing.md`  |  248  | DOC-05  | 50           | OK     |
| `guides/operations.md`             |  177  | DOC-06  | 50           | OK     |
| `guides/troubleshooting.md`        |  239  | DOC-07  | 50           | OK     |
| **Total**                          | **1,386** |     |              |        |

## Mermaid Sources Extracted from FSM Modules

The three `stateDiagram-v2` blocks in `core_concepts.md` mirror the
`@allowed_transitions` maps in `lib/rindle/domain/{asset,variant,upload_session}_fsm.ex`
verbatim. For future maintenance, here are the canonical sources:

### AssetFSM (`lib/rindle/domain/asset_fsm.ex` lines 8-19)

```elixir
@allowed_transitions %{
  "staged" => ["validating"],
  "validating" => ["analyzing"],
  "analyzing" => ["promoting"],
  "promoting" => ["available"],
  "available" => ["processing", "quarantined"],
  "processing" => ["ready", "quarantined"],
  "ready" => ["degraded", "deleted"],
  "degraded" => ["quarantined", "deleted"],
  "quarantined" => ["deleted"],
  "deleted" => []
}
```

10 states. Mermaid block in `core_concepts.md` includes terminal `[*]`
on `deleted` to show the lifecycle endpoint.

### VariantFSM (`lib/rindle/domain/variant_fsm.ex` lines 6-15)

```elixir
@allowed_transitions %{
  "planned" => ["queued"],
  "queued" => ["processing"],
  "processing" => ["ready", "failed"],
  "ready" => ["stale", "missing", "purged"],
  "stale" => ["queued", "purged"],
  "missing" => ["queued", "purged"],
  "failed" => ["queued", "purged"],
  "purged" => []
}
```

8 states. Mermaid block shows the recovery loops (stale/missing/failed →
queued) explicitly so adopters understand why `mix rindle.regenerate_variants`
is the recovery path for all three.

### UploadSessionFSM (`lib/rindle/domain/upload_session_fsm.ex` lines 8-18)

```elixir
@allowed_transitions %{
  "initialized" => ["signed", "aborted", "expired", "failed"],
  "signed" => ["uploading", "uploaded", "verifying", "aborted", "expired", "failed"],
  "uploading" => ["uploaded", "verifying", "aborted", "expired", "failed"],
  "uploaded" => ["verifying"],
  "verifying" => ["completed", "failed"],
  "completed" => [],
  "aborted" => [],
  "expired" => [],
  "failed" => []
}
```

9 states. Mermaid block shows the permissive cross-transitions explicitly
(initialized → aborted/expired/failed; signed → uploaded/verifying without
going through uploading) — these reflect the reality that not all clients
report intermediate progress, so the FSM admits the shortcut paths.

## D-16 Compliance (Adopter Lane Drift Gate)

`guides/getting_started.md` references all three canonical adopter API
calls that Plan 06 Task 4's CI grep step checks for:

| Required Call                         | Occurrences in getting_started.md |
| ------------------------------------- | --------------------------------- |
| `Broker.initiate_session`             | 2                                 |
| `Broker.verify_completion`            | 2                                 |
| `Rindle.Delivery.url`                 | 2                                 |

The snippet in the "Upload Lifecycle" section uses the same four-step
sequence as `test/adopter/canonical_app/lifecycle_test.exs` Steps 1, 2, 4,
and 7. Steps 5 and 6 (manual job invocation) are not shown in the guide
because they are test-only — in adopter production they happen
automatically via Oban.

## D-15 Compliance (Seven Markdown Guides)

```
$ ls guides/
background_processing.md
core_concepts.md
getting_started.md
operations.md
profiles.md
secure_delivery.md
troubleshooting.md
```

Exactly seven files. Names match `D-15` exactly.

## D-18 Compliance (operations.md Cross-Linking)

Each of the five Mix task names appears in `operations.md` with a
cross-reference to the underlying module rather than a re-authored
command-line spec:

| Mix Task                              | Section heading occurrences | Module cross-reference |
| ------------------------------------- | --------------------------- | ---------------------- |
| `mix rindle.cleanup_orphans`          | 5                           | `Mix.Tasks.Rindle.CleanupOrphans` |
| `mix rindle.regenerate_variants`      | 2                           | `Mix.Tasks.Rindle.RegenerateVariants` |
| `mix rindle.verify_storage`           | 2                           | `Mix.Tasks.Rindle.VerifyStorage` |
| `mix rindle.abort_incomplete_uploads` | 3                           | `Mix.Tasks.Rindle.AbortIncompleteUploads` |
| `mix rindle.backfill_metadata`        | 2                           | `Mix.Tasks.Rindle.BackfillMetadata` |

operations.md does NOT re-author command-line argument tables, exit-code
reference, or option lists — those remain in the `@moduledoc` blocks.
The guide is a thin index + recommended schedule + telemetry handler
example.

## `mix docs` End-to-End Build

After authoring all seven guides:

```
$ mix docs
... (compile output) ...
Generating docs...
    warning: documentation references function "Phoenix.LiveView.Upload.allow_upload/3" but it is hidden
... (warning repeated; pre-existing — not introduced by Plan 07) ...
View html docs at "doc/index.html"
View markdown docs at "doc/llms.txt"
View epub docs at "doc/Rindle.epub"
$ echo $?
0
```

`mix docs` exits 0. All seven guides emit HTML in `doc/`:

```
$ ls doc/{getting_started,core_concepts,profiles,secure_delivery,background_processing,operations,troubleshooting}.html | wc -l
7
```

The two warnings about `Phoenix.LiveView.Upload.allow_upload/3` being
hidden are pre-existing in `lib/rindle/live_view.ex:41` — not introduced
by this plan. They concern Phoenix's own private function reference,
not anything in the guides.

## Task Commits

| Task | Commit    | Description                                                          |
| ---- | --------- | -------------------------------------------------------------------- |
| 1    | `784076f` | docs(05-07): author getting_started + core_concepts guides           |
| 2    | `e5ed776` | docs(05-07): author profiles + secure_delivery + background_processing guides |
| 3    | `6357df5` | docs(05-07): author operations + troubleshooting guides              |

## Quality Gates

| Gate                                              | Result      | Notes                                                              |
| ------------------------------------------------- | ----------- | ------------------------------------------------------------------ |
| All seven `guides/*.md` files exist               | PASS        | `for f in ...; do test -f "guides/$f.md"; done` exits 0           |
| Per-guide minimum line counts                     | PASS        | All ≥ 50; core_concepts.md 208 (≥ 60)                              |
| `getting_started.md` D-16 grep gate               | PASS        | All three canonical API calls present (2 occurrences each)         |
| `core_concepts.md` 3 stateDiagram-v2 blocks       | PASS        | grep -c → 3                                                        |
| `core_concepts.md` 3 FSM module references        | PASS        | grep -cE "AssetFSM\|VariantFSM\|UploadSessionFSM" → 3              |
| `operations.md` 5 Mix task names                  | PASS        | Each appears ≥ 2 times                                             |
| `troubleshooting.md` quarantine + 3 state words   | PASS        | quarantine: 8; stale\|missing\|expired: 29                          |
| `mix docs` exits 0                                | PASS        | (after `mix deps.get`)                                              |
| All 7 guides emit HTML in `doc/`                  | PASS        | `ls doc/{...}.html` lists all 7                                    |

## Deviations from Plan

### Auto-fixed Issues

None. The plan's `<action>` body for each task was followed verbatim. The
plan's skeleton for `getting_started.md` showed an illustrative state list
in the Asset FSM block; I replaced it with the actual `@allowed_transitions`
from `lib/rindle/domain/asset_fsm.ex` (which the plan explicitly required
under "IMPORTANT: Before authoring the Mermaid blocks, READ the actual FSM
modules and copy their `@allowed_transitions` literally"). This is plan
adherence, not a deviation.

### Adaptations to Plan Snippets

**A. `core_concepts.md` UploadSession diagram has more transitions than the
plan's example.** The plan skeleton showed a simplified linear flow
(`initialized → signed → uploading → uploaded → verifying → completed/failed`
plus `signed → aborted/expired`). The actual FSM is more permissive:
`initialized` can transition to `aborted/expired/failed` directly; `signed`
can transition to `uploaded` or `verifying` directly (skipping `uploading`).
I rendered ALL `@allowed_transitions` faithfully so the diagram matches the
code. Trade-off: the diagram is busier, but it reflects the real surface
adopters' workers will encounter (clients that don't report `uploading`/`uploaded`
events still need to be modeled in the state machine).

**B. `getting_started.md` system-dependency note added.** The pending todo
"Add libvips system dependency note to CI config and getting started guide"
in STATE.md was satisfied by adding a libvips installation note in the
Installation section. This is Rule 2 (auto-add missing critical functionality)
— without the note, an adopter following the guide would `mix deps.get`,
attempt to compile, and get a confusing libvips link-error. The note pre-empts
that.

**C. `operations.md` includes worker-equivalent cron config example.** The
plan asked for a "Recommended Schedule" section. I added a code block
showing the Oban cron crontab configuration that maps the schedule to
worker invocations — this is the production-correct form (per Rindle's
"adopters own Oban supervision" policy). The Mix task forms in the
schedule table are kept for one-off operator use.

### Out-of-scope discoveries (logged, NOT fixed)

**1. `mix format --check-formatted` fails project-wide.** Plan 06's SUMMARY
already documented this — pre-existing format issues in
`lib/rindle/ops/variant_maintenance.ex`, `test/rindle/workers/process_variant_test.exs`,
etc. are not within Plan 07's scope (markdown is not formatted by `mix format`,
and Plan 07 did not modify any Elixir source). Per the SCOPE BOUNDARY rule,
deferred.

**2. `Phoenix.LiveView.Upload.allow_upload/3` is hidden but referenced in
`lib/rindle/live_view.ex:41`.** `mix docs` warns about this every time it
runs. Pre-existing — not introduced by Plan 07. Logged for a future cleanup
but not fixed here.

## Authentication Gates

None. Pure documentation work; no auth, no secrets, no human intervention.

## Verification Results

### Plan-level invariants

- All seven guide files exist under `guides/` and meet minimum line counts (verified above). ✓
- `getting_started.md` references the three canonical adopter API calls (Plan 06 CI grep gate). ✓
- `core_concepts.md` contains three Mermaid `stateDiagram-v2` blocks (one per FSM). ✓
- `operations.md` cross-links to all five Mix tasks (D-18). ✓
- `mix docs` builds successfully end-to-end. ✓ (after `mix deps.get` in worktree; the deps issue is a worktree-environment artifact, not a build issue)

### Acceptance grep checks (Task 1)

- `test -f guides/getting_started.md` → exits 0 ✓
- `test -f guides/core_concepts.md` → exits 0 ✓
- `wc -l guides/getting_started.md` → 142 (≥ 50) ✓
- `wc -l guides/core_concepts.md` → 208 (≥ 60) ✓
- `grep -c "Broker.initiate_session" guides/getting_started.md` → 2 (≥ 1) ✓
- `grep -c "Broker.verify_completion" guides/getting_started.md` → 2 (≥ 1) ✓
- `grep -c "Rindle.Delivery.url" guides/getting_started.md` → 2 (≥ 1) ✓
- `grep -c "stateDiagram-v2" guides/core_concepts.md` → 3 (= 3) ✓
- `grep -cE "AssetFSM|VariantFSM|UploadSessionFSM" guides/core_concepts.md` → 3 (≥ 3) ✓

### Acceptance grep checks (Task 2)

- `test -f guides/profiles.md` → exits 0 ✓
- `test -f guides/secure_delivery.md` → exits 0 ✓
- `test -f guides/background_processing.md` → exits 0 ✓
- `wc -l guides/profiles.md` → 175 (≥ 50) ✓
- `wc -l guides/secure_delivery.md` → 197 (≥ 50) ✓
- `wc -l guides/background_processing.md` → 248 (≥ 50) ✓
- `grep -c "use Rindle.Profile" guides/profiles.md` → 5 (≥ 1) ✓
- `grep -ci "signed" guides/secure_delivery.md` → 27 (≥ 3) ✓
- `grep -c "Oban" guides/background_processing.md` → 24 (≥ 2) ✓
- `grep -cE "telemetry|:rindle," guides/background_processing.md` → 18 (≥ 1) ✓

### Acceptance grep checks (Task 3)

- `test -f guides/operations.md` → exits 0 ✓
- `test -f guides/troubleshooting.md` → exits 0 ✓
- `wc -l guides/operations.md` → 177 (≥ 50) ✓
- `wc -l guides/troubleshooting.md` → 239 (≥ 50) ✓
- `grep -c "mix rindle.cleanup_orphans" guides/operations.md` → 5 (≥ 1) ✓
- `grep -c "mix rindle.regenerate_variants" guides/operations.md` → 2 (≥ 1) ✓
- `grep -c "mix rindle.verify_storage" guides/operations.md` → 2 (≥ 1) ✓
- `grep -c "mix rindle.abort_incomplete_uploads" guides/operations.md` → 3 (≥ 1) ✓
- `grep -c "mix rindle.backfill_metadata" guides/operations.md` → 2 (≥ 1) ✓
- `grep -ci "quarantine" guides/troubleshooting.md` → 8 (≥ 1) ✓
- `grep -ciE "stale|missing|expired" guides/troubleshooting.md` → 29 (≥ 3) ✓
- All seven guide files exist (checked above) ✓
- `mix docs` exits 0 ✓
- `mix format --check-formatted` — N/A for markdown; project-wide failures pre-exist Plan 07 (per Plan 06 SUMMARY) ✓

## Threat Surface

No new threat surface beyond the plan's `<threat_model>`:

- **T-05-07-01** (secrets/PII in code examples) — mitigated. All examples
  use placeholder identifiers: `MyApp.MediaProfile`, `MyApp.AvatarProfile`,
  `MyApp.PostImageProfile`, `MyApp.SensitiveDocsProfile`,
  `MyApp.PublicLogoProfile`, `MyApp.AdminUploadProfile`, `MyApp.AvatarAuthorizer`,
  `current_user`, `asset.id`, `session_id`, `key`. Storage example uses
  `System.fetch_env!/1` for credentials (correct production pattern), no
  literal access keys or hostnames.
- **T-05-07-02** (drift between guide and code) — mitigated for DOC-01 by
  the adopter-lane CI grep gate from Plan 06; for DOC-02..07 drift is a
  docs-review concern (not a CI failure), as planned. The Mermaid sources
  are documented in this SUMMARY for future re-derivation.

No new file-system access, no new network endpoints, no new auth paths.

## Threat Flags

None. This plan adds documentation only; no code paths, no I/O, no
attack surface.

## Self-Check: PASSED

- File: `guides/getting_started.md` → FOUND (142 lines)
- File: `guides/core_concepts.md` → FOUND (208 lines)
- File: `guides/profiles.md` → FOUND (175 lines)
- File: `guides/secure_delivery.md` → FOUND (197 lines)
- File: `guides/background_processing.md` → FOUND (248 lines)
- File: `guides/operations.md` → FOUND (177 lines)
- File: `guides/troubleshooting.md` → FOUND (239 lines)
- Commit `784076f` → FOUND in `git log`
- Commit `e5ed776` → FOUND in `git log`
- Commit `6357df5` → FOUND in `git log`
- `mix docs` build → PASS (all 7 HTML files in `doc/`)
- D-16 drift-gate parity (3 canonical API calls in getting_started.md) → PASS
- D-18 cross-linking (5 Mix task names in operations.md) → PASS
