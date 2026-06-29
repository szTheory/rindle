---
phase: 110-async-isolation-hardening
plan: 01
subsystem: config-resolver
tags: [async-isolation, repo-override, callers-walk, test-seam, hex-0.3.2]
status: complete
requires: []
provides:
  - "Rindle.Config.repo/0 $callers-aware per-process override resolver"
  - "Rindle.Config.put_repo_override/1 (test-only setter)"
  - "Rindle.Config.delete_repo_override/0 (test-only clearer)"
  - "@repo_override_key {Rindle.Config, :repo_override}"
affects:
  - "110-02 (counting-double migration consumes put_repo_override/1)"
  - "110-03 (:global_repo_swap guard rule points at the sanctioned setter)"
  - "110-04 (concurrency/isolation proof test exercises the resolver + $callers walk)"
tech-stack:
  added: []
  patterns:
    - "process-dictionary override + :\"$callers\" walk (Mox/Ecto.Sandbox idiom)"
    - "with nil <- ... do app-env fallback (byte-unchanged production default branch)"
key-files:
  created: []
  modified:
    - lib/rindle/config.ex
decisions:
  - "D-01: repo/0 consults repo_override(self()) before Application.get_env; default branch byte-unchanged; $callers walk runs only when an override is present"
  - "D-02: put/delete_repo_override are @doc false test-only seams, process-dict writes only, no Application.put_env/delete_env"
  - "Release coupling D-13/D-v1.21-01: landed as fix: conventional commits so release-please cuts a patch bump to Hex 0.3.2 on green main"
metrics:
  duration: 1 min
  completed: 2026-06-28
  tasks: 2
  files: 1
status: complete
---

# Phase 110 Plan 01: $callers-aware per-process repo override Summary

`Rindle.Config.repo/0` now resolves a process-dictionary repo override (walking the
`:"$callers"` chain so `Task`-spawned / inline-Oban children inherit it) before falling
through to the unchanged `Application.get_env(:rindle, :repo, Rindle.Repo)` app-env default,
plus two `@doc false` test-only setters (`put_repo_override/1` / `delete_repo_override/0`)
that write that override with no global state — the research-locked Option (i) foundation
(ISO-01 + ISO-02) for the counting-double migration, guard rule, and isolation proof.

## What Was Built

- **`@repo_override_key {Rindle.Config, :repo_override}`** module attribute — the single
  Rindle-namespaced key shared by the resolver and the setters.
- **`repo/0` rewrite** — `with nil <- repo_override(self()) do Application.get_env(:rindle,
  :repo, Rindle.Repo) end`. The production default branch is byte-unchanged: with no override
  set, the path is one `Process.get` returning `nil` followed by the original app-env read.
  `@spec repo() :: module()` unchanged.
- **Private `$callers`-walk helpers (research §3 verbatim):**
  - `repo_override/1` — consults this pid's dict key, else `caller_repo_override/1`.
  - `caller_repo_override/1` — reads `:"$callers"`, `List.wrap`, `Enum.find_value` over
    callers `!= pid` (the cycle guard), recursing through `repo_override/1`.
  - `process_get/2` — `Process.get(key)` when `pid == self()`, else `Process.info(pid,
    :dictionary)` + `Keyword.get`, returning `nil` on any non-`{:dictionary, _}` result
    (dead/unknown pid tolerant).
- **Test-only setters** — `put_repo_override(mod)` → `Process.put(@repo_override_key, mod)`;
  `delete_repo_override()` → `Process.delete(@repo_override_key)`. Both `@doc false`, both
  process-dict only, no `Application.put_env`/`delete_env`. Specs:
  `put_repo_override(module()) :: module() | nil`, `delete_repo_override() :: module() | nil`.

## Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | repo/0 consults $callers-aware process-dict override before app env | 9948a22 | lib/rindle/config.ex |
| 2 | Expose test-only put_repo_override/1 + delete_repo_override/0 | 830a9a4 | lib/rindle/config.ex |

## Verification

- `grep 'Application.get_env(:rindle, :repo, Rindle.Repo)'` → present (default branch byte-unchanged, D-01).
- `grep -cE 'defp repo_override|defp caller_repo_override|defp process_get'` → 4 clauses present.
- `grep -cE 'def put_repo_override|def delete_repo_override'` → 2.
- `! grep -nE 'Application\.(put_env|delete_env)\(:rindle, :repo'` → no global mutation introduced.
- `mix compile --warnings-as-errors` → clean.
- `mix test test/rindle/config/config_test.exs` → 4 tests, 0 failures (app-env resolution path
  preserved; config_test sets no override so the resolver falls through to app env, D-10).

## Deviations from Plan

None — plan executed exactly as written. The locked research §3 sketch was followed verbatim
for the resolver and helpers; the setters match the D-02 sketch.

### TDD note

Plan tasks were marked `tdd="true"` but the phase config has `tdd_mode: false` and the plan's
own `done` criteria specify no standalone test file is created in this plan (the grep + compile
gate plus the unchanged `config_test.exs` is the gate; Plan 04 supplies the concurrency proof
test). No RED test commit was created — consistent with the plan's stated gate, not a gap.

## Release Coupling

Per D-13 / D-v1.21-01 this is the phase's only `lib/` touch. Both commits use the `fix:`
conventional type so release-please bundles them into a single **patch** bump to Hex **0.3.2**
on green main. No `feat:` (would mis-bump to a minor) or `chore:`/`docs:` (would skip publish)
was used.

## Self-Check: PASSED

- FOUND: lib/rindle/config.ex (modified, compiles clean)
- FOUND commit 9948a22 (Task 1)
- FOUND commit 830a9a4 (Task 2)
