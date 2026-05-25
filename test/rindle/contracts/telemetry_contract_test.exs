defmodule Rindle.Contracts.TelemetryContractTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Plug.Test
  alias Rindle.Delivery.LocalPlug
  alias Rindle.Domain.AssetFSM
  alias Rindle.Domain.{MediaAsset, MediaVariant, VariantFSM}
  alias Rindle.Ops.RuntimeChecks
  alias Rindle.Storage.Local
  alias Rindle.Upload.ResumableTelemetry
  alias Rindle.Workers.ProcessVariant

  @moduledoc """
  Telemetry public contract — locked event family.

  Asserts the exact event-name allowlist, required `profile` + `adapter`
  metadata keys, and that all measurements are numeric. A name change,
  metadata-key drift, or AV transcode event-shape drift breaks this lane.

  Run: `mix test --only contract`

  Per D-04/D-05/D-06 in `.planning/phases/05-ci-1-0-readiness/05-CONTEXT.md`.
  """

  @moduletag :contract

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule AVContractProfile do
    @moduledoc false

    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [
        web_720p: [kind: :video, preset: :web_720p]
      ],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000
  end

  defmodule LocalContractProfile do
    @moduledoc false
    # Delivery is set to public so the local adapter (which advertises
    # [:local, :presigned_put] but not :signed_url) resolves a URL without
    # the private-mode capability gate rejecting the call. The locked
    # [:rindle, :delivery, :signed] event still fires for both :public and
    # :private modes (mode is metadata, not a separate event name).
    use Rindle.Profile,
      storage: Local,
      variants: [thumb: [mode: :fit, width: 8, height: 8]],
      allow_mime: ["image/png"],
      max_bytes: 10_485_760,
      delivery: [public: true]
  end

  defmodule StreamingContractProfile do
    @moduledoc false

    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [web: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000,
      delivery: [public: true]
  end

  @public_events [
    [:rindle, :upload, :start],
    [:rindle, :upload, :stop],
    [:rindle, :upload, :resumable, :start],
    [:rindle, :upload, :resumable, :patch],
    [:rindle, :upload, :resumable, :stop],
    [:rindle, :upload, :resumable, :status],
    [:rindle, :upload, :resumable, :cancel],
    [:rindle, :asset, :state_change],
    [:rindle, :variant, :state_change],
    [:rindle, :delivery, :signed],
    [:rindle, :delivery, :streaming, :resolved],
    [:rindle, :delivery, :range_request],
    [:rindle, :cleanup, :run],
    [:rindle, :repair, :start],
    [:rindle, :repair, :stop],
    [:rindle, :repair, :exception],
    [:rindle, :runtime, :refusal],
    [:rindle, :runtime, :check, :stop],
    [:rindle, :media, :transcode, :start],
    [:rindle, :media, :transcode, :stop],
    [:rindle, :media, :transcode, :exception]
  ]
  @background_processing_path Path.expand("../../../guides/background_processing.md", __DIR__)

  setup do
    ref = :telemetry_test.attach_event_handlers(self(), @public_events)
    on_exit(fn -> :telemetry.detach(ref) end)
    {:ok, ref: ref}
  end

  describe "public event allowlist" do
    test "is exactly the documented public contract" do
      assert length(@public_events) == 21

      assert [:rindle, :upload, :resumable, :start] in @public_events
      assert [:rindle, :upload, :resumable, :patch] in @public_events
      assert [:rindle, :upload, :resumable, :stop] in @public_events
      assert [:rindle, :upload, :resumable, :status] in @public_events
      assert [:rindle, :upload, :resumable, :cancel] in @public_events

      for event <- @public_events do
        assert is_list(event)
        assert length(event) in [3, 4, 5]
        assert Enum.all?(event, &is_atom/1)
        assert hd(event) == :rindle
      end
    end

    test "background processing guide documents the public telemetry allowlist and AV triplet" do
      guide = File.read!(@background_processing_path)

      assert guide =~ ":start / :stop / :exception"
      assert guide =~ "@public_events"
      assert guide =~ "test/rindle/contracts/telemetry_contract_test.exs"

      for event_name <-
            @public_events |> Enum.reject(&resumable_event?/1) |> Enum.map(&format_event_name/1) do
        assert guide =~ event_name
      end
    end

    test "asset-scoped repair flows emit the additive repair telemetry family", %{ref: ref} do
      asset =
        %MediaAsset{}
        |> MediaAsset.changeset(%{
          state: "degraded",
          profile: to_string(LocalContractProfile),
          kind: "image",
          content_type: "image/png",
          storage_key: "repair/source.png"
        })
        |> Rindle.Repo.insert!()

      _variant =
        %MediaVariant{}
        |> MediaVariant.changeset(%{
          asset_id: asset.id,
          name: "thumb",
          state: "failed",
          recipe_digest: LocalContractProfile.recipe_digest(:thumb),
          output_kind: "image"
        })
        |> Rindle.Repo.insert!()

      assert {:ok, _report} = Rindle.requeue_variants(asset.id)

      assert_received {[:rindle, :repair, :start], ^ref, start_measurements, start_metadata}
      assert_received {[:rindle, :repair, :stop], ^ref, stop_measurements, stop_metadata}

      assert_numeric_measurements(start_measurements)
      assert_numeric_measurements(stop_measurements)

      assert start_metadata == %{
               operation: :requeue,
               scope: :asset,
               result: :started,
               dry_run: false
             }

      assert stop_metadata.operation == :requeue
      assert stop_metadata.scope == :asset
      assert stop_metadata.result == :ok
      assert stop_metadata.dry_run == false
      assert stop_measurements.enqueued == 1
    end

    test "repair exception telemetry stays low-cardinality", %{ref: ref} do
      assert_raise FunctionClauseError, fn ->
        Rindle.reprobe(123)
      end

      assert_received {[:rindle, :repair, :start], ^ref, start_measurements, start_metadata}

      assert_received {[:rindle, :repair, :exception], ^ref, exception_measurements,
                       exception_metadata}

      assert_numeric_measurements(start_measurements)
      assert_numeric_measurements(exception_measurements)

      assert start_metadata == %{
               operation: :reprobe,
               scope: :asset,
               result: :started,
               dry_run: false
             }

      assert exception_metadata == %{
               operation: :reprobe,
               scope: :asset,
               result: :exception,
               dry_run: false
             }
    end

    test "runtime_status invalid filters emit runtime refusal telemetry", %{ref: ref} do
      assert {:error, {:unknown_filters, [:unknown]}} = Rindle.runtime_status(%{unknown: true})

      assert_received {[:rindle, :runtime, :refusal], ^ref, measurements, metadata}
      assert_numeric_measurements(measurements)
      assert metadata == %{surface: :runtime_status, reason: :unknown_filters, mode: :api}
    end

    test "doctor check runner emits runtime check stop telemetry", %{ref: ref} do
      _report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: []
        )

      assert_received {[:rindle, :runtime, :check, :stop], ^ref, measurements, metadata}
      assert_numeric_measurements(measurements)
      assert is_binary(metadata.check)
      assert metadata.status in [:ok, :error]
      assert is_atom(metadata.component)
    end

    test "resumable telemetry helpers emit the locked public contract", %{ref: ref} do
      session = %Rindle.Domain.MediaUploadSession{
        id: "sess-1",
        session_uri: "https://storage.googleapis.com/upload/secret"
      }

      ResumableTelemetry.emit_status(
        "TestProfile",
        Rindle.Storage.GCS,
        session,
        %{state: "resuming", source: :poll, session_uri: session.session_uri},
        %{committed_bytes: 128, offset_delta: 64}
      )

      ResumableTelemetry.emit_cancel(
        "TestProfile",
        Rindle.Storage.GCS,
        session,
        %{outcome: :cancelled, reason: :operator_request, source: :maintenance},
        %{duration_us: 42}
      )

      ResumableTelemetry.emit_start(
        "TestProfile",
        Rindle.Storage.GCS,
        session,
        %{state: "signed", source: :broker, protocol: :tus},
        %{}
      )

      ResumableTelemetry.emit_patch(
        "TestProfile",
        Rindle.Storage.GCS,
        session,
        %{state: "signed", source: :patch, outcome: :ok, protocol: :tus},
        %{committed_bytes: 256, offset_delta: 128}
      )

      ResumableTelemetry.emit_stop(
        "TestProfile",
        Rindle.Storage.GCS,
        session,
        %{outcome: :ok, source: :verify_completion, protocol: :tus},
        %{committed_bytes: 256}
      )

      assert_received {[:rindle, :upload, :resumable, :start], ^ref, start_measurements,
                       start_metadata}

      assert_received {[:rindle, :upload, :resumable, :patch], ^ref, patch_measurements,
                       patch_metadata}

      assert_received {[:rindle, :upload, :resumable, :stop], ^ref, stop_measurements,
                       stop_metadata}

      assert_received {[:rindle, :upload, :resumable, :status], ^ref, status_measurements,
                       status_metadata}

      assert_received {[:rindle, :upload, :resumable, :cancel], ^ref, cancel_measurements,
                       cancel_metadata}

      assert_required_metadata_keys(start_metadata)
      assert_required_metadata_keys(patch_metadata)
      assert_required_metadata_keys(stop_metadata)
      assert_numeric_measurements(start_measurements)
      assert_numeric_measurements(patch_measurements)
      assert_numeric_measurements(stop_measurements)
      assert_required_metadata_keys(status_metadata)
      assert_required_metadata_keys(cancel_metadata)
      assert_numeric_measurements(status_measurements)
      assert_numeric_measurements(cancel_measurements)

      refute Map.has_key?(status_metadata, :session_uri)
      assert status_metadata.profile == "TestProfile"
      assert status_metadata.adapter == Rindle.Storage.GCS
      assert cancel_metadata.profile == "TestProfile"
      assert cancel_metadata.adapter == Rindle.Storage.GCS
    end
  end

  describe "metadata + measurement contract" do
    test "AssetFSM.transition/3 emits with required metadata + numeric measurements",
         %{ref: ref} do
      assert :ok =
               AssetFSM.transition("staged", "validating", %{
                 profile: "TestProfile",
                 adapter: __MODULE__
               })

      assert_received {[:rindle, :asset, :state_change], ^ref, measurements, metadata}
      assert_required_metadata_keys(metadata)
      assert_numeric_measurements(measurements)
      assert metadata.profile == "TestProfile"
      assert metadata.adapter == __MODULE__
    end

    test "VariantFSM.transition/3 emits with required metadata + numeric measurements",
         %{ref: ref} do
      assert :ok =
               VariantFSM.transition("planned", "queued", %{
                 profile: "TestProfile",
                 adapter: __MODULE__
               })

      assert_received {[:rindle, :variant, :state_change], ^ref, measurements, metadata}
      assert_required_metadata_keys(metadata)
      assert_numeric_measurements(measurements)
    end

    test "Delivery.url/3 emits :delivery :signed with required metadata", %{ref: ref} do
      # Use a tmp root for the local adapter so the call resolves a URL without IO setup
      root =
        Path.join(System.tmp_dir!(), "rindle-contract-#{System.unique_integer([:positive])}")

      File.mkdir_p!(root)
      previous = Application.get_env(:rindle, Local)
      Application.put_env(:rindle, Local, root: root)

      on_exit(fn ->
        case previous do
          nil -> Application.delete_env(:rindle, Local)
          value -> Application.put_env(:rindle, Local, value)
        end

        File.rm_rf(root)
      end)

      {:ok, _url} = Rindle.Delivery.url(LocalContractProfile, "test/key.png")

      assert_received {[:rindle, :delivery, :signed], ^ref, measurements, metadata}
      assert_required_metadata_keys(metadata)
      assert_numeric_measurements(measurements)
      assert metadata.profile == LocalContractProfile
      assert metadata.adapter == Local
    end

    test "Delivery.streaming_url/3 emits :delivery :streaming :resolved with stable metadata",
         %{ref: ref} do
      key = "telemetry/video.mp4"

      expect(Rindle.StorageMock, :url, fn ^key, _opts ->
        {:ok, "https://stream.example/#{key}"}
      end)

      assert {:ok, %{url: url, kind: :progressive, mime: "audio/mpeg"}} =
               Rindle.Delivery.streaming_url(
                 StreamingContractProfile,
                 key,
                 mime: "audio/mpeg"
               )

      assert url == "https://stream.example/#{key}"

      assert_received {[:rindle, :delivery, :streaming, :resolved], ^ref, measurements, metadata}
      assert_numeric_measurements(measurements)
      assert metadata.profile == StreamingContractProfile
      assert metadata.adapter == Rindle.StorageMock
      assert metadata.mode == :public
      assert metadata.kind == :progressive
      assert metadata.mime == "audio/mpeg"
    end

    test "LocalPlug emits :delivery :range_request with stable metadata", %{ref: ref} do
      root =
        Path.join(
          System.tmp_dir!(),
          "rindle-contract-range-#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(root)
      on_exit(fn -> File.rm_rf(root) end)

      key = "telemetry/video.mp4"
      path = Local.path_for(key, root: root)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, "0123456789abcdef")

      route = [
        base_url: "http://example.test/rindle/local",
        secret_key_base: String.duplicate("contract-secret-", 4)
      ]

      {:ok, %{url: url}} =
        Rindle.Delivery.streaming_url(
          LocalContractProfile,
          key,
          root: root,
          local_route: route,
          actor: %{id: "viewer-1"}
        )

      conn =
        Test.conn("GET", request_path(url))
        |> Map.put(:secret_key_base, route[:secret_key_base])
        |> Plug.Conn.put_req_header("range", "bytes=4-7")

      opts =
        LocalPlug.init(
          profile: LocalContractProfile,
          root: root,
          secret_key_base: route[:secret_key_base]
        )

      response = LocalPlug.call(conn, opts)

      assert response.status == 206

      assert_received {[:rindle, :delivery, :range_request], ^ref, measurements, metadata}
      assert_numeric_measurements(measurements)
      assert measurements.offset == 4
      assert measurements.length == 4
      assert measurements.file_size == 16
      assert metadata.profile == LocalContractProfile
      assert metadata.adapter == Local
      assert metadata.key == key
      assert metadata.actor_subject == "viewer-1"
    end

    test "ProcessVariant emits the AV transcode start/stop contract on success", %{ref: ref} do
      asset =
        %MediaAsset{}
        |> MediaAsset.changeset(%{
          state: "available",
          profile: to_string(AVContractProfile),
          kind: "video",
          storage_key: "telemetry/source.mp4",
          duration_ms: 1_200
        })
        |> Rindle.Repo.insert!()

      variant =
        %MediaVariant{}
        |> MediaVariant.changeset(%{
          asset_id: asset.id,
          name: "web_720p",
          state: "planned",
          recipe_digest: AVContractProfile.recipe_digest(:web_720p),
          output_kind: "video"
        })
        |> Rindle.Repo.insert!()

      expect(Rindle.StorageMock, :download, fn _key, tmp_path, _opts ->
        build_video_fixture!(tmp_path)
        {:ok, tmp_path}
      end)

      expect(Rindle.StorageMock, :store, fn key, _path, _opts ->
        {:ok, %{key: key}}
      end)

      assert :ok =
               perform_job(ProcessVariant, %{
                 "asset_id" => asset.id,
                 "variant_name" => variant.name
               })

      assert_received {[:rindle, :media, :transcode, :start], ^ref, start_measurements,
                       start_metadata}

      assert_received {[:rindle, :media, :transcode, :stop], ^ref, stop_measurements,
                       stop_metadata}

      assert start_measurements == %{system_time: start_measurements.system_time}
      assert stop_measurements.duration > 0
      assert is_integer(stop_measurements.system_time)

      assert start_metadata == %{
               asset_id: asset.id,
               output_kind: "video",
               preset: :web_720p,
               profile: to_string(AVContractProfile),
               variant_id: variant.id,
               variant_name: variant.name
             }

      assert stop_metadata == start_metadata
    end

    test "ProcessVariant emits the AV transcode exception contract on failure", %{ref: ref} do
      asset =
        %MediaAsset{}
        |> MediaAsset.changeset(%{
          state: "available",
          profile: to_string(AVContractProfile),
          kind: "video",
          storage_key: "telemetry/missing.mp4",
          duration_ms: 1_200
        })
        |> Rindle.Repo.insert!()

      variant =
        %MediaVariant{}
        |> MediaVariant.changeset(%{
          asset_id: asset.id,
          name: "web_720p",
          state: "planned",
          recipe_digest: AVContractProfile.recipe_digest(:web_720p),
          output_kind: "video"
        })
        |> Rindle.Repo.insert!()

      expect(Rindle.StorageMock, :download, fn _key, _tmp_path, _opts ->
        {:error, :missing_source}
      end)

      assert {:error, :missing_source} =
               perform_job(ProcessVariant, %{
                 "asset_id" => asset.id,
                 "variant_name" => variant.name
               })

      assert_received {[:rindle, :media, :transcode, :start], ^ref, _start_measurements,
                       start_metadata}

      assert_received {[:rindle, :media, :transcode, :exception], ^ref, exception_measurements,
                       exception_metadata}

      assert exception_measurements.duration > 0
      assert is_integer(exception_measurements.system_time)

      assert exception_metadata ==
               Map.merge(start_metadata, %{kind: :error, reason: :missing_source})
    end
  end

  describe "no event outside allowlist fires" do
    test "every emitted [:rindle | _] event is in @public_events", %{ref: _ref} do
      # Attach a separate broad handler that captures every probe event observed.
      handler_id = "rindle-contract-broad-#{System.unique_integer([:positive])}"
      parent = self()

      # We cannot truly wildcard in :telemetry, so we attach to every event in
      # @public_events PLUS a superset of plausible-but-not-public names. If
      # those plausible names ever fire, the assertion below catches them.
      probe_events =
        @public_events ++
          [
            [:rindle, :upload, :began],
            [:rindle, :upload, :ended],
            [:rindle, :asset, :transitioned],
            [:rindle, :variant, :transitioned],
            [:rindle, :delivery, :issued],
            [:rindle, :cleanup, :ran],
            [:rindle, :repair, :ran],
            [:rindle, :runtime, :denied],
            [:rindle, :media, :transcode, :began],
            [:rindle, :media, :transcode, :ended],
            [:rindle, :media, :transcode, :failed]
          ]

      :telemetry.attach_many(
        handler_id,
        probe_events,
        fn name, measurements, metadata, _config ->
          send(parent, {:probe_observed, name, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      # Trigger every locked emission site we can fire in-process.
      AssetFSM.transition("staged", "validating", %{profile: "p", adapter: A})

      VariantFSM.transition("planned", "queued", %{
        profile: "p",
        adapter: A
      })

      # Drain probe messages and check each is on the allowlist.
      observed = drain_probe_observations([])

      for {name, _meas, _meta} <- observed do
        assert name in @public_events,
               "telemetry contract violation: observed event #{inspect(name)} is NOT in @public_events allowlist"
      end
    end
  end

  # ----------------------------------------------------------------------
  # Private assertion helpers — keep contract surface in this module.
  # ----------------------------------------------------------------------

  defp assert_required_metadata_keys(metadata) when is_map(metadata) do
    assert Map.has_key?(metadata, :profile),
           "telemetry contract violation: emitted event missing :profile metadata key"

    assert Map.has_key?(metadata, :adapter),
           "telemetry contract violation: emitted event missing :adapter metadata key"
  end

  defp assert_numeric_measurements(measurements) when is_map(measurements) do
    for {key, value} <- measurements do
      assert is_number(value),
             "telemetry contract violation: measurement #{inspect(key)} = #{inspect(value)} is not numeric"
    end
  end

  defp drain_probe_observations(acc) do
    receive do
      {:probe_observed, name, m, md} -> drain_probe_observations([{name, m, md} | acc])
    after
      10 -> Enum.reverse(acc)
    end
  end

  defp build_video_fixture!(path) do
    args = [
      "-y",
      "-f",
      "lavfi",
      "-i",
      "testsrc=size=320x180:rate=30:duration=1.2",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=880:sample_rate=48000:duration=1.2",
      "-map",
      "0:v:0",
      "-map",
      "1:a:0",
      "-c:v",
      "libx264",
      "-pix_fmt",
      "yuv420p",
      "-c:a",
      "aac",
      path
    ]

    {_output, 0} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
  end

  defp request_path(url) do
    uri = URI.parse(url)
    uri.path <> if(uri.query, do: "?" <> uri.query, else: "")
  end

  defp format_event_name(event) do
    event
    |> Enum.map_join(", ", &inspect/1)
    |> then(&"[#{&1}]")
  end

  defp resumable_event?([:rindle, :upload, :resumable, _action]), do: true
  defp resumable_event?(_event), do: false
end
