# Phase 71: CI Proof Honesty — Pattern Map

**Mapped:** 2026-05-27

## Analog: Phase 36 mux-soak comment block

**File:** `.github/workflows/ci.yml` (~580–590)

```yaml
  # Phase 36 (D-19, D-20, D-22, T-36-FORK-SECRETS, T-36-ASSET-LEAK):
  # Real-Mux soak proof. Sibling top-level job (NOT a step inside
  # package-consumer). Label-gated on `streaming` ...
  mux-soak:
```

**Reuse:** Phase 71 blocks use same multi-line `#` prefix style, `# Phase 71 (CI proof honesty):` header, reason for non-blocking, pointer to `RUNNING.md`.

## Analog: Phase 41 docs_parity_test

**File:** `test/install_smoke/docs_parity_test.exs`

```elixir
  test "running guide publishes the durable FFmpeg install matrix", %{running: running} do
    for snippet <- [
          "FFmpeg >= 6.0",
          ...
        ] do
      assert running =~ snippet
    end
  end
```

**Reuse:** Add sibling test asserting CI severity section strings in `@running_path` content.

## Analog: adopter job header (release-readiness documentation)

**File:** `.github/workflows/ci.yml` (~427–433)

```yaml
    # Adopter lane (CI-08): proves the canonical adopter-facing media
    # lifecycle works end-to-end against MinIO + PostgreSQL. Runs ONLY
    # after quality, integration, and contract have all passed —
    # the release-readiness signal ...
    needs: [quality, integration, contract]
```

**Reuse:** Extend header after D-05 to state **merge-blocking** explicitly.

## Analog: package-consumer job comment (~299–302)

Currently describes release preflight shift-left but does not state severity. After D-04, add merge-blocking language matching adopter pattern.

## PATTERN MAPPING COMPLETE
