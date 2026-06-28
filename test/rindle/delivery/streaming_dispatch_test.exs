defmodule Rindle.Delivery.StreamingDispatchTest do
  @moduledoc """
  Per-branch coverage for `Rindle.Delivery.streaming_url/3` D-19 dispatch tree
  (Phase 33 STREAM-06).

  Branch matrix (from CONTEXT.md D-19 + Plan 33-03):

    Branch 1 — no streaming configured → v1.4 progressive path (kind: :progressive)
    Branch 2 — streaming + binary key → :streaming_provider_requires_asset_struct
    Branch 3a/3b/3c — row in pending|uploading|processing → :provider_asset_not_ready
    Branch 4 — row in errored → :provider_sync_failed
    Branch 5 — row in ready + playback_id → provider.signed_playback_url + kind: :hls
    Branch 5b — row in ready + playback_ids: [] → :provider_asset_not_ready
    Branch 6 — no row, non-strict → progressive fallback (kind: :progressive)
    Branch 7 — no row, strict → :provider_asset_not_ready

  Tripwires that MUST stay green (delivery_test.exs:352-391; telemetry_contract_test.exs:74,277):
    - [:rindle, :delivery, :streaming, :resolved] preserved verbatim on Branches 1, 6 (kind: :progressive)
    - Telemetry metadata key set unchanged: profile, adapter, mode, kind, mime
  """
  # async: true — root-caused in Phase 110. This suite was previously serialized because the only
  # cross-test pollution source was Rindle.Test.CountingFailingTxnRepo's former GLOBAL `:rindle, :repo`
  # swap: a concurrent test that force-failed a transaction in its window made Branch 5/5b dispatch
  # resolve the wrong repo → intermittent `==` failures. That double is now process-scoped (it sets
  # the override via Config.put_repo_override/1, visible only to its own process tree), so no
  # concurrent process can pollute this suite's Config.repo() reads. The global mutation is gone, so
  # the workaround is eliminated rather than deferred — these 17 tests are safe to run async again.
  use Rindle.DataCase, async: true

  import Mox
  alias Rindle.Domain.MediaAsset
  alias Rindle.Domain.MediaProviderAsset
  alias Rindle.Repo

  # Define a Mox mock for the Rindle.Streaming.Provider behaviour. Idempotent
  # — Mox.defmock raises if already defined, so guard with Code.ensure_loaded?.
  unless Code.ensure_loaded?(Rindle.Streaming.ProviderMock) do
    Mox.defmock(Rindle.Streaming.ProviderMock, for: Rindle.Streaming.Provider)
  end

  setup :set_mox_from_context
  setup :verify_on_exit!

  # Profiles defined at compile time so `delivery_policy/0` returns frozen maps.

  defmodule NoStreamingProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [web: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      delivery: [public: true]
  end

  defmodule StreamingProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [web: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      delivery: [
        public: true,
        streaming: [
          provider: Rindle.Streaming.ProviderMock,
          playback_policy: :signed,
          ingest_mode: :server_push,
          source_variant: :web
        ]
      ]
  end

  defmodule DirectUploadStreamingProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [web: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      delivery: [
        public: true,
        streaming: [
          provider: Rindle.Streaming.ProviderMock,
          playback_policy: :signed,
          ingest_mode: :direct_creator_upload,
          source_variant: :web
        ]
      ]
  end

  # CR-01 regression: profile with BOTH :streaming AND :authorizer configured.
  # Branch 5 must run the authorizer before calling the provider — otherwise
  # signed HLS URLs leak past the authorizer the profile declared.
  defmodule AuthorizedStreamingProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [web: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      delivery: [
        public: false,
        authorizer: Rindle.AuthorizerMock,
        streaming: [
          provider: Rindle.Streaming.ProviderMock,
          playback_policy: :signed,
          ingest_mode: :server_push,
          source_variant: :web
        ]
      ]
  end

  # Helpers --------------------------------------------------------------------

  defp insert_asset!(attrs \\ %{}) do
    %MediaAsset{}
    |> MediaAsset.changeset(
      Map.merge(
        %{
          state: "available",
          storage_key: "assets/#{System.unique_integer([:positive])}/orig.mp4",
          content_type: "video/mp4",
          byte_size: 1024,
          filename: "orig.mp4",
          recipe_digest: "abc",
          profile: inspect(StreamingProfile),
          kind: "video"
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp insert_provider_asset!(asset, attrs) do
    insert_provider_asset!(asset, StreamingProfile, attrs)
  end

  defp insert_provider_asset!(asset, profile_module, attrs) do
    base = %{
      asset_id: asset.id,
      profile: to_string(profile_module),
      provider_name: "provider_mock",
      state: "pending"
    }

    %MediaProviderAsset{}
    |> MediaProviderAsset.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end

  defp attach_streaming_telemetry do
    ref =
      :telemetry_test.attach_event_handlers(self(), [[:rindle, :delivery, :streaming, :resolved]])

    on_exit(fn -> :telemetry.detach(ref) end)
    ref
  end

  # ---------------------------------------------------------------------------

  describe "Branch 1: no streaming configured (v1.4 progressive path)" do
    test "binary key on no-streaming profile returns kind: :progressive and emits telemetry" do
      ref = attach_streaming_telemetry()
      key = "assets/asset-1/video.mp4"

      expect(Rindle.StorageMock, :url, fn ^key, _opts ->
        {:ok, "https://public.example/#{key}"}
      end)

      assert {:ok, %{url: _url, kind: :progressive, mime: "video/mp4"}} =
               Rindle.Delivery.streaming_url(NoStreamingProfile, key)

      assert_received {[:rindle, :delivery, :streaming, :resolved], ^ref, measurements, metadata}

      assert is_integer(measurements.system_time)
      assert metadata.profile == NoStreamingProfile
      assert metadata.adapter == NoStreamingProfile.storage_adapter()
      assert metadata.mode == :public
      assert metadata.kind == :progressive
      assert metadata.mime == "video/mp4"
    end
  end

  describe "Branch 2: streaming configured + binary key" do
    test "returns :streaming_provider_requires_asset_struct (no telemetry)" do
      ref = attach_streaming_telemetry()
      key = "assets/asset-2/video.mp4"

      assert {:error, :streaming_provider_requires_asset_struct} =
               Rindle.Delivery.streaming_url(StreamingProfile, key)

      refute_received {[:rindle, :delivery, :streaming, :resolved], ^ref, _, _}
    end
  end

  describe "Branch 3a: row state = pending" do
    test "returns :provider_asset_not_ready (no telemetry)" do
      ref = attach_streaming_telemetry()
      asset = insert_asset!()
      _row = insert_provider_asset!(asset, %{state: "pending"})

      assert {:error, :provider_asset_not_ready} =
               Rindle.Delivery.streaming_url(StreamingProfile, asset)

      refute_received {[:rindle, :delivery, :streaming, :resolved], ^ref, _, _}
    end
  end

  describe "Branch 3b: row state = uploading" do
    test "returns :provider_asset_not_ready (no telemetry)" do
      ref = attach_streaming_telemetry()
      asset = insert_asset!()
      _row = insert_provider_asset!(asset, %{state: "uploading"})

      assert {:error, :provider_asset_not_ready} =
               Rindle.Delivery.streaming_url(StreamingProfile, asset)

      refute_received {[:rindle, :delivery, :streaming, :resolved], ^ref, _, _}
    end
  end

  describe "Branch 3c: row state = processing" do
    test "returns :provider_asset_not_ready (no telemetry)" do
      ref = attach_streaming_telemetry()
      asset = insert_asset!()
      _row = insert_provider_asset!(asset, %{state: "processing"})

      assert {:error, :provider_asset_not_ready} =
               Rindle.Delivery.streaming_url(StreamingProfile, asset)

      refute_received {[:rindle, :delivery, :streaming, :resolved], ^ref, _, _}
    end
  end

  describe "Branch 4: row state = errored" do
    test "returns :provider_sync_failed (no telemetry)" do
      ref = attach_streaming_telemetry()
      asset = insert_asset!()
      _row = insert_provider_asset!(asset, %{state: "errored"})

      assert {:error, :provider_sync_failed} =
               Rindle.Delivery.streaming_url(StreamingProfile, asset)

      refute_received {[:rindle, :delivery, :streaming, :resolved], ^ref, _, _}
    end
  end

  describe "Branch 5: row state = ready with playback_id" do
    test "calls provider.signed_playback_url and emits telemetry with kind: :hls" do
      ref = attach_streaming_telemetry()
      asset = insert_asset!()

      _row =
        insert_provider_asset!(asset, %{
          state: "ready",
          playback_ids: ["pb-abc-1234", "pb-zzz-9999"]
        })

      expect(Rindle.Streaming.ProviderMock, :signed_playback_url, fn StreamingProfile,
                                                                     "pb-abc-1234",
                                                                     _opts ->
        {:ok,
         %{
           url: "https://stream.example/pb-abc-1234.m3u8?token=abc",
           kind: :hls,
           mime: "application/vnd.apple.mpegurl"
         }}
      end)

      assert {:ok,
              %{
                url: "https://stream.example/pb-abc-1234.m3u8?token=abc",
                kind: :hls,
                mime: "application/vnd.apple.mpegurl"
              }} = Rindle.Delivery.streaming_url(StreamingProfile, asset)

      assert_received {[:rindle, :delivery, :streaming, :resolved], ^ref, measurements, metadata}

      assert is_integer(measurements.system_time)
      assert metadata.profile == StreamingProfile
      assert metadata.adapter == StreamingProfile.storage_adapter()
      assert metadata.mode == :public
      assert metadata.kind == :hls
      assert metadata.mime == "application/vnd.apple.mpegurl"
    end
  end

  describe "Branch 5b: row state = ready with playback_ids: []" do
    test "returns :provider_asset_not_ready (defensive guard; no telemetry; no provider call)" do
      ref = attach_streaming_telemetry()
      asset = insert_asset!()
      _row = insert_provider_asset!(asset, %{state: "ready", playback_ids: []})

      # No expect on provider — Mox.verify_on_exit! ensures provider is NOT called.

      assert {:error, :provider_asset_not_ready} =
               Rindle.Delivery.streaming_url(StreamingProfile, asset)

      refute_received {[:rindle, :delivery, :streaming, :resolved], ^ref, _, _}
    end
  end

  describe "Branch 6: no row + non-strict (default) → progressive fallback" do
    test "falls through to v1.4 progressive path and emits kind: :progressive" do
      ref = attach_streaming_telemetry()
      asset = insert_asset!()
      # No insert_provider_asset! — Repo.get_by returns nil.

      key = asset.storage_key

      expect(Rindle.StorageMock, :url, fn ^key, _opts ->
        {:ok, "https://public.example/#{key}"}
      end)

      assert {:ok, %{url: _url, kind: :progressive, mime: "video/mp4"}} =
               Rindle.Delivery.streaming_url(StreamingProfile, asset)

      assert_received {[:rindle, :delivery, :streaming, :resolved], ^ref, _measurements, metadata}

      assert metadata.kind == :progressive
      assert metadata.profile == StreamingProfile
      assert metadata.adapter == StreamingProfile.storage_adapter()
      assert metadata.mode == :public
      assert metadata.mime == "video/mp4"
    end
  end

  describe "Branch 7: no row + strict opt → :provider_asset_not_ready (D-20)" do
    test "returns :provider_asset_not_ready when opts[:strict] = true (no telemetry)" do
      ref = attach_streaming_telemetry()
      asset = insert_asset!()
      # No insert_provider_asset!

      assert {:error, :provider_asset_not_ready} =
               Rindle.Delivery.streaming_url(StreamingProfile, asset, strict: true)

      refute_received {[:rindle, :delivery, :streaming, :resolved], ^ref, _, _}
    end
  end

  describe "Repo.get_by lookup keys (D-21, D-22)" do
    test "lookup keys on (asset_id, profile, provider_name) — single row hit (no N+1)" do
      asset = insert_asset!()

      # Insert a row that should match the lookup
      _row =
        insert_provider_asset!(asset, %{state: "errored", provider_name: "provider_mock"})

      # Insert a decoy with a different provider_name — should NOT be matched
      decoy_asset = insert_asset!()

      _decoy =
        insert_provider_asset!(decoy_asset, %{
          state: "ready",
          provider_name: "other_provider",
          playback_ids: ["should-not-be-used"]
        })

      # Expect only the matching row's state branches (errored → :provider_sync_failed).
      assert {:error, :provider_sync_failed} =
               Rindle.Delivery.streaming_url(StreamingProfile, asset)
    end
  end

  # WR-04: Branch 5 must cross-check the persisted playback_policy / ingest_mode
  # on the media_provider_assets row against the live streaming_config. When
  # they disagree, refuse the URL and emit a config_drift warning telemetry.
  describe "Branch 5: config drift between row and profile (WR-04)" do
    test "row playback_policy differs from streaming_config returns :provider_sync_failed and emits drift telemetry" do
      drift_ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rindle, :delivery, :streaming, :config_drift]
        ])

      on_exit(fn -> :telemetry.detach(drift_ref) end)

      resolved_ref = attach_streaming_telemetry()
      asset = insert_asset!()

      # StreamingProfile declares playback_policy: :signed; persist a row that
      # disagrees ("public") to simulate config drift between the persisted
      # provider asset and the live profile config.
      _row =
        insert_provider_asset!(asset, %{
          state: "ready",
          playback_ids: ["pb-drift-1234"],
          playback_policy: "public",
          ingest_mode: "server_push"
        })

      # Provider must NOT be called when drift is detected.
      assert {:error, :provider_sync_failed} =
               Rindle.Delivery.streaming_url(StreamingProfile, asset)

      assert_received {[:rindle, :delivery, :streaming, :config_drift], ^drift_ref, _measurements,
                       drift_metadata}

      assert drift_metadata.field == :playback_policy
      assert drift_metadata.row_value == "public"
      assert drift_metadata.expected == "signed"
      assert drift_metadata.profile == StreamingProfile
      assert drift_metadata.provider == Rindle.Streaming.ProviderMock

      refute_received {[:rindle, :delivery, :streaming, :resolved], ^resolved_ref, _, _}
    end

    test "row ingest_mode differs from streaming_config returns :provider_sync_failed and emits drift telemetry" do
      drift_ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rindle, :delivery, :streaming, :config_drift]
        ])

      on_exit(fn -> :telemetry.detach(drift_ref) end)

      resolved_ref = attach_streaming_telemetry()
      asset = insert_asset!()

      # StreamingProfile declares ingest_mode: :server_push; persist a row
      # whose policy matches but ingest_mode disagrees.
      _row =
        insert_provider_asset!(asset, %{
          state: "ready",
          playback_ids: ["pb-drift-mode-1234"],
          playback_policy: "signed",
          ingest_mode: "direct_creator_upload"
        })

      assert {:error, :provider_sync_failed} =
               Rindle.Delivery.streaming_url(StreamingProfile, asset)

      assert_received {[:rindle, :delivery, :streaming, :config_drift], ^drift_ref, _measurements,
                       drift_metadata}

      assert drift_metadata.field == :ingest_mode
      assert drift_metadata.row_value == "direct_creator_upload"
      assert drift_metadata.expected == "server_push"

      refute_received {[:rindle, :delivery, :streaming, :resolved], ^resolved_ref, _, _}
    end

    test "row playback_policy/ingest_mode matching the streaming_config proceeds to provider call" do
      drift_ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rindle, :delivery, :streaming, :config_drift]
        ])

      on_exit(fn -> :telemetry.detach(drift_ref) end)

      asset = insert_asset!()

      _row =
        insert_provider_asset!(asset, %{
          state: "ready",
          playback_ids: ["pb-aligned-1234"],
          playback_policy: "signed",
          ingest_mode: "server_push"
        })

      expect(Rindle.Streaming.ProviderMock, :signed_playback_url, fn StreamingProfile,
                                                                     "pb-aligned-1234",
                                                                     _opts ->
        {:ok,
         %{
           url: "https://stream.example/pb-aligned-1234.m3u8?token=ok",
           kind: :hls,
           mime: "application/vnd.apple.mpegurl"
         }}
      end)

      assert {:ok, %{kind: :hls}} = Rindle.Delivery.streaming_url(StreamingProfile, asset)

      refute_received {[:rindle, :delivery, :streaming, :config_drift], ^drift_ref, _, _}
    end

    test "direct_creator_upload rows still resolve signed playback once the provider row is ready" do
      asset =
        insert_asset!(%{
          profile: inspect(DirectUploadStreamingProfile)
        })

      _row =
        insert_provider_asset!(asset, DirectUploadStreamingProfile, %{
          state: "ready",
          playback_ids: ["pb-direct-1234"],
          playback_policy: "signed",
          ingest_mode: "direct_creator_upload"
        })

      expect(Rindle.Streaming.ProviderMock, :signed_playback_url, fn DirectUploadStreamingProfile,
                                                                     "pb-direct-1234",
                                                                     _opts ->
        {:ok,
         %{
           url: "https://stream.example/pb-direct-1234.m3u8?token=ok",
           kind: :hls,
           mime: "application/vnd.apple.mpegurl"
         }}
      end)

      assert {:ok, %{kind: :hls, url: url}} =
               Rindle.Delivery.streaming_url(DirectUploadStreamingProfile, asset)

      assert url =~ "pb-direct-1234"
    end
  end

  # CR-01: Branch 5 must call the configured authorizer before the provider call.
  # Without this, profiles with both :streaming AND :authorizer leak signed HLS
  # URLs to callers the authorizer would have rejected, as soon as the row state
  # flips to :ready. Mirrors the Branch 1/6 (progressive) authorize_delivery
  # contract.
  describe "Branch 5: authorizer integration (CR-01 regression)" do
    defp insert_authorized_asset!(attrs \\ %{}) do
      %MediaAsset{}
      |> MediaAsset.changeset(
        Map.merge(
          %{
            state: "available",
            storage_key: "assets/#{System.unique_integer([:positive])}/orig.mp4",
            content_type: "video/mp4",
            byte_size: 1024,
            filename: "orig.mp4",
            recipe_digest: "abc",
            profile: inspect(AuthorizedStreamingProfile),
            kind: "video"
          },
          attrs
        )
      )
      |> Repo.insert!()
    end

    test "authorizer rejection on :ready row returns {:error, :forbidden} and emits no telemetry" do
      ref = attach_streaming_telemetry()
      asset = insert_authorized_asset!()

      _row =
        insert_provider_asset!(asset, AuthorizedStreamingProfile, %{
          state: "ready",
          playback_ids: ["pb-secret-1234"]
        })

      expect(Rindle.AuthorizerMock, :authorize, fn _actor,
                                                   :deliver,
                                                   %{
                                                     profile: AuthorizedStreamingProfile,
                                                     playback_id: "pb-secret-1234",
                                                     mode: :private,
                                                     kind: :hls
                                                   } ->
        {:error, :forbidden}
      end)

      # Provider must NOT be called when the authorizer rejects.
      # Mox.verify_on_exit! enforces no unexpected calls.

      assert {:error, :forbidden} =
               Rindle.Delivery.streaming_url(AuthorizedStreamingProfile, asset)

      refute_received {[:rindle, :delivery, :streaming, :resolved], ^ref, _, _}
    end

    test "authorizer approval on :ready row proceeds through the provider call" do
      ref = attach_streaming_telemetry()
      asset = insert_authorized_asset!()

      _row =
        insert_provider_asset!(asset, AuthorizedStreamingProfile, %{
          state: "ready",
          playback_ids: ["pb-allowed-1234"]
        })

      expect(Rindle.AuthorizerMock, :authorize, fn _actor,
                                                   :deliver,
                                                   %{
                                                     profile: AuthorizedStreamingProfile,
                                                     playback_id: "pb-allowed-1234",
                                                     mode: :private,
                                                     kind: :hls
                                                   } ->
        :ok
      end)

      expect(Rindle.Streaming.ProviderMock, :signed_playback_url, fn AuthorizedStreamingProfile,
                                                                     "pb-allowed-1234",
                                                                     _opts ->
        {:ok,
         %{
           url: "https://stream.example/pb-allowed-1234.m3u8?token=ok",
           kind: :hls,
           mime: "application/vnd.apple.mpegurl"
         }}
      end)

      assert {:ok,
              %{
                url: "https://stream.example/pb-allowed-1234.m3u8?token=ok",
                kind: :hls,
                mime: "application/vnd.apple.mpegurl"
              }} = Rindle.Delivery.streaming_url(AuthorizedStreamingProfile, asset)

      assert_received {[:rindle, :delivery, :streaming, :resolved], ^ref, _measurements, metadata}
      assert metadata.profile == AuthorizedStreamingProfile
      assert metadata.kind == :hls
      assert metadata.mode == :private
    end
  end
end
