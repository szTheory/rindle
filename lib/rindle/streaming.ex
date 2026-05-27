defmodule Rindle.Streaming do
  @moduledoc """
  Streaming-owned public entrypoints.

  Phase 45 adds browser-to-provider direct upload creation here so the public
  contract stays separate from the storage broker lifecycle.

  ## Direct upload cancel (v1.13)

  `cancel_direct_upload/1` accepts only the Rindle `asset_id` returned from
  `create_direct_upload/2`. Success is bare `:ok` (including idempotent re-cancel
  when the row is already `deleted` or the provider upload is already terminal).

  Orchestration is FSM-first: a conditional update from `pending` or `uploading`
  to `deleted` runs before any best-effort provider cancel (Phase 65 implements
  the body). Provider handles never cross the public boundary.
  """

  alias Ecto.Multi
  alias Rindle.Domain.{MediaAsset, MediaProviderAsset}
  alias Rindle.Streaming.Capabilities

  @type direct_upload_result ::
          {:ok, %{upload_url: String.t(), asset_id: Ecto.UUID.t()}} | {:error, term()}

  @typedoc """
  Result of `cancel_direct_upload/1` (implementation ships Phase 65).

  Success is bare `:ok` (idempotent re-cancel included). Provider handles never
  appear on this boundary.
  """
  @type cancel_direct_upload_result ::
          :ok
          | {:error, :not_found}
          | {:error, :streaming_not_configured}
          | {:error, :provider_sync_failed}
          | {:error, :provider_quota_exceeded}
          | {:error, {:not_cancellable, not_cancellable_detail()}}

  @type not_cancellable_detail ::
          %{reason: :state, state: String.t()}
          | %{reason: :ingest_mode, ingest_mode: String.t()}
          | %{reason: :missing_upload_id}

  @doc """
  Mint a browser-safe direct upload for a streaming-enabled profile.

  Creates the durable local asset + provider rows, calls the provider adapter
  for the one-time upload URL, persists only non-secret correlation state, and
  returns exactly `%{upload_url, asset_id}`.
  """
  @spec create_direct_upload(module(), keyword()) :: direct_upload_result()
  def create_direct_upload(profile, opts \\ []) when is_atom(profile) and is_list(opts) do
    with {:ok, streaming} <- fetch_streaming_config(profile),
         :ok <- require_direct_upload_mode(streaming),
         :ok <- require_direct_upload_capability(streaming.provider),
         {:ok, cors_origin} <- fetch_binary_opt(opts, :cors_origin) do
      asset_id = Ecto.UUID.generate()
      passthrough = Ecto.UUID.generate()
      repo = Rindle.Config.repo()

      multi =
        Multi.new()
        |> Multi.insert(
          :asset,
          MediaAsset.changeset(%MediaAsset{}, %{
            id: asset_id,
            state: "ready",
            storage_key: direct_upload_storage_key(streaming.provider, asset_id),
            profile: to_string(profile),
            kind: "video",
            filename: Keyword.get(opts, :filename),
            metadata: %{
              "streaming_provider" => derive_provider_name(streaming.provider),
              "ingest_mode" => "direct_creator_upload"
            }
          })
        )
        |> Multi.insert(:provider_asset, fn %{asset: asset} ->
          MediaProviderAsset.changeset(%MediaProviderAsset{}, %{
            asset_id: asset.id,
            profile: to_string(profile),
            provider_name: derive_provider_name(streaming.provider),
            playback_policy: Atom.to_string(streaming.playback_policy),
            ingest_mode: "direct_creator_upload",
            mux_passthrough: passthrough,
            state: "pending"
          })
        end)
        |> Multi.run(:direct_upload, fn repo, %{asset: asset, provider_asset: provider_asset} ->
          adapter_opts = [
            cors_origin: cors_origin,
            passthrough: passthrough,
            playback_policy: streaming.playback_policy
          ]

          case streaming.provider.create_direct_upload(profile, adapter_opts) do
            {:ok, %{upload_url: upload_url, upload_id: upload_id}} ->
              case provider_asset
                   |> MediaProviderAsset.changeset(%{
                     state: "uploading",
                     provider_upload_id: upload_id
                   })
                   |> repo.update() do
                {:ok, _updated} ->
                  {:ok, %{upload_url: upload_url, asset_id: asset.id}}

                {:error, changeset} ->
                  {:error, changeset}
              end

            {:error, reason} ->
              {:error, reason}
          end
        end)

      case repo.transaction(multi) do
        {:ok, %{direct_upload: result}} -> {:ok, result}
        {:error, _step, reason, _changes} -> {:error, reason}
      end
    end
  end

  defp fetch_streaming_config(profile) do
    case Map.get(profile.delivery_policy(), :streaming) do
      %{provider: provider} = config when is_atom(provider) -> {:ok, config}
      _ -> {:error, :streaming_not_configured}
    end
  end

  defp require_direct_upload_mode(%{ingest_mode: :direct_creator_upload}), do: :ok
  defp require_direct_upload_mode(_), do: {:error, :streaming_not_configured}

  defp require_direct_upload_capability(provider) do
    if Capabilities.supports?(provider, :direct_creator_upload) do
      :ok
    else
      {:error, :streaming_not_configured}
    end
  end

  defp fetch_binary_opt(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :provider_sync_failed}
    end
  end

  defp direct_upload_storage_key(provider, asset_id) do
    "streaming/#{derive_provider_name(provider)}/direct_upload/#{asset_id}"
  end

  defp derive_provider_name(provider_module) when is_atom(provider_module) do
    provider_module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
