defmodule Rindle.FocusVisibleModalityGuardTest do
  @moduledoc """
  LOCK-04 (Phase 111, D-03) — focus-visible keyboard-modality regression lock.

  A merge-blocking meta-test that locks the Plan 03 dedupe: post-dedupe the raw
  `:focus-visible` modality call lives in EXACTLY ONE place — the shared
  `focusVisibly(page, locator)` helper in `admin-polish.js`. This guard asserts the
  POST-DEDUPE invariant so a future fourth focus check that copies the raw modality
  call (without the Tab press, without the shared helper) goes RED in CI — the exact
  "duplicated in two places at once" footgun that produced the original
  `:focus-visible` flake.

  ## What it asserts (dual-assert, D-03)

  1. **Tab-first ordering** — the `focusVisibly` helper presses a real `Tab`
     (flipping headless Chromium into keyboard-focus mode) BEFORE it runs the
     programmatic focus call-form. Asserted by index order inside the helper file.
  2. **Single-source-of-truth** — counting the CODE CALL-FORM occurrences (the
     `el.focus({ focusVisible: true })` expression, NOT the bare `focusVisible: true`
     substring, which ALSO appears in explanatory comments), `admin-polish.js` has
     EXACTLY ONE (inside the helper) and `admin-gallery-check.mjs` has ZERO (it calls
     the helper). This count pair catches a future 4th copy in EITHER file.

  ## Why the CODE call-form, not the bare substring

  The bare token `focusVisible: true` appears in backtick-wrapped prose comments
  (admin-polish.js explains the workaround; the gallery references it). A bare-substring
  count would see those comment occurrences and assert a wrong number — either
  always-red or, worse, masking a real bypass. The call-form expression
  (`.focus(` + `{` + the focusVisible option + `}` + `)`) appears ONLY at real call
  sites, never in those prose comments, so counting it is immune to the comment noise
  (T-111-09). The call-form regex is built at runtime from fragments so the bare prose
  literal is not written as a standalone grep-able token in this file.

  ## Anti-vacuous guards

  - `assert files != []` so a mis-rooted or empty harness list fails loudly instead of
    vacuously passing (T-111-10).
  - The guard keys off the PRESENCE of the call-form / helper, so a file that silently
    drops the feature cannot exempt itself.

  ## SHIPPED artifacts ONLY

  Reads `examples/` and `brandbook/` SHIPPED harness paths only — never a `.planning/`
  path (those move when a milestone is archived; the LOCK-05 planning-path-hygiene
  sibling would red-gate this file otherwise). `async: true`, no exclude tag → rides the
  default suite / merge-blocking `quality` lane like the other Phase 111 meta-tests.
  """
  use ExUnit.Case, async: true

  @repo_root Path.expand("..", __DIR__)

  @admin_polish "examples/adoption_demo/e2e/support/admin-polish.js"
  @gallery "brandbook/src/admin-gallery-check.mjs"

  @harnesses [@admin_polish, @gallery]

  # The CODE call-form matcher, assembled from fragments at runtime so the bare prose
  # literal is NOT written as a standalone grep-able token in this test file. Matches
  # `.focus({ focusVisible: true })` with flexible inner spacing — the real call site
  # only, never the backtick-prose comments that mention the bare option name.
  defp call_form_regex do
    option = "focusVisible" <> ":" <> "\\s+" <> "true"
    Regex.compile!("focus\\(\\s*\\{\\s*" <> option <> "\\s*\\}\\s*\\)")
  end

  defp read_harness(relpath), do: File.read!(Path.join(@repo_root, relpath))

  defp call_form_offenders(relpath) do
    read_harness(relpath)
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _n} -> Regex.match?(call_form_regex(), line) end)
    |> Enum.map(fn {line, n} -> {Path.basename(relpath), n, String.trim(line)} end)
  end

  defp count_failure_message(offenders, expected, relpath) do
    listing =
      offenders
      |> Enum.sort()
      |> Enum.map_join("\n", fn {file, n, line} -> "  - #{file}:#{n}: #{line}" end)

    """
    Expected #{Path.basename(relpath)} to contain EXACTLY #{expected} focusVisible \
    modality call-form occurrence(s), found #{length(offenders)}:

    #{listing}

    Post-dedupe (Plan 03), the raw `:focus-visible` modality call lives ONLY inside the \
    shared `focusVisibly(page, locator)` helper in admin-polish.js. A new occurrence here \
    is a future copy that bypasses the helper (and likely forgets the Tab press) — \
    reintroducing the original flake. Route the new focus site through `focusVisibly` \
    instead of inlining the raw call-form (LOCK-04, D-03).
    """
  end

  test "the shared focusVisibly helper presses Tab before the programmatic focus" do
    helper = read_harness(@admin_polish)

    assert helper =~ ~r/function\s+focusVisibly|focusVisibly\s*=\s*(async\s*)?\(/,
           "admin-polish.js must define the shared focusVisibly helper " <>
             "(the single source of truth for the Tab-first :focus-visible workaround)"

    # Index-order assertion: the Tab press must precede the focus call-form. Both
    # :binary.match / Regex.run raise (or return nil → KeyError on elem) if the token is
    # ABSENT, so this fails loudly if the helper drops the Tab press OR the focus call.
    tab_idx = :binary.match(helper, ~s|keyboard.press("Tab")|) |> elem(0)

    [{fv_idx, _len}] = Regex.run(call_form_regex(), helper, return: :index)

    assert tab_idx < fv_idx,
           "focusVisibly must press Tab (idx #{tab_idx}) BEFORE the focusVisible focus " <>
             "call-form (idx #{fv_idx}); a real keyboard interaction must flip Chromium " <>
             "into keyboard-focus mode before the programmatic focus, or the ring does " <>
             "not deterministically paint (the original flake)."
  end

  test "no harness calls the raw focusVisible call-form outside the shared helper" do
    files =
      @harnesses
      |> Enum.map(&Path.join(@repo_root, &1))
      |> Enum.filter(&File.exists?/1)

    # Anti-vacuous (T-111-10 / RESEARCH Pitfall 5): an empty or mis-rooted harness list
    # must fail loudly, not silently pass.
    assert files != [],
           "expected the focus-visible harness list to resolve to files under " <>
             "#{@repo_root}, got none — the guard would otherwise pass vacuously"

    # Count-based dual-assert (RESEARCH Pattern 2 / Open Q1, D-03): admin-polish.js has
    # EXACTLY ONE call-form (inside focusVisibly); the gallery has ZERO (it calls the
    # helper). This pair catches a future 4th copy in EITHER file.
    polish_offenders = call_form_offenders(@admin_polish)
    gallery_offenders = call_form_offenders(@gallery)

    assert length(polish_offenders) == 1,
           count_failure_message(polish_offenders, 1, @admin_polish)

    assert gallery_offenders == [],
           count_failure_message(gallery_offenders, 0, @gallery)
  end
end
