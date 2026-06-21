# Phase 104: Cache & Tooling Hygiene - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `104-CONTEXT.md` — this log preserves the analysis.

**Date:** 2026-06-21
**Phase:** 104-cache-tooling-hygiene
**Mode:** assumptions + maintainer-requested ecosystem research
**Areas analyzed:** CACHE-01 (composite actions), CACHE-02/03 (cache keys + PLT split),
CACHE-04 (lockfile gates), CACHE-05 (lint de-dup + `.tool-versions` + ffmpeg)

## Assumptions Presented (gsd-assumptions-analyzer, repo-grounded)

### CACHE-01 — Composite action + shared MinIO
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `setup-elixir` composite (setup-beam + deps/`_build` cache, inputs for matrix/MIX_ENV/prefix); 2nd `setup-minio` composite; adopt across 9 setup-triplet jobs + 5 MinIO-trio jobs | Confident (map) / Likely (input surface) | `ls .github/actions` → none (greenfield); setup block byte-identical across 9 jobs; MinIO trio identical across 5 |

### CACHE-02/03 — Cache keys + PLT split
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New key template w/ OS+arch, OTP, Elixir, MIX_ENV, lock hash, buster; deps/`_build`/PLT separate; PLT key hashes `mix.exs`+`.dialyzer_ignore.exs`; convert PLT to restore/save split w/ save-on-failure | Confident (current keys, PLT problem) / Likely (save `if:` predicate) | deps key `ci.yml:70`, build `:78`, PLT `:170` (hashes `**/mix.lock`); dialyzer config `mix.exs:38-42`; PLT single `actions/cache@v4`, `mix dialyzer` continue-on-error |

### CACHE-04 — Lockfile-drift gates
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `--check-locked` + `--check-unused` in `quality`, primary pair; `--check-unused` risks false-positive on OTP<27-only `json_polyfill` | Likely | `mix deps.get` w/o `--check-locked` `ci.yml:85`; `json_polyfill_dep/0` OTP<27 `mix.exs:141-147`; `grep -c json_polyfill mix.lock` = 0 |

### CACHE-05 — Lint de-dup + `.tool-versions` + ffmpeg
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Lint runs 2× in matrix `quality`; gate to primary pair; land `.tool-versions`; swap `release.yml` ffmpeg action for `install_ffmpeg.sh` | Confident | lint steps `ci.yml:97-110`; no `.tool-versions` (`ls` error); `FedericoCarboni/setup-ffmpeg@v3` `release.yml:457`; `scripts/ci/install_ffmpeg.sh` used 4× in ci.yml |

## Ecosystem Research (4 parallel gsd-advisor-researcher agents — maintainer-requested)

Maintainer requested a deep per-area research pass: pros/cons/tradeoffs, idiomatic Elixir/Phoenix
CI, lessons from successful libs, DX/least-surprise, footguns → one coherent recommendation set.

### CACHE-01 — Composite vs reusable workflow vs status quo
- **Finding:** `erlef/setup-beam` has **no** built-in deps/`_build` caching (only its own tool
  install) — `actions/cache` stays mandatory. Phoenix/Ecto/Oban/Ash/Broadway **inline** setup at
  2–4 jobs (correct at their scale); Rindle's 9-way + 5-way duplication is exactly where a composite
  pays off. The `felt/ultimate-elixir-ci` `elixir-setup` action is the canonical input schema.
- **Decision impact:** confirmed composite action (not reusable workflow — that would rename
  required checks); MinIO as a 2nd composite (the `docker run` trio is manual `run:` steps, movable);
  composite does NOT compile (job-specific flags stay out). → D-01..D-04.

### CACHE-02/03 — Key schema + PLT split
- **Finding:** dialyxir's own GH-Actions doc uses the restore/save split with `cache-hit != 'true'`
  guard; caches are immutable (re-saving an identical key warns + wastes). felt proves the
  deps-vs-`_build` key differentiation. Use resolved `steps.beam.outputs.*` (patch-level) not coarse
  `matrix.otp`. PLT hashing `mix.exs`+`.dialyzer_ignore.exs` (not `mix.lock`) avoids over-invalidation.
- **Tension w/ requirement → resolved toward the requirement:** research recommended omitting
  OTP/Elixir from the **deps** key (source tarballs are OTP-agnostic) and dropping `runner.arch` on a
  single-arch runner. **Declined** — CACHE-02's literal schema says keys include OS+arch+OTP+Elixir;
  at 2 matrix cells the sharing saving is negligible and a uniform key shape is easier to audit. Kept
  uniform full-dimension keys. → D-05 (+ recorded as a deliberate decline in Deferred).
- **Decision impact:** save-PLT-BEFORE-analysis is the crux; `if: cache-hit != 'true'` (not
  `always()`). → D-07, D-08, D-09.

### CACHE-04 — Lockfile gates + the conditional-dep footgun
- **Finding (empirically reproduced):** `--check-locked` cleanly fails on stale lock (exit 1),
  validates lock-vs-`mix.exs` even on a cache hit, costs nothing → run on **both** cells.
  `--check-unused` evaluates `mix.exs` against the **running** OTP: with the lock resolved under
  OTP 27, running `--check-unused` on an OTP≠27 cell would flag the conditional `json_polyfill` as
  unused (false-positive, exit 1, broken build). Pinning `--check-unused` to `matrix.otp == '27'`
  (the lock's resolution OTP) makes the false positive structurally impossible. Fly.io + Hashrocket
  guides place these as dedicated steps, not per-matrix-cell. Cross-ecosystem: `cargo --locked`,
  `bundle --frozen`, `npm ci` gate "lock satisfiable without mutation" everywhere; prune-unused is a
  separate narrower concern.
- **Refinement over analyzer:** analyzer said both checks on primary-only; research showed
  `--check-locked` is better run on **both** cells (closes OTP26 staleness gap). → D-10, D-11.

### CACHE-05 — Lint de-dup + `.tool-versions` + ffmpeg
- **Finding:** Phoenix/Ecto/Oban all use `lint: true` matrix include + `if: ${{ matrix.lint }}` on
  the **newest** cell — preserves required-check names (a separate `lint` job would mint a new name).
  Format belongs on newest (enforces what an up-to-date contributor produces locally). `.tool-versions`
  (asdf format `elixir x-otp-N`) over `.mise.toml` (superset; mise reads `.tool-versions`, asdf can't
  read `.mise.toml`); track the primary pair; keep local-dev-only (avoid `setup-beam` `version-file`
  strict-mode CI churn). ffmpeg swap safe — `public_verify` already runs repo scripts.
- **Refinement over analyzer:** use the idiomatic `matrix.lint` flag rather than a raw
  `matrix.elixir == '1.17'` compare. → D-12, D-13, D-14.

## Corrections Made

No maintainer corrections to the assumptions themselves. The maintainer instead requested a deep
ecosystem-research pass across all four areas; its decisive findings refined three assumptions
(CACHE-02 deps-key schema kept uniform per requirement; CACHE-04 `--check-locked` moved to both
cells; CACHE-05 adopted the `matrix.lint` idiom) and are folded into `104-CONTEXT.md`.

## Sources

- `erlef/setup-beam` README (no built-in deps cache; resolved-version outputs; version-file strict).
- `felt/ultimate-elixir-ci` `elixir-setup/action.yml` + Felt "Ultimate Elixir CI" blog (composite
  schema; deps-vs-`_build` split).
- `phoenixframework/phoenix`, `elixir-ecto/ecto`, `sorentwo/oban` CI workflows (`matrix.lint` idiom).
- `jeremyjh/dialyxir` GitHub Actions doc (PLT restore/save split; `cache-hit != 'true'` guard).
- `mix deps.get`/`mix deps.unlock` HexDocs + `elixir-lang/elixir` `deps.unlock.ex` source;
  Elixir Forum "Unused dependencies in mix.lock after cache restore".
- Fly.io "GitHub Actions for Elixir CI"; actions/cache docs (immutability, 10 GB / 7-day eviction).
