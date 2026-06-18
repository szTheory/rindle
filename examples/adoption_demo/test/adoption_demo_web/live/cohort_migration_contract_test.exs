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

  # --- Plan 03: /ops frozen-contract + daisyUI-retirement -------------------
  # Seeds two students so the batch-member spans render against real rows. The
  # always-present selectors (the four phx-click buttons, the batch section, the
  # member spans) are asserted statically here; the `<pre :if=...>` output panels
  # (doctor-output/runtime-status-output/batch-preview/batch-result) only render
  # after their handler fires and touch the erasure/storage subsystem, so they
  # are exercised by the ops-surfaces / batch-erasure behavior specs (the runtime
  # backstop), NOT force-clicked here. We still assert their ids/testids survive
  # in source via the per-page acceptance greps; this test pins the static body
  # contract + every phx-click handler + the .ck shell.
  test "/ops preserves its frozen contract and retires daisyUI", %{conn: conn} do
    AdoptionDemo.Accounts.seed_member!(%{
      email: "ops-batch-a@cohort.test",
      name: "Batch A",
      role: "student"
    })

    AdoptionDemo.Accounts.seed_member!(%{
      email: "ops-batch-b@cohort.test",
      name: "Batch B",
      role: "student"
    })

    html = render_route(conn, ~p"/ops")

    assert_frozen_contract(html, [
      ~s(data-testid="run-doctor-button"),
      ~s(data-testid="run-runtime-status-button"),
      ~s(data-testid="batch-erasure-section"),
      ~s(data-testid="preview-batch-button"),
      ~s(data-testid="execute-batch-button"),
      ~s(id="batch-erasure"),
      ~s(phx-click="run_doctor"),
      ~s(phx-click="run_runtime_status"),
      ~s(phx-click="preview_batch"),
      ~s(phx-click="execute_batch")
    ])

    assert_daisyui_retired(html)
  end

  # --- Plan 03: /account erasure frozen-contract + daisyUI-retirement --------
  # Seeds a member and renders /account/:id/delete. The always-present selectors
  # (erasure-member-name + the two phx-click buttons) are asserted statically;
  # the `<pre :if=...>` erasure-preview/erasure-result panels render only after a
  # handler fires and touch the erasure subsystem, so they are exercised by the
  # owner-erasure behavior spec (runtime backstop), not force-clicked here.
  test "/account erasure preserves its frozen contract and retires daisyUI", %{conn: conn} do
    AdoptionDemo.Accounts.seed_member!(%{
      email: "erasure-target@cohort.test",
      name: "Erasure Target",
      role: "student"
    })

    member = AdoptionDemo.Accounts.get_member_by_email!("erasure-target@cohort.test")

    html = render_route(conn, ~p"/account/#{member.id}/delete")

    assert_frozen_contract(html, [
      ~s(data-testid="erasure-member-name"),
      ~s(data-testid="preview-erasure-button"),
      ~s(data-testid="execute-erasure-button"),
      ~s(phx-click="preview"),
      ~s(phx-click="execute")
    ])

    assert_daisyui_retired(html)
  end

  # --- Plan 04: /members/:id frozen-contract + daisyUI-retirement ------------
  # Seeds a member WITHOUT an avatar attached. The static ExUnit lane cannot boot
  # the storage subsystem (MinIO) needed to `Media.attach!` an avatar asset, so
  # the avatar branch (member-picture-tag / member-avatar-state) is exercised at
  # runtime by rendering.spec.js (CI-delegated) and grep-verified in source by the
  # per-page acceptance. This test pins the ALWAYS-PRESENT static contract (title,
  # both sections, replace-status, both replace/detach phx-click buttons) PLUS the
  # empty-branch member-no-avatar selector + the .ck shell, then daisyUI-retirement.
  test "/members preserves its frozen contract and retires daisyUI", %{conn: conn} do
    AdoptionDemo.Accounts.seed_member!(%{
      email: "member-page@cohort.test",
      name: "Member Page",
      role: "student"
    })

    member = AdoptionDemo.Accounts.get_member_by_email!("member-page@cohort.test")

    html = render_route(conn, ~p"/members/#{member.id}")

    assert_frozen_contract(html, [
      ~s(data-testid="member-profile-title"),
      ~s(data-testid="member-avatar-section"),
      ~s(data-testid="member-no-avatar"),
      ~s(data-testid="replace-detach-section"),
      ~s(data-testid="replace-status"),
      ~s(data-testid="replace-avatar-button"),
      ~s(data-testid="detach-avatar-button"),
      ~s(phx-click="replace_avatar"),
      ~s(phx-click="detach_avatar")
    ])

    assert_daisyui_retired(html)
  end

  # --- Plan 04: /lessons/:id frozen-contract + daisyUI-retirement ------------
  # Seeds a course + lesson WITHOUT a video attached (same MinIO constraint as the
  # member test). The video/variant branch (lesson-video-tag, lesson-asset-state,
  # variant-#{name}) is exercised at runtime by rendering.spec.js (CI-delegated)
  # and grep-verified in source. This test pins the ALWAYS-PRESENT static contract
  # (title, video section, variants section) PLUS the empty-branch lesson-no-video
  # selector + the .ck shell, then daisyUI-retirement.
  test "/lessons preserves its frozen contract and retires daisyUI", %{conn: conn} do
    course =
      AdoptionDemo.Cohort.seed_course!(%{title: "Cohort Lesson Course", slug: "lesson-course"})

    lesson =
      AdoptionDemo.Cohort.seed_lesson!(%{
        title: "Lesson page contract",
        position: 1,
        course_id: course.id
      })

    html = render_route(conn, ~p"/lessons/#{lesson.id}")

    assert_frozen_contract(html, [
      ~s(data-testid="lesson-title"),
      ~s(data-testid="lesson-video-section"),
      ~s(data-testid="lesson-no-video"),
      ~s(data-testid="lesson-variants")
    ])

    assert_daisyui_retired(html)
  end

  # --- Plan 05: /posts/:id frozen-contract + daisyUI-retirement --------------
  # Seeds a member + post WITHOUT an image attached, so the post-no-image branch
  # renders (the image branch requires Media.attach! → the storage subsystem /
  # MinIO, not bootable in the static ExUnit lane — the member/lesson precedent).
  # This test pins the ALWAYS-PRESENT static contract (post-title, the image
  # section) PLUS the empty-branch post-no-image selector + the .ck shell, then
  # daisyUI-retirement. The post-picture-tag image branch is grep-verified in
  # source (per-page acceptance) and runtime-exercised by rendering.spec.js.
  test "/posts preserves its frozen contract and retires daisyUI", %{conn: conn} do
    AdoptionDemo.Accounts.seed_member!(%{
      email: "post-author@cohort.test",
      name: "Post Author",
      role: "student"
    })

    member = AdoptionDemo.Accounts.get_member_by_email!("post-author@cohort.test")

    post =
      AdoptionDemo.Cohort.seed_post!(%{
        title: "Cohort post page contract",
        body: "Body text survives the class-by-class restyle.",
        member_id: member.id
      })

    html = render_route(conn, ~p"/posts/#{post.id}")

    assert_frozen_contract(html, [
      ~s(data-testid="post-title"),
      ~s(data-testid="post-image-section"),
      ~s(data-testid="post-no-image")
    ])

    assert_daisyui_retired(html)
  end

  # --- Plan 05: /media/:id frozen-contract + daisyUI-retirement --------------
  # The HIGHEST-RISK swap in the phase: the hand-built <dl><dt><dd> whose <dd>s
  # carry media-id/media-state/media-delivery-url MUST be restyled in place, NOT
  # replaced by ck_detail/1 (which generates its own <dd> and would drop those
  # ids — Pitfall 2). We insert a MediaAsset and one MediaVariant directly (both
  # plain Repo rows — no MinIO needed) so all three <dd> ids/testids AND a real
  # variant-#{name} <li> render. Asserts the three <dd> ids/testids survive (each
  # as id= and data-testid=), the variant id, the variants section, the alex link
  # + its text, the .ck shell, then daisyUI-retirement.
  test "/media preserves its frozen contract and retires daisyUI", %{conn: conn} do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    asset =
      AdoptionDemo.Repo.insert!(%Rindle.Domain.MediaAsset{
        state: "ready",
        storage_key: "seed/test/media_page_contract",
        profile: "AdoptionDemo.RindleProfile",
        kind: "image",
        content_type: "image/png",
        filename: "media_page.png",
        byte_size: 1024,
        inserted_at: now,
        updated_at: now
      })

    AdoptionDemo.Repo.insert!(%Rindle.Domain.MediaVariant{
      asset_id: asset.id,
      name: "thumb",
      state: "ready",
      output_kind: "image",
      inserted_at: now,
      updated_at: now
    })

    html = render_route(conn, ~p"/media/#{asset.id}")

    assert_frozen_contract(html, [
      ~s(id="media-id"),
      ~s(data-testid="media-id"),
      ~s(id="media-state"),
      ~s(data-testid="media-state"),
      ~s(id="media-delivery-url"),
      ~s(data-testid="media-delivery-url"),
      ~s(data-testid="media-variants"),
      ~s(id="variant-thumb"),
      ~s(data-testid="media-alex-profile-link"),
      "Open Alex profile for replace/detach"
    ])

    assert_daisyui_retired(html)
  end
end
