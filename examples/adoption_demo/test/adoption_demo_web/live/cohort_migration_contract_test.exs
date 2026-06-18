defmodule AdoptionDemoWeb.CohortMigrationContractTest do
  @moduledoc """
  Wave-0 home for the Phase 99 Cohort page-migration contract gates (D-96-05/06,
  Pitfall 6). Per-page plans (P2–P5) extend this module with one `test` per
  migrated route that calls the shared helpers below — they never re-implement
  the rendering/grep machinery.

  Two shared helpers form the frozen-contract gate:

    * `assert_frozen_contract/2` — renders a route, asserts every preserved DOM
      selector (`id=`/`data-testid=`/`phx-click=`/`phx-submit=`) still appears in
      the HTML, asserts the new `.ck` shell is present (`data-ck-root`), and
      refutes any `raw(` token leaked into the page body (HEEx auto-escape, T-99-01-02).

    * `assert_daisyui_retired/1` — refutes the known daisyUI/Tailwind utility
      classes inside the PAGE BODY (the `[data-ck-root]` subtree), proving the
      class-by-class swap is complete. The scan is scoped to the page body — NOT
      the shared `Layouts.app` `<main>`/`cohort_nav`/`cohort_footer`, which keep
      daisyUI until Phase 101 — by slicing the rendered HTML to the `data-ck-root`
      subtree. The retired-class list lives only as data here, never echoed in
      page-renderable prose.
  """
  use AdoptionDemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # The daisyUI/Tailwind utility classes a migrated page body must NOT contain
  # after the Cohort swap (Pitfall 6). Kept as DATA — never echoed in a comment a
  # rendered page could contain. Each entry is a literal substring scanned for in
  # the page body. `Layouts.app`'s own `space-y-4` wrapper is excluded by scoping
  # the scan to the `[data-ck-root]` subtree (page body), per D-96-06 / Phase 101.
  @retired_daisyui_classes [
    ~s(class="btn"),
    "text-2xl",
    "text-lg",
    "bg-gray-",
    "list-disc",
    "opacity-80",
    "space-y-",
    "font-mono text-sm"
  ]

  @doc """
  Render a Cohort LiveView route and return its full HTML string. Mirrors the
  sibling LiveView tests' `live/2` + `render/1` idiom (launchpad_live_test.exs).
  """
  def render_route(conn, route) do
    {:ok, view, _html} = live(conn, route)
    render(view)
  end

  @doc """
  Slice the rendered HTML to the page-body subtree rooted at the migrated page's
  `.ck` shell (the element carrying `data-ck-root`). Scans/refutations scope to
  this slice so the shared `Layouts.app` chrome (which keeps daisyUI until Phase
  101) never produces a false positive (D-96-06).
  """
  def page_body(html) do
    case String.split(html, "data-ck-root", parts: 2) do
      [_before, after_root] -> after_root
      [_only] -> html
    end
  end

  @doc """
  Assert the frozen DOM contract for a migrated page: every selector in
  `selectors` still appears in the rendered HTML, the new `.ck` shell is present,
  and no `raw(` leaked. `selectors` are matched as literal substrings (callers
  pass full attribute fragments, e.g. `~s(data-testid="run-doctor-button")`).
  """
  def assert_frozen_contract(html, selectors) when is_list(selectors) do
    for sel <- selectors do
      assert String.contains?(html, sel),
             "expected the frozen-contract selector #{inspect(sel)} to survive the Cohort migration"
    end

    assert html =~ "data-ck-root",
           "expected the migrated page to render the .ck shell (data-ck-root)"

    refute html =~ "raw(",
           "the migrated page must not introduce raw/1 (HEEx auto-escape, T-99-01-02)"

    :ok
  end

  @doc """
  Assert every retired daisyUI/Tailwind utility class is absent from the PAGE
  BODY (`page_body/1` subtree). The shared `Layouts.app` chrome is out of scope
  (Phase 101).
  """
  def assert_daisyui_retired(html) do
    body = page_body(html)

    for klass <- @retired_daisyui_classes do
      refute String.contains?(body, klass),
             "expected the retired daisyUI utility #{inspect(klass)} to be absent from the migrated page body"
    end

    :ok
  end

  # --- Wave-0 smoke test ----------------------------------------------------
  # Proves the shared helpers compile and run against /styleguide — which already
  # renders the .ck shell (data-ck-root) + .ck-* primitives and carries no
  # daisyUI body utilities. The 7 real per-page contract tests are added in P2–P5.
  test "shared helpers run green against /styleguide (Wave-0 smoke)", %{conn: conn} do
    html = render_route(conn, ~p"/styleguide")

    assert_frozen_contract(html, [
      ~s(data-ck-section="table"),
      ~s(data-theme=)
    ])

    assert_daisyui_retired(html)
  end

  # --- Plan 02: /dashboard frozen-contract + daisyUI-retirement -------------
  # Seeds a member + course/lesson + post so the LOAD-BEARING member-row contract
  # (id="member-#{id}" + data-testid="member-row-#{email}") and the lesson/post
  # link testids are exercised against real rows — support/cohort.js and 5+ upload
  # specs navigate via these (RESEARCH Runtime State Inventory).
  test "/dashboard preserves its frozen contract and retires daisyUI", %{conn: conn} do
    AdoptionDemo.Accounts.seed_member!(%{
      email: "maya@cohort.test",
      name: "Maya",
      role: "student"
    })

    # Re-fetch so we hold the PERSISTED row id (seed_member! uses
    # on_conflict: :nothing, which can return an unpersisted struct).
    member = AdoptionDemo.Accounts.get_member_by_email!("maya@cohort.test")

    course = AdoptionDemo.Cohort.seed_course!(%{title: "Intro to Elixir", slug: "intro-elixir"})

    lesson =
      AdoptionDemo.Cohort.seed_lesson!(%{
        title: "Pattern matching basics",
        position: 1,
        course_id: course.id
      })

    post =
      AdoptionDemo.Cohort.seed_post!(%{
        title: "Study group this week",
        body: "Anyone in?",
        member_id: member.id
      })

    html = render_route(conn, ~p"/dashboard")

    assert_frozen_contract(html, [
      ~s(data-testid="cohort-dashboard-title"),
      ~s(id="demo-members"),
      ~s(data-testid="demo-members"),
      ~s(data-testid="demo-courses"),
      ~s(data-testid="demo-posts"),
      ~s(data-testid="demo-assets"),
      ~s(id="member-#{member.id}"),
      ~s(data-testid="member-row-#{member.email}"),
      ~s(data-testid="member-no-avatar"),
      ~s(data-testid="member-upload-link"),
      ~s(data-testid="member-delete-link"),
      ~s(data-testid="lesson-link-#{lesson.id}"),
      ~s(data-testid="post-link-#{post.id}"),
      ~s(data-testid="nav-upload"),
      ~s(data-testid="nav-ops")
    ])

    assert_daisyui_retired(html)
  end
end
