# Development without recurring readiness holds

Decision: approved development and ordinary PRs continue under their existing gates.
Readiness acceptance retains a separate, explicit pending state. The current Phase 139
acceptance policy stays intact; immutable snapshot acceptance is the recommended next
architecture if certification must complete while main continues moving.

This note is for maintainers and agents choosing work during a readiness wait. It does
not grant READY, pilot, publication, credential or new feature-scope authority.

## Evidence and the defect

Three independent analyses covered development/product routing, controller/evidence
integrity, and CI/security/release engineering. A final pass checked their combined
recommendation against stale observations, existing job ownership and misleading claims.
No new dependency is needed.

The existing development contract allowed branch work while the readiness plan waited,
but older instructions also held draft PRs/main and PROJECT imposed chronological
milestone blocking. More concretely, the handoff guard returned `status: missing` and
`$gsd-execute-phase 139` with an instruction saying execution was safe, while STATE
explicitly prohibited acceptance until current-main CI, scheduled evidence and source
prerequisites passed. A missing report concealed a known prerequisite wait.

The fix represents that wait separately and reports scoped development availability.
It preserves external-job ownership and returns completed plans to GSD verification.
Recorded observations never become current eligibility; actual collectors still decide.

## Decisions and tradeoffs

| Decision | Adopted recommendation | Tradeoff / rejected alternative |
|----------|------------------------|----------------------------------|
| Development permission | Authorized branch work remains available; ordinary patch PRs follow existing checks | Keeping all PRs in draft imposes unnecessary calendar latency |
| New milestone scope | Demand, explicit scope and actual dependencies decide eligibility | Chronological overlap is not a dependency; availability does not approve speculative scope |
| Merge and publication | Preserve green-main PR and protected release gates | A readiness status flag cannot authorize either operation |
| Known acceptance wait | Explicit phase/plan record, evidence reference, owner, prerequisites and gated resume command | Generic missing-report guidance erases the real wait |
| Stale observations | Report subject/time and require fresh re-observation | A cron time or old green run cannot establish eligibility |
| Scheduled proof | Keep current D-12/EVID-04 event semantics | A manual run can diagnose the same code but does not prove scheduled incident behavior |
| Acceptance subject | Retain the current contract in this change | Deleting one `main_changed` check would leave inconsistent, insecure semantics |
| Durable architecture | Versioned immutable previously-main snapshot acceptance | Requires changes across controllers, validators, workflows and policy; not delivered by a routing fix |
| Dependencies | Reuse Python, JSON, gh and existing test owners | A watcher service or workflow framework adds maintenance and trust boundaries without fixing identity |

## Why the calendar is the wrong global lock

GitHub scheduled workflows use the latest default-branch commit; runs may be delayed or
dropped under load. A schedule is therefore an observation opportunity, not a precise
reservation for a selected candidate. Manual dispatch is a distinct event. GitHub also
documents that a `workflow_run` downstream workflow uses default-branch identity and can
receive privileged credentials even when the upstream workflow could not. Any future
automated handoff must authenticate the upstream run and bind its actual head SHA, event,
repository, conclusion, run ID and attempt. [GitHub event semantics](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows)

Concurrency controls may replace pending work. Interactive PR cancellation and durable
qualification therefore need different lifecycle policies; changing concurrency is not
part of this repair. [GitHub concurrency](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#concurrency)

Checkout can select an exact SHA, which is the appropriate source identity for a future
candidate. Privileged workflows must preserve trust boundaries around untrusted code and
artifacts. Keep the distinct Nightly workflow identity: this repository's CI completion
listeners participate in release automation. [Checkout](https://github.com/actions/checkout),
[GitHub secure use](https://docs.github.com/en/actions/reference/security/secure-use)

Rust's development, beta qualification and stable promotion demonstrate the relevant
separation: development can continue while an older snapshot is qualified. Rindle needs
the separation, not Rust's branch count or release cadence. This is an architectural
inference from that example. [Rust release trains](https://doc.rust-lang.org/stable/book/appendix-07-nightly-rust.html)

## Remaining constraint and bounded follow-up

Current139 acceptance can still chase main when merges continue. Do not describe the
routing repair as eliminating that problem. A short voluntary acceptance window remains
possible, but a project-wide freeze throughout the overnight wait is not the default.

An immutable snapshot policy should be implemented as one separately reviewed vertical
slice with this automated contract:

1. Select an immutable candidate authenticated as a previously protected-main commit
   containing the intended implementation and evidence policy. Reject arbitrary PR/fork
   subjects. Record the then-current main independently from the candidate.
2. Bind every immutable proof, package, tool/input identity, workflow run/current attempt,
   producer digest and retained artifact byte to that candidate. A candidate change starts
   a new attempt; it cannot splice receipts from another subject.
3. Refresh security, inbox, effective protection, release/adoption parity and other mutable
   facts close to verdict time. Missing authorization fails closed. Older source does not
   justify older security facts or incomplete inventories.
4. Preserve actual scheduled incident-health proof as its own predicate. If adding
   on-demand qualification, record its event provenance separately and amend the policy
   deliberately. Never relabel a manual run as scheduled.
5. Let main advance without cancelling candidate qualification. Return only qualified
   snapshot/historical readiness; current-main readiness remains a separate claim. Normal
   publication retains its exact-source, permission and protected-environment gates.
6. Test main advancement during collection and refresh; a failed latest attempt after an
   earlier success; wrong SHA/event/repository; skipped applicability; stale/private-source
   denial; artifact substitution; cleanup failure; and metadata-only follow-up. Preserve
   historical failures and all durable digest/refresh checks.

The enforcement surface includes `verify_subject`, producer selection and terminal
rechecks in readiness acceptance; local qualification; CI/Nightly and remote inventory
collectors; closure and refresh; immutable graph validation; retention workflow admission;
claim-status; Phase139 D-01/D-02/D-12/D-20, Plan07 and validation metadata. A versioned
policy/schema makes the changed meaning explicit. It must pass the existing acceptance,
runs, remote, closure, retention, qualifier and immutable-validator suites plus the new
moving-main scenarios before any live readiness claim uses it.

## Lessons carried forward

- Name the operation a gate blocks. A failed acceptance predicate does not freeze unrelated work.
- Distinguish development permission, merge eligibility, evidence acceptance and publication.
- Evidence belongs to an immutable subject and interval; mutable facts need fresh observation.
- Represent known waits in routing data instead of making agents rediscover them from prose.
- Treat status templates as templates, not invented task authorization or automatic execution.
- Keep historical instructions and failures; clearly supersede their current routing authority.
- Stop research when the options and adverse cases converge. More orchestration is not progress.

The reusable research instructions are in `prompts/decision-fanout-prompt.txt`. They require
relevant stakeholder perspectives, primary evidence, conflict resolution, a final adversarial
pass, small dependency surface and executable validation with a finite stopping condition.

## Approved implementation follow-up — 2026-10-25

The user invoked quick261025-nfr with --full and selected All clear. The separate
snapshot slice implements the six-point contract above as opt-in rindle-snapshot-v2.
Prior routing research is retained as history; its descriptions of a future policy
are superseded by the implementation and current RUNNING.md commands after merge.
This is no live acceptance claim: READY-01–05 remain pending until actual proof.
