# Domain Pitfalls

**Domain:** Pre-adopter software-quality consolidation and synthetic media-lifecycle adoption proof
**Project:** Rindle v1.26
**Researched:** 2026-09-09
**Overall confidence:** HIGH for repository-specific findings (direct inspection); MEDIUM for general ecosystem guidance (official GitHub, Oban, and Git documentation reached through the research seam's web-search fallback)

## Trust Model

This milestone can look unusually successful while making Rindle less trustworthy. Counts can fall because code or tests were deleted, comments can become longer while intent becomes less clear, CI can become faster because proof moved behind a skip condition, and a synthetic adopter can “recover” from states it inserted directly into the database. The governing rule should therefore be:

> A quality improvement counts only when it is tied to an immutable source revision, preserves declared contracts, exercises the boundary it claims to prove, and leaves machine-readable evidence that distinguishes pass, fail, skipped, and not-run.

The highest-risk facts already visible in this repository are:

- `.github/workflows/ci.yml` is part of the release protocol, not merely a test runner. `release.yml` waits for the full `push:main` workflow conclusion on an exact SHA, while branch protection requires the `CI Summary` aggregate.
- `CI Summary` intentionally treats some skipped jobs as acceptable for fork safety, while off-PR full-package and Cohort lanes are excluded from its `needs`. Changing topology without modeling both PR and `push:main` events can create a false green or a pending-forever gate.
- `.github/workflows/nightly.yml` has secret-gated GCS jobs that can finish successfully without executing provider proof. The current recurring red is the gating Dialyzer job, and the nightly issue bot files failure state but does not itself prove recovery.
- `scripts/maintainer/repo_hygiene_check.sh --ci` omits local worktree and divergence checks. Local mode checks `git status`, but its `git fetch` failure is swallowed and its latest-CI lookup can degrade to a warning. A green CI hygiene invocation is not proof that a maintainer's checkout is clean and synchronized.
- `.dialyzer_ignore.exs` contains exact, rationale-bearing suppressions, many tied to old run IDs and milestones. Removing warnings by broadening ignores, deleting paths, or changing accepted behavior would be type-safety theater.
- `examples/adoption_demo/config/test.exs` configures Oban `testing: :inline`, which the Oban documentation says executes in the caller without database interaction. Cohort code also calls `Oban.drain_queue/2` directly and rescues failures. That is useful demonstration plumbing, but it cannot prove production-like retry, scheduling, restart, or queue recovery.
- The adoption proof matrix labels GCS as live even though its browser spec is skipped, and it correctly calls MinIO fake/local. v1.26 must strengthen that honesty rather than collapse the distinctions.
- The worktree was already dirty when research began due to active milestone artifacts. Any cleanup acceptance that simply asserts `git status --porcelain` in this shared checkout would confuse orchestrator activity with repository residue.

## Critical Pitfalls

### Pitfall 1: Aesthetic churn masquerades as maintainability

**What goes wrong:** Broad renames, file splitting, helper extraction, formatting, and comment rewrites produce a large “beautiful code” diff without reducing change cost. Reviews become shallow, `git blame` loses signal, subtle ordering or failure behavior moves, and defects hide inside subjective edits.

**Why it happens:** “Work of art” is interpreted as uniform style or small files rather than low accidental complexity and explicit ownership.

**Warning signs:** Rename-only commits across unrelated subsystems; falling line counts with unchanged behavior and no measured hotspot; helpers used once; modules split on arbitrary size thresholds; large diffs with no requirement-to-proof map; churn in previously dispositioned cycles without new evidence.

**Automated prevention:** Begin with a current-SHA candidate ledger. Every changed owner must name a measured trigger (complexity identity, repeated change coupling, defect, duplication, or readability review), a preservation suite, and a before/after result. Run `scripts/maintainer/refactor_contract.sh`, public-contract tests, package build/consumer proof, and focused behavior tests before and after each slice. Add a changed-path budget or review gate that fails unscoped cross-subsystem edits rather than enforcing arbitrary file-size targets.

**Recovery:** Revert the aesthetic slice independently; retain only changes whose proof demonstrates lower complexity or clearer ownership without contract drift.

**Phase ownership:** Quality census and charter first; bounded code-craft phase second.

### Pitfall 2: Comment-density and provenance cleanup make code harder to read

**What goes wrong:** Maximizing comments repeats syntax, freezes implementation details, or replaces concise historical markers with verbose prose. Conversely, deleting every phase/decision reference erases explanations for release coupling, fork-secret behavior, migration safety, and failure ordering.

**Why it happens:** A mechanical search treats every `Phase N`, `D-N`, `TODO`, or old run ID as artifacting, while “self-documenting” is treated as “no comments.” The workflows currently contain many historical markers alongside genuinely load-bearing rationale.

**Warning signs:** Comment count used as a target; prose describes what the next line does; present-tense invariant disappears with a planning ID; tests assert exact comments rather than the policy they represent; comments contradict current topology.

**Automated prevention:** Classify each live comment as invariant/rationale, public explanation, removable narration, or stale claim. Preserve why, ownership, ordering, security, and failure semantics in present tense. Gate known documentation and workflow parity with executable structural checks, but do not create a generic “no phase IDs” regex that incentives deleting context. Require changed production owners to pass formatter, Credo, docs-link/parity, and behavior suites.

**Recovery:** Restore the last correct rationale from history, rewrite it in present tense, and add a policy-level test where the invariant can be executed.

**Phase ownership:** Quality census; code/comment craft.

### Pitfall 3: Repository cleanup deletes assets that are source, evidence, or release inputs

**What goes wrong:** Historical `.planning/` records, checked-in generated CSS, migration fixtures, cassettes, sample media, snapshots, or generated-package inputs are labeled “junk” and deleted. `.gitignore` is then expanded to conceal missing regeneration or consumer drift.

**Why it happens:** Generated is confused with disposable. Git's official documentation is explicit that ignore rules affect intentionally untracked files; they do not make already tracked files disappear or prove that tracked artifacts are unnecessary.

**Warning signs:** Deletion justified only by filename or size; adding an ignore rule and deleting a tracked file in the same patch; generated outputs removed without locating their generator and consumer; archive rewrites; package contents change unexpectedly.

**Automated prevention:** For every deletion, record provenance, generator, consumers (`rg`, `git ls-files`, package manifest, CI references), regeneration command, and disposition. For committed generated outputs, regenerate in a clean checkout and require `git diff --exit-code`. Compare `mix hex.build` contents and run built-package consumer proof. Run docs-link and planning-contract checks after any planning deletion. Only ignore reproducible local outputs; test ignores with `git check-ignore -v` and tracked inventory with `git ls-files`.

**Recovery:** Restore from Git, document ownership, and add a regeneration/drift gate. If provenance cannot be established, retain explicitly rather than delete speculatively.

**Phase ownership:** Repository hygiene phase after census, before broad craft edits.

### Pitfall 4: Refactoring silently changes public API, schema, telemetry, or error vocabulary

**What goes wrong:** “Cleaner” types, error tuples, event metadata, queue names, migration behavior, schema prefixes, or function boundaries break adopters while unit tests remain green. A twin coupled to new internals then validates the changed behavior instead of detecting drift.

**Why it happens:** Internal elegance is optimized without treating pre-1.0 compatibility and operational vocabulary as contracts. The project explicitly locks public API, schema/migrations, telemetry, errors, release coupling, and supported behavior.

**Warning signs:** Public docs or typespecs change in a refactor-only slice; migrations are edited rather than appended; telemetry names/measurements/metadata disappear; error assertions are weakened to wildcard matching; generated consumer tests are updated in the same commit as the behavior they should guard.

**Automated prevention:** Keep preservation tests and expected-contract fixtures independent of implementation edits. Gate exported API/typespec inventory, migration/schema snapshots and upgrade paths, telemetry contract tests, error-freeze tests, package contents, canonical adopter, and generated fresh-app installation. Any intentional change requires an explicit semver/scoped decision rather than being absorbed into cleanup.

**Recovery:** Restore the prior contract or isolate an explicitly approved compatibility change with upgrade documentation and its own release decision.

**Phase ownership:** Cross-cutting hard gate in every implementation phase; closure re-runs the full SAFE/refactor contract.

### Pitfall 5: Quality metrics become stale, self-referential, or easy to game

**What goes wrong:** The milestone reports fewer Credo findings, higher coverage, fewer files, or faster CI using a stale baseline, a different denominator, deleted tests, excluded paths, incomparable runs, or fixtures generated by the code under test.

**Why it happens:** Numeric movement is easier to communicate than behavioral trust. v1.25's accepted baseline is precise—31 curated complexity findings and 82.1343% coverage—but it belongs to a specific revision and policy.

**Warning signs:** No source SHA/toolchain/config hash on receipts; counts without finding identities; coverage rises after exclusion changes; elapsed time compares PRs with different lanes/cache states; proof verifies its own generated expectation; baseline fixtures are edited with production changes.

**Automated prevention:** Receipts must include source SHA, dirty-state flag, tool versions, config/lock hashes, denominator, finding identities, lane/result taxonomy, and command. Recompute the v1.25 baseline on current head before ratcheting. Fail on unexplained identity substitution even when counts do not rise. Keep golden contracts reviewer-owned and mutation-test critical evidence collectors with deliberately broken fixtures/workflows.

**Recovery:** Mark the receipt invalid, restore the comparable baseline, and rerun on the immutable target SHA from a clean checkout.

**Phase ownership:** Evidence charter; static-analysis/testing ratchets; measured closure.

### Pitfall 6: Coverage and Dialyzer suppression theater

**What goes wrong:** Coverage is driven toward 100% with low-value literal tests, branches are excluded, or production code is bent around the analyzer. Dialyzer goes green because warnings are broadly ignored, descriptions drift, or the failing paths are deleted—not because contracts improved.

**Why it happens:** The recurring Nightly Dialyzer red creates pressure for a fast green, while the existing ignore file contains substantial accepted debt with precise rationales.

**Warning signs:** File-wide ignore patterns; suppression count grows; exact warning text becomes a substring wildcard; coverage configuration changes without a separate decision; tests mirror private clauses; dead code removal changes public fallbacks; a warm-PLT pass cannot reproduce cold.

**Automated prevention:** First reproduce the five-run Nightly failure on the exact `main` SHA and supported OTP/Elixir pair. Ratchet both suppression count and normalized identity, reject broad filters, and require a rationale plus behavioral witness for every retained suppression. Run cold- and warm-PLT paths. For coverage, freeze configuration and denominator before test additions; prioritize branch/error/lifecycle gaps and reject coverage-only tests that assert private implementation literals.

**Recovery:** Restore the last exact ignore set and coverage config, reopen the warning as debt, and classify it as fix, retain with executable witness, or defer with owner/trigger.

**Phase ownership:** Live-truth restoration (Nightly); static analysis and test-value phase.

### Pitfall 7: CI optimization breaks topology or release coupling

**What goes wrong:** A job moves, a `needs` edge changes, or an `if` expression turns a failure into `skipped`; `CI Summary` passes while required work never ran, or a conditional job leaves branch protection pending forever. Alternatively, `push:main` is canceled or made advisory, allowing release automation to accept incomplete proof.

**Why it happens:** GitHub's official syntax propagates failed/skipped dependencies unless conditions such as `always()` override that behavior. Rindle also has two distinct truth surfaces: the PR aggregate and the full `push:main` workflow conclusion used by release.

**Warning signs:** A required lane omitted from `CI Summary.needs`; blanket “skipped is pass” logic applied to a lane expected for the current event; renaming `ci.yml`, workflow `name: CI`, or `CI Summary`; enabling cancellation on main; moving full-package/demo breadth off `push:main`; release gate checked only by context name.

**Automated prevention:** Model the workflow for fork PR, same-repo PR, labeled streaming PR, push main, manual dispatch, missing secrets, failed dependency, and canceled predecessor. Assert expected jobs and acceptable result sets per event—not globally. Keep `cancel-in-progress` true only for PRs, preserve exact-SHA full-run release lookup, and test branch-protection context names. Every topology change must run the CI script/meta-tests and automation-first contract.

**Recovery:** Restore the prior topology and required-context names, then replay the workflow on the exact target SHA before release readiness can resume.

**Phase ownership:** CI/CD boundedness phase; final release-readiness phase.

### Pitfall 8: Unbounded or mutable external inputs make CI fast only when lucky

**What goes wrong:** Actions, containers, OS packages, browser binaries, service downloads, or APIs change beneath the same commit. Network waits, recursive polling, and cleanup loops run without deadlines. A faster median hides an unbounded tail and transient provider failures.

**Why it happens:** SHA-pinned actions create a sense that the whole supply chain is pinned. GitHub jobs default to a six-hour timeout, and many Rindle jobs do not currently declare `timeout-minutes`.

**Warning signs:** Floating container tags or package repositories; downloads without checksum/provenance; recursive waits using attempt counts that silently return success on exhaustion; retry loops without total deadline; jobs lacking timeouts; live-provider failures retried until they become green with no classification.

**Automated prevention:** Inventory every external input and classify it as immutable, verified, or explicitly volatile. Pin actions by SHA, lock container/browser/toolchain versions or digests where feasible, verify downloaded artifacts, and set evidence-based job/step deadlines above measured p95. Bound retries by attempts and wall clock; emit final error/state on exhaustion. Track cache-hit state and cold-path timings separately.

**Recovery:** Quarantine the volatile input, reproduce with the last known digest/version, and record infrastructure failure separately from product failure; do not rerun-to-green without a disposition.

**Phase ownership:** CI/CD boundedness and supply-chain pass.

### Pitfall 9: Dirty-worktree and clean-checkout false greens

**What goes wrong:** Local untracked files, ignored outputs, stale dependencies, generated assets, or an ahead/behind main influence proof. Conversely, acceptance fails merely because GSD research files are intentionally dirty in the shared worktree. CI starts clean but never checks residue after generators/tests.

**Why it happens:** One `git status --porcelain` check is asked to represent three different properties: clean input, no generated drift, and no residue after execution. The existing hygiene script checks working-tree state only in local mode, and tolerates fetch/status uncertainty as warnings.

**Warning signs:** Hygiene passes under `--ci` despite generated changes; acceptance runs in the orchestrator checkout; ignored residue accumulates; `git fetch` failure is invisible; local `main` is not the immutable revision cited by the receipt.

**Automated prevention:** Use a disposable clean clone/worktree at the exact SHA for acceptance. Record pre-run porcelain including untracked files; run generation/proof; record post-run porcelain and an explicit inventory of ignored residues. Treat remote synchronization uncertainty as not-proven for release prep. Keep the developer convenience check separate from the hermetic acceptance collector.

**Recovery:** Remove only namespaced outputs through their owner cleanup command, recreate the isolated checkout, and rerun. Never “fix” the result by globally cleaning the shared working tree.

**Phase ownership:** Repository hygiene; measured closure.

### Pitfall 10: Issue and PR triage mutates remote state before evidence is settled

**What goes wrong:** The nightly issue is closed before a scheduled recovery run; flaky-test issue #42 is dismissed because one suite passed; Dependabot PRs are merged, rebased, or closed in bulk despite distinct compatibility or package-consumer failures. Comments or labels trigger automation unexpectedly.

**Why it happens:** “Inbox zero” is mistaken for readiness. Current remote state includes two issues and six dependency PRs, with at least one dependency PR showing blocked/failing proof and canceled predecessor runs.

**Warning signs:** Bulk close/merge; issue disposition without linked immutable runs; a bot PR judged by `mergeStateStatus` alone; triage edits mixed into code changes; nightly issue closed by a manual dispatch rather than scheduled success.

**Automated prevention:** Snapshot the remote inbox read-only, then require one machine-readable disposition per item: merge, supersede, close-with-evidence, retain-open, or defer. Mutation is a separate reviewed step. Require current-head required checks and relevant full package/adopter proof for each dependency group. Close recurring-nightly incidents only after the owned scheduled lane succeeds on current main and the failure fingerprint is absent.

**Recovery:** Reopen incorrectly closed issues, restore labels/milestones from the snapshot, and revert unsafe dependency merges individually.

**Phase ownership:** Live-truth and inbox phase; final remote reconciliation.

### Pitfall 11: The digital twin proves its own implementation instead of adopter behavior

**What goes wrong:** Cohort imports private Rindle modules, inspects internal tables, calls workers directly, or shares fixtures with the library tests. Refactors update twin and implementation together, so incompatible public behavior remains green.

**Why it happens:** In-repo access makes private shortcuts easy. The current proof already has three layers, but the persistent Cohort host is checked into the same repository and its runtime helpers directly drain Rindle queues.

**Warning signs:** `alias Rindle.Internal.*`; direct calls to worker `perform/1`; assertions on internal schema shape instead of public outcomes/telemetry; twin code compiled from the checkout rather than the built package; expected receipts generated by library internals.

**Automated prevention:** Build the Hex tarball first and make the twin consume that artifact through supported installer/config/public APIs. Enforce a private-module import denylist and scan for direct worker invocation or library-table mutation outside migration/setup allowlists. Observe public return values, HTTP behavior, documented DB states, telemetry, storage effects, and operator surfaces. Keep fault injection at external boundaries (storage/provider/HTTP/process lifecycle), not inside private implementation.

**Recovery:** Replace the shortcut with a public-boundary scenario and add a negative fixture that proves the guard catches private coupling.

**Phase ownership:** Twin contract/architecture phase before scenario implementation.

### Pitfall 12: Direct-seeded failure states and inline Oban create fake recovery

**What goes wrong:** A test inserts a `failed`, `retryable`, `processing`, or `stale` row and then confirms the UI or recovery command sees it. Inline Oban executes immediately without database interaction, so the test never observes real enqueue, attempts, backoff, state transitions, queue shutdown, restart, or uniqueness behavior.

**Why it happens:** It is deterministic and fast. Oban's official testing guide explicitly says inline mode runs in the caller without touching the database and may not suit complex jobs; manual mode inserts jobs for controlled execution.

**Warning signs:** Target failure state appears in fixture setup; `Repo.update_all` creates the state under test; `perform_job` substitutes for queue lifecycle; `Oban.drain_queue(..., with_safety: false)` is called from UI code; rescue converts drain failure to success; attempts never increment in the database.

**Automated prevention:** Permit direct seeding only for neutral prerequisites. Create failure through executed work: a controllable storage/provider fault returns the real error, a supervised database-backed Oban queue runs the job, and the receipt captures queued→executing→retryable/discarded→recovered transitions, attempt counts, error terms, telemetry, and durable side effects. Restart the app/queue between interruption and recovery for restart claims. Retain fast inline unit tests, but label them unit evidence and never use them to satisfy lifecycle-twin requirements.

**Recovery:** Downgrade the claim to presentation/unit coverage, implement a real queue scenario, and rerun from a fresh namespace.

**Phase ownership:** Twin substrate first; failure/recovery scenario phase next.

### Pitfall 13: Secret-gated live tests are reported as green proof

**What goes wrong:** GCS or Mux credentials are missing, every meaningful step skips, and the job or workflow is green. A cassette or MinIO path is then described as live-provider evidence. Live credentials can also introduce quota, latency, expiry, and remote-service flakiness into the deterministic merge gate.

**Why it happens:** GitHub job conditions and secret availability make skip behavior necessary for forks, but dashboards compress successful no-op and successful proof into similar signals.

**Warning signs:** No `executed=true` marker; “Skip live...” step is the only executed provider step; summary says success without resource IDs/namespace; cassette labeled live; merge-blocking PR depends on external secrets.

**Automated prevention:** Every provider receipt records `proof_level` (`fake`, `cassette`, `live`), `execution` (`passed`, `failed`, `not_run`), reason, target SHA, and cleanup result. Deterministic MinIO/fault-server proof remains merge-blocking. Live proof stays separately scheduled or explicitly dispatched, never counted when secrets are absent, and gates only claims that require it. Add a secret-present canary and a secret-absent fixture that verifies honest `not_run` reporting.

**Recovery:** Correct the ledger and docs, rerun the live lane when authorized, and leave the live claim open until a real receipt exists.

**Phase ownership:** Twin evidence contract; live-provider companion phase; measured closure.

### Pitfall 14: Failure injection leaves storage, rows, jobs, processes, or secrets behind

**What goes wrong:** Interrupted tus sessions, multipart uploads, Mux/GCS objects, Oban jobs, temp files, containers, ports, or database schemas persist. Later runs pass because they reuse residue, fail nondeterministically, leak cost, or delete another run's resources.

**Why it happens:** Happy-path assertions finish before cleanup; cleanup uses broad prefixes; `|| true` hides deletion failure; process cancellation prevents teardown.

**Warning signs:** Shared bucket prefixes; no run ID/attempt namespace; cleanup output absent from receipts; teardown executes only on success; recursive best-effort deletion with no postcondition; second run behaves differently; ignored `.tmp`/test-results accumulate.

**Automated prevention:** Allocate a unique namespace from immutable SHA + run ID + attempt. Maintain an append-only resource ledger as resources are created. Run idempotent `always()` cleanup with bounded retries, then independently query each backend for zero residue. Emit created/deleted/remaining counts and fail readiness when residue remains. Test cleanup itself by interrupting a scenario midway and running the janitor twice. Never log raw session URIs or credentials.

**Recovery:** Run the namespaced janitor from the retained ledger, verify zero residue, rotate any exposed credential, and invalidate contaminated receipts.

**Phase ownership:** Twin substrate before any destructive scenario; closure residue audit.

### Pitfall 15: Synthetic evidence is promoted to a “first adopter” claim

**What goes wrong:** Cohort's breadth is used to mark the independent Phoenix pilot complete or to widen support claims. The project becomes confident in paths designed and operated by the same maintainer who built the library, while integration friction outside the repository remains unobserved.

**Why it happens:** A realistic twin can exercise more failure modes than an early adopter and therefore feels stronger, but it lacks organizational independence, unknown host conventions, and external maintenance behavior.

**Warning signs:** README says “production proven” or “adopter validated” based only on Cohort; LIFE/STREAM or 1.0 pilot gates close from synthetic receipts; the twin's host configuration mirrors Rindle examples exactly; no explicit synthetic marker in evidence.

**Automated prevention:** Stamp every receipt `evidence_subject: synthetic_maintainer_twin` and every claim with its proof level. Add a policy test that rejects using synthetic receipt IDs to satisfy the named independent Phoenix pilot requirement. Keep the pilot requirement open in planning and public readiness language until external evidence exists.

**Recovery:** Retract the claim, publish the narrower verified statement, and reopen the independent-adopter gate.

**Phase ownership:** Evidence charter and final readiness/claims audit.

## Moderate Pitfalls

### Pitfall 16: Exhaustive enumeration becomes an infinite quality backlog

**What goes wrong:** Every conceivable dimension produces speculative work, preventing closure and encouraging churn.

**Prevention:** Freeze a finite taxonomy and current-head census. Every candidate receives exactly one state—fix, retain, or evidence-gated defer—with owner, proof, and trigger. New findings enter only through reproducible evidence, not taste.

### Pitfall 17: Previously accepted architecture debt is reopened without a trigger

**What goes wrong:** The twelve-node facade/worker cycle and GCS/Mux configuration cycles consume the milestone despite v1.25 explicitly accepting them as cohesive or harm-gated.

**Prevention:** Retain the prior defer unless compile-time, defect, ownership, or change-cost evidence now crosses a recorded threshold. A changed visualization alone is not new evidence.

### Pitfall 18: Flake handling normalizes rerun-to-green

**What goes wrong:** Issue #42 remains open while successful retries are counted as clean evidence; retry wrappers obscure DB isolation defects.

**Prevention:** Record first-attempt results and seeds, run a bounded repeated/stress probe, classify infrastructure versus product failures, and make unexplained flake recurrence a blocker for the affected claim.

### Pitfall 19: Dependency triage is bundled into unrelated refactoring

**What goes wrong:** Six bot PRs change runtime and dev dependencies while craft changes alter the same signals, destroying attribution and making rollback difficult.

**Prevention:** Process dependency groups in isolated commits/PRs, regenerate the lock from a clean toolchain, run package/adopter/compatibility proof appropriate to each group, and avoid opportunistic majors.

### Pitfall 20: “Efficient CI” optimizes median while degrading detection latency

**What goes wrong:** PR latency improves but expensive failures are detected only after merge or on an unreliable Nightly schedule.

**Prevention:** Preserve the accepted <=8 minute median / <=10 minute p95 PR envelope and report time-to-detection by defect class. Any lane moved off PR must have an explicit push-main or scheduled owner, maximum detection delay, and release-blocking consequence.

### Pitfall 21: Quality tools become policy by accident

**What goes wrong:** Credo, coverage, Dialyzer, linters, or accessibility scanners dictate architecture despite false positives or incomplete models.

**Prevention:** Keep curated policies and executable behavior authoritative. Tool findings are candidates; accepted exceptions require narrow identities and present-tense rationales. Never bend runtime semantics solely to satisfy an analyzer.

### Pitfall 22: Evidence collectors are untested production code

**What goes wrong:** JSON receipts parse, but omit failed scenarios, misclassify skip states, or read stale artifacts.

**Prevention:** Give collectors schemas, unit tests, malformed/missing/stale fixtures, mutation tests, and SHA binding. Consumers must fail closed on unknown fields/statuses where trust depends on them.

## Minor Pitfalls

### Pitfall 23: Mojibake cleanup changes valid binary or fixture data

**What goes wrong:** Global text replacement corrupts cassettes, binary fixtures, encoded signatures, or deliberately malformed-input tests.

**Prevention:** Restrict encoding cleanup to reviewed text files, validate UTF-8, and rerun fixture/signature/contract tests. Classify intentional malformed bytes as retained test data.

### Pitfall 24: Ignore rules hide developer-only debugging artifacts too broadly

**What goes wrong:** Patterns such as `*.json`, `test-results/`, or `.tmp/` hide checked-in receipts or drift evidence in nested locations.

**Prevention:** Anchor ignore patterns to exact owners, include negations for committed evidence, and test representative paths with `git check-ignore -v`.

### Pitfall 25: Readability review rewards terseness

**What goes wrong:** Explicit domain names and guard clauses are compressed into pipelines or metaprogramming that are shorter but harder to debug.

**Prevention:** Review for local reasoning, failure visibility, ownership, and unsurprising Elixir—not line count. Prefer explicit state transitions at storage, job, and migration boundaries.

### Pitfall 26: Screenshot and accessibility polish substitutes for lifecycle correctness

**What goes wrong:** Cohort appears polished while retry, interruption, cleanup, or provider paths remain synthetic or skipped.

**Prevention:** Keep visual/accessibility receipts as a distinct quality dimension. They cannot satisfy lifecycle or provider requirements.

## Hard Blockers Versus Explicit Retain/Defer Decisions

| Finding | Disposition for v1.26 | Blocking condition |
|---------|------------------------|--------------------|
| Recurring current-main Nightly Dialyzer failure | **FIX — hard blocker** | Milestone/release readiness cannot close until a current-main scheduled-equivalent Dialyzer run is green with suppression identity intact. |
| Public API, schema/migration, telemetry, or error drift from cleanup | **PREVENT — hard blocker** | Any unexplained preservation-contract delta blocks the owning slice. |
| CI aggregate/release exact-SHA topology drift | **PREVENT — hard blocker** | Any event model that permits false green, pending forever, or canceled/incomplete `push:main` proof blocks merge. |
| Twin failure state created by direct target-state seeding or inline-only execution | **REJECT — hard blocker for lifecycle claims** | Scenario may remain unit/UI evidence but cannot satisfy the digital-twin requirement. |
| Twin/provider receipt says pass when steps skipped or secrets absent | **REJECT — hard blocker for that claim** | Must report `not_run`; deterministic non-live gates may still pass independently. |
| Residual namespaced remote/local resources after twin execution | **FIX — hard blocker** | Cleanup receipt must show zero residue or an explicit externally owned exemption. |
| Synthetic twin counted as independent adopter | **REJECT — hard blocker** | Independent pilot stays open regardless of twin breadth. |
| Historical `.planning/` records | **RETAIN by default** | Delete only with provenance/consumer proof and planning-contract validation; aesthetic dislike is insufficient. |
| Checked-in generated assets | **RETAIN or regenerate-by-contract** | Delete only if all consumers migrate and clean regeneration/package proof passes. |
| v1.25 twelve-node runtime cycle | **DEFER** | Reopen only on measured compile/change/defect harm. |
| v1.25 GCS/Mux configuration cycles | **DEFER** | Reopen only on measured ownership or correctness harm. |
| Live GCS/Mux evidence when credentials are unavailable | **EXPLICIT NOT-RUN** | Does not block deterministic twin proof, but blocks any live-provider claim. |
| Open issue/PR without evidence for mutation | **RETAIN/DEFER** | Inbox zero is not acceptance; explicit disposition is sufficient until evidence authorizes mutation. |

## Phase-Specific Warnings

| Likely phase | Likely pitfall | Required automated mitigation |
|--------------|----------------|-------------------------------|
| 1. Evidence charter and current-head census | Infinite scope; stale/self-referential metrics; synthetic-adopter claim inflation | Finite dimension taxonomy; immutable SHA/tool/config baseline; fix/retain/defer ledger; proof-level schema; mutation-tested collectors. |
| 2. Live truth and remote inbox | Dialyzer green-by-ignore; rerun-to-green; unsafe issue/PR mutation | Exact failure fingerprint; cold/warm PLT; suppression identity ratchet; scheduled recovery receipt; read-only inbox snapshot and per-item disposition before mutations. |
| 3. Repository and code craft | Aesthetic churn; comment-density harm; deleting provenance/generated inputs; contract drift | Candidate triggers, diff boundaries, deletion provenance, regeneration drift, package contents, SAFE/refactor/public contract suite. |
| 4. Static analysis and test value | Coverage theater; brittle private tests; accepted cycles reopened | Frozen denominator/config, branch/error targets, suppression identity, behavioral witnesses, defer triggers honored. |
| 5. CI/CD truth and boundedness | Skip-as-green; release decoupling; mutable inputs; missing timeouts | Multi-event workflow model, branch-protection parity, exact-SHA push-main release gate, input inventory, checksum/digest verification, evidence-based deadlines. |
| 6. Twin substrate | Private implementation coupling; direct state mutation; inline Oban; missing namespace/cleanup | Built-package consumption, public-boundary denylist, database-backed supervised queues, fault adapters, append-only resource ledger, idempotent janitor. |
| 7. Failure/recovery scenarios | Happy-path demo expansion; swallowed drain errors; no restart; contaminated retries | Executed failure transitions, attempt/error/telemetry receipts, process restart where claimed, first-attempt reporting, zero-residue postconditions. |
| 8. Live companions and closure | Secrets skipped as pass; flaky APIs; dirty shared checkout; false first adopter | `not_run` taxonomy, separate live receipts, clean isolated checkout, post-run porcelain/ignored inventory, release-train and claims policy gates. |

## Sources

### Repository evidence (HIGH confidence)

- `.planning/PROJECT.md` — v1.26 goal, boundaries, starting signals, and explicit synthetic-adopter limitation.
- `.planning/RELEASE-TRAIN.md` — exact-ref release coupling, `CI Summary` branch protection, full `push:main` proof, demand-gated posture, and release-readiness rules.
- `.planning/milestones/v1.25-MILESTONE-AUDIT.md` — accepted 31-finding complexity baseline, 82.1343% coverage, PR timing receipt, and explicit architecture deferrals.
- `.github/workflows/ci.yml` — PR/push topology, skip semantics, release-coupled full lanes, action pins, and limited explicit timeouts.
- `.github/workflows/nightly.yml` — gating Dialyzer, secret-gated GCS proofs, cleanup, summary, and issue automation.
- `scripts/maintainer/repo_hygiene_check.sh` — CI/local check split, clean-worktree behavior, remote fetch/status warning behavior, and release truth checks.
- `.dialyzer_ignore.exs` — exact suppressions, historical run references, and rationale-bearing accepted debt.
- `examples/adoption_demo/docs/adoption-proof-matrix.md` — package/canonical/Cohort layering and fake/cassette/live distinctions.
- `examples/adoption_demo/config/test.exs`, `examples/adoption_demo/lib/adoption_demo/media.ex`, `examples/adoption_demo/lib/adoption_demo/seed_support.ex`, and `examples/adoption_demo/lib/adoption_demo_web/live/upload_live.ex` — inline Oban configuration and direct queue-drain behavior.
- GitHub remote snapshot on 2026-09-09 — open issues #42 and #88 plus six open Dependabot PRs; used only as read-only research evidence.

### External primary documentation (MEDIUM confidence through web-search fallback)

- [GitHub Actions workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) — dependency skip propagation, `always()`, permissions, concurrency, and default/max job timeouts.
- [Oban: Introduction to Testing](https://hexdocs.pm/oban/testing.html) — inline versus manual testing semantics and suitability limits.
- [Oban: Testing Workers](https://oban.hexdocs.pm/testing_workers.html) — worker-unit-test boundary and `perform_job/3` purpose.
- [Git: gitignore documentation](https://git-scm.com/docs/gitignore) — ignore rules apply to intentionally untracked files and do not affect tracked files.
- [Git: git-status documentation](https://git-scm.com/docs/git-status) — index, worktree, and untracked state represented by status.

## Research Gaps

- The exact current Nightly Dialyzer warning text and root cause must be captured from the immutable failed run during the live-truth phase; the five-run recurrence is a starting signal, not a diagnosis.
- Which of the six dependency PRs can be safely grouped requires per-PR lock diff and supported-toolchain/package proof; remote status alone is insufficient.
- The minimum production-faithful Oban topology for Cohort must be designed against Rindle's current Oban version and queue ownership during phase research. The requirement is clear—database-backed executed transitions—but process supervision and fault-injection seams remain implementation decisions.
- Live GCS/Mux cleanup guarantees depend on current provider APIs, quotas, and secret availability; deterministic local proof should not wait on those external conditions.
