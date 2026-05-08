# Phase 37: GCS Adapter Foundation - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or
> execution agents. Decisions captured in CONTEXT.md — this log preserves
> the analysis.

**Date:** 2026-05-07
**Phase:** 37-gcs-adapter-foundation
**Mode:** assumptions
**Areas analyzed:** Module file layout, public contract shape, optional deps + config keying, CI proof lane + test harness

## Assumptions Presented

### Module file layout & seam mirroring

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 3-file split: `gcs.ex` (behaviour) + `gcs/client.ex` (Finch JSON-API) + `gcs/signer.ex` (V4 signing) | Confident | `lib/rindle/storage/s3.ex` (197 LOC, single-file, but delegates to `ExAws.S3.*`); candidate plan §3+§11 lock hand-rolled ~250 LOC over Finch; Phases 38–41 add 4 more callbacks sharing same plumbing; `mix.exs:158-163` hexdoc grouping |

### Public contract shape (mirrors `Rindle.Storage.S3`)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `head/2 → {:ok, %{size:, content_type:}}`, `{:error, :not_found}` on 404 | Confident | `lib/rindle/storage/s3.ex:130-149`; `test/rindle/storage/s3_test.exs:117`; `test/rindle/storage/storage_adapter_test.exs:41-51` |
| `store/3` writes `Content-Type` + `Content-Disposition` as object metadata, not URL params | Confident | Active Storage lesson (candidate §8.7 + §10); GCS V4 signed URLs don't enforce `response-content-*` |
| `url/2` accepts `expires_in` opt, falls back to `Rindle.Config.signed_url_ttl_seconds/0` | Confident | `lib/rindle/storage/s3.ex:55-61`; `lib/rindle/config.ex:14-17` |
| Phase 37 does NOT touch `lib/rindle/error.ex` — atoms route through generic fallthrough | Confident | `lib/rindle/error.ex:334-336`; S3's `:missing_bucket` at `lib/rindle/storage/s3.ex:173-178` is a bare-atom transport error with no message branch |

### Optional deps + config keying

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `goth ~> 1.4`, `finch ~> 0.21`, `gcs_signed_url ~> 0.4.6` as `optional: true` | Confident | `mix.exs:67-69` (mux/jose optional pattern from v1.6) |
| Extend `mix.exs:22 dialyzer.plt_add_apps` with `:goth` + `:gcs_signed_url` | Confident | `mix.exs:22` currently `[:mix, :ex_unit, :mux, :jose]` |
| Config keyspace `Rindle.Storage.GCS` mirrors S3 `Application.get_env(:rindle, __MODULE__, [])` | Confident | `lib/rindle/storage/s3.ex:173-177` |
| `Code.ensure_loaded?(Goth) → {:error, :goth_unconfigured}` runtime guard | Confident | `lib/rindle/ops/runtime_checks.ex:536` (Mux equivalent) |

### CI proof lane + test harness

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `gcs-soak` job mirrors `mux-soak` shape but secret-gated, not label-gated | Likely | `.github/workflows/ci.yml:566-653`; REQUIREMENTS GCS-04 specifies "secret presence" not "label" |
| Tests at `test/rindle/storage/gcs_test.exs` tagged `@tag :gcs` with `@gcs_skip_reason` | Confident | `test/rindle/storage/s3_test.exs:13-18, 29-30` |
| Bypass alone (already in `mix.exs:92`) for unit-level fixtures; live bucket for `@tag :gcs` | Likely | `mix.exs:92` — Bypass already declared `only: :test` |
| Phase 37 does NOT add doctor branch (Phase 41 / RESUMABLE-13) | Confident | REQUIREMENTS.md RESUMABLE-13 maps to Phase 41; locked candidate plan §2 firmly places doctor in Phase 41 |
| Phase 37 does NOT touch package-consumer lane (Phase 41 / RESUMABLE-14) | Confident | REQUIREMENTS.md RESUMABLE-14 maps to Phase 41 |

## Corrections Made

### 2026-05-07 (initial run)

No corrections — user selected "Yes, proceed" and confirmed all 4
assumption areas as locked decisions.

### 2026-05-07 (continuation run, doctor scope re-opened)

Re-ran assumption analysis to surface unresolved scope ambiguity. User
**flipped the doctor-scope decision** from the initial run:

| Decision | Initial run | User correction |
|----------|-------------|-----------------|
| Does Phase 37 ship `mix rindle.doctor` GCS health checks? | NO — defer all doctor work to Phase 41 (RESUMABLE-13) | YES — Phase 37 ships basic Goth/bucket/signing-key health checks; Phase 41 layers the resumable-specific CORS-suspected check on top |
| Reason | Loose ROADMAP phrasing read as superseded by candidate plan §2 placing all doctor work in Phase 41 | ROADMAP success criterion #5 (`.planning/ROADMAP.md:105-108`) is the binding contract; basic checks belong with the adapter that needs to be checked, resumable-specific check belongs with the resumable capability promotion in Phase 41 |
| Effect on CONTEXT.md | D-13 read "Phase 37 does NOT add doctor branch" | D-13 now reads "Phase 37 ships basic doctor health checks; resumable-specific CORS check stays Phase 41" |

User also confirmed the other 5 area assumptions correct as written:
adapter shape (D-01..D-05), config & runtime (D-06..D-09 + Area 2 framing
of `:finch_unconfigured`), V4 signing & metadata (D-02..D-04 + Area 3
framing), CI lane (D-10..D-11), test seam (D-12 + Area 5 framing —
real-bucket-only in Phase 37, defer Bypass-fakegcs to Phase 39).

## Scope Correction Surfaced

The earlier "scope correction" framing — that ROADMAP wording was loose and
REQUIREMENTS was the binding contract — was itself the wrong call. ROADMAP
success criterion #5 IS the binding scope statement for Phase 37; REQUIREMENTS
GCS-01..04 don't enumerate every shipping artifact (that's the ROADMAP's job).
The basic doctor checks belong in Phase 37 and Phase 41 layers the
resumable-specific branch on top.

## External Research

None performed. The locked candidate plan
(`.planning/research/v1.6-CANDIDATE-GCS.md`) verified hex versions live
on hex.pm at the time of writing (2026-05-06), and REQUIREMENTS.md
preserves those locks. No additional research surface required for
Phase 37; downstream `gsd-phase-researcher` may revalidate library
versions before plan execution.
