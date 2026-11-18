# Cowboy/Cowlib security fixes and the OTP 26 support boundary

## Finding

The 2026-11-18 readiness candidate initially upgraded the root test dependency chain to Cowboy 2.21.0 / Cowlib 2.22.0. Hosted CI on PR #232 (run `44236702135`) failed both Elixir 1.15 / OTP 26 compile lanes at `cow_capsule.erl:67`: Cowlib 2.22 uses OTP 27 syntax. Nine Nines' release notes state Cowboy 2.21 and Cowlib 2.22 support OTP 27 and above. The repo's `RUNNING.md` keeps Elixir 1.15 / OTP 26 and Elixir 1.17 / OTP 27 as required matrix cells; the ledger already records the same Cowlib compatibility exception.

Keep the root test lock at Cowboy 2.18.0 / Cowlib 2.19.0 while OTP 26 remains supported. The root lock contains this chain only through Bypass (`only: :test`), so it is not part of Hex consumers' dependency graph. Preserve the dated exception policy and record current findings for Cowboy 2.18.0 and Cowlib 2.19.0, including the newly published high-severity advisories. The Plug 1.20.4 upgrade and its root/demo disposition remain independent.

## Evidence

- CI run `44236702135`: `ADMIN-06 Optional Dependencies (1.15, 26)` and `Quality (1.15, 26)` failed compiling Cowlib 2.22.0; the corresponding OTP 27 optional-dependency lane passed.
- `mix deps.tree` in the candidate shows the root Cowboy/Cowlib chain under Bypass; `mix.exs` declares Bypass `only: :test`.
- `RUNNING.md` names OTP 26 and OTP 27 as required merge-blocking matrix cells.
- Official release compatibility: <https://ninenines.eu/articles/cowboy-2.21.0/>.
- Official advisory records: <https://cna.erlef.org/cves/CVE-2026-115701.html>, <https://cna.erlef.org/cves/CVE-2026-113431.html>, <https://cna.erlef.org/cves/CVE-2026-43966.html>.

## Reusable lesson

When a security-fixed BEAM package is OTP-27-only, don't merge its lock update while the repository still requires OTP 26. Keep test-only lock exceptions explicit and time-bounded, retain the green compatibility matrix, and revisit the exception when OTP 26 leaves support or a compatible fix becomes available. Local `mix hex.audit` should report the exceptions; that output is not an operational failure when the audited findings match the reviewed ledger.
