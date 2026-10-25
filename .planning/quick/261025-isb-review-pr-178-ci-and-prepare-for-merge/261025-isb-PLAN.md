---
quick_id: 261025-isb
mode: quick-validate-inline
status: planned
must_haves:
  - Review the actual PR diff and all GitHub feedback on its exact source head
  - Fix concrete CI or review findings without weakening security or readiness gates
  - Require green exact-head CI and no unresolved review threads before removing draft status
  - Keep overall readiness requirements open and leave merge to the maintainer
---

Review PR #178 in the existing clean /private/tmp/rindle-readiness-hex26-20261025 checkout on fix/readiness-hex-26-cache. Execute inline without agents, new branches or worktrees.

<task id="1">
<files>scripts/maintainer/readiness_hex_audit.exs; scripts/maintainer/collect_readiness_remote.py; scripts/maintainer/validate_exact_head_readiness.exs; scripts/ci/prepare_readiness_fixture_runtime.sh; scripts/ci/test_readiness_hex_audit.exs; scripts/ci/test_exact_head_readiness.sh; scripts/ci/test_readiness_remote.sh</files>
<action>Inspect the branch diff and surrounding source, cache API dispatch, tests, input identity and all retained security invariants. Read live PR reviews, inline threads and CI job outcomes. Record concrete findings only.</action>
<verify><automated>gh pr checks 178 --repo szTheory/rindle --required</automated></verify>
<done>Review is bound to the actual PR source head and no feedback is omitted.</done>
</task>

<task id="2">
<files>Only reviewed source/test files if a concrete defect is found; otherwise no code change</files>
<action>Apply any necessary narrowly scoped fixes, regression-test them, and commit atomically. With no findings, retain the already green source unchanged. Preserve explicit Hex version allowlist, verified native/ETS readers, fresh isolated caches, signed registry/TLS, complete lock coverage, no ignored findings, and no READY credit.</action>
<verify><automated>bash scripts/ci/test_exact_head_readiness.sh</automated></verify>
<done>No concrete finding remains; required verification passes for any modified code.</done>
</task>

<task id="3">
<files>.planning/quick/261025-isb-review-pr-178-ci-and-prepare-for-merge/; .planning/STATE.md; PR #178 draft state</files>
<action>Commit review/verification records and quick-task state, push to the same branch, then verify CI on the exact final PR head and the absence of unresolved threads. Mark the PR ready for review only after its merge-blocking checks pass. Do not merge or grant project readiness credit.</action>
<verify><automated>bash scripts/maintainer/automation_first_contract.sh</automated></verify>
<done>Clean pushed branch, reviewed PR ready for review with exact-head green required checks; final status reported.</done>
</task>

Inline plan check, iteration 1: bounded three-task scope; executable acceptance; all links resolve; conditional fix task avoids speculative work. PR source c02d992f is already green on CI run 40210585213; recording this task creates a new head whose CI must also pass before ready-for-review.
