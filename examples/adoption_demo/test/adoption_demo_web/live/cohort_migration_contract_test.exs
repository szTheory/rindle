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
      refutes any `raw(` token leaked into the rendered route HTML (HEEx auto-escape,
      T-99-01-02 / T-101-01).

    * `assert_daisyui_retired/1` — refutes the known daisyUI/Tailwind utility
      classes from the full composed route render, including shared `Layouts.app`
      chrome and flash. Phase 101 promoted the scan from the old `[data-ck-root]`
      body slice so shared scaffold regressions cannot hide outside the page shell.
      The retired-class list lives only as data here, never echoed in page-renderable
      prose.
  """
  use AdoptionDemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # The daisyUI/Tailwind utility classes a migrated route must NOT contain after
  # the Cohort swap (Pitfall 6). Kept as DATA — never echoed in a comment a
  # rendered page could contain. Each entry is a literal substring scanned for in
  # the full composed render; class-boundary literals prevent false failures on
  # Cohort classes such as `.ck-btn`, `.ck-tab`, and `.ck-tabs`.
  @retired_daisyui_classes [
    ~s(class="btn"),
    ~s(class="px-4 py-8),
    ~s(class="mx-auto max-w-3xl),
    ~s(class="toast),
    ~s(class="alert),
    "text-2xl",
    "text-lg",
    "bg-gray-",
    "list-disc",
    "opacity-80",
    "space-y-",
    "mx-auto max-w-3xl",
    "toast-top",
    "toast-end",
    "alert-info",
    "alert-error",
    "font-mono text-sm",
    # daisyUI tab classes are anchored to the class-attribute leading position
    # (`class="tabs tabs-boxed"`, `class="tab px-3 ..."`) so they can't substring-match
    # the Cohort DS's own `class="ck-tabs__..."`/`class="ck-tab..."` nor the prose word "tab".
    ~s(class="tabs ),
    "text-red-600",
    ~s(class="tab ),
    "break-all"
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
  Assert every retired daisyUI/Tailwind utility class is absent from the full
  composed route HTML, including shared layout chrome and flash.
  """
  def assert_daisyui_retired(html) do
    for klass <- @retired_daisyui_classes do
      refute String.contains?(html, klass),
             "expected the retired daisyUI utility #{inspect(klass)} to be absent from the full composed render"
    end

    :ok
  end

  defp adoption_demo_path(path) do
    [__DIR__, "../../..", path]
    |> Path.join()
    |> Path.expand()
  end

  defp occurrence_count(html, literal) do
    html
    |> String.split(literal)
    |> length()
    |> Kernel.-(1)
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

  test "assert_daisyui_retired scans the full composed render" do
    html = ~s(<main class="px-4 py-8"><div data-ck-root class="ck">clean body</div></main>)

    assert_raise ExUnit.AssertionError, ~r/retired daisyUI utility/, fn ->
      assert_daisyui_retired(html)
    end
  end

  # --- Plan 101-02: layout wrapper retirement contract ----------------------
  test "Layouts.app renders bare Cohort chrome without Tailwind width or padding wrapper", %{
    conn: conn
  } do
    html = render_route(conn, ~p"/dashboard")

    assert occurrence_count(html, ~s(<nav class="ck-nav")) == 1
    assert occurrence_count(html, "<main>") == 1
    assert occurrence_count(html, ~s(<footer class="ck-footer")) == 1
    assert occurrence_count(html, ~s(id="flash-group")) == 1

    refute html =~ ~s(<main class="px-4 py-8)
    refute html =~ ~s(class="mx-auto max-w-3xl)
    refute html =~ "space-y-4"
  end

  # --- Plan 101-01: flash retirement contract ------------------------------
  # These render-component assertions pin the shared flash surface before the
  # destructive default.css teardown. They intentionally target exact retired
  # flash/icon/button scaffold literals so Cohort classes such as .ck-btn and
  # .ck-tabs cannot false-fail.
  test "flash renders Cohort info status without daisyUI or Heroicon classes" do
    html =
      render_component(&AdoptionDemoWeb.CoreComponents.flash/1, %{
        id: "flash-info",
        kind: :info,
        flash: %{"info" => "Upload complete"}
      })

    assert html =~ ~s(id="flash-info")
    assert html =~ ~s(class="ck ck-flash")
    assert html =~ "ck-alert ck-alert--info"
    assert html =~ ~s(role="status")
    assert html =~ ~s(aria-live="polite")
    assert html =~ "<svg"
    assert html =~ ~s(aria-hidden="true")
    assert html =~ ~s(aria-label="Close notification")
    assert html =~ ~s(phx-click="lv:clear-flash")
    assert html =~ ~s(phx-value-key="info")
    assert html =~ "Upload complete"

    refute html =~ ~s(class="toast)
    refute html =~ "toast-top"
    refute html =~ "alert-info"
    refute html =~ "hero-information-circle"
    refute html =~ "hero-x-mark"
  end

  test "flash renders Cohort error alert semantics without daisyUI or Heroicon classes" do
    html =
      render_component(&AdoptionDemoWeb.CoreComponents.flash/1, %{
        id: "flash-error",
        kind: :error,
        flash: %{"error" => "Upload failed - resume from the last chunk"}
      })

    assert html =~ ~s(id="flash-error")
    assert html =~ ~s(class="ck ck-flash")
    assert html =~ "ck-alert ck-alert--error"
    assert html =~ ~s(role="alert")
    assert html =~ ~s(aria-live="assertive")
    assert html =~ "<svg"
    assert html =~ ~s(aria-hidden="true")
    assert html =~ ~s(aria-label="Close notification")
    assert html =~ ~s(phx-click="lv:clear-flash")
    assert html =~ ~s(phx-value-key="error")
    assert html =~ "Upload failed - resume from the last chunk"

    refute html =~ ~s(class="toast)
    refute html =~ "toast-top"
    refute html =~ "alert-error"
    refute html =~ "hero-exclamation-circle"
    refute html =~ "hero-x-mark"
  end

  test "CoreComponents source has retired flash and button scaffold literals" do
    source =
      __DIR__
      |> Path.join("../../../lib/adoption_demo_web/components/core_components.ex")
      |> Path.expand()
      |> File.read!()

    for literal <- [
          ~s(class="toast),
          "toast-top",
          ~s(class="alert),
          "alert-info",
          "alert-error",
          "hero-information-circle",
          "hero-exclamation-circle",
          "hero-x-mark",
          "btn-primary",
          "btn-soft"
        ] do
      refute source =~ literal,
             "expected #{inspect(literal)} to be retired from CoreComponents source"
    end

    refute source =~ "raw(",
           "CoreComponents must keep escaped HEEx interpolation and avoid raw/1"
  end

  test "Phase 101 source and deleted generator files stay retired" do
    source_files = [
      adoption_demo_path("lib/adoption_demo_web/components/core_components.ex"),
      adoption_demo_path("lib/adoption_demo_web/components/layouts.ex"),
      adoption_demo_path("lib/adoption_demo_web/components/layouts/root.html.heex")
    ]

    for path <- source_files do
      source = File.read!(path)

      for literal <- [
            ~s(class="toast),
            "toast-top",
            "toast-end",
            ~s(class="alert),
            "alert-info",
            "alert-error",
            "hero-information-circle",
            "hero-exclamation-circle",
            "hero-x-mark",
            "btn-primary",
            "btn-soft",
            ~s(class="px-4 py-8),
            "mx-auto max-w-3xl",
            "space-y-4"
          ] do
        refute source =~ literal,
               "expected #{inspect(literal)} to stay retired from #{Path.relative_to_cwd(path)}"
      end
    end

    root = File.read!(adoption_demo_path("lib/adoption_demo_web/components/layouts/root.html.heex"))

    assert root =~ ~s(~p"/assets/css/app.css")
    assert root =~ ~s(~p"/assets/cohort.css")

    for path <- [
          "lib/adoption_demo_web/controllers/page_controller.ex",
          "lib/adoption_demo_web/controllers/page_html.ex",
          "lib/adoption_demo_web/controllers/page_html/home.html.heex",
          "test/adoption_demo_web/controllers/page_controller_test.exs"
        ] do
      refute File.exists?(adoption_demo_path(path)),
             "expected deleted Phoenix generator artifact #{path} to stay absent"
    end

    router = File.read!(adoption_demo_path("lib/adoption_demo_web/router.ex"))

    refute router =~ "PageController"
    refute router =~ "PageHTML"
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
      recipe_digest: "digest_thumb_contract",
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

  # --- Plan 100-01: /upload per-tab frozen-contract + daisyUI-retirement ------
  # /upload is the heaviest Cohort inner page (6 tabs, 4 phx-hook flows, 2 forms).
  # load_member!(nil) falls back to the first seeded member, so ?tab=X renders
  # with no id. Each tab renders only its own `:if`-gated panel, so we assert the
  # always-present contract (member line + all 6 tab links) plus the active tab's
  # panel selectors per tab, then daisyUI-retirement. The `:if`-only selectors
  # (tus-upload-error / image-upload-asset-id / mux-streaming-url) render only
  # after a handler fires — they are the behavior specs' backstop, NOT asserted
  # statically. The a11y shape (routed links, not a tablist) is pinned once.
  test "/upload preserves its frozen contract and retires daisyUI across all tabs", %{conn: conn} do
    for tab <- ~w(image tus video multipart liveview mux) do
      html = render_route(conn, ~p"/upload?tab=#{tab}")

      # always-present (every tab): the member line + all 6 tab links + .ck shell
      assert_frozen_contract(html, [
        ~s(data-testid="upload-member-name"),
        ~s(id="upload-member-name"),
        ~s(data-testid="upload-tab-image"),
        ~s(data-testid="upload-tab-tus"),
        ~s(data-testid="upload-tab-video"),
        ~s(data-testid="upload-tab-multipart"),
        ~s(data-testid="upload-tab-liveview"),
        ~s(data-testid="upload-tab-mux")
      ])

      # active-panel selectors per tab (only the :if-rendered panel is in the DOM)
      assert_frozen_contract(html, panel_contract(tab))

      # routed-tab a11y shape: links carry aria-current, NOT a role=tablist/tab
      assert html =~ ~s(aria-current="page"),
             "expected the active routed tab to carry aria-current=\"page\""

      refute html =~ ~s(role="tablist"),
             "the routed tab strip must be navigation links, not a role=tablist"

      refute html =~ ~s(role="tab"),
             "the routed tab strip must be navigation links, not role=tab"

      assert_daisyui_retired(html)
    end
  end

  defp panel_contract("image"),
    do: [
      ~s(id="image-upload-panel"),
      ~s(data-testid="image-upload-status"),
      ~s(id="image-file-input"),
      ~s(phx-hook="PresignedPut")
    ]

  defp panel_contract("tus"),
    do: [
      ~s(id="tus-upload-panel"),
      ~s(data-testid="tus-upload-status"),
      ~s(id="tus-form"),
      ~s(phx-submit="save_tus"),
      ~s(id="tus-submit")
    ]

  defp panel_contract("video"),
    do: [
      ~s(id="video-upload-panel"),
      ~s(data-testid="video-upload-status"),
      ~s(id="video-file-input"),
      ~s(phx-hook="PresignedVideoPut")
    ]

  defp panel_contract("multipart"),
    do: [
      ~s(id="multipart-upload-panel"),
      ~s(data-testid="multipart-upload-status"),
      ~s(id="multipart-upload-button"),
      ~s(phx-hook="MultipartUpload")
    ]

  defp panel_contract("liveview"),
    do: [
      ~s(id="liveview-upload-panel"),
      ~s(data-testid="liveview-upload-status"),
      ~s(id="liveview-form"),
      ~s(phx-submit="save_liveview"),
      ~s(id="liveview-submit")
    ]

  defp panel_contract("mux"),
    do: [
      ~s(id="mux-upload-panel"),
      ~s(data-testid="mux-upload-status"),
      ~s(id="mux-file-input"),
      ~s(phx-hook="PresignedMuxPut")
    ]
end
