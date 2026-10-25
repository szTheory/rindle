---
quick_id: 261025-grp
mode: quick-validate-inline
status: planned
must_haves:
  - Hex 2.5.1 verified ETS and Hex 2.6.0 CRC cache snapshots preserve normalized identity
  - Missing or corrupt caches and unsupported versions fail closed
  - Collector and immutable validator accept only reviewed versions with all security gates intact
  - Actual signed root/demo audit and complete read-only remote collector are exercised without readiness credit
---

Fix readiness Hex 2.6 cache compatibility on a clean branch from origin/main 8651494743baea30732c40c5d1b6ca92991ce08e.
The user's primary checkout remains untouched. Planning, plan checking, execution, and verification run inline as explicitly requested.

<task id="1">
<files>scripts/maintainer/readiness_hex_audit.exs; scripts/ci/test_readiness_hex_audit.exs; scripts/ci/test_exact_head_readiness.sh; scripts/ci/test_readiness_remote.sh</files>
<action>Add deterministic regressions at the persisted cache snapshot seam using real Hex readers, old/new valid formats, timestamp normalization, corruption/missing caches and unsupported versions. Add collector/validator version and security regressions.</action>
<verify><automated>bash scripts/ci/test_readiness_fixtures.sh</automated></verify>
<done>New regressions fail against baseline for the reported compatibility defect; runtime stays Elixir 1.17.3 / OTP 27.</done>
</task>

<task id="2">
<files>scripts/maintainer/readiness_hex_audit.exs; scripts/maintainer/collect_readiness_remote.py; scripts/maintainer/validate_exact_head_readiness.exs; .planning/PROJECT.md</files>
<action>Use explicit 2.5.1/2.6.0 version dispatch, verified ETS/native CRC reader and the same sorted timestamp-free key/value hash projection with guaranteed table cleanup. Keep byte-bound helper identity, fresh empty isolated HEX_HOME, signed online registry/TLS, full lock/checksum coverage, no ignored findings and no retirement credit. Document bounded support truth.</action>
<verify><automated>bash scripts/ci/test_readiness_fixtures.sh</automated></verify>
<done>All relevant fixtures pass; no lock, workflow, credential or gate weakening.</done>
</task>

<task id="3">
<files>.planning/quick/261025-grp-fix-readiness-hex-2-6-cache-compatibilit/; .planning/STATE.md</files>
<action>Run actual signed root/demo audits and complete read-only collector on current main with modified helper; keep raw outputs in restricted external directories. Record truthful blocked remote verdicts without READY credit. Commit code atomically, update quick state through GSD tooling, and prepare separate PR to main.</action>
<verify><automated>bash scripts/maintainer/automation_first_contract.sh</automated></verify>
<done>Executable evidence and limitations recorded, clean PR branch with no unrelated changes, PR URL provided.</done>
</task>

Plan check: one bounded compatibility repair; executable acceptance for each task; reviewed Hex sources:
https://github.com/hexpm/hex/blob/v2.5.1/lib/hex/registry/server.ex
https://github.com/hexpm/hex/blob/v2.6.0/lib/hex/registry/server.ex
Snapshot reading uses the explicitly reviewed Hex API, never a new arbitrary term decoder.
