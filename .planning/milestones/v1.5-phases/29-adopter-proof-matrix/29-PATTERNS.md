# Phase 29: Adopter Proof Matrix - Patterns

## Reuse Map

| Target Area | Closest Analog | Why It Matters |
|-------------|----------------|----------------|
| Fresh package-consumer harness | `test/install_smoke/support/generated_app_helper.ex` | Already owns `mix phx.new`, dependency patching, explicit migration handoff, boot verification, and smoke test generation. |
| Built-artifact smoke entrypoint | `scripts/install_smoke.sh` | Narrow wrapper around generated-app smoke for local/built package proof. |
| Published-version smoke entrypoint | `scripts/public_smoke.sh` | Existing network-mode wrapper for proving a published Hex version without repo-local path deps. |
| CI package-consumer lane | `.github/workflows/ci.yml` `package-consumer` job | Current release-preflight + smoke job; best anchor for matrix expansion. |
| Repo-local AV truth | `test/adopter/canonical_app/lifecycle_test.exs` | Source of concrete AV assertions and public lifecycle calls to port into generated-app proof. |
| Canonical image/AV profiles | `test/adopter/canonical_app/profile.ex` | Keeps image-only and AV-enabled package-consumer profiles aligned with public docs. |
| Docs parity | `test/install_smoke/docs_parity_test.exs`, `test/install_smoke/release_docs_parity_test.exs` | Established exact-string docs contract style for install/release surfaces. |

## File-Level Analog Guidance

### `test/install_smoke/support/generated_app_helper.ex`
- Extend by adding a second generated profile module instead of replacing the current one.
- Follow the existing pattern of writing files into the generated app (`write_profile!`, `write_smoke_test!`, fixture helpers).
- Preserve the explicit `Application.app_dir(:rindle, "priv/repo/migrations")` migration handoff and default Oban wiring.

### `test/install_smoke/generated_app_smoke_test.exs`
- Mirror the current assertion style: installability first, lifecycle proof second.
- Prefer explicit AV/image mode tests or tagged test groups over one monolithic smoke assertion.

### `scripts/install_smoke.sh` and `scripts/public_smoke.sh`
- Keep them as thin wrappers that set env vars and call ExUnit.
- Add mode/profile switching via env vars rather than forking the full helper logic.

### `.github/workflows/ci.yml`
- Follow the current readable topology of named jobs and explicit setup steps.
- Keep service-backed proof lanes explicit; avoid hiding the matrix inside a single large shell script.

### `test/install_smoke/docs_parity_test.exs`
- Add exact required snippets for package-consumer matrix guidance.
- Keep parity repo-native and reader-facing; do not assert internal helper names unless those are intentionally public.

## Likely Files For Phase 29

- `.github/workflows/ci.yml`
- `scripts/install_smoke.sh`
- `scripts/public_smoke.sh`
- `scripts/release_preflight.sh`
- `test/install_smoke/generated_app_smoke_test.exs`
- `test/install_smoke/support/generated_app_helper.ex`
- `test/install_smoke/docs_parity_test.exs`
- `test/install_smoke/release_docs_parity_test.exs`
- `README.md`
- `guides/getting_started.md`
- `guides/operations.md`

---
*Pattern map completed: 2026-05-05*
