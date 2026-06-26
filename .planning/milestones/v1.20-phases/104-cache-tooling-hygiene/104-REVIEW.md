---
phase: 104-cache-tooling-hygiene
reviewed: 2026-06-21T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - .github/actions/setup-elixir/action.yml
  - .github/actions/setup-minio/action.yml
  - .github/workflows/ci.yml
  - .github/workflows/release.yml
findings:
  critical: 0
  warning: 4
  info: 2
  total: 6
status: issues_found
---

# Phase 104: Code Review Report

**Reviewed:** 2026-06-21
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

This phase introduces two composite actions (`setup-elixir`, `setup-minio`) and migrates ~9 `ci.yml` jobs plus the `release.yml` MinIO setup onto them. I reviewed for GitHub Actions correctness: cache-key correctness/collisions, restore-vs-save semantics, composite↔caller input/output wiring, shell-injection risk in `run:` interpolation, MinIO bring-up races, and migration fidelity against pre-phase inline code.

Overall the migration is high-fidelity. I traced every migrated job against its pre-phase inline form via git history:

- **MinIO bring-up** (`ci.yml` ×5 jobs + `release.yml`) is byte-faithful to the prior inline trio, including the CORS `*` injection that only the `adoption-demo-e2e` caller needs.
- **Composite↔setup-beam output wiring** is correct: `steps.beam.outputs.otp-version` / `elixir-version` are the canonical `erlef/setup-beam@v1` resolved-version outputs, so there is no empty-key-segment / cross-toolchain poisoning risk.
- **Namespace separation** (`deps-v1-…` vs `deps-no-optional-v1-…`) is collision-free because the `-v1-` segment immediately follows the namespace token, so the default restore-key prefix can never partial-match the `no-optional` namespace.

No BLOCKERs. The findings below are correctness-adjacent robustness gaps and one genuine behavioral change (cache-key narrowing from `**/mix.lock` to `mix.lock`) that the team should consciously accept. Per the domain note I did not re-report the 6 documented `actionlint` baseline findings.

## Warnings

### WR-01: Cache key narrowed from `**/mix.lock` to root `mix.lock` — silent one-time cache-miss + correctness gap for nested lockfile drift

**File:** `.github/actions/setup-elixir/action.yml:81,90` (and restore-keys 83,92)
**Issue:** The composite hashes `hashFiles('mix.lock')` (root only). Every pre-phase job hashed `hashFiles('**/mix.lock')`, which is a recursive glob that also covered `examples/adoption_demo/mix.lock` (confirmed: exactly two lockfiles exist in the repo — `./mix.lock` and `./examples/adoption_demo/mix.lock`). Two consequences:

1. **One-time cold cache on first run after merge** — the key string changed for every job (`deps-<os>-1.17-27-<hash(**/mix.lock)>` → `deps-v1-<os>-<arch>-otp27-elixir1.17-test-<hash(mix.lock)>`), so the first post-merge run is an unavoidable full miss. Expected and self-healing, but worth flagging so a "cache regressed" alarm isn't misread.
2. **Correctness gap:** the new key no longer changes when `examples/adoption_demo/mix.lock` changes. For the root-deps jobs this is fine (they don't consume the demo lock), but it means the deps/build cache lineage is now blind to demo-lockfile drift. Since the demo job (`adoption-demo-unit`) caches only the *root* `deps`/`_build` it never populates (see WR-02), the demo's real deps were never cached anyway — so this is acceptable, but the narrowing should be a conscious decision, not an accident.

**Fix:** This appears intentional (comment at lines 72-75 says "repo-root mix.lock hash"). If intended, no code change — just confirm in the phase SUMMARY that demo-lockfile drift is deliberately excluded from the root cache lineage. If the recursive behavior was meant to be preserved, restore it:
```yaml
key: ${{ steps.ns.outputs.deps_ns }}-v1-${{ runner.os }}-${{ runner.arch }}-otp${{ steps.beam.outputs.otp-version }}-elixir${{ steps.beam.outputs.elixir-version }}-${{ inputs.mix-env }}-${{ hashFiles('**/mix.lock') }}
```

### WR-02: `adoption-demo-unit` saves an empty/partial root `deps`+`_build` under the shared cache key — can serve a useless cache to sibling jobs

**File:** `.github/workflows/ci.yml:711-738`
**Issue:** `adoption-demo-unit` uses the composite (mix-env `test`, default prefix, `install-deps: false`) so it RESTORES root `deps`/`_build` under the same key `K` that `integration`, `contract`, `proof`, `package-consumer`, `adopter`, and the `quality` 1.17/27 cell all share. But this job does all real work in `working-directory: examples/adoption_demo` and never runs root `mix deps.get` or root `mix compile`. On a cache miss it will, at POST, save a near-empty root `deps/`+`_build/` tree under `K`. Because `actions/cache@v4` save is first-writer-wins, if this job finishes first it can publish an empty `_build`/`deps` under the shared key; siblings then restore an empty tree and recompile from scratch (correctness is preserved — `mix` rebuilds — but the cache provides no benefit and the OBS-01 hit/miss table will look healthy while the cache is hollow).

**Note:** This topology is **pre-existing** (pre-phase `adoption-demo-unit` already used the shared `deps-<os>-1.17-27-<hash>` keys with the same demo-only workdir), so it is not introduced by phase 104. Flagging because the composite migration was the natural opportunity to fix it and the new richer key still shares with the heavy jobs.
**Fix:** Give the demo-only job an isolated namespace so it cannot publish a hollow cache under the shared key:
```yaml
      - name: Set up Elixir
        uses: ./.github/actions/setup-elixir
        with:
          elixir-version: "1.17"
          otp-version: "27"
          mix-env: test
          cache-prefix: adoption-demo   # isolate from the heavy shared deps/_build cache
          install-deps: "false"
```

### WR-03: `cors-allow-origin` interpolated directly into the `docker run` command string — template-injection / quote-breakout surface

**File:** `.github/actions/setup-minio/action.yml:23`
**Issue:** `inputs.cors-allow-origin` is expanded by the GitHub Actions template engine directly into the bash `run:` body (`format('-e MINIO_API_CORS_ALLOW_ORIGIN=''{0}''', inputs.cors-allow-origin)`). The single-quote wrapping is applied at template-expansion time, so a value containing a single quote (e.g. `'; docker rm -f $(docker ps -aq); #`) would break out of the quoting and inject shell. Today the only caller passes the literal `'*'` (trusted), and the input is not wired to any `github.*` untrusted context, so exploitability is low — but this is the canonical GitHub Actions "do not interpolate inputs into run scripts" anti-pattern and should be hardened.
**Fix:** Pass the value through the environment instead of string-splicing it into the command:
```yaml
    - name: Start MinIO
      shell: bash
      env:
        CORS_ALLOW_ORIGIN: ${{ inputs.cors-allow-origin }}
      run: |
        cors_args=()
        if [ -n "$CORS_ALLOW_ORIGIN" ]; then
          cors_args=(-e "MINIO_API_CORS_ALLOW_ORIGIN=$CORS_ALLOW_ORIGIN")
        fi
        docker run -d --name rindle-minio -p 9000:9000 \
          -e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin \
          "${cors_args[@]}" \
          minio/minio server /data --console-address ":9001"
        for _ in $(seq 1 30); do
          if curl -fsS http://localhost:9000/minio/health/ready >/dev/null; then exit 0; fi
          sleep 2
        done
        exit 1
```

### WR-04: `inputs.cache-prefix` interpolated into bash `if`/`echo` — same template-injection class

**File:** `.github/actions/setup-elixir/action.yml:64,68,69`
**Issue:** `${{ inputs.cache-prefix }}` is spliced into the `Compute cache namespaces` bash body inside `[ "..." = "default" ]`, `[ -z "..." ]`, and `echo "deps_ns=deps-..."`. A value containing `"` / `]` / `;` would break the test or inject into `$GITHUB_OUTPUT`. Only two trusted literal callers exist (`default`, `no-optional`), so practical risk is low, but it is the same anti-pattern as WR-03 and trivially hardened.
**Fix:** Read the input from `env:` rather than interpolating into the script:
```yaml
    - name: Compute cache namespaces
      id: ns
      shell: bash
      env:
        CACHE_PREFIX: ${{ inputs.cache-prefix }}
      run: |
        if [ "$CACHE_PREFIX" = "default" ] || [ -z "$CACHE_PREFIX" ]; then
          echo "deps_ns=deps"  >> "$GITHUB_OUTPUT"
          echo "build_ns=build" >> "$GITHUB_OUTPUT"
        else
          echo "deps_ns=deps-$CACHE_PREFIX"   >> "$GITHUB_OUTPUT"
          echo "build_ns=build-$CACHE_PREFIX" >> "$GITHUB_OUTPUT"
        fi
```

## Info

### IN-01: MinIO `mc` client and `minio/minio` image are unpinned (supply-chain)

**File:** `.github/actions/setup-minio/action.yml:23,35`
**Issue:** `minio/minio` resolves to `:latest` (no tag) and `mc` is downloaded from `dl.min.io/.../release/linux-amd64/mc` with no version pin and no checksum/signature verification. A compromised or breaking upstream release would silently flow into CI (and into the `release.yml` publish path that now uses this composite). This is **pre-existing** (byte-identical to the prior inline steps), and the composite centralizes it — which is actually the upside: a single place to add a pin now exists.
**Fix:** Pin the image (e.g. `minio/minio:RELEASE.2025-…`) and the `mc` binary to a known release URL, and verify the downloaded `mc` against a published `mc.sha256sum` before `chmod +x`.

### IN-02: PLT cache key uses coarse `matrix.otp`/`matrix.elixir` while deps/build use resolved patch versions — known asymmetry

**File:** `.github/workflows/ci.yml:191,193,211`
**Issue:** The PLT restore/save (`CACHE-03`) keys on `otp${{ matrix.otp }}-elixir${{ matrix.elixir }}` (coarse `26`/`1.17`), whereas the composite deps/build keys use the `setup-beam`-resolved patch versions. A patch-level OTP/Elixir bump (same matrix label) would reuse a PLT built against a different patch. PLT format is generally stable across patch releases so this is low-risk, and the asymmetry is explicitly documented at lines 183-185 (the composite does not surface resolved versions at job scope). Noted for awareness only; no action required unless a patch-bump dialyzer mismatch is ever observed.
**Fix:** If tighter invalidation is ever wanted, surface `otp-version`/`elixir-version` as composite outputs (the `id: beam` step already has them) and feed them into the PLT key.

---

_Reviewed: 2026-06-21_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
