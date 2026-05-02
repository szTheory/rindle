# Phase 16 Revert Rehearsal

## 0. Signoff

- Captured: 2026-04-30
- Hex identity proved during rehearsal: `sztheory`
- Package owner proved during rehearsal: `jon@coderjon.com`
- Scope: read-only rehearsal only; no live revert or retire command executed
- Runbook cross-check status: `guides/release_publish.md` updated in the same working tree and matches the canonical commands below

## 1. Identity Proof Transcript

### `mix hex.user whoami`

```text
sztheory
```

### `mix hex.owner list rindle`

```text
Email             Level
jon@coderjon.com  full
```

### `mix hex.info rindle 0.1.4`

```text
Config: {:rindle, "~> 0.1.4"}
Documentation at: https://hexdocs.pm/rindle/0.1.4
Dependencies:
  ecto_sql ~> 3.11
  ex_aws ~> 2.5
  ex_aws_s3 ~> 2.5
  ex_marcel ~> 0.2
  image ~> 0.65
  jason ~> 1.4
  nimble_options ~> 1.1
  oban ~> 2.21
  phoenix_live_view ~> 1.0 (optional)
  plug ~> 1.16
  postgrex ~> 0.18
  telemetry ~> 1.2
Published by: sztheory (jon@coderjon.com)
```

## 2. Decision Matrix

| Situation | Action | Canonical command | Why |
| --- | --- | --- | --- |
| Bad release inside revert window | Revert | `mix hex.publish --revert VERSION` | Removes the release while the Hex grace window is still open |
| Runtime breakage after revert window | Retire + patch | `mix hex.retire rindle VERSION REASON --message "..."` | Warns new resolvers while the fix release is prepared |
| Docs broken, package fine | Docs-only republish | `mix hex.docs publish` | Fixes docs without mutating the package version |
| Window closed and package broken | Retire bad version, ship fix immediately | `mix hex.retire ...` then Release Please patch release | Lockfiles still install the bad version, so retire alone is not enough |

## 3. Command Canonicalization

- Canonical revert command: `mix hex.publish --revert VERSION`
- Wrong legacy wording from the old runbook: `mix hex.revert rindle VERSION`
- Retire peer procedure: `mix hex.retire rindle VERSION REASON --message "..."`
- Valid retire reasons: `renamed`, `deprecated`, `security`, `invalid`, `other`
- Docs-only repair path: `mix hex.docs publish`
- Window semantics: first publish gets 24h; subsequent releases get 1h

## 4. Adopter Advisory

### Advisory template

```text
Adopter advisory: VERSION is retired due to REASON. Upgrade to FIX_VERSION immediately. Existing lockfiles can still install VERSION until you update your dependency resolution.
```

### Commit title convention

```text
fix(release): retire BAD_VERSION, ship FIX_VERSION
```

### GitHub Release title format

```text
rindle FIX_VERSION - replacement for retired BAD_VERSION
```

## 5. Runbook Cross-Reference

- `guides/release_publish.md` now uses `mix hex.publish --revert VERSION` as the canonical revert command.
- `guides/release_publish.md` documents `mix hex.retire rindle VERSION REASON --message "..."` and the retire reasons `renamed`, `deprecated`, `security`, `invalid`, `other`.
- `guides/release_publish.md` documents `mix hex.docs publish` for docs-only recovery.
- `guides/release_publish.md` warns that lockfiles still install the bad version after retirement.
- `guides/release_publish.md` includes the adopter advisory template and `fix(release): retire BAD_VERSION, ship FIX_VERSION` convention.

Cross-check result: Phase 16 runbook and rehearsal commands align as of 2026-04-30.
