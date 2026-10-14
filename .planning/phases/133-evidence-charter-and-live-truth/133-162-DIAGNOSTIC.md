# Plan 162 Supplemental Bounded Diagnostic

This note supplements the immutable halted record in `133-162-SUMMARY.md`; it does not retroactively change Plan 162's terminal status or create Plan 163 authority.

## Exact-source probe

- Source: `36a3d0920d210abe4d6f17a3117ff79580a15507`.
- The probe cloned that source locally with `git clone --shared --no-checkout`, detached at the exact SHA, and invoked `scripts/maintainer/phase_133_registry_closure_154.mjs` with an unsupported diagnostic-only mode. No qualification-preflight, authorization, network, or credential operation ran.
- On this macOS host, `os.tmpdir()` is `/var/folders/f3/f0clj9rd2zb85n2c849wcsrc0000gn/T`, while its filesystem real path is `/private/var/folders/f3/f0clj9rd2zb85n2c849wcsrc0000gn/T`.
- The script's lexical temp-checkout path and canonical real path differed. Invoking the lexical path returned status 0 with empty stdout/stderr. Invoking the same file by its canonical real path reached `main()`, returned status 1, and wrote `{"status":"halted","plan":"133-154/155","code":null,"reason":"unsupported registry closure mode","qualification_credit":0}` to stderr.

## Causal conclusion

Plan 154's entrypoint guard compares `path.resolve(process.argv[1])` with `fileURLToPath(import.meta.url)`. When Node launches a script through the `/var/folders/...` alias, its ESM module URL resolves under `/private/var/folders/...`; the comparison is false, so the module silently skips `main()` and exits 0. The same alias occurs for detached checkouts created under `os.tmpdir()`. This explains the status-0, empty-output child result that caused the JSON parse failure.

The repair should canonicalize both paths (or otherwise use a symlink-safe ESM entrypoint check) and add a regression that invokes the real Plan 154 script through a temp-directory alias, then proves its normal output/error path runs. Preserve all existing source, receipt, and no-network gates. This is diagnosis only; Plan 163 remains disabled until a new reviewed repair plan is executed and committed.
