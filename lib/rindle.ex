defmodule Rindle do
  @moduledoc """
  Phoenix/Ecto-native media lifecycle library.

  Rindle manages the full post-upload lifecycle: upload sessions, staged object
  verification, asset modeling, attachment associations, variant/derivative
  generation, background processing, secure delivery, observability, and
  day-2 operations.
  """

  require Logger

  @typedoc "Tagged storage result shape: {:ok, result} | {:error, reason}"
  @type storage_result :: {:ok, term()} | {:error, term()}

  @doc """
  Returns the current version of Rindle.
  """
  @spec version :: String.t()
  def version do
    Application.spec(:rindle, :vsn) |> to_string()
  end

  @doc """
  Resolves the storage adapter module for a given profile.
  """
  @spec storage_adapter_for(module()) :: module()
  def storage_adapter_for(profile) do
    profile.storage_adapter()
  end

  @doc """
  Stores an object through the profile-specific storage adapter.
  """
  @spec store(module(), String.t(), Path.t(), keyword()) :: storage_result()
  def store(profile, key, source_path, opts \\ []) do
    invoke_storage(profile, :store, [key, source_path, opts])
  end

  @doc """
  Deletes an object through the profile-specific storage adapter.
  """
  @spec delete(module(), String.t(), keyword()) :: storage_result()
  def delete(profile, key, opts \\ []) do
    invoke_storage(profile, :delete, [key, opts])
  end

  @doc """
  Generates a delivery URL through the profile-specific storage adapter.
  """
  @spec url(module(), String.t(), keyword()) :: storage_result()
  def url(profile, key, opts \\ []) do
    invoke_storage(profile, :url, [key, opts])
  end

  @doc """
  Generates a presigned PUT payload through the profile-specific storage adapter.
  """
  @spec presigned_put(module(), String.t(), pos_integer(), keyword()) :: storage_result()
  def presigned_put(profile, key, expires_in, opts \\ []) do
    invoke_storage(profile, :presigned_put, [key, expires_in, opts])
  end

  @doc """
  Executes variant storage and logs failures with required context metadata.
  """
  @spec store_variant(module(), String.t(), Path.t(), keyword()) :: storage_result()
  def store_variant(profile, key, source_path, opts \\ []) do
    asset_id = Keyword.get(opts, :asset_id)
    variant_name = Keyword.get(opts, :variant_name)
    adapter_opts = Keyword.drop(opts, [:asset_id, :variant_name])

    case store(profile, key, source_path, adapter_opts) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} = error ->
        log_variant_processing_failure(asset_id, variant_name, reason)
        error
    end
  end

  @doc """
  Logs a structured storage processing failure for downstream observability.
  """
  @spec log_variant_processing_failure(term(), term(), term()) :: :ok
  def log_variant_processing_failure(asset_id, variant_name, reason) do
    Logger.error("rindle.storage.variant_processing_failed",
      asset_id: asset_id,
      variant_name: variant_name,
      reason: reason
    )
  end

  defp invoke_storage(profile, function_name, args) do
    adapter = storage_adapter_for(profile)

    try do
      normalize_storage_result(apply(adapter, function_name, args))
    rescue
      exception ->
        {:error, {:storage_adapter_exception, exception}}
    end
  end

  defp normalize_storage_result({:ok, _result} = result), do: result
  defp normalize_storage_result({:error, _reason} = result), do: result
  defp normalize_storage_result(other), do: {:error, {:invalid_storage_response, other}}
end
