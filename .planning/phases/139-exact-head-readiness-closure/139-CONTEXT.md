# Phase 139: Exact-Head Readiness Closure - Context

> **Prerequisite reconciliation (2026-10-22):** This discussion records the original
> decisions. In the authoritative `gsd/phase-136-execution` worktree, Phases 133–138
> now have passed verification and retained executable evidence. The Phase 139
> preflight confirms the immediate Phase 138 digest and matrix. PROJECT.md and
> STATE.md assign the versioned-host Doctor correction to Phase 139. The D-16
> numeric timing amendment below reflects the intervening explicit user decision.

**Gathered:** 2026-10-22 (assumptions mode; delegated research and decide-by-default synthesis)
**Status:** Reconciled for execution planning after passed Phase 138

<domain>
## Phase Boundary

Produce one authoritative, fail-closed readiness verdict for the current immutable `main` revision,
joining the completed evidence from Phases 133–138 with clean-checkout qualification and current
remote truth. Cover READY-01 through READY-05 while correcting public Doctor's supported
host-owned versioned migration-ledger diagnosis, without promoting the
maintainer-operated synthetic twin to independent adoption evidence.

This discussion grants no requirement credit, execution authority, remote mutation, publication, or
release approval. The original discussion preceded the completed Phase 133–138 execution chain.
Phase 139 execution must first verify Phase 138 and the upstream requirement/evidence chain through
executable validators, rather than trusting a planning status or checkbox alone.
</domain>

<decisions>
## Implementation Decisions

### Revision and verdict authority
- **D-01 (amended 2026-10-25):** Qualify an explicit immutable previously-main SHA
  containing the intended implementation and versioned snapshot policy after protected PR
  delivery. Require actual push-main provenance, current protected-main ancestry and matching
  executing controller/policy bytes. An arbitrary PR/fork commit is ineligible.
- **D-02 (amended 2026-10-25):** Keep the accepted candidate fixed while main advances.
  Record authenticated main observations separately; every local proof, CI/Nightly run,
  producer digest and artifact byte remains candidate-bound. Refresh mutable current
  security, inbox ledger, effective protection and adoption/release authority. Missing or
  changed facts fail closed. A different candidate requires a new immutable attempt.
  Snapshot verdicts are historical only and never assert current-head readiness.
- **D-03:** Store the terminal manifest and its receipts outside the tested source tree. Do not commit
  a manifest into the revision it claims to certify, hash the manifest into itself, or silently exempt
  closure/checkmark commits from exact-head binding. Later archival pointers must explicitly describe
  the earlier subject; they do not certify their own commit.
- **D-04:** Distinguish `ready` from `not_ready`, with machine-readable reasons for failed, unavailable,
  incomplete, stale, or changed evidence. Missing proof never means passing proof. Record the verdict's
  observation interval; it is not an indefinitely valid assertion about a moving branch or service.

### Qualification and evidence contract
- **D-05:** Use a fresh isolated checkout of the subject, with exact resolved supported toolchains and
  detector/configuration inputs. Derive supported pairs and gate ownership from the committed policy;
  do not widen support or allow a newer local toolchain to substitute. Separate incompatible build
  outputs by toolchain. Verify initial cleanliness and final state after owned cleanup.
- **D-06:** Enumerate the required evidence set explicitly: formatting, compilation, reviewed Credo,
  supported Dialyzer including applicable fresh/restored-PLT proof, Doctor, exact accepted coverage
  floor, security, documentation/contracts, built package, generated consumer, twin/recovery matrix,
  release/adoption truth, and strict repository hygiene. Every required gate has actual execution
  evidence, source/tool/input identity, command outcome, and a verifiable receipt. Neither declared
  commands nor a green aggregate alone establish this set.
- **D-07:** Reuse upstream schemas, collectors, and pure validators where their contracts fit, and
  requalify on the closing subject. A receipt from an earlier SHA cannot become exact-head proof by
  relabeling it. Static proof can be reused for identical subject, toolchain, inputs, and proof policy;
  mutable remote facts must be reobserved at closure.
- **D-08:** Bind built-package, generated-consumer, and twin evidence to the actual tested artifact
  bytes and unpacked payload using explicitly named digest kinds. Preserve no-checkout-fallback and
  no-prebuilt-BEAM guarantees. A metadata-file digest is not an archive digest; normalize the existing
  helper's ambiguous `package_sha256` field at the evidence boundary rather than overstating it.
- **D-09:** Give the manifest a versioned schema, finite required proof IDs, receipt paths and byte
  digests, subject/repository identity, package identity, tool/input identity, applicability decisions,
  outcomes, cleanup/residue results, and adoption-proof class. Reject duplicate IDs, missing required
  entries, malformed or unknown trust-bearing states, digest mismatch, wrong subject/package,
  incomplete attempts, and explanations that do not satisfy an executable policy.
- **D-10:** Persist failed outcomes for diagnosis. A crash before terminal finalization, command failure,
  timeout, or cleanup failure cannot leave a passing manifest. Inventory tracked, untracked, ignored,
  generated, database, job, object, provider, multipart, and temporary-resource residue as applicable.
  Require observed cleanup results and absence of unapproved residue, not just a cleanup call returning
  `:ok`. Explicitly inventoried tool caches/evidence outputs are distinguishable from unexplained junk;
  cleanup is confined to resources owned by this run.

### CI, Nightly, and protection
- **D-11:** Require the complete successful `ci.yml` / `CI` execution for `event=push`, branch `main`,
  and the exact subject, including applicable main-only jobs. Preserve `CI Summary` as the sole
  required PR context; its success alone cannot replace full main/release proof.
- **D-12 (amended 2026-10-27, explicit user approval):** Under `rindle-snapshot-v3`,
  require full exact-candidate Nightly qualification from the newest candidate
  schedule or workflow_dispatch execution, independently joined with newest real
  scheduled incident health at its actual SHA under matching reviewed controls.
  Manual qualification cannot impersonate schedule or recover/close an incident.
  The prior same-candidate scheduled-only clause remains historical v2 policy.
  Preserve EVID-04's real scheduled incident recovery semantics. A newer pending,
  failed or incompatible schedule cannot borrow an older green witness.
- **D-13:** Bind workflow identity, repository, event, branch, SHA, run ID, attempt, and complete expected
  job set. Discover runs without success-only filtering and select the newest eligible execution
  deterministically. A later failure, pending run, or changed attempt cannot be hidden behind an older
  green result. Require a complete successful selected attempt; do not silently splice partial reruns.
  Recheck attempt and terminal status after job collection.
- **D-14:** Keep applicability event-specific. PR's intentional skips do not define Nightly or readiness
  policy. Required work may not be skipped/neutral/cancelled-as-green. Optional live-provider work can
  be explicitly `not_run` only under the existing machine-checked applicability rule; it grants no live
  provider claim and cannot exempt required deterministic proof.
- **D-15:** Compare the committed topology with effective live protection: classic branch protection
  plus applicable active repository/organization rulesets. Normalize legacy and structured required
  checks, preserve app/integration bindings and enforcement/bypass facts, and reject incompatible
  drift. The effective required-context set stays exactly `CI Summary`, supplied by the intended
  workflow/provider. Informational diffs are not acceptance evidence; inaccessible protection is an
  evidence gap, not an empty set.
- **D-16:** Preserve `ci.yml`, workflow `CI`, exact-SHA release coupling, fork safety, and the accepted
  <=480-second median / <=600-second p95 PR envelope. Put cheap deterministic validator regressions
  in the existing script-test seam; run full closure and privileged read-only remote checks outside
  the PR critical path. Do not widen routine CI proof or add recurring cloud work without measured need.

  **Recorded amendment (2026-10-21 user decision):** `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`,
  `136-SPEED-DEFERRAL.json`, and `136-VERIFICATION.md` supersede D-16's numeric acceptance clause.
  The exact-ten median/p95 target is `deferred_unfinished` to SEED-261021-918 with zero acceptance
  credit and is not a Phase 139 READY gate. Preserve the original blocked qualification receipt;
  apply D-16's CI topology, exact-SHA, fork-safety, required-context, and green-CI clauses.

### Current remote and advisory truth
- **D-17:** Revalidate Phase 134's disposition ledger against a fresh complete read-only inventory;
  do not repeat all triage or require inbox zero. New items, changed decision inputs, expired exceptions,
  or undispositioned blockers yield `not_ready` with the owning phase/item and next action.
- **D-18:** Collect issues, distinct PRs and their exact heads/checks/statuses, relevant repository
  security advisories, Dependabot alerts, Hex audit findings/database identity, and protection as
  separate sources. Follow all pagination and reject truncation. Account for the issues endpoint
  containing PRs, check history versus default latest views, and separate legacy commit statuses.
  Revisit previously tracked items absent from the open inventory to establish their disposition.
- **D-19:** Record each source's query/API policy, coverage/visibility, observation interval, completion,
  and response identity. Authentication, authorization, private-resource 404, rate limiting, partial
  pagination, timeout, and malformed responses must remain distinct from a successfully observed empty
  inventory. An empty Dependabot inventory cannot replace Hex audit evidence or prove unpublished
  advisory visibility. Use authorized existing connectors/credentials; never copy tokens or broaden
  permissions automatically.
- **D-20:** Collect and revalidate remote state within the same bounded closure invocation. Compare
  complete normalized inventories and relevant mutable decision inputs; use conditional requests only
  with the exact retained representation and request context. Changed main, PR head/check attempt,
  advisory, exception, or protection invalidates affected proof. Do not invent a universal 24-hour TTL
  or treat `updated_at` as a version for every related resource. Record that GitHub provides no
  cross-endpoint atomic snapshot guarantee; a later consumer must refresh current facts again.
- **D-21:** Keep request retries and total collection time bounded and failures explicit. Preserve
  private security content in an appropriately restricted evidence location; public receipts retain
  redacted coverage, identity and disposition proof without publishing sensitive details. A redacted
  receipt must derive from actual collection, not human acceptance.

### Maintainer experience, retention, and claim boundaries
- **D-22:** Provide one documented maintainer entry point with collection, offline read-only validation,
  and bounded read-only remote refresh responsibilities. Use existing shell orchestration and Elixir
  scripts/Jason for pure policy where suitable. Keep this outside the shipped public API, runtime
  supervision, Ecto schema, Plug routes, and Admin UI. Prefer explicit options, stable proof IDs,
  concise failure reasons, nonzero failure exits, and the next existing repair command.
- **D-23:** Retain one portable redacted bundle using the existing pinned artifact mechanism, unique
  source/run/attempt identity, explicit retention, no overwrite, and error on missing files. Default
  closeout retention to 30 days subject to repository limits; keep a byte-verified local copy for
  longer historical inspection. A separate locator records artifact/run identity, subject, manifest
  digest, archive digest and expiry. Transport identifiers do not go back into the already uploaded
  manifest. Expired/deleted/inaccessible remote bytes cannot earn current acceptance from a URL alone.
- **D-24:** Verify bundle bytes directly and fail on digest mismatch; a download action warning is
  insufficient. Hashes establish byte identity, not signing, independent authenticity, or SLSA
  compliance. Do not add a signing/provenance service or generic per-attempt authorization protocol.
- **D-25:** Stamp twin evidence as maintainer-operated synthetic evidence. Executable release/adoption
  parity must leave PILOT-01 and PILOT-02 open and reject independent-adopter or 1.0 authority derived
  from synthetic receipts. Preserve Release Please ownership of version/release intent; readiness
  grants no publish, merge, issue mutation, protection mutation, or forced version bump.

### Agent's Discretion
- Exact filenames, internal helper boundaries, JSON representation, compact failure vocabulary, and
  sensible bounded deadlines measured during implementation.
- The narrow mechanism for retaining portable historical bytes and presenting their locator, within
  existing repository access and retention policy. A material recurring cost/security boundary change
  requires a scoped decision; otherwise reuse existing infrastructure.
- No routine maintainer choices remain unresolved. Reinspect upstream implementations at planning
  time against the authoritative execution worktree. Phases 134–138 are complete here; use their
  tracked artifact paths and requalify subject-dependent proof on the closing revision.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 139 boundary and dependency order.
- `.planning/REQUIREMENTS.md` — READY-01–05, upstream acceptance, PILOT-01/02.
- `.planning/PROJECT.md` — scope, decide-by-default contract, immutable support/release boundaries.
- `.planning/STATE.md` — actual active executor and pending prerequisites; this context does not advance it.
- `.planning/METHODOLOGY.md` — repo-truth, adopter-first, automation-first, diminishing-returns lenses.
- `.planning/DEVELOPMENT-TRAIN.md` and `.planning/RELEASE-TRAIN.md` — PR and release contracts.
- `.planning/phases/133-evidence-charter-and-live-truth/133-CONTEXT.md` — census, scheduled incident,
  applicability, and adoption-truth decisions.
- `.planning/research/ARCHITECTURE.md`, `.planning/research/PITFALLS.md`,
  `.planning/research/SUMMARY.md`, `.planning/research/STACK.md` — existing evidence-plane design and limits.
- `prompts/gsd-rindle-research-index.md`, `prompts/gsd-rindle-elixir-oss-dna.md`,
  `prompts/rindle-milestone-roadmap-posture.txt` — relevant prior-art framing below live repository truth.
- `RUNNING.md` and `guides/release_publish.md` — gate/toolchain ownership and release prep commands.
- `config/ci_required_checks.json`, `.github/workflows/ci.yml`, `.github/workflows/nightly.yml`,
  `.github/workflows/release.yml` — exact committed topology, event semantics, release coupling.
- `scripts/ci/eval_ci_summary.sh`, `scripts/ci/eval_nightly_summary.sh`,
  `scripts/ci/verify_nightly_run.sh`, `scripts/ci/check_required_checks.sh` — existing verdict and collector seams.
- `scripts/maintainer/evidence_census.exs`, `scripts/maintainer/validate_evidence_census.exs`,
  `scripts/maintainer/validate_live_truth.exs`, `scripts/maintainer/repo_hygiene_check.sh`,
  `scripts/maintainer/automation_first_contract.sh` — validators and diagnostic/acceptance distinctions.
- `test/install_smoke/support/generated_app_helper.ex`,
  `test/install_smoke/support/generated_app/workspace.ex`,
  `test/install_smoke/generated_app_smoke_test.exs` — package identity, cleanup, no-source-fallback proof.
- [GitHub workflow events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule),
  [workflow runs](https://docs.github.com/en/rest/actions/workflow-runs),
  [attempt jobs](https://docs.github.com/en/rest/actions/workflow-jobs#list-jobs-for-a-workflow-run-attempt)
  — event/SHA and complete attempt semantics.
- [GitHub branch protection](https://docs.github.com/en/rest/branches/branch-protection#get-status-checks-protection),
  [effective branch rules](https://docs.github.com/en/rest/repos/rules#get-rules-for-a-branch),
  [pagination](https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api),
  [conditional requests](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api#use-conditional-requests)
  — protection coverage and mutable remote acquisition.
- [GitHub repository advisories](https://docs.github.com/en/rest/security-advisories/repository-advisories#list-repository-security-advisories),
  [Dependabot alerts](https://docs.github.com/en/rest/dependabot/alerts#list-dependabot-alerts-for-a-repository),
  [supported dependency ecosystems](https://docs.github.com/en/code-security/reference/supply-chain-security/dependency-graph-supported-package-ecosystems)
  — distinct security sources and visibility limits.
- [Artifact action contract](https://github.com/actions/upload-artifact/tree/v4),
  [artifact API](https://docs.github.com/en/rest/actions/artifacts),
  [artifact digest validation](https://docs.github.com/en/actions/tutorials/store-and-share-data#validating-artifacts),
  [Mix.Task](https://hexdocs.pm/mix/Mix.Task.html) — bounded retention, strict byte verification, tooling limits.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Census/validator scripts already use versioned receipts, subject/input identity, and pure policy.
- Nightly's strict evaluator, run verifier, and scheduled incident artifacts supply event-aware proof.
- Generated-app proof exercises the unpacked package; preserve its supported consumer boundary.
- Existing script tests and parity tests provide cheap negative-fixture integration points.

### Established Patterns
- `repo_hygiene_check.sh` currently tolerates fetch failure, can exit zero with warnings, looks up latest
  branch CI without a SHA, and omits worktree inspection in `--ci` mode. Its exit code alone is insufficient.
- `check_required_checks.sh` intentionally treats its diff as informational and reads legacy contexts;
  final acceptance must include structured checks and effective active rulesets.
- Generated-app `package_sha256` currently hashes `hex_metadata.config`; `unpacked_tree_sha256` is a
  distinct payload identity. Workspace cleanup currently discards the `File.rm_rf` result.
- These are observed integration hazards, not instructions for broad rewrites. First use the strict
  replacements/repairs delivered by earlier phases; fill only remaining closure-specific gaps.

### Integration Points
- Phase 134 dispositions feed the fresh remote verifier; Phase 136 ratchets feed the declared gate set.
- Phases 137/138 package/twin receipts feed the manifest only after exact-subject, package, scenario,
  terminal-state, cleanup and residue validation.
- Live CI/Nightly/protection, remote inbox/security, local qualification and adoption parity converge
  in one terminal verdict; individual green subreports cannot independently close the phase.
</code_context>

<specifics>
## Specific Ideas

- Primary job: a release maintainer obtains an inspectable answer for a named revision before closing
  v1.26. Contributors need the failing proof and reproducible repair command; security reviewers need
  complete source coverage without disclosure; adopters need honest package and support claims.
- Keep explanations calm and explicit. CLI output carries state in text, not color alone; JSON and
  concise stderr diagnostics serve automation and humans. No visual redesign is needed for this phase.
- Borrow the useful provenance idea of explicit immutable subjects and digests, and Elixir's explicit
  boundary/pure-function style. Do not transplant another framework's runtime or general quality platform.
- Acceptance must include adversarial fixtures for wrong SHA/package/event/repository, missing or
  duplicate proof, forged success, partial pagination/attempts, unknown/skipped states, inaccessible or
  changing remote sources, protection drift, digest corruption, failed cleanup/residue, unfinished
  manifests, and synthetic-to-independent claim inflation. Real generated-consumer/twin execution
  complements these policy regressions; human approval never supplies acceptance evidence.
</specifics>

<deferred>
## Deferred Ideas

- Initial remote triage/security resolution, repository cleanup, quality ratchets, twin infrastructure,
  and recovery scenarios remain owned by earlier phases; do not duplicate them under closure.
- Independent Phoenix pilot/1.0, new providers, public API/schema changes, Admin UI, broad onboarding
  redesign, signing services, permanent webhook mirrors, and a general evidence platform are outside scope.
- Return to the demand-gated sustaining posture after v1.26; this discussion creates no next milestone.
- The later Doctor migration-ledger todo was assigned to Phase 139 by PROJECT.md and STATE.md;
  it is planned in 139-00 and is outside the earlier deferred recovery-matrix scope.
</deferred>

## Versioned snapshot implementation amendment — 2026-10-25

User invoked `$gsd-quick --full` for the referenced snapshot design and selected All clear.
The explicit `--snapshot --subject FULL_SHA` path uses `rindle-snapshot-v2`; the legacy
current-main path remains distinct. D-20 producer run identity now records producer main
SHA separately from the admitted evidence subject. Admission executes trusted main code
before candidate checkout, retains candidate-specific non-cancelling concurrency and
verifies both identities at retrieval. All D-03/D-04/D-11–14/D-16/D-17/D-23–25 byte,
event, freshness, disposal, retention and synthetic-only boundaries remain required.
No live acceptance, credentials, merge or publication is authorized by fixture success.

## Readiness liveness implementation amendment — 2026-10-27

The user accepted the three-claim recommendation and authorized implementation
and live validation inline within 139-07. Supersede D-02's universal candidate-bound
Nightly wording only for the independent scheduled-health proof: that receipt keeps
its actual execution SHA; every candidate qualification/artifact remains exact-source.
Keep current-main legacy mode distinct. New collector/controller bytes require a new
protected green-main source; no old receipt or READY status is rewritten.

Reuse unchanged Nightly workflow bytes. Bind candidate qualification to complete
matrix/jobs and authenticated required step outcomes, exact strict Summary evaluator
and enforcement, and actual optional live/skip branches. Initially accept only full
attempt 1 for v3 Nightly; reject partial reruns. Select the newest candidate execution
across both allowed events without success filtering. Only explicit `capture-nightly`
may dispatch; status and collectors stay read-only. Capture uses the API-returned run
ID, authenticates actual main/ref/source/workflow, bounds proven capture races to
three attempts, and never retries an ambiguous POST. Preserve owned run evidence.

Scheduled health selects newest global main schedule before success/control filtering.
Authenticate actual event, full topology, strict-verdict ZIP, checkpoint ZIP and chain,
complete incident history and matching whole-workflow/transitive control bytes.
Unresolved incident or checkpoint/history mismatch blocks; do not mutate an incident
to satisfy readiness. Require a matching daily occurrence by slot 07:27 UTC +60m;
require completion by run creation +120m including all job queues. A newer pending
run is Unknown immediately; deadline expiry is a specific failure, never a pass.
Artifact evidence needs at least one hour of remaining retention at observation.

Keep existing same-source/input/policy proof reuse and fresh mutable refresh. The
retained-intent rebase rule is a separate optional follow-up, outside this amendment's
acceptance. No new dependency, service, workflow, release trigger or credential grant.
PR189 stays held and READY-01–05 remain Pending until automated live terminal acceptance.

### Snapshot hygiene enablement

Native-gate review found the older qualifier still called current-tip release hygiene,
which would reject an admitted source after a necessary ledger-only main advance.
The v3 qualifier must use the explicit authenticated snapshot-source hygiene mode.
Preserve actual fetch and protected-main ancestry, exact local HEAD/control bytes,
cleanliness, generator/artifact checks, warning refusal and observed residue. Retain
that gate's actual source-admission JSON in the portable graph and validate its SHA,
repository, push provenance, controls and observation interval. Unknown/foreign/dirty
source refuses repository execution. Ordinary default/`--release-prep` keeps its strict
current-tip behavior; snapshot hygiene asserts no release or current-main eligibility.
Adding the hygiene controller to the mirrored control/input registry requires a new
admitted post-delivery source. Preserve the completed 61131fd2 diagnostic proofs; do
not relabel them. The independent operational Nightly control identity is unchanged.

### Actual producer boundary repairs (2026-10-27)

The first actual v3 terminal attempt on f2e9fbaf preserved `not_ready` with zero
credit: its owned producer run40447986047/1 reports evaluated run-name text in
the run API `name`, unlike the static workflow metadata name. Bind discovery and
retrieval to the authenticated active workflow ID/path, preserving exact owned
request title, repository, source, event, branch, attempt and artifact verification.
The producer then failed clean-checkout admission before native qualification.
Direct admission imports reproduce six untracked bytecode files with Linux cache
behavior; macOS redirects its default cache outside the checkout. Disable bytecode
in the public wrapper and existing retention job before imports, without adding
ignore rules or relaxing cleanliness. Only this environment setting changes the
existing retention workflow; production Nightly and permissions stay unchanged.
Controller identity changes require a new post-delivery source. Preserve the
failed terminal and run; never relabel its passing prerequisite diagnostics.

The first producer-repair CI passed readiness fixtures in237s but terminated the
subsequent independent11s baseline harness at the unchanged240s shared deadline.
Measured existing/incident groups finished218s/220s. Keep all commands and three
workers; move the baseline into existing contracts in its original declared order,
without extending timeouts or skipping tests. This is execution ordering only;
production Nightly, proof criteria and the shared deadline remain unchanged.

A second Linux run still exhausted240s in existing contracts while readiness232s
and incident236s passed; reordering alone did not provide enough shared CPU margin.
Confine one normal/dirty-CPU/dirty-I/O scheduler to the existing parser-only Mix
adapter and verify actual counts after preparation. Native qualification remains
four-scheduler. A complete direct-binary local grouped comparison passed at
107s/51s/118s versus126s/59s/129s; these are diagnostic observations, not deferred
CI target credit or proof of Linux headroom. Fresh full Linux CI is required.
The existing actual-validator fixture-worker pattern is a researched fallback if
reducing parser VM startup contention is insufficient; no new worker is introduced.

### Fine-grained Dependabot permission identity (2026-10-27)

Actual producer40462191283/1 reached fresh private-source validation, then refused
`dependabot_visibility_unproved` after the successful alert GET. The verifier used
the invented API key `dependabot_alerts`; GitHub documents `vulnerability_alerts`
for the display label Dependabot alerts. Correct only that key. Require actual
successful authorized GETs, complete pages and the documented read/write signal;
missing, unrelated or malformed permissions remain unproved, and401/403 remain
failures. No token, permission, exception, workflow or alert state changes. The
failed terminal and producer remain immutable with zero credit. This controller
change requires a new delivered/admitted source, rather than reinterpreting the
failed eb814ef8 attempt. Production Nightly controls remain unchanged.

The later metadata-only main run40461846541 again hit240s: incident239s passed,
existing/readiness groups were stopped. The single-scheduler configuration was
insufficient under runner variance. Reuse the already existing test-only validator
worker for the actual pure topology, Nightly-control, remote-validation and Hex
functions; patch only Runs/Remote fixture callers. Retain fresh subprocess CLI
integration, explicit success/rejection parity for all four operation families,
unknown-operation fail-closed/reap checks, complete API reads and all assertions.
One worker per suite stays in its enclosing group, with strict framing, the same
45s policy deadline and2MiB policy-output bound, cleanup and no automatic fallback.
Production collectors, credential scope, native gates, three groups and240s bound
remain unchanged. No persistent production service or dependency is introduced.


### 2026-10-27 actual scheduled collector repair

Actual schedule40468662976/1 oncc48fa21 passed compute, strict summary and verdict
publication, then lifecycle122073213512 failed `invalid artifact metadata`.
The failed inventory was not retained; current complete inventory validates.
Concurrent-upload pagination overlap is a hypothesis, not a proved root cause.
The user's instruction to unblock139-07 authorizes a narrow acquisition repair:
validate the entire artifact inventory before checkpoint reads, refetch invalid
metadata/duplicate IDs within the existing bounded coverage-read budget, emit
bounded numeric/field diagnostics, never silently deduplicate. Persistent bad
metadata and all semantic authentication failures remain fail-closed. This
supersedes the prior unchanged incident-collector bytes constraint only for this
repair; it does not change workflow cadence, permissions or readiness criteria.
A new source and authentic healthy schedule under the new matching control bytes
are required. PR189 stays held; no READY credit or native acceptance is inferred.
An extra real cron recovery window, if proposed separately, needs explicit
approval before merge because the earlier amendment preserved production cadence.
