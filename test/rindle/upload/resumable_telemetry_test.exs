defmodule Rindle.Upload.ResumableTelemetryTest do
  use ExUnit.Case, async: false

  alias Rindle.Domain.MediaUploadSession
  alias Rindle.Upload.ResumableTelemetry

  @start_event [:rindle, :upload, :resumable, :start]
  @patch_event [:rindle, :upload, :resumable, :patch]
  @stop_event [:rindle, :upload, :resumable, :stop]
  @status_event [:rindle, :upload, :resumable, :status]
  @cancel_event [:rindle, :upload, :resumable, :cancel]
  @raw_session_uri "https://storage.googleapis.com/upload/session/secret-token"
  @allowed_metadata_keys [
    :profile,
    :adapter,
    :state,
    :outcome,
    :reason,
    :source,
    :protocol,
    :session_id
  ]

  setup do
    handler_id = "resumable-telemetry-test-#{System.unique_integer([:positive])}"
    parent = self()

    :telemetry.attach_many(
      handler_id,
      [@start_event, @patch_event, @stop_event, @status_event, @cancel_event],
      fn event, measurements, metadata, _config ->
        send(parent, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    session = %MediaUploadSession{id: "sess-1", session_uri: @raw_session_uri}

    %{session: session}
  end

  test "emit_start/5 emits the locked public event with allowed metadata only", %{
    session: session
  } do
    ResumableTelemetry.emit_start(
      "test-profile",
      Rindle.Storage.GCS,
      session,
      %{state: "signed", source: :broker, protocol: :tus, session_uri: @raw_session_uri},
      %{}
    )

    assert_received {:telemetry_event, @start_event, measurements, metadata}

    assert metadata.profile == "test-profile"
    assert metadata.adapter == Rindle.Storage.GCS
    assert metadata.state == "signed"
    assert metadata.source == :broker
    assert metadata.protocol == :tus
    assert metadata.session_id == "sess-1"
    refute Map.has_key?(metadata, :session_uri)
    assert is_integer(measurements.system_time)
  end

  test "emit_patch/5 emits committed-byte measurements without forbidden metadata", %{
    session: session
  } do
    ResumableTelemetry.emit_patch(
      "test-profile",
      Rindle.Storage.GCS,
      session,
      %{state: "signed", source: :patch, outcome: :ok, protocol: :tus},
      %{committed_bytes: 256, offset_delta: 128}
    )

    assert_received {:telemetry_event, @patch_event, measurements, metadata}

    assert metadata.protocol == :tus
    assert measurements.committed_bytes == 256
    assert measurements.offset_delta == 128
    assert is_integer(measurements.system_time)
  end

  test "emit_stop/5 emits the locked public stop event", %{session: session} do
    ResumableTelemetry.emit_stop(
      "test-profile",
      Rindle.Storage.GCS,
      session,
      %{outcome: :ok, source: :verify_completion, protocol: :gcs_native},
      %{committed_bytes: 512}
    )

    assert_received {:telemetry_event, @stop_event, measurements, metadata}

    assert metadata.outcome == :ok
    assert metadata.protocol == :gcs_native
    assert measurements.committed_bytes == 512
    assert is_integer(measurements.system_time)
  end

  test "emit_status/5 emits the locked public event without leaking session_uri", %{
    session: session
  } do
    ResumableTelemetry.emit_status(
      "test-profile",
      Rindle.Storage.GCS,
      session,
      %{state: "signed", source: :poll, session_uri: @raw_session_uri, upload_key: "forbidden"},
      %{committed_bytes: 128, offset_delta: 64}
    )

    assert_received {:telemetry_event, @status_event, measurements, metadata}

    assert metadata.profile == "test-profile"
    assert metadata.adapter == Rindle.Storage.GCS
    assert metadata.state == "signed"
    assert metadata.source == :poll
    assert metadata.session_id == "sess-1"

    assert Map.keys(metadata) |> Enum.sort() ==
             Enum.sort([:adapter, :profile, :session_id, :source, :state])

    assert Enum.all?(Map.keys(metadata), &(&1 in @allowed_metadata_keys))
    refute Map.has_key?(metadata, :session_uri)
    refute Map.has_key?(metadata, :upload_key)
    refute Enum.any?(Map.values(metadata), &(&1 == @raw_session_uri))
    refute inspect(session) =~ @raw_session_uri
    assert measurements.committed_bytes == 128
    assert measurements.offset_delta == 64
    assert is_integer(measurements.system_time)
  end

  test "emit_cancel/5 emits the locked public event with allowed metadata only", %{
    session: session
  } do
    ResumableTelemetry.emit_cancel(
      "test-profile",
      Rindle.Storage.GCS,
      session,
      %{
        outcome: :cancelled,
        reason: :operator_request,
        source: :maintenance,
        body: %{forbidden: true},
        headers: %{"x-goog-resumable" => "start"}
      },
      %{duration_us: 42}
    )

    assert_received {:telemetry_event, @cancel_event, measurements, metadata}

    assert metadata.profile == "test-profile"
    assert metadata.adapter == Rindle.Storage.GCS
    assert metadata.session_id == "sess-1"
    assert metadata.outcome == :cancelled
    assert metadata.reason == :operator_request
    assert metadata.source == :maintenance
    assert Enum.all?(Map.keys(metadata), &(&1 in @allowed_metadata_keys))
    refute Map.has_key?(metadata, :body)
    refute Map.has_key?(metadata, :headers)
    refute Map.has_key?(metadata, :session_uri)
    refute Enum.any?(Map.values(metadata), &(&1 == @raw_session_uri))
    refute inspect(session) =~ @raw_session_uri
    assert measurements.duration_us == 42
    assert is_integer(measurements.system_time)
  end
end
