# Phase 109: Subprocess `:epipe` hardening - Pattern Map

**Mapped:** 2026-06-28
**Files analyzed:** 7 (4 modified, 3 created)
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/rindle/av/subprocess.ex` (MOD: add `run_isolated/5` shim + NOTE block) | utility (subprocess wrapper) | request-response (synchronous spawn→reply) | self (`run/3` in same file) + `Rindle.Domain.AssetFSM` (NOTE+`require Logger`) | exact (self) |
| `test/test_helper.exs` (MOD: add `:canary` to excludes) | config (test harness) | n/a | self (existing exclude branches) | exact (self) |
| `.planning/PROJECT.md` (MOD: TRUTH-01 invariant-13 + Key-Decisions) | docs | n/a | self (text-string targets at :458 and :503) | exact (self) |
| `.github/workflows/nightly.yml` (MOD: advisory `--include canary` step) | config (CI) | n/a | self (`compat-matrix` job, :39-116) | exact (self) |
| `test/rindle/av/subprocess_epipe_test.exs` (NEW) | test (regression) | event-driven (trap_exit mailbox) + request-response (real subprocess) | `test/rindle/av/subprocess_test.exs` + `broker_test.exs`/`av_runtime_guard_test.exs` (trap_exit/refute_received) | role-match |
| `test/rindle/av/subprocess_epipe_canary_test.exs` (NEW) | test (advisory canary / behavioral tripwire) | event-driven | `test/rindle/api_surface_boundary_test.exs` (tripwire) + `lib/rindle.ex:147` / `probe.ex:22` (version introspection) | role-match |
| TRUTH-01 doc-assertion test → extend `test/install_smoke/docs_parity_test.exs` (NEW assertion, existing file) | test (docs-parity) | file-I/O (read+assert) | `test/install_smoke/docs_parity_test.exs` | exact |

---

## Pattern Assignments

### `lib/rindle/av/subprocess.ex` — `run_isolated/5` shim (utility, request-response)

**Analog:** self — `run/3` at `lib/rindle/av/subprocess.ex:11-16` (house style for the wrapper).

**Current `run/3` shape to mirror** (`lib/rindle/av/subprocess.ex:11-16`):
```elixir
def run(cmd, args, opts \\ []) do
  opts = Keyword.put_new(opts, :use_cgroups, default_use_cgroups?())
  muon_opts = build_opts(opts)
  modified_args = build_args(cmd, args, opts)
  MuonTrap.cmd(cmd, modified_args, muon_opts)
end
```
The only change: replace the final `MuonTrap.cmd(...)` call with `run_isolated(cmd, modified_args, muon_opts, 1, &MuonTrap.cmd/3)`. Lines 12-14 stay byte-identical (preserves invariants 8-13 by construction; `build_args/3` + `build_opts/2` untouched). Exact shim body is given verbatim in RESEARCH §1 (lines 123-156) — copy it.

**`@doc false def` over `defp` convention** (already in this file at `lib/rindle/av/subprocess.ex:28-29` and `:52`):
```elixir
@doc false
def build_opts(opts) do
```
Mirror this for `run_isolated/5` so the synthetic test calls it directly (no `apply/3`). This is the house pattern the planner should copy — RESEARCH §1 line 197 + Pitfall 2 mandate it.

**`# NOTE (<REQ-ID>, <citation>):` comment convention** (analog: `lib/rindle/domain/asset_fsm.ex:9-10`):
```elixir
# NOTE: "analyzing" => "quarantined" added per AV-02-09 (probe-failure path).
# CONTEXT.md D-09 omitted this edge; researcher-flagged in RESEARCH.md A4 + Pitfall 5.
```
Apply D-13's `# NOTE (EPIPE-07, MuonTrap #98):` block above `run_isolated` — exact text drafted in RESEARCH §1 lines 109-122 (URL + OPEN status + affected versions 1.7.0/1.8.0/2.0.0-rc.0 + removal condition + canary coupling).

**`require Logger` placement** (analog: `lib/rindle/domain/asset_fsm.ex:4`):
```elixir
defmodule Rindle.Domain.AssetFSM do
  @moduledoc false

  require Logger
```
`subprocess.ex` has NO `require Logger` today (verified) — add it under the `@moduledoc` block (after line 4). Needed for the single D-07 `Logger.debug` in the retry branch. Exact string: RESEARCH §5 lines 382-385.

---

### `test/rindle/av/subprocess_epipe_test.exs` (test, regression)

**Analog (file structure / aliasing):** `test/rindle/av/subprocess_test.exs:1-4`:
```elixir
defmodule Rindle.AV.SubprocessTest do
  use ExUnit.Case, async: true

  alias Rindle.AV.Subprocess
```
NOTE deviation: the new file must be `async: false` (spawns OS processes) — see `ffmpeg_test.exs:2` precedent cited in RESEARCH §2. Module name → `Rindle.AV.SubprocessEpipeTest`.

**`trap_exit` + `refute_received` precedent** (analog: `test/rindle/upload/broker_test.exs:769`):
```elixir
refute_received {[:rindle, :upload, :stop], ^ref, _measurements, _metadata}
```
Other live precedents using `Process.flag(:trap_exit, true)` / `refute_received` / `spawn_monitor`: `test/rindle/processor/av_runtime_guard_test.exs`, `test/rindle/delivery_test.exs`, `test/rindle/workers/process_variant_test.exs`. The two `@tag :regression` `@tag :av` tests (deterministic synthetic + real stress) are spelled out verbatim in RESEARCH §1 lines 168-189 and §2 lines 229-247 — copy those. Both end in `refute_received {:EXIT, _, :epipe}` (D-08).

**Tag placement** (analog: file-level `@moduletag` vs per-test `@tag`): see canary analog below for `@moduletag`; for this file RESEARCH uses per-test `@tag :regression` + `@tag :av` (lines 170-171, 230-231).

---

### `test/rindle/av/subprocess_epipe_canary_test.exs` (test, behavioral tripwire / advisory)

**Analog (tripwire structure + `@moduletag`):** `test/rindle/api_surface_boundary_test.exs:1-4` — the repo's established behavioral-tripwire precedent (module-level constants drive a single asserting test). The canary uses `@moduletag :canary` + `@moduletag :av` (RESEARCH §3 lines 272-273) — the module-level tag form, matching how api_surface_boundary scopes its concern.

**Version introspection in the failure message** (analogs):
- `lib/rindle.ex:145-148`:
```elixir
@spec version :: String.t()
def version do
  Application.spec(:rindle, :vsn) |> to_string()
end
```
- `lib/rindle/av/probe.ex:20-24` (`Version.compare` runtime version gate):
```elixir
case Regex.run(~r/ffmpeg version n?(\d+\.\d+)/, output) do
  [_, version] ->
    if Version.compare(version <> ".0", "6.0.0") == :lt do
```
The canary uses `Application.spec(:muontrap, :vsn)` in its loud-failure message (D-11) — same `Application.spec(:app, :vsn)` idiom as `lib/rindle.ex:147`. Full canary file is in RESEARCH §3 lines 268-316 — copy verbatim (probes UNGUARDED `MuonTrap.cmd/3`, 500 iters, advisory).

---

### `test/install_smoke/docs_parity_test.exs` (test, docs-parity — TRUTH-01 guard) — SUPERSEDED

> **SUPERSEDED by planning decision:** TRUTH-01 is enforced via a **CI grep step in the merge-blocking
> `quality` lane** (see 109-02-PLAN.md), NOT an ExUnit doc-assertion test. An ExUnit test reading
> `.planning/PROJECT.md` would collide with **Phase 111 LOCK-05** (a meta-test banning tests that read
> `.planning/` paths). The pattern below is retained only as reference for the affirm-new/deny-stale
> string shape the grep guard mirrors — do NOT add this as an ExUnit test.

**Analog (reference only):** self — the existing docs-parity file's read+assert/refute shape.

**File-read + assert/refute-string pattern to copy** (`test/install_smoke/docs_parity_test.exs:7,32-43,286-295`):
```elixir
@operations_path Path.expand("../../guides/operations.md", __DIR__)
# ...
test "operations guide lists all nine shipped mix tasks" do
  operations = File.read!(@operations_path)
  assert operations =~ "nine Mix tasks"
  refute operations =~ "six Mix tasks"
  # ...
end
```
**TRUTH-01 assertion to add** (target file `.planning/PROJECT.md`, match on text strings per D-17): read PROJECT.md, then assert the corrected prose is present and the stale strings are absent:
- `refute project_md =~ "Rambo"` scoped to invariant 13 region, OR `refute invariant_13_block =~ ~r/Rambo/`
- `refute project_md =~ "FFmpex + MuonTrap"` (the Key-Decisions row, PROJECT.md:503)
- `assert project_md =~ "MuonTrap is the sole subprocess runner on every platform"` (new D-15 text)

Note the existing TRUTH-style precedent in the SAME file (`docs_parity_test.exs:336-358` uses `assert ... =~` for affirmed prose + `refute ... =~` for the reversed/stale claim) — mirror that affirm-new / deny-stale structure exactly.

---

### `test/test_helper.exs` (config — add `:canary` to excludes)

**Analog:** self — `test/test_helper.exs:24-29` (the live exclude block):
```elixir
exclude_tags =
  if targeted_adopter_or_integration? do
    [:minio, :contract]
  else
    [:integration, :minio, :contract, :adopter]
  end
```
> CORRECTION to upstream docs: CONTEXT.md/RESEARCH state the default list is `[:integration, :minio, :contract, :adopter]` (correct, line 28) but the targeted branch is `[:minio, :contract]` (line 26), NOT `[:minio, :contract, :canary]` as RESEARCH §4's snippet implies a pre-existing `:adopter`. Add `:canary` to **both** branches (D-12 / RESEARCH §4 step 1 — the LOAD-BEARING safety):
> - targeted branch → `[:minio, :contract, :canary]`
> - default branch → `[:integration, :minio, :contract, :adopter, :canary]`

---

### `.planning/PROJECT.md` (docs — TRUTH-01 D-15/16/17)

**Analog:** self — two text-string-targeted edits (D-17: match strings, not line numbers).

**Target 1 — invariant 13** (`PROJECT.md:456-459`, current stale clause verified):
```
    No transcode is allowed without an enforceable parent-death subprocess
    kill (MuonTrap on Linux; Rambo on macOS / Windows dev).
```
Replace the kill clause with D-15's verbatim text (CONTEXT.md lines 144-154); preserve the `Rindle.tmp/` + Ops-reaper sentence verbatim.

**Target 2 — Key-Decisions row** (`PROJECT.md:503`, current verified):
```
| Video / audio ships via system FFmpeg subprocess (FFmpex + MuonTrap), not Membrane / NIFs / bundled provider | ...
```
`(FFmpex + MuonTrap)` → `(MuonTrap runner; argv built in-house, not FFmpex)` (D-16). Match literal `(FFmpex + MuonTrap)`.

> Do NOT touch `PROJECT.md:58-59` (milestone description — already accurate) or any archived artifact (D-17).

---

### `.github/workflows/nightly.yml` (config — advisory canary step)

**Analog:** self — `nightly.yml:39` (`compat-matrix:` job), step at `:115-116`:
```yaml
      - name: Run tests with coverage
        run: mix coveralls
```
Add a NEW advisory step in `compat-matrix` (after the coveralls step) using `continue-on-error: true` (RESEARCH §4 step 2 lines 357-359):
```yaml
      - name: Subprocess :epipe cleanup canary (advisory)
        continue-on-error: true
        run: mix test test/rindle/av/subprocess_epipe_canary_test.exs --include canary
```
House precedent for `continue-on-error` semantics in this file: `nightly.yml:118-123` documents the advisory-vs-gating convention (gating jobs drop `continue-on-error`; advisory keep it). The canary is advisory → keep `continue-on-error: true`.

---

## Shared Patterns

### `# NOTE (<REQ-ID>, <citation>):` comment convention
**Source:** `lib/rindle/domain/asset_fsm.ex:9-10`
**Apply to:** `lib/rindle/av/subprocess.ex` (D-13 NOTE block) and both new test files (canary's removal-signal moduledoc, RESEARCH §3 lines 278-281).
```elixir
# NOTE: "analyzing" => "quarantined" added per AV-02-09 (probe-failure path).
# CONTEXT.md D-09 omitted this edge; researcher-flagged in RESEARCH.md A4 + Pitfall 5.
```

### `@doc false def` for testable-but-private functions
**Source:** `lib/rindle/av/subprocess.ex:28-29` and `:52` (`build_opts`, `build_args`)
**Apply to:** `run_isolated/5` — use `@doc false def`, not `defp`, so the synthetic test calls it without `apply/3` (RESEARCH Pitfall 2).
```elixir
@doc false
def build_opts(opts) do
```

### Runtime version introspection
**Source:** `lib/rindle.ex:147` (`Application.spec(:rindle, :vsn)`), `lib/rindle/av/probe.ex:22` (`Version.compare`)
**Apply to:** canary failure message — `Application.spec(:muontrap, :vsn)` (D-11).
```elixir
Application.spec(:rindle, :vsn) |> to_string()
```

### `trap_exit` + `refute_received` test idiom
**Source:** `test/rindle/upload/broker_test.exs:769`; also `av_runtime_guard_test.exs`, `process_variant_test.exs`, `delivery_test.exs`
**Apply to:** both `subprocess_epipe_test.exs` assertions — `Process.flag(:trap_exit, true)` in the test body, `refute_received {:EXIT, _, :epipe}` to prove non-propagation (D-08).

### Docs-parity affirm-new / deny-stale assertion
**Source:** `test/install_smoke/docs_parity_test.exs:32-43` (read via `File.read!` + `@path` module attr), `:286-295` (`assert =~` / `refute =~`), `:336-358` (TRUTH-07 affirm-new + deny-stale precedent)
**Apply to:** the TRUTH-01 guard assertion (assert new D-15 prose, refute `"Rambo"` / `"FFmpex + MuonTrap"`).

---

## No Analog Found

None. Every file has an exact-self or close role-match analog in the codebase.

---

## Metadata

**Analog search scope:** `lib/rindle/av/`, `lib/rindle/domain/`, `lib/rindle.ex`, `test/rindle/`, `test/install_smoke/`, `.github/workflows/`, `.planning/PROJECT.md`
**Files scanned:** subprocess.ex, asset_fsm.ex, rindle.ex, probe.ex, subprocess_test.exs, docs_parity_test.exs, api_surface_boundary_test.exs, av_runtime_guard_test.exs, broker_test.exs, test_helper.exs, nightly.yml, PROJECT.md (+ greps across test/ and lib/)
**Pattern extraction date:** 2026-06-28
