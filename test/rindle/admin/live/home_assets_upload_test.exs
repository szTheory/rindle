if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.Live.HomeAssetsUploadTest do
    use Rindle.DataCase, async: false

    require Phoenix.LiveViewTest

    import Mox

    alias Phoenix.PubSub

    alias Rindle.Domain.{
      MediaAsset,
      MediaAttachment,
      MediaProcessingRun,
      MediaProviderAsset,
      MediaUploadSession,
      MediaVariant
    }

    @endpoint __MODULE__.Endpoint
    @secret_payload "https://storage.example/raw-session-secret-token"
    # Task-first nav labels (UI-SPEC §E, D-98-03): relabeled for task-scent.
    @surfaces [
      "Overview",
      "Assets",
      "Upload sessions",
      "Processing",
      "Doctor",
      "Maintenance"
    ]

    for live_module <- [
          Rindle.Admin.Live.VariantsJobsLive,
          Rindle.Admin.Live.RuntimeDoctorLive,
          Rindle.Admin.Live.ActionsLive
        ] do
      unless Code.ensure_loaded?(live_module) do
        Module.create(
          live_module,
          quote do
            use Phoenix.LiveView
          end,
          Macro.Env.location(__ENV__)
        )
      end
    end

    defmodule Router do
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

      scope "/ops" do
        pipe_through(:browser)

        rindle_admin("/media", auth_guarded?: true, as: :rindle_media)
      end
    end

    defmodule Endpoint do
      use Phoenix.Endpoint, otp_app: :rindle

      socket("/live", Phoenix.LiveView.Socket)

      plug(Plug.Session,
        store: :cookie,
        key: "_rindle_admin_test",
        signing_salt: "rindle-admin-test"
      )

      plug(Rindle.Admin.Live.HomeAssetsUploadTest.Router)
    end

    import Phoenix.ConnTest

    defmodule ImageProfile do
      use Rindle.Profile,
        storage: Rindle.StorageMock,
        variants: [thumb: [mode: :fit, width: 64, height: 64]],
        allow_mime: ["image/png"],
        max_bytes: 10_485_760
    end

    setup_all do
      Application.put_env(:rindle, Endpoint,
        url: [host: "localhost"],
        debug_errors: true,
        secret_key_base: String.duplicate("a", 64),
        live_view: [signing_salt: "rindle-admin-live"]
      )

      start_supervised!(Endpoint)
      :ok
    end

    setup do
      set_mox_global()
      stub(Rindle.StorageMock, :capabilities, fn -> [:signed_url] end)
      ensure_pubsub_started!()
      {:ok, conn: Phoenix.ConnTest.build_conn()}
    end

    setup :verify_on_exit!

    test "shell and Overview render the task-first triage home", %{conn: conn} do
      insert_asset(%{state: "ready", profile: to_string(ImageProfile)})

      {:ok, _view, html} = Phoenix.LiveViewTest.live(conn, "/admin/rindle")

      assert_shell(html, "home-status")
      assert html =~ "Rindle Admin"
      # GDS triage home (UI-SPEC §E): task-first sections, no inspect/1 anti-pattern.
      assert html =~ "Overview"
      assert html =~ "Needs attention"
      assert html =~ "System health"
      assert html =~ "Recent activity"
      assert html =~ "Totals"
      assert html =~ "Waiting for lifecycle events"
      assert html =~ ~s(aria-current="page")
      assert html =~ ~s(data-rindle-admin-surface="home-status")

      for surface <- @surfaces do
        assert html =~ surface
      end
    end

    test "shell links stay inside custom host mount paths", %{conn: conn} do
      {:ok, _view, html} = Phoenix.LiveViewTest.live(conn, "/ops/media")

      assert_shell(html, "home-status")
      assert html =~ ~s(href="/ops/media")
      assert html =~ ~s(href="/ops/media/assets")
      assert html =~ ~s(href="/ops/media/upload-sessions")
      assert html =~ ~s(href="/ops/media/variants-jobs")
      assert html =~ ~s(href="/ops/media/runtime-doctor")
      assert html =~ ~s(href="/ops/media/actions")
      refute html =~ ~s(href="/admin/rindle)
    end

    test "Assets lists filters, rows, and detail context", %{conn: conn} do
      asset = insert_asset(%{state: "ready", profile: to_string(ImageProfile), kind: "image"})
      _attachment = insert_attachment(asset, %{slot: "hero"})
      _variant = insert_variant(asset, %{name: "thumb", state: "ready"})
      _session = insert_upload_session(asset, %{state: "completed"})
      _run = insert_processing_run(asset, %{variant_name: "thumb", state: "succeeded"})
      _provider = insert_provider_asset(asset, %{provider_asset_id: "provider-secret-asset-id"})

      {:ok, _view, html} =
        Phoenix.LiveViewTest.live(
          conn,
          "/admin/rindle/assets?state=ready&profile=#{URI.encode_www_form(to_string(ImageProfile))}&kind=image"
        )

      assert_shell(html, "assets")
      assert html =~ ~s(data-rindle-admin-filter="state")
      assert html =~ ~s(data-rindle-admin-filter="profile")
      assert html =~ ~s(data-rindle-admin-filter="kind")
      assert html =~ ~s(data-rindle-admin-row="asset")
      assert html =~ ~s(data-rindle-admin-detail-link="asset")
      assert html =~ "Inspect asset"
      assert html =~ asset.filename
      assert html =~ "ready"
      assert html =~ ~s(class="rindle-admin-table)
      assert html =~ "rindle-admin-button--secondary"

      {:ok, _detail, detail_html} =
        Phoenix.LiveViewTest.live(conn, "/admin/rindle/assets/#{asset.id}")

      assert_shell(detail_html, "assets")
      assert detail_html =~ "Attachment context"
      assert detail_html =~ "Variants"
      assert detail_html =~ "Upload sessions"
      assert detail_html =~ "Processing runs"
      assert detail_html =~ "State context"
      assert detail_html =~ "Provider identifier redacted"
      refute detail_html =~ "provider-secret-asset-id"
    end

    test "Asset detail hosts the distributed quarantine review (UI-SPEC §E)", %{conn: conn} do
      asset = insert_asset(%{state: "quarantined", profile: to_string(ImageProfile)})

      {:ok, _detail, html} =
        Phoenix.LiveViewTest.live(conn, "/admin/rindle/assets/#{asset.id}")

      # The release/quarantine verb was distributed off Maintenance onto asset
      # detail, where the operator already has the asset in context (D-98-10).
      assert html =~ ~s(data-rindle-admin-section="quarantine-review")
      assert html =~ "Quarantine review"
      assert html =~ "permanently blocked from delivery"
    end

    test "Assets detail refreshes from queries after forged PubSub payloads", %{conn: conn} do
      asset = insert_asset(%{state: "processing", profile: to_string(ImageProfile)})
      _variant = insert_variant(asset, %{name: "thumb", state: "processing"})

      {:ok, view, html} = Phoenix.LiveViewTest.live(conn, "/admin/rindle/assets/#{asset.id}")

      assert html =~ "processing"

      update_asset_state!(asset.id, "ready")

      PubSub.broadcast(
        Rindle.PubSub,
        "rindle:asset:#{asset.id}",
        {:rindle_event, :asset_ready, %{asset_id: asset.id, session_uri: @secret_payload}}
      )

      refreshed = Phoenix.LiveViewTest.render(view)
      assert refreshed =~ "Updated just now"
      assert refreshed =~ "ready"
      refute refreshed =~ @secret_payload
    end

    test "Upload Sessions lists filters, redacted rows, and detail guidance", %{conn: conn} do
      asset = insert_asset(%{profile: to_string(ImageProfile)})

      session =
        insert_upload_session(asset, %{
          state: "failed",
          upload_strategy: "resumable",
          resumable_protocol: "gcs",
          session_uri: @secret_payload,
          failure_reason: "checksum mismatch"
        })

      {:ok, _view, html} =
        Phoenix.LiveViewTest.live(
          conn,
          "/admin/rindle/upload-sessions?state=failed&strategy=resumable&profile=#{URI.encode_www_form(to_string(ImageProfile))}"
        )

      assert_shell(html, "upload-sessions")
      assert html =~ ~s(data-rindle-admin-filter="state")
      assert html =~ ~s(data-rindle-admin-filter="strategy")
      assert html =~ ~s(data-rindle-admin-filter="profile")
      assert html =~ ~s(data-rindle-admin-row="upload-session")
      assert html =~ ~s(data-rindle-admin-detail-link="upload-session")
      assert html =~ "Review session"
      assert html =~ "Redacted by Rindle Admin"
      refute html =~ @secret_payload

      {:ok, _detail, detail_html} =
        Phoenix.LiveViewTest.live(conn, "/admin/rindle/upload-sessions/#{session.id}")

      assert_shell(detail_html, "upload-sessions")
      assert detail_html =~ "Strategy/protocol"
      assert detail_html =~ "Expiration"
      assert detail_html =~ "Failure reason"
      assert detail_html =~ ~s(data-rindle-admin-detail-link="asset")
      assert detail_html =~ "Cleanup guidance"
      assert detail_html =~ "checksum mismatch"
      assert detail_html =~ "Redacted by Rindle Admin"
      refute detail_html =~ @secret_payload
    end

    test "Upload Sessions detail refreshes through queries and never renders forged secrets", %{
      conn: conn
    } do
      asset = insert_asset(%{profile: to_string(ImageProfile)})

      session =
        insert_upload_session(asset, %{
          state: "signed",
          upload_strategy: "resumable",
          resumable_protocol: "gcs",
          session_uri: @secret_payload
        })

      {:ok, view, html} =
        Phoenix.LiveViewTest.live(conn, "/admin/rindle/upload-sessions/#{session.id}")

      assert html =~ "signed"
      assert html =~ "Redacted by Rindle Admin"
      refute html =~ @secret_payload

      update_upload_session_state!(session.id, "failed", "expired upload residue")

      PubSub.broadcast(
        Rindle.PubSub,
        "rindle:upload_session:#{session.id}",
        {:rindle_event, :upload_session_failed,
         %{session_id: session.id, session_uri: @secret_payload, token: "raw-secret-token"}}
      )

      refreshed = Phoenix.LiveViewTest.render(view)
      assert refreshed =~ "Updated just now"
      assert refreshed =~ "failed"
      assert refreshed =~ "expired upload residue"
      assert refreshed =~ "Redacted by Rindle Admin"
      refute refreshed =~ @secret_payload
      refute refreshed =~ "raw-secret-token"
    end

    test "empty and error state copy remains stable", %{conn: conn} do
      {:ok, _view, html} = Phoenix.LiveViewTest.live(conn, "/admin/rindle/assets?state=missing")

      assert html =~ ~s(data-rindle-admin-empty-state)
      refute html =~ ~s(data-rindle-admin-error-state)
      assert html =~ "No records match this view"
      refute html =~ "Rindle Admin could not load this surface"
    end

    defp assert_shell(html, surface) do
      assert html =~ ~s(data-rindle-admin-root)
      assert html =~ ~s(data-rindle-admin-surface="#{surface}")
      assert html =~ ~s(data-rindle-admin-nav-item)
      assert html =~ ~s(data-rindle-admin-status-chip)
      assert html =~ ~s(data-rindle-admin-live-indicator)
      assert html =~ ~s(data-theme="auto")
      assert html =~ ~s(data-rindle-admin-theme="light")
      assert html =~ ~s(data-rindle-admin-theme="dark")
      assert html =~ ~s(data-rindle-admin-theme="auto")
      assert html =~ ~s(aria-label="Theme")
      assert html =~ "rindle-admin-target-min"
    end

    defp insert_asset(attrs) do
      params =
        %{
          state: "available",
          profile: to_string(ImageProfile),
          storage_key: "assets/#{System.unique_integer([:positive])}.bin",
          kind: "image",
          content_type: "image/png",
          byte_size: 1234,
          filename: "sample.png"
        }
        |> Map.merge(attrs)

      %MediaAsset{}
      |> MediaAsset.changeset(params)
      |> Rindle.Repo.insert!()
    end

    defp insert_attachment(asset, attrs) do
      params =
        %{
          asset_id: asset.id,
          owner_type: "User",
          owner_id: Ecto.UUID.generate(),
          slot: "avatar"
        }
        |> Map.merge(attrs)

      %MediaAttachment{}
      |> MediaAttachment.changeset(params)
      |> Rindle.Repo.insert!()
    end

    defp insert_variant(asset, attrs) do
      variant_name = Map.get(attrs, :name, "thumb")

      params =
        %{
          asset_id: asset.id,
          name: variant_name,
          state: "ready",
          recipe_digest: ImageProfile.recipe_digest(String.to_existing_atom(variant_name)),
          storage_key: "variants/#{System.unique_integer([:positive])}.bin",
          output_kind: "image"
        }
        |> Map.merge(attrs)

      %MediaVariant{}
      |> MediaVariant.changeset(params)
      |> Rindle.Repo.insert!()
    end

    defp insert_upload_session(asset, attrs) do
      params =
        %{
          asset_id: asset.id,
          state: "completed",
          upload_key: "uploads/#{System.unique_integer([:positive])}.bin",
          upload_strategy: "presigned_put",
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
          session_uri_expires_at: DateTime.add(DateTime.utc_now(), 1800, :second)
        }
        |> Map.merge(attrs)

      %MediaUploadSession{}
      |> MediaUploadSession.changeset(params)
      |> Rindle.Repo.insert!()
    end

    defp insert_processing_run(asset, attrs) do
      params =
        %{
          asset_id: asset.id,
          variant_name: "thumb",
          worker: "Rindle.Workers.ProcessVariant",
          state: "queued",
          attempt: 1
        }
        |> Map.merge(attrs)

      %MediaProcessingRun{}
      |> MediaProcessingRun.changeset(params)
      |> Rindle.Repo.insert!()
    end

    defp insert_provider_asset(asset, attrs) do
      params =
        %{
          asset_id: asset.id,
          profile: asset.profile,
          provider_name: "mux",
          provider_asset_id: "mux-asset-#{System.unique_integer([:positive])}-tail",
          state: "processing"
        }
        |> Map.merge(attrs)

      %MediaProviderAsset{}
      |> MediaProviderAsset.changeset(params)
      |> Rindle.Repo.insert!()
    end

    defp update_asset_state!(asset_id, state) do
      asset = Rindle.Repo.get!(MediaAsset, asset_id)

      asset
      |> MediaAsset.changeset(%{state: state})
      |> Rindle.Repo.update!()
    end

    defp update_upload_session_state!(session_id, state, failure_reason) do
      session = Rindle.Repo.get!(MediaUploadSession, session_id)

      session
      |> MediaUploadSession.changeset(%{state: state, failure_reason: failure_reason})
      |> Rindle.Repo.update!()
    end

    defp ensure_pubsub_started! do
      case Process.whereis(Rindle.PubSub) do
        nil -> start_supervised!({Phoenix.PubSub, name: Rindle.PubSub})
        _pid -> :ok
      end
    end
  end
end
