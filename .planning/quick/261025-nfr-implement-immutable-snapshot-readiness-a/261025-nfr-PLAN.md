---
quick_id: 261025-nfr
mode: quick-full
execution: inline
files_modified: []
must_haves:
  truths:
    - "An explicitly selected protected-main snapshot can finish qualification and refresh while main advances; current-main readiness never transfers."
    - "Scheduled Nightly proof still binds to that candidate, latest attempts and full jobs; manual runs grant no scheduled credit."
    - "Fresh mutable-source authority and all immutable byte, artifact, cleanup and synthetic-adoption checks fail closed."
  artifacts:
    - scripts/maintainer/readiness_subject.py
    - scripts/ci/test_readiness_snapshot.sh
  key_links:
    - "Authenticated protected-main candidate -> qualification/collectors -> versioned immutable graph -> distinct producer SHA -> durable snapshot verdict"
---
<objective>Eliminate moving-main starvation through opt-in immutable snapshot acceptance without weakening scheduled-event or fresh-source evidence.</objective>
<tasks>
<task type="auto"><name>1: Candidate identity and versioned graph</name>
<files>scripts/maintainer/readiness_subject.py; scripts/maintainer/validate_exact_head_readiness.exs; scripts/maintainer/exact_head_readiness.py; scripts/ci/test_readiness_snapshot.sh</files>
<action>Add shared authenticated admission and explicit snapshot mode; version its graph policy; preserve legacy mode and receipts. Bind candidate provenance, executing control bytes and separately observed main identities; reject arbitrary PR/fork subjects.</action>
<verify><automated>bash scripts/ci/test_readiness_snapshot.sh</automated></verify>
<done>Executable identity and immutable-validator scenarios accept moving-main snapshots and reject substituted candidates or policy.</done></task>
<task type="auto"><name>2: Complete acceptance path and mutable authority</name>
<files>scripts/maintainer/readiness_acceptance.py; scripts/maintainer/readiness_closure.py; scripts/maintainer/collect_readiness_runs.py; scripts/maintainer/collect_readiness_remote.py; scripts/maintainer/readiness_adoption.py; scripts/maintainer/readiness_retention.py; .github/workflows/readiness-retention.yml</files>
<action>Carry candidate identity through every owner, including producer checkout admission and byte retrieval. Keep producer run SHA distinct. Refresh current authority inputs, complete private inventories, protection and adoption facts. Retain real scheduled proof on candidate and current attempts. Report only snapshot/historical readiness.</action>
<verify><automated>bash scripts/ci/test_readiness_fixtures.sh</automated></verify>
<done>All old rejection scenarios and new moving-main/authority/retention scenarios pass without gate or timeout changes.</done></task>
<task type="auto"><name>3: Contract, documentation and review</name>
<files>RUNNING.md; .planning/PROJECT.md; .planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md; .planning/phases/139-exact-head-readiness-closure/139-07-PLAN.md; .planning/phases/139-exact-head-readiness-closure/139-VALIDATION.md; .planning/STATE.md</files>
<action>Record deliberate snapshot policy amendment, candidate-scoped requirements and commands; preserve pending live acceptance and historical receipts. Update quick-task state, verify automation contract, review diff and commit only this task on its clean branch. No live acceptance, credential change, merge or publication.</action>
<verify><automated>bash scripts/maintainer/automation_first_contract.sh</automated></verify>
<done>Reviewable tested implementation with honest pending live readiness, fresh verification report and committed artifacts.</done></task>
</tasks>

<threat_model>
| Threat | Boundary | Mitigation | Automated evidence |
|---|---|---|---|
| Arbitrary PR/fork execution with read credentials | selected candidate -> producer | protected-main ancestry, actual push-main provenance, exact trusted control bytes before checkout | identity negatives and actual validator |
| Splicing producer/source SHA or attempt | Actions -> archive -> durable host | v2 sidecar binds both; exact repository/run/current attempt and transport digests | retrieval substitution and terminal join |
| Stale mutable security/authority | historical source -> current facts | complete live inventory/protection and byte-bound current ledger/adoption authorities; missing visibility fails closed | authority drift, current ledger and existing denial cases |
| False current-ready or pilot/release claim | terminal/metadata -> consumer | historical-only snapshot schema/status and no independent adoption/publication grant | full terminal and claim-status replay |
</threat_model>

Scope: existing GitHub GET transport plus candidate ancestry/branch reads only; no general
GitHub API integration, database schema, credential provisioning or watcher service.
The task adds no feature milestone or new dependency. All decisions follow the user's
referenced design and All clear response. Research/planning/review execute inline.
