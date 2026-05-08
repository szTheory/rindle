defmodule Rindle.Upload.ResumableTelemetry do
  @moduledoc false

  alias Rindle.Domain.MediaUploadSession

  @status_event [:rindle, :upload, :resumable, :status]
  @cancel_event [:rindle, :upload, :resumable, :cancel]
  @allowed_metadata_keys [:state, :outcome, :reason, :source]
  @forbidden_metadata_keys [:session_uri, :upload_key, :headers, :body, :session_id]

  @spec emit_status(
          term(),
          term(),
          MediaUploadSession.t() | nil,
          map() | keyword(),
          map() | keyword()
        ) ::
          :ok
  def emit_status(profile, adapter, session_or_nil, metadata_overrides, measurements_overrides) do
    measurements =
      measurements_overrides
      |> normalize_map()
      |> Map.take([:committed_bytes, :offset_delta, :system_time])
      |> Map.put_new(:system_time, System.system_time())
      |> then(fn measurements ->
        %{committed_bytes: Map.fetch!(measurements, :committed_bytes)}
        |> Map.merge(Map.take(measurements, [:offset_delta, :system_time]))
      end)

    emit(@status_event, profile, adapter, session_or_nil, metadata_overrides, measurements)
  end

  @spec emit_cancel(
          term(),
          term(),
          MediaUploadSession.t() | nil,
          map() | keyword(),
          map() | keyword()
        ) ::
          :ok
  def emit_cancel(profile, adapter, session_or_nil, metadata_overrides, measurements_overrides) do
    measurements =
      measurements_overrides
      |> normalize_map()
      |> Map.take([:duration_us, :system_time])
      |> Map.put_new(:system_time, System.system_time())
      |> then(fn measurements ->
        %{duration_us: Map.fetch!(measurements, :duration_us)}
        |> Map.merge(Map.take(measurements, [:system_time]))
      end)

    emit(@cancel_event, profile, adapter, session_or_nil, metadata_overrides, measurements)
  end

  defp emit(event, profile, adapter, session_or_nil, metadata_overrides, measurements) do
    metadata =
      metadata_overrides
      |> normalize_map()
      |> Map.drop(@forbidden_metadata_keys)
      |> Map.take(@allowed_metadata_keys)
      |> Map.merge(%{profile: profile, adapter: adapter})
      |> maybe_put_session_id(session_or_nil)

    :telemetry.execute(event, measurements, metadata)
  end

  defp maybe_put_session_id(metadata, %MediaUploadSession{id: session_id})
       when is_binary(session_id),
       do: Map.put(metadata, :session_id, session_id)

  defp maybe_put_session_id(metadata, _session_or_nil), do: metadata

  defp normalize_map(map) when is_map(map), do: map
  defp normalize_map(keyword) when is_list(keyword), do: Map.new(keyword)
  defp normalize_map(_other), do: %{}
end
