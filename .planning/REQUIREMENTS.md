# Requirements: Rindle — v1.21 CI/DX Reliability Tail

**Defined:** 2026-06-26
**Core Value:** Media, made durable. *(Milestone lens: a green PR reliably means a green `main` — a trustworthy, deterministic merge gate.)*
**Charter:** SEED-004 + the 2026-06-26 flake cluster. Non-feature/DX milestone; ships Hex **0.3.2** (two adopter-invisible `lib/` patches authorized, D-v1.21-01). Research locked in `.planning/research/v1.21-*.md`.

## v1 Requirements

Requirements for this milestone. Each maps to exactly one roadmap phase.

### Coverage — single-run suite (COV)

Source: `v1.21-COVERAGE-SINGLE-RUN.md`. CI/mix-config only; zero `lib/`.

- [x] **COV-01**: Each default-suite lane (`quality`, `integration`, install-smoke/adoption) runs the ExUnit suite **exactly once** per matrix cell. The `quality` lane emits both the console gate and `cover/excoveralls.json` from that one run (`mix coveralls.multiple --type local --type json --slowest 20`); the `integration` and install-smoke/adoption lanes **drop their redundant standalone coverage run** (decision 2b — no artifact consumer exists), leaving each with one suite execution.
- [x] **COV-02**: The merge-blocking coverage gate keeps running the **`local`** analyzer (`ensure_minimum_coverage` still exercised); gate pass/fail is **never** derived from `coveralls.json`'s exit code.
- [x] **COV-03**: The redundant standalone coverage run is removed from all three lanes (the `Generate coverage JSON artifact` step on `quality`; the standalone `mix coveralls.json` step on `integration`/adoption). `cover/excoveralls.json` is still produced at the same path on the `quality` lane and uploaded; integration/adoption upload steps tolerate its absence (`if-no-files-found: warn` preserved).
- [x] **COV-04**: A contributor reproduces the CI coverage step locally with one documented command (`mix coveralls.multiple --type local --type json --slowest 20`, in RUNNING.md); the gate alone stays reproducible via `mix coveralls`. `mix ci`'s final merge-blocking `test` task is **unchanged** (D-08 — dual-output is a CI-only concern), preserving local↔CI parity.

### Subprocess `:epipe` hardening (EPIPE) — `lib/`

Source: `v1.21-SUBPROCESS-EPIPE.md`. Root cause: upstream MuonTrap #98. Adopter-invisible; ships `fix:`.

- [x] **EPIPE-01**: `Rindle.AV.Subprocess.run/3` never propagates `:epipe` (or any broken-pipe transport exit) to its caller; the caller still receives the real `{output, status}`.
- [x] **EPIPE-02**: The fix preserves the exact contract (`{collectable, status | :timeout}`, `into: ""`, `stderr_to_stdout: true`) and keeps security invariants 8–13 byte-equivalent at argv (`build_args`/`build_opts` unchanged; no shell); `Ffmpeg`/`Ffprobe` call sites unchanged.
- [x] **EPIPE-03**: A legitimate ffmpeg cap-hit early-exit (`-t`/`-fs`/`-timelimit`) is reported via its real exit status and never surfaces `:epipe`.
- [x] **EPIPE-04**: A deterministic `@tag :regression` repro reproduces the pre-fix `:epipe` (fails unpatched, passes patched); the two originally-flaking tests (`ffmpeg_test.exs:32`, `lifecycle_repair_test.exs:122`) pass **unmodified** after the fix.
- [x] **EPIPE-05**: The fix is forward-compatible with an upstream MuonTrap #98 resolution (degrades to a no-op; no leaked monitors/processes); a code comment cites #98.

### PR↔main gate-coverage gap (GATE)

Source: `v1.21-PR-MAIN-GATE-GAP.md`. CI-only; zero `lib/`.

- [ ] **GATE-01**: A lean, deterministic **`adoption-demo-e2e-smoke`** job runs on **every PR** — Chromium-only, MinIO-local, **no secrets**, pinned Playwright container, deterministic specs only (excludes the screenshot spec) — and is part of `CI Summary.needs` (and `ci-observability.needs`).
- [ ] **GATE-02**: PR p95 wall-clock stays ≤ ~7.5 min (the new lane runs as a parallel chain at/under the existing image-smoke long pole); this is observed/guarded, not assumed.
- [ ] **GATE-03**: `cohort-demo-smoke`, `package-consumer-full`, and `mux-soak` stay **off** the PR gate with documented rationale; `setup_branch_protection.sh` is byte-unchanged (`CI Summary` remains the sole required check; no second required context).
- [ ] **GATE-04**: The lean lane enters `CI Summary.needs` **only after** COV/EPIPE/ISO land and N consecutive green push:main `adoption-demo-e2e` runs are observed — the gate must not import a still-live flake (load-bearing ordering dependency).

### Async-isolation hardening (ISO) — `lib/`

Source: `v1.21-ASYNC-ISOLATION.md`. One private fn in `config.ex`; adopter-invisible; default branch byte-unchanged.

- [x] **ISO-01**: `Rindle.Config.repo/0` consults a `$callers`-aware process-dictionary override (covering spawned Tasks / inline Oban) **before** the application env; behavior is unchanged when no override is set.
- [x] **ISO-02**: Test-only `Config.put_repo_override/1` + `delete_repo_override/0` set/clear the per-process override (process-dictionary only; no global state).
- [x] **ISO-03**: `with_counting_repo/2` uses the process override and performs **no** `Application.put_env(:rindle, :repo, …)`; defensive `async: false` demotions caused by the old global swap are reverted (e.g. `StreamingDispatchTest` restored to `async: true`).
- [x] **ISO-04**: The v1.20 async-safety guard gains a `:global_repo_swap` rule that flags `Application.put_env/delete_env(:rindle, :repo, …)` in **any** test module, with a message pointing to `put_repo_override/1` (closes the structural guard gap).
- [x] **ISO-05**: A concurrency regression test proves isolation: the counting double in process A force-fails its transaction while an unrelated spawned process B reads `Config.repo() == Rindle.Repo` and its transaction succeeds; the test fails on the old impl and passes on the new.

### Regression locks (LOCK)

Source: `v1.21-REGRESSION-LOCKS.md`. Asserts **shipped artifacts only**, never `.planning/`. Rides existing required lanes.

- [x] **LOCK-01**: A merge-blocking meta-test asserts `scripts/install_smoke.sh` keeps the `phx.new` probe + self-install before the smoke proceeds (`quality`).
- [x] **LOCK-02**: A CI step purges the `phx.new` archive before the package-consumer smoke so the cold-cache path is exercised on every PR (`package-consumer`).
- [ ] **LOCK-03**: The keyboard-modality (`:focus-visible` Tab-first) helper is deduped into one shared exported function consumed by both `examples/adoption_demo/e2e/support/admin-polish.js` and `brandbook/src/admin-gallery-check.mjs`.
- [ ] **LOCK-04**: A merge-blocking meta-test asserts the Tab-first modality is present at every `focus({focusVisible:true})` site (post-dedupe, asserts the shared helper) (`quality`).
- [x] **LOCK-05**: A merge-blocking meta-test globbing `test/**/*.exs` fails if any test reads a `.planning/` path (keeps the decoupled hygiene from regressing) (`quality`).

### Truth fix (TRUTH)

- [x] **TRUTH-01**: PROJECT.md security-invariant 13's "Rambo on macOS/Windows dev" clause is corrected to reflect the actual MuonTrap-only subprocess path (no Rambo in `mix.lock`).

## Future Requirements

Deferred; tracked but not in this milestone's roadmap.

- **PART-01**: ExUnit `--partitions` test parallelization (carried from v1.20 DEFER-02; evidence-gated on measured core-starvation).

## Out of Scope

| Feature | Reason |
|---------|--------|
| GitHub merge queue / `merge_group` trigger | Considered (Area 3); for a solo-maintainer 0.x lib the lean-PR-lane + `CI Summary` aggregate is simpler and sufficient. Revisit if contributor volume grows. |
| Vendoring / forking MuonTrap | We absorb #98 locally and stay forward-compatible; carrying a fork is higher maintenance than the ~25-line guard. |
| Pixel-baseline `toHaveScreenshot()` as a merge-blocker | Confirmed non-blocking audit/reference signal (v1.19 decision); the smoke lane excludes the screenshot spec. |
| Coveralls.io service upload | Only the local `cover/excoveralls.json` artifact is in scope; no external coverage-service wiring. |
| `--partitions` parallelization | Deferred to Future (PART-01); payoff is evidence-gated, not assumed. |

## Traceability

Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| COV-01 | Phase 108 — Coverage single-run | Complete |
| COV-02 | Phase 108 — Coverage single-run | Complete |
| COV-03 | Phase 108 — Coverage single-run | Complete |
| COV-04 | Phase 108 — Coverage single-run | Complete |
| EPIPE-01 | Phase 109 — Subprocess `:epipe` hardening | Complete |
| EPIPE-02 | Phase 109 — Subprocess `:epipe` hardening | Complete |
| EPIPE-03 | Phase 109 — Subprocess `:epipe` hardening | Complete |
| EPIPE-04 | Phase 109 — Subprocess `:epipe` hardening | Complete |
| EPIPE-05 | Phase 109 — Subprocess `:epipe` hardening | Complete |
| TRUTH-01 | Phase 109 — Subprocess `:epipe` hardening | Complete |
| ISO-01 | Phase 110 — Async-isolation hardening | Complete |
| ISO-02 | Phase 110 — Async-isolation hardening | Complete |
| ISO-03 | Phase 110 — Async-isolation hardening | Complete |
| ISO-04 | Phase 110 — Async-isolation hardening | Complete |
| ISO-05 | Phase 110 — Async-isolation hardening | Complete |
| LOCK-01 | Phase 111 — Regression locks | Complete |
| LOCK-02 | Phase 111 — Regression locks | Complete |
| LOCK-03 | Phase 111 — Regression locks | Pending |
| LOCK-04 | Phase 111 — Regression locks | Pending |
| LOCK-05 | Phase 111 — Regression locks | Complete |
| GATE-01 | Phase 112 — PR↔main gate shift-left | Pending |
| GATE-02 | Phase 112 — PR↔main gate shift-left | Pending |
| GATE-03 | Phase 112 — PR↔main gate shift-left | Pending |
| GATE-04 | Phase 112 — PR↔main gate shift-left | Pending |

**Coverage:**

- v1 requirements: 24 total (COV 4, EPIPE 5, GATE 4, ISO 5, LOCK 5, TRUTH 1)
- Mapped to phases: 24 ✓ (COV→108, EPIPE+TRUTH→109, ISO→110, LOCK→111, GATE→112)
- Unmapped: 0 ✓ (every v1.21 requirement maps to exactly one phase)

---
*Requirements defined: 2026-06-26*
*Last updated: 2026-06-26 — roadmap created (Phases 108–112); traceability filled, 24/24 requirements mapped (de-flake 108–110 → lock 111 → shift-left 112 LAST).*
