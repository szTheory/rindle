defmodule Rindle.Storage.Capabilities do
  @moduledoc """
  Shared storage capability vocabulary and negotiation helpers.
  """

  @typedoc """
  Known adapter capability atoms.

  Reserved resumable capability names are additive placeholders for future
  adapters and do not require current adapters to advertise them.
  """
  @type capability ::
          :presigned_put
          | :multipart_upload
          | :signed_url
          | :head
          | :local
          | :resumable_upload
          | :resumable_upload_session

  @known [
    :presigned_put,
    :multipart_upload,
    :signed_url,
    :head,
    :local,
    :resumable_upload,
    :resumable_upload_session
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

  @spec require_upload(module(), capability()) :: :ok | {:error, {:upload_unsupported, capability()}}
  def require_upload(adapter, capability) do
    if supports?(adapter, capability) do
      :ok
    else
      {:error, {:upload_unsupported, capability}}
    end
  end

  @spec require_delivery(module(), capability()) ::
          :ok | {:error, {:delivery_unsupported, capability()}}
  def require_delivery(adapter, capability) do
    if supports?(adapter, capability) do
      :ok
    else
      {:error, {:delivery_unsupported, capability}}
    end
  end
end
