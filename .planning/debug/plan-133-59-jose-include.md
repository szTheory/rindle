---
status: complete
trigger: "Plan 133-59 mix ci failed under Elixir 1.17.3/OTP 27 because JOSE could not read _build/test/lib/jose/include/jose_jwt.hrl (enoent) in the detached MIX_BUILD_ROOT worktree; determine the root cause without rerunning or reusing SHA 8e56d85c4339be69ecff482c7ee9c5611c20dc3d."
created: 2026-09-30
updated: 2026-09-30
---

# Debug Session: Plan 133-59 JOSE include missing

## Symptoms

- **Expected:** The supported Elixir 1.17.3 / OTP 27 `mix ci` gate compiles dependencies and completes with a nonzero test count.
- **Actual:** The sole recorded Plan 133-59 `mix ci` exited 1 while compiling `lib/jose/jwt.ex`; CI did not reach tests and coverage was not started.
- **Error:** Elixir's `Record.Extractor.read_file/2` returned `{:error, :enoent}` for the detached worktree path `_build/test/lib/jose/include/jose_jwt.hrl`.
- **Timeline:** The attempt is recorded in `133-59-LOCAL-GATES.json` as occurring on 2026-09-30; it followed a successful `mix deps.get` in the same clean detached worktree.
- **Reproduction boundary:** The failing runner and SHA are immutable historical evidence. Do not rerun Mix, CI, coverage, build tasks, or check out/use SHA `8e56d85c4339be69ecff482c7ee9c5611c20dc3d` as an execution subject. Investigate from committed source, dependency metadata, and recorded artifacts only.

## Current Focus

- **hypothesis:** `Record.extract/2` resolves JOSE's header under the compiled app directory; the preserved failure proves that path lacked `include/jose_jwt.hrl`, but current static evidence may not distinguish why the include was absent there.
- **test:** Compare JOSE's source/package declarations, pinned dependency metadata, runner path overrides, and the exact failure path. Do not execute compilation or tests.
- **expecting:** Establish the failing lookup mechanism and determine whether available artifacts identify the upstream cause.
- **next_action:** Closed at the static-evidence limit with the confirmed lookup failure, unresolved initiating cause, missing evidence, and safest next diagnostic recorded below.
- **reasoning_checkpoint:** `mix deps.get` exited 0, so the initial evidence narrows the failure to dependency contents/build output/layout or compile-time path selection. The full transient CI log was removed by runner cleanup; only the final excerpt and structured status remain.

## Evidence

- timestamp: 2026-09-30 — `.planning/phases/133-evidence-charter-and-live-truth/133-59-LOCAL-GATES.json` records exact SHA `8e56d85c4339be69ecff482c7ee9c5611c20dc3d`, `mix deps.get` exit 0, one `mix ci` exit 1, JOSE `jose_jwt.hrl` `enoent`, zero test count, and zero coverage invocations.
- timestamp: 2026-09-30 — `133-59-SUMMARY.md` states the runner set `MIX_BUILD_ROOT` to the detached worktree `_build`, `MIX_ENV=test`, and `MIX_DEPS_PATH` to that worktree's `deps`; cleanup removed the full temporary log and worktree.
- timestamp: 2026-09-30 — `mix.lock` pins Hex JOSE 1.11.12 (Mix and Rebar3), and `mix.exs` allows JOSE through the optional dependency declaration; JOSE is also transitively required by Goth and Mux.
- timestamp: 2026-09-30 — Available JOSE 1.11.12 source declares `include` in its Hex package files, the checked-in `deps/jose/include/jose_jwt.hrl` exists, and `deps/jose/lib/jose/jwt.ex:41` calls `Record.extract(:jose_jwt, from_lib: "jose/include/jose_jwt.hrl")`. This establishes the header is package source and the lookup is via the application library path, not a generated header.
- timestamp: 2026-09-30 — Runner sets `MIX_BUILD_ROOT=<worktree>/_build`, clears `MIX_BUILD_PATH`, and sets `MIX_DEPS_PATH=<worktree>/deps`; the recorded ENOENT is specifically in `<worktree>/_build/test/lib/jose/include/...`, the compiled-app include location. Static code cannot establish why that include was not present in the failed transient worktree.
- timestamp: 2026-09-30 — Current checkout is descended from the recorded subject, but current `deps/jose` is not a preserved snapshot of the deleted transient worktree. No permitted command was run against the forbidden SHA; investigation used read-only source/artifact inspection.
- timestamp: 2026-09-30 — Plan 58 summary records that an earlier diagnostic using the prior shared `MIX_BUILD_PATH` failed earlier at the same JOSE include compilation step. This weakens the theory that Plan 58's `MIX_BUILD_ROOT`/`MIX_DEPS_PATH` isolation change alone introduced the missing-header symptom, but the earlier run's exact output and file state are not preserved.
- timestamp: 2026-09-30 — Plan 58's runner tests use fake Mix to assert command ordering and environment/path values. They do not exercise real Mix dependency materialization or JOSE include lookup. Plan 59 retained only the final 60-line excerpt; its cleanup removes the full command log and worktree, preventing causal localization to deps retrieval versus compile staging.
- timestamp: 2026-09-30 — Elixir v1.17.3 Mix source confirms `MIX_BUILD_PATH` takes precedence over `MIX_BUILD_ROOT`; with `MIX_BUILD_PATH` unset, `MIX_BUILD_ROOT` supplies the root and Mix appends target/environment. `Mix.Project.build_structure/2` creates the dependency app path and symlinks or copies its `include/` and `priv/` directories there. This makes a source-vs-staged file manifest the decisive missing observation; it still does not establish which side was absent in the deleted run. Sources: [Mix.Project v1.17.3](https://github.com/elixir-lang/elixir/blob/v1.17.3/lib/mix/lib/mix/project.ex), [Mix.Dep v1.17.3](https://raw.githubusercontent.com/elixir-lang/elixir/v1.17.3/lib/mix/lib/mix/dep.ex).
- timestamp: 2026-09-30 — Official [Cargo package documentation](https://doc.rust-lang.org/cargo/commands/cargo-package.html) validates and rebuilds a pristine package archive, while [Gradle incremental-build guidance](https://docs.gradle.org/current/userguide/incremental_build.html) emphasizes declaring and fingerprinting actual file inputs/outputs. These support checking consumer-visible packaged/staged resources and retaining diagnostics; they are analogies only and do not identify the Mix/JOSE cause.

## Eliminated

-

## Resolution

- root_cause: Not determined from available static evidence. Confirmed immediate mechanism: JOSE's compile-time Record.Extractor attempted to read `jose/include/jose_jwt.hrl` through the compiled app path `_build/test/lib/jose/include`, where the recorded run observed ENOENT. The header is included in pinned JOSE source package metadata and is not generated during compilation. The available evidence does not establish why it was absent from the transient compiled app directory. Plan 58's report that the same failure also occurred with the former shared MIX_BUILD_PATH makes the Plan 58 root override an insufficiently supported initiating cause.
- fix: Not applied; diagnosis-only session.
- verification: Static inspection of the preserved Plan 59 record, runner summary/configuration, pinned JOSE metadata/source, and Plan 58 history. No Mix, build, test, CI, or coverage commands were run; the restricted SHA was not used as an execution subject.
- files_changed: Debug session record only; no application/source files changed.
- unresolved_evidence: The deleted transient worktree, full deps.get/mix ci output, and staged compiled-app directory are unavailable. The current deps/jose tree does not prove what mix deps.get materialized during the failing attempt. It remains unknown whether the include was missing directly after dependency retrieval or was not copied/present in Mix's compiled app layout.
- safest_next_diagnostic: On a fresh recovery commit distinct from the restricted SHA, create a disposable worktree and preserve complete logs plus file manifests for deps/jose/include/jose_jwt.hrl and _build/test/lib/jose/include/jose_jwt.hrl immediately after dependency retrieval and when JOSE compilation reaches Record.extract; compare the source and compiled-app paths. Do not reuse the historical subject as an execution subject.

## Recovery Option Assessment

1. **Recommended — one fresh, source-distinct instrumented qualification attempt.** Add observation only; do not alter Mix/dependency semantics until evidence points to a defect. After `mix deps.get`, record canonical path, file type, symlink target and target existence, permissions, and hash for `deps/jose/include/jose_jwt.hrl`. Run `mix ci` once on the new exact SHA; before cleanup on success or failure, preserve the corresponding metadata for `_build/test/lib/jose/include/jose_jwt.hrl`, the resolved JOSE app path, and complete bounded/redacted output. This costs about one previous qualification cycle but has the best causal and exact-subject evidence, and can become the new qualification if CI passes.
   - If the source header is absent after dependency retrieval, investigate package retrieval/extraction.
   - If source exists but staged include is absent, dangling, or unreadable, investigate Mix staging/path behavior.
   - If both are present and readable, capture `Record.extract/2`'s resolved application path and inspect code-path/path-permission behavior.
2. **Cheaper but weaker — standalone minimal Mix reproduction.** A pinned-JOSE probe can test general staging behavior at lower cost, but cannot reconstruct the deleted Plan 59 worktree; it is a narrowing tool only, not qualification or root-cause proof.
3. **Defer — runner workaround or dependency upgrade.** Copying the header or changing path variables could mask missing package/staging evidence. A version upgrade expands compatibility surface without evidence of an upstream package defect. Use either only after the new observation localizes a repeatable defect.

## Transferable DX Lesson

Cargo, Gradle, and Maven documentation all treat non-code build inputs as explicit package/resource artifacts: inspect the package inventory, declare and fingerprint inputs/outputs, verify the consumer-visible staged file, and retain full diagnostics. Maven warns that resource filtering can corrupt binary files. These practices fit Rindle's project guidance that CI is a contract surface and known footguns should be locked into checks; they do not justify applying another ecosystem's packaging workaround to this failure. No UI/brand-book decision applies to this maintainer-tooling issue.
