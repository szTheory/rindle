---
phase: 104-cache-tooling-hygiene
plan: 03
subsystem: ci-cd
tags: [ci, github-actions, composite-action, cache, no-optional-namespace, secret-gated, dx]

requires:
  - phase: 104-01
    provides: "setup-elixir composite (uses: ./.github/actions/setup-elixir) with cache-prefix input + deps-cache-hit / build-cache-hit outputs"
  - phase: 104-02
    provides: "the quality-job canary pattern (id: setup, install-deps:false, OBS-01 summary repoint) replicated across the remaining jobs"
provides:
  - "setup-elixir adopted across the 7 literal-1.17/27 setup-triplet jobs (integration, contract, proof, package-consumer, adoption-demo-unit, adoption-demo-e2e, adopter)"
  - "optional-dependencies migrated onto the composite with cache-prefix:no-optional (no-optional namespace preserved, D-06)"
  - "package-consumer-gcs-live migrated onto the composite with its secret-gated enabled if-guard intact (D-03)"
affects:
  - "Phase 104 Plan 04 (MinIO-trio adoption: integration/package-consumer/adoption-demo-e2e/adopter/mux-soak + release.yml; ffmpeg align)"
  - "Phase 105 (CI Summary aggregate), 106 (lane/trigger split), 107 (SHA-pin / mix ci)"

tech-stack:
  added: []
  patterns:
    - "uses: ./.github/actions/setup-elixir with install-deps:false to preserve each job's existing job-level deps.get (no dropped/duplicated fetch)"
    - "cache-prefix:no-optional to keep a deliberately-separate deps/_build namespace through the shared composite (D-06)"
    - "secret-gated composite call: same `if: steps.gcs-live-config.outputs.enabled == 'true'` guard moved onto the single uses: step (D-03)"
    - "OBS-01 cache summary repointed to composite outputs (steps.setup.outputs.deps-cache-hit / build-cache-hit) keeping the table markdown byte-identical"

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml

key-decisions:
  - "install-deps:false on EVERY adopting job (not true) so each job keeps its own existing deps.get verbatim — the most behavior-preserving choice; the composite never runs a second/duplicate fetch."
  - "gcs-soak composite adoption DECLINED (plan-sanctioned optional): it has no deps/_build cache today and is fully secret-gated, so adopting the composite would ADD new cache read/write behavior. Left byte-identical (inline setup-beam) to avoid a behavior change on a rarely-run secret-gated lane."
  - "no-optional namespace is preserved THROUGH the composite via cache-prefix:no-optional (yields deps-no-optional-v1-… / build-no-optional-v1-…), not a default-namespace cache — the --no-optional-deps tree never shares the default jobs' cache."

patterns-established:
  - "Composite cache-namespace isolation: cache-prefix routes a job onto a separate deps/_build cache lineage without re-inventing the cache steps."
  - "Optional-adoption discipline: a job whose current behavior lacks a cache is left inline rather than gaining caching it never had, when the plan marks adoption optional."

requirements-completed: [CACHE-01, CACHE-02]

duration: 4min
completed: 2026-06-21
status: complete
---

# Phase 104 Plan 03: Fan-out setup-elixir Adoption Summary

**The 7 literal-1.17/27 setup-triplet jobs (integration, contract, proof, package-consumer, adoption-demo-unit, adoption-demo-e2e, adopter) plus `optional-dependencies` (via `cache-prefix:no-optional`, D-06) and `package-consumer-gcs-live` (secret-gate guard intact, D-03) now `uses: ./.github/actions/setup-elixir` — replacing the inline setup-beam + deps/_build cache triplet — with every required-check NAME, `name: CI`, and the `ci.yml` filename byte-identical, and the actionlint baseline (6) unchanged.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-06-21T16:52Z
- **Completed:** 2026-06-21T16:56:45Z
- **Tasks:** 2
- **Files modified:** 1 (`.github/workflows/ci.yml`)

## Accomplishments

- **Task 1 (CACHE-01, D-03 step 2):** Replaced the inline `Set up Elixir` (setup-beam) + `Restore deps cache` + `Restore build cache` triplet in **integration, contract, proof, package-consumer, adoption-demo-unit, adoption-demo-e2e, adopter** with a single `uses: ./.github/actions/setup-elixir` step (`elixir-version: "1.17"`, `otp-version: "27"`, `mix-env: test`, `install-deps: "false"`). Repointed the OBS-01 "Summarize cache hit/miss" steps in **integration** and **package-consumer** to `steps.setup.outputs.deps-cache-hit` / `build-cache-hit` (gave those two jobs `id: setup`), keeping the table markdown byte-identical. All compile/test/flag steps + the MinIO trio left untouched at job level (D-01; MinIO is Plan 04).
- **Task 2 (CACHE-01, D-06/D-03):** Migrated **optional-dependencies** onto the composite with `cache-prefix: no-optional` + `install-deps: "false"`, preserving its `deps-no-optional-`/`build-no-optional-` namespace and keeping the job-level `mix deps.get --no-optional-deps` and `mix compile --no-optional-deps --warnings-as-errors` exactly as-is. Migrated **package-consumer-gcs-live** onto the composite carrying the same `if: steps.gcs-live-config.outputs.enabled == 'true'` secret-gate guard, with `install-deps: "false"` keeping its enabled-gated `mix deps.get`.

## Per-job install-deps choice (recorded per plan)

| Job | install-deps | Why |
|-----|--------------|-----|
| integration | `false` | keeps its bare job-level `mix deps.get` (between FFmpeg/MinIO setup) |
| contract | `false` | keeps `mix deps.get` before the job-level `Compile` |
| proof | `false` | keeps `mix deps.get` before the job-level `Compile` |
| package-consumer | `false` | keeps `mix deps.get`; composite is the long-pole job's setup source |
| adoption-demo-unit | `false` | real fetch is `mix deps.get` **inside** `examples/adoption_demo` (working-directory block); a root composite fetch would be wrong/extra |
| adoption-demo-e2e | `false` | keeps `Install root dependencies` (`mix deps.get`) |
| adopter | `false` | keeps `mix deps.get` before the MinIO trio |
| optional-dependencies | `false` | keeps the special `mix deps.get --no-optional-deps` |
| package-consumer-gcs-live | `false` | keeps its enabled-gated `mix deps.get` |

Rationale: `install-deps:false` everywhere is the maximally behavior-preserving option — no job loses or gains a `deps.get`; the composite contributes setup + cache only, never a second fetch.

## gcs-soak adoption decision (recorded per plan)

**DECLINED.** `gcs-soak` (now ~L1140) inlines only `erlef/setup-beam@v1` + a plain `mix deps.get`, has **no** deps/_build `actions/cache` today, and is fully `enabled == 'true'`-gated. Adopting the composite there would **add** deps/_build cache read/write behavior it does not currently have — a behavior change on a rarely-run secret-gated lane. The plan explicitly marks gcs-soak adoption optional, so it is left **byte-identical** (inline setup-beam). The only remaining `erlef/setup-beam@v1` references in `ci.yml` are now **gcs-soak** (declined) and **mux-soak** (MinIO-trio job; setup migration is Plan 04 territory).

## no-optional namespace confirmation

`optional-dependencies` calls the composite with `cache-prefix: no-optional`. The composite's `Compute cache namespaces` step maps any non-`default` prefix to `deps-<prefix>` / `build-<prefix>`, so the resolved cache keys are `deps-no-optional-v1-…` / `build-no-optional-v1-…`. The `--no-optional-deps` tree therefore resolves through the composite into the **distinct** no-optional namespace and never shares a cache with the default-namespace jobs (D-06 held). Note: the old key carried coarse `${{ matrix.elixir }}-${{ matrix.otp }}` + `hashFiles('**/mix.lock')`; the composite key carries resolved-version segments + repo-root `hashFiles('mix.lock')` + the `v1` buster (CACHE-02 schema) — an intentional first-run cold-miss as this namespace re-keys onto the corrected schema, identical to how the canary re-keyed the default namespace in Plan 02.

## Files Created/Modified

- `.github/workflows/ci.yml` — 9 jobs migrated onto `setup-elixir` (7 literal-1.17/27 in Task 1; optional-dependencies + package-consumer-gcs-live in Task 2). No other job touched; gcs-soak and mux-soak left inline by design.

## Decisions Made

- **install-deps:false on all 9 adopting jobs** — preserves each job's existing `deps.get` verbatim (no drop, no duplicate). Mirrors the Plan-02 canary, which also used `install-deps:false`.
- **gcs-soak DECLINED** — no existing cache + secret-gated → leave byte-identical to avoid introducing new cache behavior (plan-sanctioned optional skip).
- **no-optional namespace via cache-prefix** — preserved through the shared composite (D-06), not re-invented and not collapsed into the default namespace.

## Deviations from Plan

None — plan executed exactly as written. The `install-deps:false`-everywhere choice and the gcs-soak decline are both plan-offered options (the plan instructs deciding install-deps per job and explicitly marks gcs-soak adoption optional); neither is an unplanned deviation.

## Issues Encountered

- **package-consumer cache ordering.** In the pre-migration job the deps/_build cache steps sat *after* the Node/FFmpeg/libvips installs; the composite (which bundles caching) now runs at the top of the job before those installs. This is behavior-neutral — the deps/_build caches are independent of system packages — and it matches the canonical composite placement used in the canary and every other adopting job. The OBS-01 summary still reads the composite outputs correctly.

## Validation Results

- **YAML:** `ci.yml` parses (`yaml.safe_load`) after every task and on the committed file.
- **actionlint (v1.7.12):** 6 findings before and after — identical to the documented pre-existing baseline (3× SC2209 on `MIX_ENV=test mix …` lines; 2× `property "elixir" is not defined` at junit-coverage artifact-name lines in non-matrix jobs; 1× SC2209 on the quality `mix doctor` line). **No new findings introduced.**
- **Task 1:** composite adoption count went 1 → 8 (`>= 8` ✓); `name: Integration`, `name: Adopter`, `name: Package Consumer Proof Matrix + Release Preflight` present; `head -1` == `name: CI`; **zero** dangling `steps.deps-cache` / `steps.build-cache` references remain (both OBS-01 summaries repointed).
- **Task 2:** composite count 8 → 10; `cache-prefix` + `no-optional` present; `name: ADMIN-06 Optional Dependencies` intact; `compile --no-optional-deps --warnings-as-errors` intact; the gcs-live composite call carries the `enabled == 'true'` guard (verified the `uses:` line is preceded by that `if:`).
- **Required-check NAMEs:** Quality, Integration, Contract, Proof, Package Consumer Proof Matrix + Release Preflight, Adopter, Adoption Demo Unit, Adoption Demo E2E — all byte-identical.
- **No unexpected deletions:** `git diff --diff-filter=D` over the plan's commit range is empty.

## Prohibitions Held (D-16)

- `grep -c 'workflow_call:' ci.yml` == **0** (no reusable workflow).
- No new top-level `CI Summary` / aggregate job — `grep -c 'CI Summary'` == 0 (Phase 105 boundary).
- No `concurrency:` block added — count 0 (Phase 106 boundary).
- No third-party action SHA-pin and no `mix ci` alias introduced (Phase 107 boundary); the composite is referenced via in-repo `uses: ./…`.
- `name: CI` (line 1), required-check NAMEs, and the `ci.yml` filename byte-identical (D-04, D-15).

## Known Stubs

None. Every edit wires a real job onto the real composite outputs / cache namespace; no placeholder data.

## Threat Flags

None. No new network endpoint, auth path, or trust boundary introduced — the changes are setup/cache-step refactors within existing jobs, and the secret-gated guard on gcs-live was preserved (T-104-09 mitigation held).

## Next Plan Readiness

- The setup-triplet is now centralized on `setup-elixir` across every CI job that should carry it. **Plan 04** owns the MinIO-trio adoption (integration, package-consumer, adoption-demo-e2e, adopter, mux-soak) onto `setup-minio` + the `release.yml` callers + the ffmpeg-alignment swap. mux-soak's `setup-beam` stays inline until then (its MinIO trio + setup are Plan 04's concern); gcs-soak stays inline by the documented decline.
- **Open empirical confirmation for the next CI run** (observational, non-blocking): the no-optional namespace cold-misses once on its first composite-keyed run (re-key onto the CACHE-02 schema), then hits; the OBS-01 cache tables in integration + package-consumer render byte-equivalent to the pre-migration tables.

## Self-Check: PASSED

- `.github/workflows/ci.yml` exists and parses as valid YAML on the committed HEAD.
- `.planning/phases/104-cache-tooling-hygiene/104-03-SUMMARY.md` exists.
- Both task commits present in git history: `ebd46f2` (Task 1), `b987d40` (Task 2).
- actionlint findings unchanged from baseline (6, no new findings).

---
*Phase: 104-cache-tooling-hygiene*
*Completed: 2026-06-21*
