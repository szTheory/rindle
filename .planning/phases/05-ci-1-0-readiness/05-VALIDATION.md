---
phase: 5
slug: ci-1-0-readiness
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-26
revised: 2026-04-26
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
>
> **Revision (2026-04-26):** updated per-task map to reflect the 7-plan
> structure (Plans 01..07) after Plan 06 was split into Plan 06 (DOC-08
> audit + mix.exs wiring + drift CI step) and Plan 07 (DOC-01..07 guide
> authoring). `nyquist_compliant` and `wave_0_complete` remain `false`
> because Wave 0 dependencies (e.g., `broker_test.exs` / `delivery_test.exs`
> reuse for telemetry assertions; the `coveralls.json` and adopter-fixture
> scaffolds) are documented in plan acceptance criteria but have not been
> independently audited end-to-end against this map.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit 1.18 + excoveralls 0.18 (added by Plan 03) |
| **Config file** | `mix.exs` (test_coverage), `coveralls.json` (Plan 03 creates) |
| **Quick run command** | `mix test --exclude integration --exclude minio --exclude adopter --exclude contract` |
| **Full suite command** | `mix coveralls` (quality lane) + `mix test --only contract` (contract lane) + `mix test --only adopter` (adopter lane) |
| **Estimated runtime** | ~120 seconds (quality) + ~30 seconds (contract) + ~180 seconds (adopter) + ~60 seconds (release.yml dry-run on tag push) |

---

## Sampling Rate

- **After every task commit:** Run quick command
- **After every plan wave:** Run the relevant lane command (quality / contract / adopter / release-dryrun)
- **Before `/gsd-verify-work`:** Full suite (all lanes) must be green
- **Max feedback latency:** 180 seconds (adopter lane is the longest single command)

---

## Per-Task Verification Map

*Revised after Plan 06 split into Plan 06 + Plan 07 per checker Warning 2.*

| Task ID | Plan | Wave | Requirements | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|--------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 5-01-01 | 01 | 1 | TEL-01..03, TEL-06, TEL-08 | T-05-01-02 | AssetFSM + VariantFSM emit `:state_change` with required metadata | unit | `mix test test/rindle/telemetry/emission_test.exs` | ❌ W0 | ⬜ pending |
| 5-01-02 | 01 | 1 | TEL-01, TEL-04, TEL-06 | T-05-01-03 | Broker (`:upload :start`/`:stop`) and Delivery (`:delivery :signed`) emit AFTER transactions/with-success; Warning 3: tests inlined in broker_test.exs / delivery_test.exs (no flunk scaffold) | unit | `mix test test/rindle/upload/broker_test.exs test/rindle/delivery_test.exs test/rindle/telemetry/emission_test.exs` | ❌ W0 | ⬜ pending |
| 5-01-03 | 01 | 1 | TEL-05, TEL-08 | — | Cleanup workers emit `:cleanup :run` after Logger.info; UploadMaintenance does NOT emit | unit + worker | `mix test test/rindle/workers/cleanup_orphans_test.exs test/rindle/workers/abort_incomplete_uploads_test.exs` | ❌ W0 | ⬜ pending |
| 5-02-01 | 02 | 2 | CI-06 | T-05-02-01 | Test_helper excludes `:contract`/`:adopter`; contract test scaffold attaches handlers + asserts allowlist shape | contract | `mix test --only contract` | ❌ W0 | ⬜ pending |
| 5-02-02 | 02 | 2 | CI-06 | T-05-02-01 | Contract test asserts metadata keys + numeric measurements; allowlist-no-extras assertion | contract | `mix test --only contract` | ❌ W0 | ⬜ pending |
| 5-02-03 | 02 | 2 | CI-06 | — | New `Contract` GitHub Actions job runs `mix test --only contract`, `needs: quality` waits for ALL matrix variants (Blocker 4) | CI integration | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` + grep checks | ✅ (extends existing) | ⬜ pending |
| 5-03-01 | 03 | 1 | CI-03 | — | excoveralls dep + coveralls.json `minimum_coverage: 80` + mix.exs `test_coverage:` wiring | unit | `mix coveralls` (exit 1 below 80%) | ❌ W0 | ⬜ pending |
| 5-03-02 | 03 | 1 | CI-01..05 | T-05-03-01 | Quality job: libvips before deps.get + `mix coveralls` replacing `mix test` + format/credo/dialyzer preserved + matrix preserved (Blocker 4) + integration job byte-for-byte unchanged (Blocker 7); Warning 6 coverage-window calibration documented in SUMMARY | CI integration | `mix coveralls && mix credo --strict && mix dialyzer` + grep checks for matrix preservation + integration command preservation | ✅ (extends existing) | ⬜ pending |
| 5-04-01 | 04 | 3 | CI-08 | T-05-04-02 | Adopter Repo + Profile compile; mix.exs `elixirc_paths(:test)` adds `test/adopter`; config/test.exs wires Sandbox pool | unit | `mix compile --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 5-04-02 | 04 | 3 | CI-08 | T-05-04-04 | Adopter lifecycle: initiate → sign → **HTTP PUT to presigned URL** (Blocker 5) → verify → promote → variant → deliver → detach; TODO surfaces Rindle.Repo leak (D-09) | adopter integration | `mix test --only adopter` | ❌ W0 | ⬜ pending |
| 5-04-03 | 04 | 3 | CI-07, CI-08 | — | New `adopter` GitHub Actions job: needs [quality, integration, contract]; MinIO + Postgres services | CI integration | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` + grep checks | ✅ (extends existing) | ⬜ pending |
| 5-05-01 | 05 | 4 | CI-09 | T-05-05-03 | mix.exs package/0 `files: ~w(...)` allowlist; LICENSE present; tarball excludes `_build/`/`.planning/`/`priv/plts/`/`test/`/`coveralls.json`; `test/adopter` preserved in `elixirc_paths(:test)` (Warning 4) | release dry-run | `mix hex.build --unpack && ! test -e rindle-*/_build && ! test -e rindle-*/.planning` | ❌ W0 | ⬜ pending |
| 5-05-02 | 05 | 4 | CI-09 | T-05-05-01, T-05-05-04 | release.yml triggers ONLY on workflow_dispatch + `v*` tag push; `environment: release` declared (Blocker 6); A1 graceful fallback for hex.publish auth | CI integration | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"` + grep `environment: release` | ❌ W0 | ⬜ pending |
| 5-06-01 | 06 | 4 | DOC-08 | — | 5 domain schemas full `@moduledoc`; lib/rindle/repo.ex `@moduledoc false` | unit | `mix credo --strict && mix compile --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 5-06-02 | 06 | 4 | DOC-08 | — | Every public function in `lib/rindle.ex`, `broker.ex`, `delivery.ex` has `@doc` with at least one `iex>` example or documented rationale (Blocker 2) | unit + grep | `for f in lib/rindle.ex lib/rindle/upload/broker.ex lib/rindle/delivery.ex; do test "$(grep -c iex> $f)" -ge "$(grep -c '^  def ' $f)"; done` | ❌ W0 | ⬜ pending |
| 5-06-03 | 06 | 4 | DOC-08 | — | mix.exs docs/0 lists 7 guides + groups_for_extras + Mermaid CDN (`before_closing_head_tag:`); `test/adopter` preserved in elixirc_paths (Warning 4); `package: [files:]` preserved (Plan 05 invariant) | docs build | `mix docs` (after Plan 07 ships guides) + grep checks | ❌ W0 | ⬜ pending |
| 5-06-04 | 06 | 4 | DOC-08 (drift gate) | T-05-06-02 | Adopter job CI step greps `guides/getting_started.md` for `Broker.initiate_session`/`Broker.verify_completion`/`Rindle.Delivery.url` (D-16 drift gate, Blocker 1) | CI integration | `grep -c "D-16 drift gate" .github/workflows/ci.yml && grep -c "Broker\\.initiate_session" .github/workflows/ci.yml` | ❌ W0 | ⬜ pending |
| 5-07-01 | 07 | 4 | DOC-01, DOC-02 | T-05-07-02 | guides/getting_started.md mirrors adopter lane API (D-16); guides/core_concepts.md has 3 Mermaid `stateDiagram-v2` blocks | docs build + grep | `grep -c "stateDiagram-v2" guides/core_concepts.md && grep -c "Broker\\.initiate_session" guides/getting_started.md` | ❌ W0 | ⬜ pending |
| 5-07-02 | 07 | 4 | DOC-03, DOC-04, DOC-05 | T-05-07-01 | Profiles, secure delivery, background processing guides each ≥ 50 lines with concrete code examples | docs build | `wc -l guides/*.md` | ❌ W0 | ⬜ pending |
| 5-07-03 | 07 | 4 | DOC-06, DOC-07 | — | Operations guide cross-links to all 5 Mix tasks (D-18); troubleshooting covers FSM error states; `mix docs` builds end-to-end | docs build | `mix docs && for t in cleanup_orphans regenerate_variants verify_storage abort_incomplete_uploads backfill_metadata; do grep -q "mix rindle.$t" guides/operations.md; done` | ❌ W0 | ⬜ pending |

### Coverage of Phase Requirements

| Requirement Set | Plan(s) Covering | Status |
|-----------------|------------------|--------|
| TEL-01..08 | 01 | mapped |
| CI-01..05 | 03 | mapped |
| CI-06 | 02 | mapped |
| CI-07 | 03 (preservation), 04 (no modification) | mapped |
| CI-08 | 04 | mapped |
| CI-09 | 05 | mapped |
| DOC-01..07 | 07 (NEW) | mapped |
| DOC-08 | 06 | mapped |

---

## Sampling Rate

- **Per task commit:** `mix test --only contract` (fast, in-process)
- **Per wave merge:** `mix coveralls` (full suite with threshold)
- **Phase gate:** Full suite green + `mix credo --strict` + `mix dialyzer --format github` before `/gsd-verify-work`

---

## Wave 0 Requirements

- [ ] `coveralls.json` — covers CI-03 threshold gate (Plan 03 Task 1)
- [ ] `test/rindle/telemetry/emission_test.exs` — covers TEL-01..08 FSM emissions (Plan 01 Task 1)
- [ ] Telemetry describe blocks INLINED in `test/rindle/upload/broker_test.exs` and `test/rindle/delivery_test.exs` (Plan 01 Task 2 — Warning 3: NO flunk scaffolds)
- [ ] `test/rindle/contracts/telemetry_contract_test.exs` — covers CI-06 (Plan 02 Task 1)
- [ ] `test/adopter/canonical_app/repo.ex` — adopter Repo (Plan 04 Task 1)
- [ ] `test/adopter/canonical_app/profile.ex` — adopter profile fixture (Plan 04 Task 1)
- [ ] `test/adopter/canonical_app/lifecycle_test.exs` — covers CI-08 end-to-end via HTTP PUT to presigned URL (Plan 04 Task 2 — Blocker 5)
- [ ] `guides/getting_started.md` — covers DOC-01 + D-16 drift gate (Plan 07 Task 1)
- [ ] `guides/core_concepts.md` — covers DOC-02 (Mermaid diagrams) (Plan 07 Task 1)
- [ ] `guides/profiles.md` — covers DOC-03 (Plan 07 Task 2)
- [ ] `guides/secure_delivery.md` — covers DOC-04 (Plan 07 Task 2)
- [ ] `guides/background_processing.md` — covers DOC-05 (Plan 07 Task 2)
- [ ] `guides/operations.md` — covers DOC-06 (Plan 07 Task 3)
- [ ] `guides/troubleshooting.md` — covers DOC-07 (Plan 07 Task 3)
- [ ] `.github/workflows/release.yml` — covers CI-09 + Blocker 6 environment protection (Plan 05 Task 2)
- [ ] `mix.exs` — `test_coverage:` (Plan 03), `package: [files:]` (Plan 05), `docs/0 extras + groups + before_closing_head_tag` (Plan 06 Task 3); `elixirc_paths(:test)` adds `test/adopter` (Plan 04 Task 1) and is preserved through Plans 05/06/07 (Warning 4)
- [ ] `lib/rindle/domain/media_*.ex` (5 files) + `lib/rindle/repo.ex` — DOC-08 audit (Plan 06 Task 1)
- [ ] `lib/rindle.ex` + `lib/rindle/upload/broker.ex` + `lib/rindle/delivery.ex` — DOC-08 `@doc` audit on every public function (Plan 06 Task 2 — Blocker 2)
- [ ] Telemetry emission in `asset_fsm.ex`, `variant_fsm.ex`, `broker.ex`, `delivery.ex`, `workers/cleanup_orphans.ex`, `workers/abort_incomplete_uploads.ex` — covers TEL-01/04/05 + enables CI-06 (Plan 01)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Getting-started guide is copy-pasteable in a fresh Phoenix app | DOC-01 / Success Criterion 5.5 | Requires bootstrapping a Phoenix app outside this repo | After `mix docs` succeeds, copy snippet from `guides/getting_started.md` into a fresh `mix phx.new demo` project; run upload → variant → delivery; verify zero gaps. (Note: Plan 06 Task 4's CI grep gate enforces snippet-API parity automatically; this manual check verifies broader copy-paste-ability.) |
| State diagrams render correctly in published HexDocs | DOC-02 | Mermaid CDN renders client-side; CI cannot screenshot | Run `mix docs`, open `doc/core_concepts.html` in a browser, confirm asset/variant/upload-session diagrams render via the Mermaid CDN injected by `before_closing_head_tag:` |
| Hex publish dry-run actually rejects metadata regressions | CI-09 / D-11 | Dry-run output is human-readable; assertion needs eyeballing once before lane is trusted | Manually omit `package: [files: ...]` entry, run `mix hex.publish --dry-run`, confirm release lane fails |
| GitHub Actions `release` environment protection rules configured | T-05-05-01 / Blocker 6 | Repo admin task in repo settings UI | After Plan 05 merges, navigate to Settings → Environments → New environment → name `release`. Apply protection rules: required reviewers + branch restriction to `main` and `v*` tag refs. No real `HEX_API_KEY` secret should be added until 1.0 cutover. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter (CURRENTLY false — Wave 0 dependencies above are documented in plan acceptance criteria but not yet independently audited end-to-end)
- [ ] `wave_0_complete: true` set in frontmatter (CURRENTLY false — see above)

**Approval:** pending revision — checker confirms 7-plan structure mapped; flip `nyquist_compliant`/`wave_0_complete` to `true` only after a follow-up audit walks each Wave 0 row above and confirms the corresponding plan acceptance criterion exists and is automated.
