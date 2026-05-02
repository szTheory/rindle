---
phase: 15-ci-integrity-and-publish-preflight
plan: 02
subsystem: release
tags: [release, ci, packaging, preflight, signoff]
requirements_completed:
  - PUBLISH-01
  - PUBLISH-02
completed: 2026-04-30
---

# Phase 15 Plan 02 Summary

Phase 15 plan 02 produced the authoritative release-candidate proof and maintainer signoff contract by encoding the exact-SHA remote-CI boundary in the runbook and parity test, adding a release-candidate evidence checklist, and recording the closing evidence against the current pipeline lineage.

## Accomplishments

- Updated `guides/release_publish.md` to separate local diagnostics (`bash scripts/release_preflight.sh`, `mix hex.build --unpack`) from the authoritative remote proof: a green GitHub Actions run on the exact release-candidate SHA.
- Extended `test/install_smoke/release_docs_parity_test.exs` with executable parity assertions for the exact-SHA remote-proof language and the maintainer-only checks (`mix hex.user whoami`, `mix hex.owner list rindle`, manual `rindle` package-name availability).
- Added `.planning/phases/15-ci-integrity-and-publish-preflight/15-RELEASE-CANDIDATE-CHECKLIST.md` as the concrete blocking evidence template.
- Recorded the closing evidence in the checklist: SHA `6dd0d54081c89b68c630d9642a40453d310008c6`, CI run `https://github.com/szTheory/rindle/actions/runs/25135464796` green at 2026-04-29T21:49:44Z, maintainer Hex command outputs, and a GO decision with reality-reconciliation note.

## Reality Reconciliation

The plan was authored on 2026-04-29 assuming v0.1.0 was the upcoming first publish. During Phase 15 execution the release-please pipeline auto-bumped through 0.1.0, 0.1.1, 0.1.2, 0.1.3, and 0.1.4; `mix hex.info rindle` reports `Releases: 0.1.4` live on Hex.pm. The candidate SHA in the original checklist header (`566f6f4a…`) is six commits behind current HEAD, and the package-name availability check is moot because the name is owned.

The trust-boundary contract this plan locked in is still load-bearing for future first-publish-style work (e.g. spinning up a sibling package). The closing evidence is therefore recorded retroactively against current HEAD instead of forcing a fictional pre-publish state.

## Verification

- `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs` — passes; runbook still encodes the exact-SHA remote-proof boundary and the three maintainer checks.
- `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs` — passes; tarball metadata, MIT license, GitHub link, required shipped files (incl. `CHANGELOG.md` with `0.1.0` entry), and prohibited repo paths all enforced.
- `rg -n "exact release-candidate SHA|mix hex.user whoami|mix hex.owner list rindle|package-name availability" guides/release_publish.md .planning/phases/15-ci-integrity-and-publish-preflight/15-RELEASE-CANDIDATE-CHECKLIST.md` hits in both files.
- `gh run view 25135464796 --json conclusion` returns `success`; headSha matches HEAD.

## Authoritative Evidence

- Exact release-candidate SHA: `6dd0d54081c89b68c630d9642a40453d310008c6`
- GitHub Actions run URL: https://github.com/szTheory/rindle/actions/runs/25135464796
- CI workflow: `CI` (push, 6m04s, success, 2026-04-29T21:49:44Z)
- Filled checklist: `.planning/phases/15-ci-integrity-and-publish-preflight/15-RELEASE-CANDIDATE-CHECKLIST.md`
- Live Hex.pm state at close: `Releases: 0.1.4`

## Notes

- The `Release` workflow `workflow_dispatch` recovery run (`25135467509`, 2026-04-29T21:43Z) failed after `Publish to Hex` emitted its release_version output — a separate concern affecting manual recovery reruns, not Phase 15 closure. Worth a dedicated phase before the next release to avoid surprises in `release.yml` recovery mode.
- Phase 15-02 deliberately did not relax the "manual checks stay outside CI" boundary (decisions D-04..D-06, D-09 / parity test). Automating those checks would require shipping live Hex credentials into Actions and would break `release_docs_parity_test.exs`.
