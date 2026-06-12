if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.LiveUpdateTest do
    use Rindle.DataCase, async: false

    require Phoenix.LiveViewTest

    alias Phoenix.PubSub

    alias Rindle.Domain.{
      MediaAsset,
      MediaProviderAsset,
      MediaUploadSession,
      MediaVariant
    }

    @endpoint __MODULE__.Endpoint
    @forged_session_uri "https://secret.example/upload"
    @forged_provider_asset_id "raw-provider-secret"

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
    end

    defmodule Endpoint do
      use Phoenix.Endpoint, otp_app: :rindle

      socket("/live", Phoenix.LiveView.Socket)

      plug(Plug.Session,
        store: :cookie,
        key: "_rindle_admin_live_update_test",
        signing_salt: "rindle-admin-test"
      )

      plug(Rindle.Admin.LiveUpdateTest.Router)
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
        secret_key_base: String.duplicate("c", 64),
        live_view: [signing_salt: "rindle-admin-live"]
      )

      start_supervised!(Endpoint)
      :ok
    end

    setup do
      ensure_pubsub_started!()
      {:ok, conn: Phoenix.ConnTest.build_conn()}
    end

    test "Assets detail treats PubSub payloads as invalidation and re-queries", %{conn: conn} do
      asset = insert_asset(%{state: "processing", filename: "asset-before.png"})

      _session =
        insert_upload_session(asset, %{state: "signed", session_uri: @forged_session_uri})

      _provider = insert_provider_asset(asset, %{provider_asset_id: @forged_provider_asset_id})

      {:ok, view, html} = Phoenix.LiveViewTest.live(conn, "/admin/rindle/assets/#{asset.id}")

      assert html =~ "processing"
      refute html =~ @forged_session_uri
      refute html =~ @forged_provider_asset_id

      update_asset_state!(asset.id, "ready")

      PubSub.broadcast(
        Rindle.PubSub,
        "rindle:asset:#{asset.id}",
        {:rindle_event, :asset_ready,
         %{
           asset_id: asset.id,
           state: "forged-state",
           session_uri: @forged_session_uri,
           provider_asset_id: @forged_provider_asset_id
         }}
      )

      refreshed = Phoenix.LiveViewTest.render(view)
      assert refreshed =~ "Updated just now"
      assert refreshed =~ "ready"
      refute refreshed =~ "forged-state"
      refute refreshed =~ @forged_session_uri
      refute refreshed =~ @forged_provider_asset_id
    end

    test "Upload Sessions detail re-queries and never renders forged session_uri", %{conn: conn} do
      asset = insert_asset(%{})

      session =
        insert_upload_session(asset, %{
          state: "signed",
          upload_strategy: "resumable",
          resumable_protocol: "tus",
          session_uri: @forged_session_uri
        })

      {:ok, view, html} =
        Phoenix.LiveViewTest.live(conn, "/admin/rindle/upload-sessions/#{session.id}")

      assert html =~ "signed"
      assert html =~ "Redacted by Rindle Admin"
      refute html =~ @forged_session_uri

      update_upload_session!(session.id, %{state: "failed", failure_reason: "client disconnected"})

      PubSub.broadcast(
        Rindle.PubSub,
        "rindle:upload_session:#{session.id}",
        {:rindle_event, :upload_session_failed,
         %{
           session_id: session.id,
           state: "completed",
           session_uri: @forged_session_uri,
           provider_asset_id: @forged_provider_asset_id
         }}
      )

      refreshed = Phoenix.LiveViewTest.render(view)
      assert refreshed =~ "Updated just now"
      assert refreshed =~ "failed"
      assert refreshed =~ "client disconnected"
      assert refreshed =~ "Redacted by Rindle Admin"
      refute refreshed =~ @forged_session_uri
      refute refreshed =~ @forged_provider_asset_id
    end

    test "Variants/Jobs re-queries visible findings and ignores forged provider ids", %{
      conn: conn
    } do
      asset = insert_asset(%{})
      variant = insert_variant(asset, %{state: "failed", error_reason: "codec exploded"})

      {:ok, view, html} = Phoenix.LiveViewTest.live(conn, "/admin/rindle/variants-jobs")

      assert html =~ "failed"
      assert html =~ "codec exploded"
      refute html =~ @forged_provider_asset_id

      update_variant!(variant.id, %{state: "ready", error_reason: nil})

      PubSub.broadcast(
        Rindle.PubSub,
        "rindle:variant:#{variant.id}",
        {:rindle_event, :variant_ready,
         %{
           variant_id: variant.id,
           state: "failed",
           session_uri: @forged_session_uri,
           provider_asset_id: @forged_provider_asset_id
         }}
      )

      refreshed = Phoenix.LiveViewTest.render(view)
      assert refreshed =~ "Updated just now"
      refute refreshed =~ "codec exploded"
      refute refreshed =~ @forged_session_uri
      refute refreshed =~ @forged_provider_asset_id
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

    defp insert_variant(asset, attrs) do
      params =
        %{
          asset_id: asset.id,
          name: "thumb",
          state: "ready",
          recipe_digest: ImageProfile.recipe_digest(:thumb),
          storage_key: "variants/#{System.unique_integer([:positive])}.bin",
          output_kind: "image"
        }
        |> Map.merge(attrs)

      %MediaVariant{}
      |> MediaVariant.changeset(params)
      |> Rindle.Repo.insert!()
    end

    defp insert_provider_asset(asset, attrs) do
      params =
        %{
          asset_id: asset.id,
          profile: asset.profile,
          provider_name: "mux",
          provider_asset_id: "mux-asset-#{System.unique_integer([:positive])}",
          state: "processing"
        }
        |> Map.merge(attrs)

      %MediaProviderAsset{}
      |> MediaProviderAsset.changeset(params)
      |> Rindle.Repo.insert!()
    end

    defp update_asset_state!(asset_id, state) do
      Rindle.Repo.get!(MediaAsset, asset_id)
      |> MediaAsset.changeset(%{state: state})
      |> Rindle.Repo.update!()
    end

    defp update_upload_session!(session_id, attrs) do
      Rindle.Repo.get!(MediaUploadSession, session_id)
      |> MediaUploadSession.changeset(attrs)
      |> Rindle.Repo.update!()
    end

    defp update_variant!(variant_id, attrs) do
      Rindle.Repo.get!(MediaVariant, variant_id)
      |> MediaVariant.changeset(attrs)
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
