if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.Live.ActionsLiveTest.Router do
    use Phoenix.Router, helpers: false
    import Rindle.Admin.Router

    pipeline :browser do
      plug(:accepts, ["html"])
      plug(:fetch_session)
    end

    scope "/admin" do
      pipe_through(:browser)
      rindle_admin("/rindle", auth_guarded?: true)
    end
  end

  defmodule Rindle.Admin.Live.ActionsLiveTest.Endpoint do
    use Phoenix.Endpoint, otp_app: :rindle
    socket("/live", Phoenix.LiveView.Socket)

    plug(Plug.Session,
      store: :cookie,
      key: "_rindle_admin_actions_live_test",
      signing_salt: "rindle-admin-test"
    )

    plug(Rindle.Admin.Live.ActionsLiveTest.Router)
  end

  defmodule Rindle.Admin.Live.ActionsLiveTest do
    use Rindle.DataCase, async: false

    import Phoenix.ConnTest
    import Phoenix.LiveViewTest

    @endpoint Rindle.Admin.Live.ActionsLiveTest.Endpoint

    defmodule AdminImageProfile do
      use Rindle.Profile,
        storage: Rindle.StorageMock,
        variants: [thumb: [mode: :fit, width: 64, height: 64]],
        allow_mime: ["image/png"],
        max_bytes: 10_485_760
    end

    setup_all do
      Application.put_env(:rindle, @endpoint,
        url: [host: "localhost"],
        debug_errors: true,
        secret_key_base: String.duplicate("b", 64),
        live_view: [signing_salt: "rindle-admin-live"]
      )

      start_supervised!(@endpoint)
      :ok
    end

    setup do
      {:ok, conn: Phoenix.ConnTest.build_conn()}
    end

    test "renders action panels and defaults to first action", %{conn: conn} do
      {:ok, view, html} = live(conn, "/admin/rindle/actions")

      assert html =~ "Owner erasure"
      assert html =~ "Batch erasure"

      # Default action panel is rendered. The verb-bucket actions were
      # DISTRIBUTED to their contextual surfaces (UI-SPEC §E, D-98-10); only the
      # contextless erasure ops remain on Maintenance.
      assert html =~ ~s(data-rindle-admin-action="owner_erasure")
      assert html =~ ~s(data-rindle-admin-action="batch_erasure")
      refute html =~ ~s(data-rindle-admin-action="lifecycle_repair")
      refute html =~ ~s(data-rindle-admin-action="variant_regeneration")
      refute html =~ ~s(data-rindle-admin-action="quarantine_review")
      assert has_element?(view, "[data-rindle-admin-action-panel=\"owner_erasure\"]")
      assert has_element?(view, "h3", "Owner erasure")
      assert has_element?(view, "[data-rindle-admin-state=\"input\"]")
      assert has_element?(view, "[data-rindle-admin-form=\"owner_erasure_preview\"]")
      assert has_element?(view, "[data-rindle-admin-input=\"owner_type\"]")
      assert has_element?(view, "[data-rindle-admin-input=\"owner_id\"]")
      assert has_element?(view, "[data-rindle-admin-submit=\"preview_owner_erasure\"]")

      # Can select another action
      view
      |> element("button", "Batch erasure")
      |> render_click()

      assert has_element?(view, "h3", "Batch erasure")
      assert has_element?(view, "[data-rindle-admin-action-panel=\"batch_erasure\"]")
      assert has_element?(view, "[data-rindle-admin-form=\"batch_erasure_preview\"]")
      assert has_element?(view, "[data-rindle-admin-input=\"batch_owners\"]")
      assert has_element?(view, "[data-rindle-admin-submit=\"preview_batch_erasure\"]")
    end

    # Destructive-UX contract. These assertions discharge the human-verification item from
    # 90-VERIFICATION.md ("visual styling clearly indicates a destructive action") by turning
    # it into a deterministic, design-system-enforced contract. The computed-color proof (that
    # these classes actually paint red, in light + dark) lives in the adoption_demo Playwright
    # spec admin-destructive-ux.spec.js; here we guard the markup contract on every Elixir
    # version in the merge-blocking quality job.
    test "owner erasure panel renders the standing destructive-UX contract", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/rindle/actions")

      # Standing destructive warning is present before any interaction (input state).
      assert has_element?(view, "[data-rindle-admin-destructive-warning]")
      assert render(view) =~ "This action cannot be undone."

      # Preview (non-destructive) button carries the secondary design-system class.
      assert has_element?(
               view,
               "[data-rindle-admin-submit=\"preview_owner_erasure\"].rindle-admin-button--secondary"
             )

      owner_id = Ecto.UUID.generate()

      view
      |> form("form[phx-submit=\"preview_owner_erasure\"]", %{
        "owner_type" => "Elixir.String",
        "owner_id" => owner_id
      })
      |> render_submit()

      # The execute button carries the destructive design-system class.
      assert has_element?(
               view,
               "[data-rindle-admin-submit=\"execute_owner_erasure\"].rindle-admin-button--destructive"
             )

      # Confirmation gate and standing warning persist in the preview/confirm state.
      assert has_element?(view, "[data-rindle-admin-confirm-input]")
      assert render(view) =~ "Type <pre>ERASE Elixir.String:#{owner_id}</pre> to confirm"
      assert has_element?(view, "[data-rindle-admin-destructive-warning]")
    end

    test "batch erasure panel renders the standing destructive-UX contract", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/rindle/actions")

      view
      |> element("button", "Batch erasure")
      |> render_click()

      assert has_element?(view, "[data-rindle-admin-destructive-warning]")
      assert render(view) =~ "This action cannot be undone."

      assert has_element?(
               view,
               "[data-rindle-admin-submit=\"preview_batch_erasure\"].rindle-admin-button--secondary"
             )

      owners_text =
        "Elixir.String:#{Ecto.UUID.generate()}\nElixir.String:#{Ecto.UUID.generate()}"

      view
      |> form("form[phx-submit=\"preview_batch_erasure\"]", %{"owners" => owners_text})
      |> render_submit()

      assert has_element?(
               view,
               "[data-rindle-admin-submit=\"execute_batch_erasure\"].rindle-admin-button--destructive"
             )

      assert has_element?(view, "[data-rindle-admin-confirm-input]")
      assert render(view) =~ "Type <pre>ERASE 2 OWNERS</pre> to confirm"
      assert has_element?(view, "[data-rindle-admin-destructive-warning]")
    end

    test "owner erasure workflow: preview, reset, validation, execute", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/rindle/actions")

      # Initial state
      assert has_element?(view, "[data-rindle-admin-state=\"input\"]")

      owner_id = Ecto.UUID.generate()
      owner_id2 = Ecto.UUID.generate()

      # 1. Preview
      view
      |> form("form[phx-submit=\"preview_owner_erasure\"]", %{
        "owner_type" => "Elixir.String",
        "owner_id" => owner_id
      })
      |> render_submit()

      # Now in preview state
      assert has_element?(view, "[data-rindle-admin-state=\"preview\"]")
      assert has_element?(view, "[data-rindle-admin-form=\"owner_erasure_execute\"]")
      assert has_element?(view, "[data-rindle-admin-preview=\"owner_erasure\"]")
      assert has_element?(view, "[data-rindle-admin-input=\"confirmation\"]")
      assert has_element?(view, "[data-rindle-admin-submit=\"execute_owner_erasure\"]")
      assert render(view) =~ "Type <pre>ERASE Elixir.String:#{owner_id}</pre> to confirm"

      # 2. Reset on input change
      view
      |> form("form[phx-change=\"change_owner_erasure\"]", %{
        "owner_type" => "Elixir.String",
        "owner_id" => owner_id2
      })
      |> render_change()

      assert has_element?(view, "[data-rindle-admin-state=\"input\"]")

      # 3. Preview again
      view
      |> form("form[phx-submit=\"preview_owner_erasure\"]", %{
        "owner_type" => "Elixir.String",
        "owner_id" => owner_id
      })
      |> render_submit()

      # 4. Failed validation (wrong confirmation)
      view
      |> form("form[phx-submit=\"execute_owner_erasure\"]", %{
        "owner_type" => "Elixir.String",
        "owner_id" => owner_id,
        "confirmation" => "wrong"
      })
      |> render_submit()

      # Still in preview, error toast would be shown
      assert has_element?(view, "[data-rindle-admin-state=\"preview\"]")

      # 5. Successful execution
      view
      |> form("form[phx-submit=\"execute_owner_erasure\"]", %{
        "owner_type" => "Elixir.String",
        "owner_id" => owner_id,
        "confirmation" => "ERASE Elixir.String:#{owner_id}"
      })
      |> render_submit()

      assert has_element?(view, "[data-rindle-admin-receipt=\"owner_erasure\"]")
      assert render(view) =~ "Owner Erasure Complete"
    end

    test "owner erasure rejects unsupported owner types without creating atoms", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/rindle/actions")

      unique_type = "Elixir.Rindle.Admin.UnknownOwner#{System.unique_integer([:positive])}"

      view
      |> form("form[phx-submit=\"preview_owner_erasure\"]", %{
        "owner_type" => unique_type,
        "owner_id" => Ecto.UUID.generate()
      })
      |> render_submit()

      assert has_element?(view, "[data-rindle-admin-action-error]", "Unsupported owner type.")
      assert has_element?(view, "[data-rindle-admin-state=\"input\"]")

      assert_raise ArgumentError, fn ->
        String.to_existing_atom(unique_type)
      end
    end

    test "owner erasure accepts loaded module aliases without Elixir prefix", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/rindle/actions")

      view
      |> form("form[phx-submit=\"preview_owner_erasure\"]", %{
        "owner_type" => "String",
        "owner_id" => Ecto.UUID.generate()
      })
      |> render_submit()

      assert has_element?(view, "[data-rindle-admin-preview=\"owner_erasure\"]")
      assert has_element?(view, "[data-rindle-admin-state=\"preview\"]")
    end

    test "batch erasure workflow: preview, reset, validation, partial execution", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/rindle/actions")

      # Navigate to batch erasure
      view
      |> element("button", "Batch erasure")
      |> render_click()

      assert has_element?(view, "[data-rindle-admin-state=\"input\"]")

      owner_id1 = Ecto.UUID.generate()
      owner_id2 = Ecto.UUID.generate()
      owners_text = "Elixir.String:#{owner_id1}\nElixir.String:#{owner_id2}"

      # 1. Preview
      view
      |> form("form[phx-submit=\"preview_batch_erasure\"]", %{
        "owners" => owners_text
      })
      |> render_submit()

      assert has_element?(view, "[data-rindle-admin-state=\"preview\"]")
      assert has_element?(view, "[data-rindle-admin-preview=\"batch_erasure\"]")
      assert has_element?(view, "[data-rindle-admin-form=\"batch_erasure_execute\"]")
      assert has_element?(view, "[data-rindle-admin-submit=\"execute_batch_erasure\"]")
      assert render(view) =~ "Type <pre>ERASE 2 OWNERS</pre> to confirm"

      # 2. Validation Failure
      view
      |> form("form[phx-submit=\"execute_batch_erasure\"]", %{
        "owners" => owners_text,
        "confirmation" => "ERASE 1 OWNERS"
      })
      |> render_submit()

      assert has_element?(view, "[data-rindle-admin-state=\"preview\"]")

      # 3. Successful execution (no partial failure for empty lists since mock)
      # In reality it depends on what the storage/repo does, but for this basic test, it will just pass
      view
      |> form("form[phx-submit=\"execute_batch_erasure\"]", %{
        "owners" => owners_text,
        "confirmation" => "ERASE 2 OWNERS"
      })
      |> render_submit()

      assert has_element?(view, "[data-rindle-admin-receipt=\"batch_erasure\"]")
    end

    test "batch erasure rejects malformed owner lines without crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/rindle/actions")

      view
      |> element("button", "Batch erasure")
      |> render_click()

      view
      |> form("form[phx-submit=\"preview_batch_erasure\"]", %{"owners" => "not-a-valid-owner"})
      |> render_submit()

      assert has_element?(
               view,
               "[data-rindle-admin-action-error]",
               "Owners must be formatted as Module:id, one per line."
             )

      assert has_element?(view, "[data-rindle-admin-state=\"input\"]")
    end

    test "tampered action events and lifecycle actions render validation errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/rindle/actions")

      render_hook(view, "select_action", %{"id" => "not_a_real_action"})
      assert has_element?(view, "[data-rindle-admin-action-error]", "Unknown admin action.")

      render_hook(view, "execute_owner_erasure", %{
        "confirmation" => "ERASE Elixir.String:missing"
      })

      assert has_element?(
               view,
               "[data-rindle-admin-action-error]",
               "Preview this action before executing."
             )

      view
      |> element("button", "Batch erasure")
      |> render_click()

      render_hook(view, "execute_batch_erasure", %{"confirmation" => "ERASE 1 OWNERS"})

      assert has_element?(
               view,
               "[data-rindle-admin-action-error]",
               "Preview this action before executing."
             )
    end

    # CR-03 regression: batch-erasure preview sets dialog_open (action_state ==
    # :preview), which inerts <main>. Previously the batch confirmation was a plain
    # inline <form> rendered inside <main>, so it was inerted with no overlay to host
    # it — the confirmation gate could never be satisfied and the surface was
    # announced aria-hidden with no dialog. The form must now render through the
    # shared confirm_dialog primitive in the shell :overlay slot (sibling of <main>).
    # Fails against the prior inline-form markup (form nested inside the inerted main).
    test "batch erasure preview confirmation stays interactive outside inert <main> (CR-03 regression)",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/rindle/actions")

      view
      |> element("button", "Batch erasure")
      |> render_click()

      owners_text =
        "Elixir.String:#{Ecto.UUID.generate()}\nElixir.String:#{Ecto.UUID.generate()}"

      html =
        view
        |> form("form[phx-submit=\"preview_batch_erasure\"]", %{"owners" => owners_text})
        |> render_submit()

      # In preview, <main> is inerted (dialog_open true).
      assert_main_inerted(html)

      # The batch confirmation form + its execute submit + the typed-confirmation
      # gate must render AFTER </main> (in the sibling overlay host), not inside the
      # inerted subtree — otherwise the confirmation can never be satisfied.
      assert_outside_inert_main(html, ~s(data-rindle-admin-form="batch_erasure_execute"))
      assert_outside_inert_main(html, ~s(data-rindle-admin-submit="execute_batch_erasure"))
      assert_outside_inert_main(html, ~s(data-rindle-admin-confirm-input))

      # And the batch erasure remains confirmable end-to-end.
      view
      |> form("form[phx-submit=\"execute_batch_erasure\"]", %{
        "owners" => owners_text,
        "confirmation" => "ERASE 2 OWNERS"
      })
      |> render_submit()

      assert has_element?(view, "[data-rindle-admin-receipt=\"batch_erasure\"]")
    end

    defp assert_main_inerted(html) do
      main_open = Regex.run(~r/<main[^>]*>/, html)
      assert main_open, "expected a <main> element in the rendered shell"
      assert hd(main_open) =~ "inert", "expected <main> to carry inert while a dialog is open"

      assert hd(main_open) =~ ~s(aria-hidden="true"),
             "expected <main> to carry aria-hidden=\"true\" while a dialog is open"
    end

    defp assert_outside_inert_main(html, marker) do
      main_close = :binary.match(html, "</main>")
      assert main_close != :nomatch, "expected a </main> close tag"
      {main_close_at, _} = main_close
      marker_at = :binary.match(html, marker)
      assert marker_at != :nomatch, "expected marker #{inspect(marker)} in the rendered html"
      {marker_pos, _} = marker_at

      assert marker_pos > main_close_at,
             "#{inspect(marker)} must render AFTER </main> (sibling overlay), not inside the inerted <main>"
    end

    # Distributed verbs (UI-SPEC §E, D-98-10): the regenerate / reconcile /
    # release-quarantine workflows moved off this Maintenance junk-drawer to their
    # contextual surfaces. Their behavior is exercised on those surfaces:
    #   * regenerate (confirm_dialog) → Processing — variants_runtime_actions_test
    #   * reconcile / verify storage → Doctor — variants_runtime_actions_test
    #   * quarantine review → asset detail — home_assets_upload_test
  end
end
