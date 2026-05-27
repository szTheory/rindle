defmodule Rindle.Streaming.Capabilities do
  @moduledoc false

  @typedoc """
  Known streaming capability atoms.

  `:direct_creator_upload` is advertised by the Mux reference adapter when the
  profile enables browser→provider direct upload (shipped v1.8).
  """
  @type capability ::
          :signed_playback
          | :public_playback
          | :webhook_ingest
          | :server_push_ingest
          | :direct_creator_upload

  @known [
    :signed_playback,
    :public_playback,
    :webhook_ingest,
    :server_push_ingest,
    :direct_creator_upload
  ]

  @spec known() :: [capability()]
  def known, do: @known

  @spec safe(module()) :: [capability()]
  def safe(adapter) do
    case adapter.capabilities() do
      capabilities when is_list(capabilities) ->
        Enum.filter(capabilities, &(&1 in @known))

      _ ->
        []
    end
  rescue
    _ -> []
  end

  @spec supports?(module(), capability()) :: boolean()
  def supports?(adapter, capability), do: capability in safe(adapter)
end
