defmodule Rindle.Streaming.Capabilities do
  @moduledoc false

  @typedoc """
  Known streaming capability atoms.

  `:direct_creator_upload` is reserved — Phase 33 ships the vocabulary entry,
  but no v1.6 adapter advertises this capability. Phase 37 / v1.7 is the
  earliest landing for direct-creator-upload support.
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
