---
quick_id: 260614-ny7
slug: replace-flaky-federicocarboni-setup-ffmp
date: 2026-06-14
status: complete
---

# Quick Task 260614-ny7 Summary

Replaced the flaky `FedericoCarboni/setup-ffmpeg@v3` action (which fetched from
johnvansickle.com and intermittently failed, blocking merges) with a reliable
**static ffmpeg >= 6 install from BtbN/FFmpeg-Builds GitHub releases**, across all
4 lanes that used it (`quality` ×2 cells, `integration`, `package-consumer`,
`adopter`).

## Changes

- `scripts/ci/install_ffmpeg.sh` (new) — downloads BtbN's static `n7.1` linux64
  build from GitHub's CDN (`curl --retry`), installs to `/usr/local/bin`, asserts
  major >= 6.
- `.github/workflows/ci.yml` — 4 `uses: FedericoCarboni/setup-ffmpeg@v3` blocks →
  `run: bash scripts/ci/install_ffmpeg.sh`. The 2 apt demo lanes
  (`adoption-demo-unit`, `adoption-demo-e2e`) are unchanged.
- `lib/rindle/av/probe.ex` — widen the version regex to `n?(\d+\.\d+)` so BtbN /
  official ffmpeg git-tag version strings (`n7.1`) parse, not just bare `7.0.x`.
  Fixes a latent bug for any adopter using official/BtbN ffmpeg builds.
  `test/rindle/av/probe_test.exs` — added n-prefixed pass + below-6 fail cases.

## Source trail (each rejected in CI, nothing bad shipped)

1. **apt** → ubuntu-22.04 ships 4.4 (< 6.0); the `>=6` guard caught it.
2. **johnvansickle direct** → returns HTTP 415 to CI runners (host is hostile to
   automated curl); the original action's flakiness was this host.
3. **BtbN** → GitHub-hosted, reliable, but reports `n7.1`; paired with the
   one-char probe-regex widening it parses cleanly. **Chosen.**

## Verification

- 0 `uses: FedericoCarboni` lines; 4 script callers; 2 apt demo lanes untouched.
- `mix test test/rindle/av/probe_test.exs` → 7/7 (incl. 2 new n-prefix cases).
- YAML valid; script shellcheck-clean; BtbN tarball + binary layout verified locally.
- Final proof is CI on the PR: Quality (×2), Integration, Package Consumer
  (install-smoke `doctor_success=true`), Adopter, + all demo lanes green.

## Notes

Scope grew from CI-only to include a 1-line `lib/rindle/av/probe.ex` fix
(maintainer-approved): the only reliable ffmpeg source (BtbN) reports an
`n`-prefixed version the probe couldn't parse. Committed as `fix:` (probe) +
`ci:` (install) — release-please will patch-bump for the probe fix.
