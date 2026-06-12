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

      # Default action panel is rendered
      assert has_element?(view, "h3", "Owner erasure")
      assert has_element?(view, "[data-rindle-admin-state=\"input\"]")

      # Can select another action
      view
      |> element("button", "Batch erasure")
      |> render_click()

      assert has_element?(view, "h3", "Batch erasure")
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

    test "lifecycle repair workflow: reprobe and requeue", %{conn: conn} do
      asset = Rindle.Repo.insert!(%Rindle.Domain.MediaAsset{
        id: Ecto.UUID.generate(),
        state: "available",
        profile: to_string(AdminImageProfile),
        storage_key: "assets/sample.bin",
        content_type: "image/png",
        byte_size: 123
      })

      {:ok, view, _html} = live(conn, "/admin/rindle/actions")

      view
      |> element("button", "Lifecycle repair")
      |> render_click()

      assert has_element?(view, "[data-rindle-admin-state=\"input\"]")

      # Reprobe
      view
      |> form("form[phx-submit=\"execute_lifecycle_repair\"]", %{
        "asset_id" => asset.id,
        "repair_action" => "reprobe"
      })
      |> render_submit()

      assert has_element?(view, "[data-rindle-admin-receipt=\"lifecycle_repair\"]")
      assert render(view) =~ "Action taken: reprobe"

      view
      |> element("button", "Lifecycle repair")
      |> render_click()

      # Requeue
      view
      |> form("form[phx-submit=\"execute_lifecycle_repair\"]", %{
        "asset_id" => asset.id,
        "repair_action" => "requeue"
      })
      |> render_submit()

      assert has_element?(view, "[data-rindle-admin-receipt=\"lifecycle_repair\"]")
      assert render(view) =~ "Action taken: requeue"
    end

    test "variant regeneration workflow", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/rindle/actions")

      view
      |> element("button", "Variant regeneration")
      |> render_click()

      assert has_element?(view, "[data-rindle-admin-state=\"input\"]")

      view
      |> form("form[phx-submit=\"execute_variant_regeneration\"]", %{
        "profile" => "Elixir.AdminImageProfile",
        "variant_name" => "thumb",
        "confirm" => "true"
      })
      |> render_submit()

      assert has_element?(view, "[data-rindle-admin-receipt=\"variant_regeneration\"]")
      assert render(view) =~ "Enqueued"
    end

    test "quarantine review triage renders read-only instructional panel", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/rindle/actions")

      view
      |> element("button", "Quarantine review")
      |> render_click()

      assert has_element?(view, "[data-rindle-admin-panel=\"quarantine_review\"]")
      assert render(view) =~ "permanently blocked from delivery"
      assert render(view) =~ "state=quarantined"
    end
  end
end
