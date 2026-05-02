---
phase: 16
slug: live-publish-execution-and-post-publish-verification
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-30
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> See `16-RESEARCH.md` `## Validation Architecture` for the full matrix and per-work-item strategy. This file is the executable contract derived from that matrix.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit 1.17 (existing) + bash for `scripts/hex_release_exists.sh` (driven via ExUnit `System.cmd`) |
| **Config file** | `mix.exs` (`:test_paths`), `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs test/install_smoke/hex_release_exists_test.exs` |
| **Full suite command** | `bash scripts/release_preflight.sh` |
| **Estimated runtime** | ~30 seconds quick; ~120 seconds full preflight |

---

## Sampling Rate

- **After every task commit:** Run quick command above (≤ 30s)
- **After every plan wave:** Run `bash scripts/release_preflight.sh`
- **Before `/gsd-verify-work`:** Full suite + post-merge `gh workflow run release.yml -f recovery_reason="phase 16 idempotency rehearsal" -f recovery_ref=<sha-of-0.1.4>` must show publish steps **skipped** and `public_verify` green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

> One row per planned task. `Test Type`: `unit` (ExUnit on a single module/script), `parity` (snippet assertion across `release.yml` ↔ `release_publish.md` ↔ scripts), `integration` (live `workflow_dispatch` against `recovery_ref`), `evidence` (signed tabletop transcript). `File Exists` ✅ if test infrastructure already exists; ❌ W0 if Wave 0 must create it.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 16-01-W0 | 01 (probe) | 0 | RELEASE-01 | — | Wave 0 — create probe-script unit harness | unit | `MIX_ENV=test mix test test/install_smoke/hex_release_exists_test.exs` | ❌ W0 | ⬜ pending |
| 16-01-01 | 01 (probe) | 1 | RELEASE-01 | — | Probe script returns `already_published=true` when `mix hex.info` exit 0 (D-09) | unit | `MIX_ENV=test mix test test/install_smoke/hex_release_exists_test.exs:test_published` | ❌ W0 | ⬜ pending |
| 16-01-02 | 01 (probe) | 1 | RELEASE-01 | — | Probe returns `already_published=false` when `mix hex.info` exit 1 + curl 404 | unit | `MIX_ENV=test mix test test/install_smoke/hex_release_exists_test.exs:test_missing` | ❌ W0 | ⬜ pending |
| 16-01-03 | 01 (probe) | 1 | RELEASE-01 | — | Defense-in-depth: `mix hex.info` exec error + curl 200 → `already_published=true` (D-09 fallback) | unit | `MIX_ENV=test mix test test/install_smoke/hex_release_exists_test.exs:test_fallback_only` | ❌ W0 | ⬜ pending |
| 16-01-04 | 01 (probe) | 1 | RELEASE-01 | — | Both probes inconclusive → exit non-zero with diagnostic on stderr (avoids false-negative re-trigger of run `25135467509`) | unit | `MIX_ENV=test mix test test/install_smoke/hex_release_exists_test.exs:test_inconclusive` | ❌ W0 | ⬜ pending |
| 16-01-05 | 01 (probe) | 1 | RELEASE-01 | — | Script honors `RINDLE_PROJECT_ROOT` (workspace convention) | unit | `MIX_ENV=test mix test test/install_smoke/hex_release_exists_test.exs:test_project_root` | ❌ W0 | ⬜ pending |
| 16-01-06 | 01 (probe) | 1 | RELEASE-01 | — | Script never calls auth-required Hex commands (Pitfall 3) | parity | `MIX_ENV=test mix test test/install_smoke/hex_release_exists_test.exs:test_no_auth_calls` | ❌ W0 | ⬜ pending |
| 16-01-07 | 01 (probe) | 1 | RELEASE-01 | — | `already_published=…` is the **last** stdout line; diagnostics on stderr (Pitfall 4: `$GITHUB_OUTPUT` corruption) | unit | included in test_published / test_missing | ❌ W0 | ⬜ pending |
| 16-02-01 | 02 (workflow gate) | 2 | RELEASE-01 | — | `release.yml` references `scripts/hex_release_exists.sh` and gates publish steps on `if: steps.idempotency.outputs.already_published != 'true'` (D-09, D-10) | parity | `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs:test_workflow_idempotency_gate` | ❌ W0 | ⬜ pending |
| 16-02-02 | 02 (workflow gate) | 2 | RELEASE-01 | — | `release.yml` includes `Idempotent publish summary` step writing to `$GITHUB_STEP_SUMMARY` (D-11) | parity | `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs:test_workflow_idempotent_summary` | ❌ W0 | ⬜ pending |
| 16-02-03 | 02 (workflow gate) | 2 | RELEASE-01 | — | Single global concurrency token `release-publish-rindle` (D-14); event-conditional split removed | parity | `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs:test_workflow_concurrency_token` | ❌ W0 | ⬜ pending |
| 16-02-04 | 02 (workflow gate) | 2 | RELEASE-01 | — | Version parsing uses `Mix.Project.config()[:version]`; `sed`-based parser removed (D-15) | parity | `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs:test_workflow_version_parse_canonical` | ❌ W0 | ⬜ pending |
| 16-02-05 | 02 (workflow gate) | 2 | RELEASE-01 | — | Step renames: `Live publish to Hex` → `Publish to Hex.pm (live)`; `Wait for Hex.pm index` → `Wait for Hex.pm index (post-publish)`; live publish step has `id: live_publish` (D-16) | parity | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs:test_step_names_renamed` | ✅ (update existing list) | ⬜ pending |
| 16-02-06 | 02 (workflow gate) | 2 | RELEASE-01 | — | `HEX_API_KEY` guard error message points to runbook + Settings path (D-17) | parity | `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs:test_workflow_hex_key_guard_message` | ❌ W0 | ⬜ pending |
| 16-02-07 | 02 (workflow gate) | 2 | RELEASE-01 | — | Top-of-file YAML comment block describing the four-job topology (D-16) | parity | `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs:test_workflow_topology_comment` | ❌ W0 | ⬜ pending |
| 16-03-01 | 03 (live rehearsal) | 3 | RELEASE-01 | — | Live `workflow_dispatch` against `recovery_ref=<sha-of-0.1.4>` shows publish steps **skipped**, `public_verify` green, summary shows skip message — proves run `25135467509` regression cannot recur | integration | `gh workflow run release.yml -f recovery_reason="phase 16 probe rehearsal" -f recovery_ref=<sha-of-0.1.4>` then `gh run watch` | n/a (manual) | ⬜ pending |
| 16-04-W0 | 04 (revert rehearsal) | 0 | RELEASE-02 | — | Wave 0 — produce `16-REVERT-REHEARSAL.md` skeleton with §0..§5 sections (D-18) | evidence | `test -f .planning/phases/16-.../16-REVERT-REHEARSAL.md && grep -c '^##' …` ≥ 6 | ❌ W0 | ⬜ pending |
| 16-04-01 | 04 (revert rehearsal) | 4 | RELEASE-02 | — | §1 Identity proof transcript: `mix hex.user whoami` + `mix hex.owner list rindle` + `mix hex.info rindle 0.1.4` outputs captured (D-19 read-only only) | evidence | `grep -E "mix hex.(user whoami\|owner list rindle\|info rindle 0.1.4)" 16-REVERT-REHEARSAL.md` | ❌ W0 | ⬜ pending |
| 16-04-02 | 04 (revert rehearsal) | 4 | RELEASE-02 | — | §2 Decision matrix: 4 rows (revert / retire / docs.publish / window-closed) with canonical commands per D-21..D-23 | evidence | reviewer signoff in §0 | ❌ W0 | ⬜ pending |
| 16-04-03 | 04 (revert rehearsal) | 4 | RELEASE-02 | — | §3 Command canonicalization: `mix hex.publish --revert VERSION` documented as canonical; `mix hex.revert rindle VERSION` documented as wrong-command-from-old-runbook (D-20) | evidence | `grep "mix hex.publish --revert" 16-REVERT-REHEARSAL.md` and `grep "mix hex.revert rindle" 16-REVERT-REHEARSAL.md` (latter as anti-pattern only) | ❌ W0 | ⬜ pending |
| 16-04-04 | 04 (revert rehearsal) | 4 | RELEASE-02 | — | §4 Adopter advisory template (D-24) + commit-message convention + GitHub Release title format inline | evidence | `grep "Adopter advisory" 16-REVERT-REHEARSAL.md && grep "fix(release): retire" 16-REVERT-REHEARSAL.md` | ❌ W0 | ⬜ pending |
| 16-04-05 | 04 (revert rehearsal) | 4 | RELEASE-02 | — | §5 Runbook cross-reference signoff: confirms `release_publish.md` "Rollback and Revert" section matches the canonical commands and 4-row decision matrix; signed with maintainer + date | evidence | reviewer signoff line in §5 | ❌ W0 | ⬜ pending |
| 16-05-01 | 05 (runbook) | 5 | RELEASE-01 | — | TL;DR cheatsheet ≤ 5 lines at top of `release_publish.md` (D-02) | parity | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs:test_release_guide_tl_dr` | ❌ W0 | ⬜ pending |
| 16-05-02 | 05 (runbook) | 5 | RELEASE-01 | — | Footguns section enumerates 12 categories (D-03): version immutability, last-version revert, owner-add post-publish-only, 8MB/64MB limits, git deps blocked, conventional commits, autorelease-pending label, manual-tag conflicts, `--warnings-as-errors`, owner key vs API key, component-vs-simple tag, trusted-vs-local | parity | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs:test_release_guide_footguns_inventory` | ❌ W0 | ⬜ pending |
| 16-05-03 | 05 (runbook) | 5 | RELEASE-01 | — | Appendix A Deviation Log: contains 5 historical SHAs (`a7efefd`, `d5c21ad`, `65728e5`, `71a0f99`, `6dd0d54`) + new (b)-merge SHA (D-05 newest-first append-only) | parity | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs:test_release_guide_appendix_a` | ❌ W0 | ⬜ pending |
| 16-05-04 | 05 (runbook) | 5 | RELEASE-01 | — | Appendix B Architecture Note: `current tooling, frozen source` + `git worktree` + `recovery_ref` + `main HEAD` substrings | parity | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs:test_release_guide_appendix_b` | ❌ W0 | ⬜ pending |
| 16-05-05 | 05 (runbook) | 5 | RELEASE-01 | — | Voice rewrite (D-04): hedge phrases removed (`refute "you should consider"`, `refute "the maintainer can"`); imperative-mood markers present | parity | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs:test_release_guide_voice` | ❌ W0 | ⬜ pending |
| 16-05-06 | 05 (runbook) | 5 | RELEASE-02 | — | Rollback rewrite includes: `mix hex.publish --revert VERSION` (canonical) + retire reasons (`renamed`, `deprecated`, `security`, `invalid`, `other`) + `mix hex.docs publish` + `lockfiles still install` retire caveat + 1h/24h window semantics; **does NOT** include `mix hex.revert rindle` (D-20..D-23) | parity | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs:test_release_guide_rollback_rewrite` | ❌ W0 | ⬜ pending |
| 16-05-07 | 05 (runbook) | 5 | RELEASE-01 | — | `--replace` ban statement present (D-13) | parity | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs:test_release_guide_replace_ban` | ❌ W0 | ⬜ pending |
| 16-05-08 | 05 (runbook) | 5 | RELEASE-01 | — | Recovery Workflow Contract section mentions skip-on-rerun semantics (Open Question #3 lock) | parity | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs:test_release_guide_recovery_skip_semantics` | ❌ W0 | ⬜ pending |
| 16-05-09 | 05 (runbook) | 5 | RELEASE-01 | — | CHANGELOG.md top-of-file note about 0.1.0–0.1.3 as pipeline iterations (D-07) | parity | `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs:test_changelog_pipeline_iteration_note` | ❌ W0 | ⬜ pending |
| 16-05-10 | 05 (runbook) | 5 | RELEASE-01 | — | All `scripts/*.sh` accept `RINDLE_PROJECT_ROOT` (Claude's-Discretion CI lint, recommended) | parity | `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs:test_scripts_accept_project_root` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/install_smoke/hex_release_exists_test.exs` — new ExUnit module wrapping `System.cmd("bash", [script_path], env: …)` for the four canonical probe cases (live / missing / fallback-only / inconclusive) plus `RINDLE_PROJECT_ROOT` honor and no-auth-call assertions.
- [ ] `test/install_smoke/support/fake_hex_bin.sh` (or test-private fixture helper) — shim factory that writes tiny shell scripts emitting configurable exit codes for `mix` / `curl`. Lets unit tests cover all four probe cases without touching the network (Pitfall 2).
- [ ] **Extend** `test/install_smoke/release_docs_parity_test.exs` — new tests/assertions for: TL;DR length bound, Footguns inventory, Appendix A SHAs, Appendix B architecture note, voice rewrite, rollback rewrite, `--replace` ban, recovery skip semantics, step-name renames (D-16). Approach: add new `test "..."` blocks; do not refactor existing tests.
- [ ] **Extend** `test/install_smoke/package_metadata_test.exs` — new tests for: workflow idempotency gate, idempotent summary step, single concurrency token, canonical version parse, HEX_API_KEY guard message, four-job topology comment, CHANGELOG pipeline-iteration note, `RINDLE_PROJECT_ROOT` discipline across all `scripts/*.sh`.
- [ ] **Skeleton** `.planning/phases/16-live-publish-execution-and-post-publish-verification/16-REVERT-REHEARSAL.md` — §0..§5 structure stubbed with section headings + signoff line; populated incrementally by Plan 04.

*Existing infrastructure covers ExUnit + bash + curl + `gh` — no framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live `workflow_dispatch` rehearsal proves run `25135467509` regression cannot recur | RELEASE-01 | Requires real Hex.pm read access + GitHub Actions runner; the only end-to-end proof of the idempotency probe | Post-merge of Plans 01+02: run `gh workflow run release.yml -f recovery_reason="phase 16 probe rehearsal" -f recovery_ref=<sha-of-0.1.4>`. Expect: `idempotency` step writes `already_published=true`; `Dry run Hex publish` and `Publish to Hex.pm (live)` show as **skipped**; `public_verify` runs and passes; `$GITHUB_STEP_SUMMARY` shows the D-11 skip message. Capture run URL in Appendix A deviation log entry. |
| Maintainer signoff on `16-REVERT-REHEARSAL.md` | RELEASE-02 | Tabletop evidence file is unshipped (`.planning/` is `@prohibited_paths`); cannot be parity-tested | At phase close: maintainer reads §0..§5, confirms each section is complete, signs §0 with date + maintainer name + runbook SHA reviewed. |
| `mix docs --warnings-as-errors` does not regress on runbook edits | RELEASE-01 | Catches broken in-doc links from Plan 05 edits | Run `MIX_ENV=test mix docs --warnings-as-errors` after Plan 05 lands; expect zero warnings. |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies (3 manual-only items above are explicitly marked)
- [ ] Sampling continuity: every task in plans 01, 02, 05 has automated verify; plan 04 evidence is reviewer-signoff at phase close (acceptable per D-19)
- [ ] Wave 0 covers all MISSING references (4 new test artifacts + 1 evidence skeleton enumerated above)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (quick command)
- [ ] `nyquist_compliant: true` set in frontmatter (planner flips after coverage check)

**Approval:** pending
