---
status: partial
phase: 36-public-dx-onboarding-ci-proof
source: [36-VERIFICATION.md]
started: 2026-05-07T14:04:52Z
updated: 2026-05-07T14:04:52Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Run cassette package-consumer lane end-to-end on a real PR build
expected: `bash scripts/install_smoke.sh mux` exits 0 inside CI's `package-consumer` job: fresh `mix phx.new` + Rindle install + `mix rindle.doctor` + sample upload + `<video>` rendered with Mux-signed HLS URL. The cassette path never reaches `api.mux.com` (Mox-on-:http_client). This is SC #3 + SC #4 (cassette lane) and the Plan 03 SUMMARY explicitly defers item 1 of its verification matrix to CI.
result: [pending]

### 2. Run `mux-soak` lane against real Mux on a `streaming`-labelled PR
expected: Real-Mux API hit succeeds end-to-end; ingested asset appears + ready; signed HLS URL plays; cleanup deletes the asset; soak-asset count on the Mux account stays at 0 across consecutive labelled PRs.
result: [pending]

### 3. Verify HexDocs publish wire — `mix docs` rendering of `streaming_providers.md` + `MuxWeb` module
expected: On hexdocs.pm (or local `mix docs` preview), `Rindle.Profile.Presets.MuxWeb` module page renders, `guides/streaming_providers.md` is in the sidebar, intra-doc links resolve.
result: [pending]

### 4. Confirm no fork-secret leak when a fork PR is labelled `streaming`
expected: Fork PR labelled `streaming` fires `mux-soak` job; `${{ secrets.RINDLE_MUX_* }}` resolve to empty strings; the lane fails closed (no real-Mux call); cleanup step's no-credential branch (`exit 0`) hits.
result: [pending]

### 5. Confirm the cassette lane's WebM upload + variant fan-out yields the byte-identical `[poster, web_720p]` ready-variant assertion in the generated app
expected: Generated-app smoke test (`Rindle.InstallSmoke.GeneratedAppSmokeMuxTest`) passes — same as the `:video` lane plus the two new streaming-URL assertions (regex match + `JOSE.JWT.verify_strict/3` returning `{true, _, _}`).
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
