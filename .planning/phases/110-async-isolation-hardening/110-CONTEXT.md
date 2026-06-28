# Phase 110: Async-isolation hardening - Context

**Gathered:** 2026-06-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Make `Rindle.Config.repo/0` consult a `$callers`-aware **process-dictionary override**
*before* the application env, so the `CountingFailingTxnRepo` double becomes **process-scoped**
(like Ecto.Sandbox / Mox) and can **never** pollute a concurrently-running async reader — and add
a `:global_repo_swap` rule to the v1.20 async-safety guard that makes the global-`put_env(:rindle,
:repo, …)` footgun **un-reintroducible**.

**Approach is research-locked to Option (i) + (iv)** (`.planning/research/v1.21-ASYNC-ISOLATION.md`,
HIGH confidence). This phase clarifies the *blast-radius / scope* questions the research and
requirements left open; it does NOT revisit *whether* to use a `$callers` override (locked) or
*whether* to touch `lib/` (pre-authorized via D-v1.21-01).

**In scope:** the `Config.repo/0` `$callers`-aware resolver + `put_repo_override/1` /
`delete_repo_override/0` test setters; migrating `with_counting_repo/2` off both global keys;
the `:global_repo_swap` guard rule (scanning ALL modules); reverting 3 `async: false` demotions to
`async: true`; allowlisting the 8 pre-existing legitimate repo-swappers; the ISO-05 concurrency
proof test. Ships `fix:` → Hex **0.3.2**.

**Out of scope:** migrating the *other* lib-redirecting repo doubles (`TestRepoProbe`,
`FailingTransactionRepo`) to the process override (same anti-pattern, but async:false & not the
flake source → a future phase); changing any public API / return shape / error vocab; the
regression-lock meta-tests (Phase 111); the gate shift-left (Phase 112).

</domain>

<decisions>
## Implementation Decisions

The single research-locked approach (Option i + iv) settled the *how*. The discussion settled the
three open *scope / blast-radius* questions below; all align with the research's intent and the
milestone's de-flake → lock → shift-left order. "UX" here is **library DX**: the adopter's repo
config is byte-unchanged, and a contributor literally cannot reintroduce the flake (red guard +
sanctioned `put_repo_override/1` alternative).

### Resolver & test setters (research-locked, ISO-01 / ISO-02)
- **D-01:** `Rindle.Config.repo/0` resolves a per-process override
  (`Process.get({Rindle.Config, :repo_override})`) **before** falling back to
  `Application.get_env(:rindle, :repo, Rindle.Repo)`. The resolver walks the `:"$callers"` chain
  (via `Process.info(pid, :dictionary)`) so `Task`-spawned and inline-Oban work inherit the
  override. **Production default branch is byte-for-byte unchanged when no override is set** — the
  common production path is a single `Process.get` returning `nil` (the `$callers` walk only runs
  when an override is present, i.e. never in production). Follow the research §3 sketch verbatim
  (`repo_override/1`, `caller_repo_override/1`, `process_get/2`).
- **D-02:** Expose **test-only** `Rindle.Config.put_repo_override/1` + `delete_repo_override/0`
  (process-dictionary writes only; no global state). These are the sanctioned alternative the
  guard message points at.

### Counting double migration (ISO-03)
- **D-03:** `Rindle.Test.CountingFailingTxnRepo.with_counting_repo/2` sets the repo via
  `Config.put_repo_override/1` in the calling process and clears it in `after`; it performs **no**
  `Application.put_env(:rindle, :repo, …)`. The save/restore dance for `:repo` is deleted (a
  process-dict override needs no global save/restore — the `after` just clears it).
- **D-04:** The **second global key** `:rindle, :counting_failing_txn_repo` (the `fail_after` /
  `fail_reason` config) **also moves to the process dictionary** alongside the override
  (research ISO-03). `fail_after/0` and `fail_reason/0` read the process dict, not Application env.
  This makes the double fully process-scoped (no global mutation remains in the double).

### async:true re-promotion (ISO-03 scope decision — DECIDED: dispatch + both mutators)
- **D-05:** Revert **three** modules from the defensive `async: false` demotion back to
  `async: true`:
  - `Rindle.Delivery.StreamingDispatchTest` — the **victim** (the locked ISO-03 case; reads
    `Config.repo()` on Branch 5/5b). Update its header comment: the global-pollution workaround is
    now root-caused, not deferred.
  - `Rindle.OwnerErasureBatchProofTest` — counting-double **mutator**.
  - `Rindle.BatchOwnerErasureTaskTest` — counting-double **mutator**.
  Scout confirmed all three are `async: false` **only** for the repo-swap reason — no other unsafe
  primitive — so once the double is process-scoped they are provably clean to promote. This
  recovers the full serialization tax the workaround imposed (research §6).
- **D-06:** Do **NOT** promote the `async: false` modules that use the *other* lib-redirecting
  doubles (`TestRepoProbe`, `FailingTransactionRepo`: `maintenance_workers_test`,
  `upload_maintenance_test`, `broker_test`) — they have the same global-swap anti-pattern but are
  out of this phase's scope (see Deferred). Leave their `async: false` untouched.

### Guard rule blast radius (ISO-04 — DECIDED: allowlist the 8 legitimate swappers)
- **D-07:** Add a `:global_repo_swap` rule to `test/async_safety_guard_test.exs` that flags
  `Application.put_env`/`delete_env(:rindle, :repo, …)` in **any** test module **regardless of its
  async flag**, with a failure message pointing at `Config.put_repo_override/1`. Add
  `:global_repo_swap` to `@primitive_names`. Match the research §iv AST shape
  (`{:__aliases__, _, [:Application]}, m in [:put_env, :delete_env]` with first arg `:rindle`,
  second `:repo`).
- **D-08 (LOAD-BEARING structural change):** Today the guard **only parses `async: true` modules**
  (`parse_async_true_modules` → `Enum.filter(&async_true?/1)`, line ~114). The mutators/swappers
  are `async: false`, so the new rule **requires a separate all-modules scan path** (collect every
  `defmodule` body without the async filter) that applies **only** the `:global_repo_swap`
  classifier. The existing per-async-true-module rules stay exactly as they are. The
  `@async_safety_allow [...]` allow-list mechanism **must be honored on these now-scanned
  async:false modules** (currently `collect_allowlist` runs per body, so wire it into the new path).
- **D-09:** The **8 pre-existing legitimate swappers** keep `async: false` and each gets a
  justified `@async_safety_allow [:global_repo_swap]` attribute + a one-line `# why:` comment
  (they swap to an adopter/probe repo to test resolution, not the counting-double cross-pollution).
  Only the counting double is migrated this phase. The guard still goes **RED** on any *new*
  `put_env(:rindle, :repo, …)`, so the footgun is closed for future code. The 8:
  `config/config_test`, `storage/local_tus_test`, `workers/maintenance_workers_test`,
  `ops/upload_maintenance_test`, `upload/broker_test`, `upload/tus_plug_test`,
  `upload/tus_local_backing_test`, `upload/lifecycle_integration_test`,
  `adopter/canonical_app/lifecycle_test`. (Verify the exact set at plan time — grep
  `put_env(:rindle, :repo` / `delete_env(:rindle, :repo`.)
- **D-10 (semantic guard-rail — do NOT migrate config_test):** `config/config_test.exs` literally
  asserts `Rindle.Config.repo() == Rindle.Adopter.CanonicalApp.Repo` after
  `Application.put_env(:rindle, :repo, …)`, and asserts the `Rindle.Repo` fallback after
  `delete_env`. It is **testing the Application-env resolution path itself** — it MUST keep
  `put_env` and MUST NOT migrate to the override (an override would shadow the env and invert the
  test's intent). It is the canonical allowlist case, not a convenience exception. (It still passes
  unchanged under D-01 because it sets no override → resolver falls through to the env.)

### Guard scope — second key (ISO-04 — DECIDED: `:repo` only)
- **D-11:** The `:global_repo_swap` rule flags **only** `:rindle, :repo` (per ISO-04's literal
  scope). It does **not** flag `:rindle, :counting_failing_txn_repo`: that key is double-internal
  (read only by the double, never by `lib/`), so a global swap of it cannot pollute a `lib/`
  reader — it's lower-risk and out of the requirement. (D-04 still moves it to the process dict for
  cleanliness, but the guard need not police it.)

### Concurrency proof (ISO-05)
- **D-12:** Ship the ISO-05 proof test (research §8 sketch). In process A,
  `with_counting_repo(1, fn -> … end)` force-fails the 1st transaction and asserts
  `Config.repo() == CountingFailingTxnRepo`; a **separate spawned process B** (no override in its
  dict, **not** a `$callers` descendant of A) asserts `Config.repo() == Rindle.Repo` and that B's
  `transaction/1` succeeds concurrently inside A's window. The test must **fail against the old
  global-`put_env` impl and pass against the process-scoped one** — that delta is the proof. Make
  it `async: true` (it is the canonical async-safe demonstration). Place it in a dedicated test
  module (e.g. `test/rindle/config/repo_override_isolation_test.exs`); planner picks the exact path.

### Charter gate (research ISO-07) — already settled, not re-opened
- **D-13:** The `lib/rindle/config.ex` touch is **pre-authorized** by D-v1.21-01 (PROJECT.md:541):
  adopter-invisible, default branch byte-unchanged, no public-API / semver impact → ships `fix:` →
  Hex **0.3.2** via release-please. No escalation needed; the research's ISO-07 "charter gate" is
  satisfied by the existing authorization.

### Claude's Discretion
- Exact `$callers`-walk helper names / cycle-guard details (research §3 is the reference impl);
  the precise new-test file path/name; the exact `@async_safety_allow` `# why:` wording per module;
  the guard's all-modules-scan refactor shape (one combined walk vs. a second pass), as long as
  per-async-true rules are unchanged and the allowlist is honored on async:false modules.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Locked research & requirements (read first)
- `.planning/research/v1.21-ASYNC-ISOLATION.md` — the full root-cause + LOCKED Option (i)+(iv)
  recommendation (HIGH). §1 evidence + §1.4 the structural guard gap, §2 ExUnit async-pool
  semantics ruling (load-bearing: `async: false` does NOT run exclusively of the async pool),
  §3 the resolver + setter code sketch, §4–5 idiomatic/peer-lib (`$callers`, Mox, Sandbox),
  §8 requirement-ready bullets ISO-01..07 + the ISO-05 proof sketch.
- `.planning/REQUIREMENTS.md` — ISO-01..ISO-05 (lines 43–47).
- `.planning/ROADMAP.md` §"Phase 110" (lines 145–181) — goal, success criteria, invariants.

### Source being changed
- `lib/rindle/config.ex` — `repo/0` (lines 9–12, the resolver seam); new private `$callers` walk +
  `put_repo_override/1` / `delete_repo_override/0` (adopter-invisible; D-v1.21-01 authorizes).
- `test/support/counting_failing_txn_repo.ex` — `with_counting_repo/2` (lines 6–21, the global
  mutation site); `fail_after/0` (83–86) + `fail_reason/0` (88–91) + `restore_env/2` (93–94) move
  to the process dict; the `Rindle.Repo.__info__(:functions)` passthrough generator (66–73) stays.
- `test/async_safety_guard_test.exs` — the v1.20 guard; `@primitive_names` (44–53), `classify/2`
  Application clause (251–253), `parse_async_true_modules/1` (108–124, the `async_true?` filter
  that must be bypassed for the new rule), `collect_allowlist/1` (161–173), `failure_message/1`.
- `test/rindle/delivery/streaming_dispatch_test.exs` — header comment (21–26) + `async: false`
  (line ~27) → `async: true`; the workaround note becomes a root-caused note.
- `test/rindle/owner_erasure_batch_proof_test.exs` + `test/rindle/batch_owner_erasure_task_test.exs`
  — both `async: false` → `async: true` (mutators; clean once double is process-scoped).
- The 8 legitimate swappers to allowlist (D-09) — `config/config_test`, `storage/local_tus_test`,
  `workers/maintenance_workers_test`, `ops/upload_maintenance_test`, `upload/broker_test`,
  `upload/tus_plug_test`, `upload/tus_local_backing_test`, `upload/lifecycle_integration_test`,
  `adopter/canonical_app/lifecycle_test`.

### Project DNA & authorization
- `.planning/PROJECT.md` — D-v1.21-01 (line 541, authorizes the `lib/config.ex` touch);
  adopter-first Repo ownership (≈445–446, 468–469) — preserved (adopters still own `:rindle, :repo`;
  the override is a test-only seam they never set); HARD-01 (the async-safety guard's charter, which
  this rule structurally continues).
- `prompts/gsd-rindle-elixir-oss-dna.md` — engineering DNA / design pillars (determinism,
  stay-async, adopter-safety) the resolver + guard rule are coherence-checked against.
- Ecosystem precedent: Mox `set_mox_private` + `allow/3` + `$callers`; Ecto.Adapters.SQL.Sandbox
  per-process ownership + `shared: not tags[:async]` (already in `test/support/data_case.ex:22–25`).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Config.repo/0` is the single funnel** (~40 `lib/` call sites — `lib/rindle.ex`,
  `streaming.ex`, `delivery.ex`, `admin/queries.ex`, all `workers/*`, `ops/*`). One resolver change
  covers every call site; no `lib/` call site moves.
- **`test/support/data_case.ex:22–25`** already does the right thing for the Sandbox
  (`shared: not tags[:async]`) — the proof that per-process isolation is the house style; the repo
  override mirrors it. The guard explicitly does NOT flag the Sandbox for this reason.
- **`@async_safety_allow [...]` escape hatch** already exists (guard docstring 24–35,
  `collect_allowlist/1`) — D-09 reuses it; only the new `:global_repo_swap` atom is added.

### Established Patterns
- **`$callers` propagation** — `Task.async`/`Task.Supervisor`/Oban-inline (`config/test.exs`
  `testing: :inline`) all carry `:"$callers"`; the resolver walks it exactly like Mox/Sandbox so
  spawned/inline work inherits the override.
- **Merge-blocking guard = structural enforcement** (HARD-01 / DNA pillar) — the `:global_repo_swap`
  rule is HARD-01's continuation: HARD-01 said "async modules may not mutate shared state"; this
  says "no module may swap the globally-read `:rindle, :repo` key."

### Integration Points
- New private fns in `Config` sit before the existing `Application.get_env` fallback; nothing else
  in `lib/` moves.
- The guard gains a **second scan pass** (all modules) for the one new rule; the existing
  async:true-only pass is untouched.
- `release-please`: one `fix:` commit → patch bump to 0.3.2, auto-published on green main.

</code_context>

<specifics>
## Specific Ideas

- **§2 is load-bearing and must not be re-litigated:** `async: false` does NOT run exclusively of
  the async pool — ExUnit interleaves sync modules with the running async pool. So marking a
  global-`put_env` mutator `async: false` gives **zero** protection to a concurrent async reader.
  Per-process scoping is the *only* fix; relabeling modules is not. (This is why demoting
  `StreamingDispatchTest` only "fixed" it by serializing it *with* the mutator, not by curing the
  cause.)
- Cross-language / peer-lib north star: every mature Elixir lib that lets tests swap a global dep
  does it **process-scoped with `$callers`**, never via `try/after` global `put_env`
  (Mox `set_mox_private`, Sandbox per-process ownership). This bug is the un-flagged sibling of
  `set_mox_global`, which the v1.20 guard already flags.

</specifics>

<deferred>
## Deferred Ideas

- **Migrate the other lib-redirecting repo doubles** (`TestRepoProbe`, `FailingTransactionRepo` in
  `maintenance_workers_test`, `upload_maintenance_test`, `broker_test`) to `put_repo_override/1` —
  same global-swap anti-pattern, but those modules are `async: false` and not the flake source.
  A clean follow-up once 110 proves the override seam; out of ISO-01..05 scope. (Their `:repo`
  swaps are allowlisted this phase via D-09, so they stay green.)
- Durable shipped-artifact regression-lock meta-tests → Phase 111 (LOCK-01..05).
- Gate shift-left (move de-flaked lanes into the merge-blocking PR gate) → Phase 112 (GATE).

None raised that fell outside the milestone — discussion stayed within phase scope.

</deferred>

---

*Phase: 110-async-isolation-hardening*
*Context gathered: 2026-06-28*
