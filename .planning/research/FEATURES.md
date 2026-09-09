# Feature Landscape

**Domain:** Pre-adopter readiness and whole-product software quality for an Elixir/Phoenix/Ecto Hex library
**Project:** Rindle v1.26 — Pre-Adopter Readiness & Quality Consolidation
**Researched:** 2026-09-09
**Overall confidence:** HIGH for repository findings; MEDIUM for ecosystem framing

> In this milestone, a “feature” is a demonstrable readiness capability. Every capability below is
> tied to current repository evidence, an adopter risk, and executable acceptance. The milestone
> improves existing behavior and proof; it does not reopen already-shipped product breadth.

## Current Evidence Boundary

Rindle begins v1.26 from a strong baseline, not from neglect:

- v1.25 passed 18/18 requirements, 6/6 phases, 11/11 integration links, and 6/6 end-to-end flows.
- Exact coverage is 5,149/6,269 relevant entries (82.1343%). The accepted PR receipt is 453 seconds
  median and 481 seconds p95.
- The reviewed Credo complexity inventory is finite at 31 findings; the supported Dialyzer ignore
  baseline is removal-only at 35 entries.
- Generated-package, canonical-adopter, Cohort browser, MinIO, live GCS, cassette Mux, release,
  security-invariant, documentation-parity, and admin visual-polish proofs already exist.
- Current residual signals are concrete: eight consecutive scheduled Nightly runs on immutable
  `main` SHA `45ebde5…` failed because Dialyzer restored an “Old PLT”; the `Nightly Summary` job still
  concluded success; issue #88 tracks the failure; issue #42 remains open with only 1/25 authorized
  async-isolation iterations completed; six Dependabot PRs are open; and the latest Nightly dependency
  output reports two Mint advisories, including one high-severity memory-exhaustion DoS advisory.
- The adoption matrix names broad happy-path coverage, but it still includes a skipped GCS browser spec
  and does not prove several failure/retry/restart journeys through the built package.
- Live comments still include planning-era `Phase`, `Plan`, and decision identifiers. Some are genuine
  policy provenance; others are reader-costly artifacting. They require disposition, not bulk deletion.
- The local worktree is already dirty because `.planning/config.json` has a pre-existing modification;
  milestone closure must distinguish workflow-owned planning edits from unrelated dirt.

## Applicable Quality Surface

ISO/IEC 25010:2023 supplies nine product-quality characteristics. Rindle also needs delivery-system
dimensions that determine whether a reusable library can be trusted by an adopter.

| Dimension | Rindle interpretation | Current signal | v1.26 proof boundary |
|-----------|-----------------------|----------------|----------------------|
| Functional suitability | Existing lifecycle contracts remain correct and complete | v1.25 behavior and SAFE-02 green; adoption matrix mostly happy-path | Preserve shipped contract; add executed failure/recovery scenarios where claims outrun proof |
| Performance efficiency | Adopter operations and maintainer feedback stay bounded | PR receipt 453s median/481s p95; heavy lanes intentionally off PR | Preserve ≤480s median/≤600s p95; add timeouts only where measured and semantically safe |
| Compatibility | Supported Elixir/OTP, optional deps, storage/provider, and host-app combinations work | PR floor/home cells, Nightly diagonal, optional-deps and package consumers | Green supported matrix and built-package twin; do not invent a combinatorial matrix |
| Interaction capability | Operator/admin output is understandable, self-describing, inclusive, and actionable | Admin behavior/polish gates and operations docs already ship | Preserve existing automated UI/accessibility contracts; improve failure receipts and guidance, no redesign |
| Reliability | Failures become durable, retryable, observable, and recoverable without residue | Nightly red; issue #42 open; current demo emphasizes success paths | Exercise retry, restart, idempotency, cleanup, and terminal failure with real persisted state |
| Security | Upload, provider-secret, dependency, workflow, and release boundaries resist misuse | Fourteen invariants, SHA pins, least privilege; Mint advisories now reported | Close or explicitly disposition advisories; re-prove invariants, permissions, pins, and fail-closed release |
| Maintainability | Code communicates intent with cohesive ownership and minimal accidental complexity | 31 reviewed findings; many planning-era comments; v1.24/v1.25 already refactored hotspots | Fix only evidence-backed candidates; names/structure first, rationale comments second; removal-only ratchets |
| Flexibility | The package integrates without hidden host assumptions and adapts across supported configurations | Generated consumer, schema compatibility, optional deps, capability negotiation | Clean-checkout/package-consumer twin across supported profiles; no speculative provider/API expansion |
| Safety | Destructive and costly operations fail safe, warn clearly, and preserve recoverability | Dry-run owner erasure, async purge, bounded AV, fail-closed release already ship | Prove purge/erasure/cleanup failure paths, residue accounting, and no destructive scope expansion |
| Test quality | Tests protect behavior rather than implementation literals and yield reproducible failures | 82.1343%; issue #42 incomplete; prior source-inspection tests were reduced | Preserve floor, close/re-scope #42 with finite evidence, replace brittle literals only where identified |
| Documentation and self-description | Public docs, code, comments, errors, and operator output agree with current behavior | Release/adoption wording drift and historical identifiers remain | Executable docs parity plus present-tense comment/prose scan and explicit exceptions |
| Packaging and reproducibility | What adopters install is what CI proves | Built-tarball generated consumers already strong | Twin must consume the built package; receipts bind package checksum, source SHA, toolchain, and scenario set |
| Repository hygiene | Tracked content is intentional; generated/local residue is ignored or rejected | 2,134 tracked paths; hygiene script misses some live/remote truths | Clean-clone inventory, forbidden-path gate, ignore audit, generated-asset provenance, clean final status |
| CI/CD and release engineering | Every green signal is truthful, deterministic, bounded, economical, and release-coupled | Nightly failure/green-summary contradiction; most actions SHA-pinned; Nightly lacks explicit timeouts | Correct aggregation/cache behavior, retain sole `CI Summary`, preserve release gate and measured PR envelope |
| Governance and project truth | Issues, PRs, releases, planning, and support claims match live state | 2 open issues, 6 Dependabot PRs, stale 0.4.5/0.4.6 prose | Machine-readable inbox/release ledger with explicit close/merge/defer decisions and evidence |

## Table Stakes

Missing any of these leaves a credible first adopter exposed to avoidable uncertainty.

| Capability | Priority | Why Expected / Risk Addressed | Current Repo Signal | Automation-First Acceptance | Complexity |
|------------|----------|-------------------------------|---------------------|-----------------------------|------------|
| **Current-head quality census and disposition ledger** | P0 | “Clean everything” is otherwise unbounded and churn-prone | v1.25 used a finite ledger successfully, but v1.26 spans more dimensions and new live signals | A generated/checked ledger covers every dimension above; every unique candidate has owner, evidence, risk, and exactly one `fix`, `retain`, or trigger-bound `defer`; a contract fails on missing/duplicate/open dispositions | Medium |
| **Nightly type-signal recovery** | P0 | A red scheduled gate means supported-head confidence is currently false | Eight consecutive failures restore a cache that passes `mix dialyzer --plt` then fails analysis as “Old PLT” | Fresh and cache-hit supported Elixir 1.17/OTP 27 runs both execute Dialyzer successfully; cache identity includes every compatibility input proven necessary; a regression test reproduces stale-PLT rejection/rebuild | Medium |
| **Truthful Nightly aggregation and issue lifecycle** | P0 | A green summary attached to a failed gating lane is a misleading signal; never-closing incidents become noise | Latest workflow is red while `Nightly Summary` is success and issue #88 receives repeated updates | Pure evaluator tests cover success/failure/cancelled/skipped policy; summary fails whenever any declared gating lane fails; scheduled failure opens/updates one issue and the first qualifying recovery automatically closes it with exact-run evidence | Medium |
| **Security-advisory and dependency disposition** | P0 | A first adopter should not inherit known reachable DoS risk or opaque dependency backlog | Nightly reports Mint 1.9.3 advisories; six Dependabot PRs (#93, #95, #105, #108–110) are open | Machine-readable dependency census records direct/transitive path, reachability, fix version, and outcome; every open dependency PR is merged, superseded/closed, or deferred with tested incompatibility evidence; `mix_audit`/equivalent passes or fails only on an explicit bounded exception | Medium–High |
| **Remote inbox truth** | P0 | Open issues and PRs are part of the product’s operational state | Issues #42/#88 and six bot PRs are open, with mixed clean/behind/blocked states | A read-only collector inventories all open issues/PRs and status checks; closeout asserts zero undispositioned items, while accepted long-lived issues carry owner, next trigger, and current evidence | Low–Medium |
| **Release and planning truth reconciliation** | P0 | Conflicting version/focus prose erodes confidence and can misroute automation | Release surfaces show 0.4.6 while some STATE/PROJECT anchors still describe 0.4.5 or demand-gated pause | One executable parity check derives the live version/focus from authoritative files and verifies README/guides/planning/release-train claims; no hard-coded stale version remains outside marked history | Low–Medium |
| **Repository hygiene and clean-checkout reproducibility** | P0 | A polished library must not depend on maintainer-local residue or track junk | Current hygiene checks release fields but not the complete tracked/ignored/generated surface; worktree is dirty | From a clean clone: forbidden tracked-path inventory is empty, generated assets reproduce byte-identically, ignored scratch is recognized, package excludes repo-only paths, hygiene script passes, and final `git status --porcelain` is empty after workflow-owned artifacts are committed | Medium |
| **Self-describing code and present-tense comments** | P1 | Names and boundaries should carry mechanics; comments should preserve non-obvious rationale, invariants, ordering, and failure semantics | Live production, test, script, workflow, and demo files retain many `Phase`/`Plan`/decision references | A bounded candidate inventory classifies each hit as rewrite/remove/retain; changed code passes formatter, Credo, compile, behavior contracts, and docs checks; a regression scan rejects newly introduced planning IDs outside allowlisted historical/policy contexts | High |
| **Artifact/residue cleanup with provenance proof** | P1 | Junk removal is valuable only when consumer and history obligations are known | Historical planning, generated CSS/assets, screenshots, caches, and test output have different ownership | Each deletion is backed by `git ls-files`, consumer-reference, package-contents, and regeneration evidence; generated assets have an authority + drift gate; historical planning is archived/retained unless an explicit archive contract authorizes removal | Medium |
| **Measured complexity and ownership ratchet** | P1 | Complexity matters when it creates change risk, not when a number is aesthetically high | 31 reviewed findings remain; runtime/GCS/Mux cycles are explicitly deferred absent harm | Baseline identity/count cannot grow; each removal proves behavior and compiled-boundary preservation; retained entries keep owner and removal trigger; no split is accepted solely for line count, nesting, or cycle count | Medium–High |
| **Removal-only type-warning ratchet** | P1 | Broad ignores conceal new defects, but upstream/analyzer noise may be legitimate | 35 supported-toolchain Dialyzer filters; latest failure is infrastructure/cache, not yet a warning regression | Exact supported-cell output is compared to a typed baseline; new filters fail; removed warnings delete filters; retained filters match narrow warning identity and documented behavior rationale | Medium |
| **Behavioral test and coverage integrity** | P1 | Coverage is a searchlight, not proof; 100% can still miss executions | Exact floor is 82.1343%; issue #42’s 25-seed matrix stopped at 1/25 | One authoritative suite run preserves or raises the exact floor; changed risk branches have behavioral tests; source-text/literal assertions are replaced only where they block safe refactoring; #42 completes its finite matrix or remains explicitly open with reproducible failing evidence | Medium–High |
| **Deterministic, bounded, economical CI** | P1 | Hanging jobs, stale runs, poisoned caches, and redundant work waste time and weaken trust | PR CI has an accepted receipt; Nightly has no explicit job timeouts; stale PLT cache is actively harmful | All external/process-heavy jobs have justified `timeout-minutes`; PR-only concurrency cancellation preserves main/release runs; actions remain full-SHA pinned; cache keys and restore scopes are contract-tested; duplicate work is removed only with equivalent signal; a fresh exact-ten receipt remains ≤480s median/≤600s p95 | High |
| **Contributor bootstrap and failure reproduction** | P1 | A first external maintainer must reproduce the same failure without reverse-engineering YAML | `mix ci`, RUNNING, local E2E, and focused commands already exist but Nightly/cache/twin recovery paths are fragmented | One documented command map covers change type → focused proof → full proof; clean bootstrap succeeds on supported toolchain; failed receipts include seed, command, environment, source/package identity, and bounded log/artifact locations | Medium |
| **Built-package synthetic adopter twin** | P0 | In-repo success is weaker than the package behaving inside an adopter-owned host | Generated consumers, canonical adopter, and Cohort exist separately | The twin installs the freshly built tarball into an adopter-owned Phoenix host, runs host-owned Repo/Oban/migrations and real storage/runtime dependencies, and rejects repo path dependencies or prebuilt local BEAM leakage | High |
| **Failure-and-recovery scenario matrix** | P0 | Happy paths do not demonstrate durable media behavior under interruption | Current matrix covers uploads/rendering/ops but not all executed retry/restart claims | At minimum: interrupted tus resume; storage purge failure → persisted retry → success/authoritative absence; AV process failure → visible failed state → reprobe/requeue repair; duplicate/out-of-order Mux webhook/sync; host restart between durable transitions; cleanup of multipart/tmp/provider objects; each scenario asserts DB, Oban, storage, telemetry/error, and residue outcomes | High |
| **Machine-readable twin receipts** | P0 | A demo that merely looks green is not auditable or comparable | Existing UI action receipts and CI timing receipts provide local precedent | JSON/JSONL receipt schema records scenario, immutable source SHA, package checksum/version, toolchain, dependency lock, fixture/stimulus, ordered transitions, Oban attempts/states, external-object delta, terminal verdict, cleanup verdict, and redacted failure evidence; schema and completeness are contract-tested | Medium–High |
| **Clean readiness closure** | P0 | “Ready” must be reproducible from immutable inputs, not asserted in prose | v1.25 had strong phase closure but current live Nightly/inbox truth regressed later | One exact-head closeout manifest links clean-clone, formatter/compile/Credo/type/coverage/security/docs/package/twin/CI/Nightly/release/inbox/hygiene/worktree evidence; any missing, stale, skipped-as-green, wrong-SHA, or dirty-state input fails closed | Medium |

## Differentiators

These capabilities exceed ordinary library CI while directly strengthening Rindle’s “media, made
durable” promise.

| Capability | Value Proposition | Repo Fit | Automated Evidence | Complexity |
|------------|-------------------|----------|--------------------|------------|
| **Cross-layer lifecycle receipt** | Shows one media operation from browser/API stimulus through persisted Rindle state, real Oban attempts, storage/provider effects, telemetry, recovery, and cleanup | Rindle already has first-class lifecycle rows, workers, admin surfaces, and receipt patterns | Twin receipt joins all layers by public asset/upload identifiers while proving provider-secret redaction | High |
| **Deterministic fault choreography without a public fault API** | Recreates costly production failures while preserving the shipped public surface | Existing Mox/test adapters, MinIO, cassettes, and worker seams can inject controlled faults | Scenario-owned adapters/proxies are compiled only in the twin/test host; production package API/spec inventory remains byte-equivalent | High |
| **Restartable twin controller** | Proves recovery from the exact class of interruption that ordinary E2E tests avoid | Phase 132 already established bounded, persistent, resumable controller patterns | Controller persists schema-versioned state, resumes without duplicate stimulus, enforces an absolute deadline, and terminalizes partial/foreign evidence | Medium–High |
| **Residue accounting** | Makes cleanup a measurable product property rather than best-effort teardown | Rindle owns staged objects, multipart sessions, temp files, variants, and some provider assets | Before/after inventories prove only allowlisted durable outputs remain; cleanup failures are visible and fail the scenario, including on test failure | Medium |
| **Support-claim coverage map** | Keeps docs and adoption claims honest as proof evolves | Existing adoption-proof matrix has a drift gate but primarily checks strings/file presence | Generated map binds each support claim to an executable scenario and realism level (`local`, `cassette`, `live`); absent or skipped proof cannot be labeled blocking/verified | Medium |
| **Self-healing Nightly incident loop** | Turns recurring failures into low-noise operational feedback | Existing workflow opens/updates issue #88 but does not close on recovery | Tests and live probe prove open-or-update on failure, close-on-recovery, no duplicate issue, least-privilege token, and exact-run links | Medium |
| **Quality debt budget with negative-delta defaults** | Makes elegance durable without periodic rewrite campaigns | Credo and Dialyzer already use finite reviewed baselines | Complexity, type suppressions, stale provenance, forbidden tracked files, and undocumented skips may stay flat only with explicit retain evidence; new debt fails | Medium |

## Already-Shipped Strengths to Preserve, Not Rebuild

| Strength | Existing Evidence | v1.26 Treatment |
|----------|-------------------|-----------------|
| Public media lifecycle, upload modes, AV, delivery, repair, erasure, and Mux/GCS support | v1.0–v1.23 requirements and package consumers | Regression boundary only; no new public capability |
| Adopter-owned Repo, Oban, migrations, and isolated `rindle` schema | v1.1/v1.22/v1.23 packed-adopter proof | Twin consumes these contracts exactly |
| Fourteen security invariants and redacted provider identifiers | Contract tests, SAFE-02, security audit | Re-prove; do not reshape vocabulary |
| 100/100/100 public docs/spec/moduledoc coverage | `mix doctor --raise` | Preserve; comment cleanup is not public-doc expansion |
| Single `CI Summary` required check and fail-closed release coupling | `ci.yml`, release workflows, branch-protection scripts | Immutable milestone invariant |
| SHA-pinned actions, least-privilege defaults, lock-aware caches | Workflow contracts | Audit drift and repair stale-PLT semantics; no wholesale CI rewrite |
| Fast representative PR lane plus broad main/Nightly/release proof | v1.20–v1.25 timing and topology evidence | Preserve topology unless a measured defect requires a minimal change |
| Automated admin behavior, visual polish, contrast, focus, and responsive checks | Cohort Playwright/computed-style gates | Preserve; no aesthetic redesign |
| Generated-package and canonical-adopter happy-path proof | package-consumer and adopter lanes | Reuse as twin substrate; do not create a fourth demo |

## Anti-Features

| Anti-Feature | Why Avoid | Do Instead |
|--------------|-----------|------------|
| **Blanket rewrite or repository-wide “cleanup” diff** | Destroys blame, creates review noise, and reopens proven contracts without a defect | Work only from the finite ledger; require behavioral or reader-value evidence per change |
| **Comment quota, maximum-comment policy, or delete-all-comments pass** | Good comments explain invariants and failure semantics; counts cannot distinguish value from artifacting | Prefer names/structure; retain present-tense rationale; classify historical identifiers contextually |
| **Commenting obvious mechanics** | Duplicates code and decays | Use comments only for why, invariants, ownership, ordering, security, and non-local constraints |
| **Arbitrary file-size/function-length/cycle targets** | Metric gaming can fragment cohesive owners and add indirection | Reduce only measured change-risk hotspots with stable behavior/compiled boundaries |
| **100% coverage target** | Official Elixir docs warn line coverage cannot express all flows and 100% may create false confidence | Preserve exact floor; add behavioral assertions for identified risk branches and scenarios |
| **Snapshotting private source text or helper names** | Freezes implementation and makes clarity refactors expensive | Assert public outcomes, compiled metadata, emitted receipts, and durable state |
| **Retry-until-green or skipped-as-green twin scenarios** | Masks nondeterminism and makes readiness claims false | Bounded retries only when they are the product behavior under test; record every attempt; fail on unexecuted scenario |
| **A fourth sample/demo application** | Duplicates Cohort/canonical/generated hosts and increases maintenance | Extend Cohort plus generated-package/canonical infrastructure into one orchestrated twin |
| **Mocks-only digital twin** | Callback success does not prove DB/Oban/storage/restart integration | Use controlled faults around real persisted Oban/manual execution and real MinIO/FFmpeg processes |
| **Calling the twin a first adopter or 1.0 pilot** | Synthetic evidence cannot validate human integration friction or independent production operation | Label it maintainer-operated V&V; keep named independent Phoenix pilot gate open |
| **Live-cloud calls on every PR** | Secrets, cost, quota, fork safety, and nondeterminism harm feedback | Deterministic local/cassette PR coverage; secret-gated live confirmation in Nightly/release where needed |
| **Combinatorial OS × OTP × Elixir × provider × profile matrix** | Costs grow faster than signal and can obscure failures | Keep the curated supported diagonal plus representative package/twin profiles |
| **Broad dependency upgrade batch** | Six existing PRs have different compatibility/risk profiles | Triage and land/supersede in small dependency-risk groups with full relevant proof |
| **Deleting historical `.planning/` or generated assets as “junk”** | Removes provenance or shipped/package inputs without proving non-use | Use consumer/provenance/regeneration checks; archive with GSD workflows where appropriate |
| **Ignoring all local/tool outputs by broad wildcard** | Can hide secrets, fixtures, or accidentally generated shipped artifacts | Add the narrowest ignore pattern and pair it with a forbidden-tracked-path test |
| **Renaming `ci.yml`, workflow `CI`, or weakening `CI Summary`/release gates** | Breaks branch protection and release automation coupling | Treat names and full-verification release behavior as hard invariants |
| **Moving Dialyzer back onto the PR critical path** | Repairs the symptom by taxing every contributor and reverses the accepted topology | Fix the Nightly PLT authority and aggregation; keep type analysis owned and gating there |
| **Unbounded fault fuzzing or chaos campaign** | Expensive, flaky, and impossible to close | Enumerate deterministic failure stories with fixed budgets, seeds, deadlines, and residue checks |
| **New product APIs discovered during cleanup** | Scope creep and pre-1.0 contract churn | Record separately; only fix current behavior defects under an explicit scoped decision |

## Feature Dependencies

```text
Current-head census + live truth snapshot
    ├──> Nightly/Dialyzer repair ──> truthful summary ──> incident auto-close
    ├──> dependency/inbox triage ──> security + compatibility disposition
    ├──> repo/comment/complexity/type/test ledgers ──> bounded craft ratchets
    └──> release/planning reconciliation

Built-package twin substrate
    ├──> package checksum + clean bootstrap
    ├──> deterministic fault seams
    └──> real DB/Oban/storage/runtime execution
            └──> failure/recovery scenarios
                    └──> machine-readable receipts + residue accounting

All fix/retain/defer ledgers + twin receipts + live exact-head signals
    └──> clean-checkout readiness manifest
            └──> milestone closure
```

Ordering constraints:

1. Snapshot evidence before cleanup so changes cannot erase their own baseline.
2. Repair live Nightly and security truth before aesthetic code work; correctness and trust outrank polish.
3. Define receipt schema and twin execution boundary before adding scenarios; otherwise each journey emits
   incomparable evidence.
4. Run code/comment/complexity/test improvements in bounded ownership slices after the census assigns
   candidates; never use an open-ended sweep.
5. Optimize CI only after each retained signal and its trigger are classified. Re-run the exact-ten timing
   receipt after topology/caching changes.
6. Close only after a clean clone consumes the exact package and all live evidence points to one immutable SHA.

## Milestone Recommendation

Prioritize the following phase-sized capabilities:

1. **Evidence charter and live-truth repair** — complete the quality census; fix stale PLT behavior,
   truthful Nightly aggregation, release/planning drift, and incident lifecycle.
2. **Dependency, security, and remote-inbox closure** — disposition the two issues, six PRs, Mint
   advisories, and supported compatibility impact with executable evidence.
3. **Repository and code-craft consolidation** — clean tracked/ignored/generated residue and perform
   bounded present-tense code/comment improvements from the ledger.
4. **Measured quality ratchets** — complexity, Dialyzer ignores, coverage/behavioral tests, #42 finite
   evidence, bootstrap reproducibility, and CI timeout/cache/economy contracts.
5. **Synthetic adopter twin foundation** — built-tarball host, real Repo/Oban/MinIO/FFmpeg execution,
   deterministic fault seams, controller, receipt schema, and residue accounting.
6. **Failure/recovery scenario closure** — tus interruption, purge retry, AV repair, Mux disorder,
   restart, idempotency, and cleanup journeys with no skipped-as-green outcomes.
7. **Exact-head readiness closure** — clean checkout/worktree plus supported toolchain, package, docs,
   security, CI, Nightly, release, inbox, and twin receipts bound into one fail-closed manifest.

Defer:

- Real-pilot validation: the twin cannot substitute for a named independent Phoenix adopter.
- LIFE-06, STREAM-10, TRANS-01, PRIV-01, tus 2.0/RUFH, GCS-as-tus-backend, uploader kits, and other
  product breadth: none has the required adopter/compliance signal.
- Runtime facade/GCS/Mux compile-cycle decomposition, partitioning, or cache-topology redesign unless the
  census produces current measured harm.

## Sources

### Repository evidence — HIGH confidence

- `.planning/PROJECT.md`, `.planning/STATE.md`, and
  `.planning/milestones/v1.25-MILESTONE-AUDIT.md`
- `examples/adoption_demo/docs/adoption-proof-matrix.md`
- `RUNNING.md`, `.github/workflows/ci.yml`, `.github/workflows/nightly.yml`, `.gitignore`, and
  `scripts/maintainer/repo_hygiene_check.sh`
- Live GitHub evidence queried 2026-09-09: Nightly runs `34324448817` through `33604173427`, issue
  #88, issue #42, and Dependabot PRs #93, #95, #105, and #108–110

### Ecosystem evidence — MEDIUM confidence (official sources, cross-checked against repo behavior)

- [ISO/IEC 25010:2023 product quality model](https://www.iso.org/standard/78176.html) and
  [ISO/IEC 25023 measurement categories](https://www.iso.org/obp/ui?_escaped_fragment_=iso%3Astd%3Aiso-iec%3A25023%3Adis%3Aed-1%3Av1%3Aen)
- [GitHub Actions secure use reference](https://docs.github.com/en/actions/reference/security/secure-use),
  [workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax),
  and [dependency caching reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching)
- [Elixir/Mix coverage guidance](https://hexdocs.pm/mix/Mix.Tasks.Test.Coverage.html) and
  [Dialyxir warning-ignore guidance](https://dialyxir.hexdocs.pm/)
- [Oban testing introduction](https://hexdocs.pm/oban/testing.html),
  [worker testing](https://oban.hexdocs.pm/testing_workers.html), and
  [worker retry semantics](https://oban.hexdocs.pm/Oban.Worker.html)
- [NIST software verification and validation](https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication500-165.pdf)
  and [NIST digital-twin trust considerations](https://tsapps.nist.gov/publication/get_pdf.cfm?pub_id=957183)

## Confidence Assessment

| Area | Confidence | Reason |
|------|------------|--------|
| Existing strengths and residual gaps | HIGH | Direct repository artifacts, exact prior audit, live GitHub API results, and current workflow logs |
| Quality-dimension completeness | MEDIUM | Current ISO official model supplies the taxonomy; applicability is tailored to this library |
| CI/security capabilities | HIGH | Repo workflow inspection plus current official GitHub documentation |
| Test/type/coverage recommendations | HIGH | Exact local baselines plus official Elixir, Dialyxir, and Oban documentation |
| Digital-twin scenario selection | MEDIUM–HIGH | Direct gaps in Rindle’s proof matrix and durable lifecycle risks; exact implementation belongs in phase research |

---
*Feature research for Rindle v1.26 Pre-Adopter Readiness & Quality Consolidation.*
