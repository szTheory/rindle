# Phase 6: Adopter Runtime Ownership - Research

**Researched:** 2026-04-28
**Domain:** Elixir library runtime ownership, Ecto repo resolution, Oban ownership, adopter integration proof
**Confidence:** HIGH

---

## Summary

Phase 6 should not be treated as a single refactor. The current adopter trust gap is spread across three coupled surfaces:

1. Public runtime entrypoints hard-code `Rindle.Repo`
2. Those same flows enqueue work through globally configured `Oban`
3. The canonical adopter lane proves the desired architecture only indirectly because the runtime still falls back to the library-owned harness

The lowest-churn implementation shape is to introduce a single runtime ownership seam in `Rindle.Config`, thread option-first overrides where internal code already supports that style, and convert the canonical adopter lane from an architectural aspiration into a contract test that runs public APIs against an adopter-owned repo.

---

## Phase Requirements

| ID | Requirement | Research Support |
|----|-------------|------------------|
| ADOPT-01 | Adopter can configure runtime Repo via `config :rindle, :repo, MyApp.Repo` | Add `Rindle.Config.repo/0` with app-env lookup and use it everywhere public runtime paths touch persistence |
| ADOPT-02 | Public runtime APIs use configured adopter Repo instead of hard-coded `Rindle.Repo` | Replace direct aliases/calls in `lib/rindle.ex` and `lib/rindle/upload/broker.ex`; ensure transaction callbacks use the transaction repo arg instead of re-fetching via `Rindle.Repo` |
| ADOPT-03 | Canonical adopter integration proves upload, attach, detach, and delivery flows with adopter-owned Repo | Rework adopter fixture/test harness to set `config :rindle, :repo, Rindle.Adopter.CanonicalApp.Repo` and assert public lifecycle succeeds end-to-end |
| ADOPT-04 | Guides/examples document adopter-owned Repo and Oban ownership | Update guide snippets and API docs that still say “Requires `Rindle.Repo`” so the adopter-owned contract is explicit |

---

## Concrete Findings

### Public runtime leak points

- `lib/rindle.ex`
  - `attach/4` uses `Rindle.Repo.transaction/1` and `Rindle.Repo.get!/2`
  - `detach/3` uses `Rindle.Repo.transaction/1` and `Rindle.Repo.get!/2`
  - `upload/3` uses `Rindle.Repo.transaction/1`
  - doc examples still describe `Rindle.Repo` as a runtime requirement
- `lib/rindle/upload/broker.ex`
  - aliases `Rindle.Repo`
  - `initiate_session/2`, `sign_url/2`, and `verify_completion/2` all persist through the library repo
  - `verify_completion/2` enqueues `PromoteAsset` inside a repo-tied `Ecto.Multi`

### Best existing seam to reuse

- `lib/rindle/config.ex` already centralizes runtime accessors like queue and TTL config
- ops modules already follow option-first dependency injection with application-env fallback
- that makes `Rindle.Config.repo/0` the most consistent place to resolve runtime repo ownership

### Oban coupling findings

- public flows call `Oban.insert`/`Oban.insert(:name, job)` directly rather than resolving a named adopter-owned instance
- `test/test_helper.exs` starts Oban with `repo: Rindle.Repo`
- `use Oban.Testing, repo: Rindle.Repo` appears throughout tests, including the canonical adopter lane

### Adopter proof finding

- `test/adopter/canonical_app/lifecycle_test.exs` already documents the exact gap this phase must close
- the fixture starts an adopter repo, but the runtime still effectively proves success through the shared harness rather than a true adopter-owned contract

---

## Recommended Implementation Shape

### 1. Centralize runtime ownership

Add runtime accessors in `lib/rindle/config.ex`:

- `repo/0`
- optionally `repo!/0` if the codebase prefers explicit failure on missing config
- optionally `oban_name/0` or equivalent if public job enqueue paths should stop assuming the default global `Oban`

Recommended default:

- keep `Rindle.Repo` as dev/test harness fallback for backward compatibility in the repo itself
- treat `config :rindle, :repo, MyApp.Repo` as the public contract and move all public runtime paths onto it

### 2. Remove hard-coded repo usage from public paths

Use a local `repo = Rindle.Config.repo()` at public entrypoints and pass it through:

- `repo.transaction(...)`
- `repo.get(...)`
- `repo.preload(...)`
- inside `Ecto.Multi.run`, use the callback repo arg instead of reopening through `Rindle.Repo`

This is especially important in:

- `Rindle.attach/4`
- `Rindle.detach/3`
- `Rindle.upload/3`
- `Rindle.Upload.Broker.initiate_session/2`
- `Rindle.Upload.Broker.sign_url/2`
- `Rindle.Upload.Broker.verify_completion/2`

### 3. Decide Phase 6 scope for Oban ownership explicitly

There are two reasonable levels:

- Minimal Phase 6 scope: keep default `Oban` usage, but document that adopters own the Oban repo/config and prove public runtime repo ownership first
- Stronger Phase 6 scope: add a runtime seam for Oban naming or insertion so adopter-owned runtime boundaries are explicit for both DB and job enqueue

Recommendation:

- Plan Phase 6 around repo ownership as the hard must-have
- include enough Oban work to remove contradictory library-owned wording and keep adopter docs honest
- if named Oban-instance support is larger than expected, make it a deliberate follow-up rather than silently under-planning it

### 4. Preserve public API shape

Do not change:

- `Rindle.attach/4`
- `Rindle.detach/3`
- `Rindle.upload/3`
- broker return shapes

This phase should change runtime ownership, not user-facing call signatures.

---

## Risks and Migration Hazards

### Test harness risk

- many tests assume `Rindle.Repo` and `Oban.Testing, repo: Rindle.Repo`
- if repo resolution changes without a stable default, broad test fallout is likely
- mitigation: keep harness defaults intact while letting targeted tests override runtime repo via application env

### Transaction callback risk

- `attach/4` and `detach/3` currently ignore the transaction repo in some callbacks
- a superficial search-replace can leave mixed repo ownership inside one multi
- mitigation: explicitly audit every `Ecto.Multi.run` callback and reload path

### Oban coupling risk

- enqueue code tied to the default global `Oban` may still be acceptable for Phase 6, but it becomes misleading if docs claim full adopter ownership without qualification
- mitigation: either plan explicit Oban ownership work or constrain the documentation claims to what the code truly guarantees

### Documentation drift risk

- current docs and doctests still mention `Rindle.Repo`
- canonical adopter guide parity was already locked in Phase 5
- mitigation: plan docs/API doc updates in the same phase as the runtime fix, not as cleanup later

---

## Verification Priorities

Phase 6 verification should prove behavior at three levels:

1. Unit/regression tests for repo resolution behavior
2. Public runtime regression coverage for `attach/4`, `detach/3`, `upload/3`, and direct-upload verification
3. Canonical adopter lifecycle proving the configured adopter repo is the one actually used

High-signal checks:

- setting `config :rindle, :repo, Rindle.Adopter.CanonicalApp.Repo` causes public flows to persist/query through that repo
- broker direct-upload flow still promotes correctly
- attach/detach replacement and purge flows still behave atomically
- canonical adopter lane no longer relies on the shared `Rindle.Repo` loophole described in the existing TODO
- updated guides/examples no longer instruct adopters to run `Rindle.Repo`

---

## Recommended Plan Slices

The phase should likely be split into 3 executable plans:

### Plan 06-01: Runtime repo resolution seam

- add `Rindle.Config.repo/0`
- replace hard-coded repo usage in public facade and broker paths
- add focused regression tests around configured repo selection

### Plan 06-02: Adopter proof and test harness hardening

- update canonical adopter fixture to run public lifecycle against adopter-owned repo
- adjust harness/env setup carefully so existing tests keep working
- prove upload, verify, attach, detach, and delivery with the adopter repo

### Plan 06-03: Docs and contract cleanup

- update guides and API docs to adopter-owned wording
- remove stale TODO-era language that describes `Rindle.Repo` as a public runtime requirement
- document Repo and Oban ownership in adopter-first terms that match the proven path

If the planner finds Oban ownership changes are substantial, it can pull part of that work into Plan 06-02 and leave deeper named-instance support deferred, but it should make that boundary explicit.

---

## Recommendation To Planner

Optimize for a narrow but enforced contract:

- one runtime seam for repo ownership
- no public API signature churn
- adopter lifecycle proof that fails if the runtime falls back to `Rindle.Repo`
- docs updated in the same phase so the contract is both real and teachable

This phase is successful when the adopter repo is no longer a comment or aspiration in the test suite. It has to become the actual runtime dependency public flows use.
