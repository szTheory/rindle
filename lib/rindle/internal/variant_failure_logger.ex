defmodule Rindle.Internal.VariantFailureLogger do
  @moduledoc false

  require Logger

  @spec log(term(), term(), term()) :: :ok
  def log(asset_id, variant_name, reason) do
    Logger.error("rindle.storage.variant_processing_failed",
      asset_id: asset_id,
      variant_name: variant_name,
      reason: reason
    )
  end
end
