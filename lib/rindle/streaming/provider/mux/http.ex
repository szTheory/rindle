# Compiled only when {:mux, "~> 3.2"} is loaded.
# Adopters who do not configure streaming pay zero transitive cost.
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Streaming.Provider.Mux.HTTP do
    alias Mux.Video.Assets
    alias Mux.Video.Uploads
    @moduledoc false

    @behaviour Rindle.Streaming.Provider.Mux.Client

    # Real HTTP-client implementation for the Mux REST adapter. Delegates to the
    # `mux` SDK's `Assets` module. The `Mux.Base.new/2` Tesla client is
    # constructed per call (D-30 — no caching of credentials at module load time;
    # adopters using runtime config are unaffected).
    #
    # Return shapes match the `Rindle.Streaming.Provider.Mux.Client` behaviour:
    #   * `{:ok, asset_map}` — happy path (env is dropped here; the adapter does
    #     not need it on success because Mux returns full state in the body).
    #   * `{:error, msg, %Tesla.Env{}}` — preserves status + headers so the
    #     adapter can branch on 429 / 4xx / 5xx and read `Retry-After` (Pitfall
    #     3 / SDK Issue #42).
    #   * `:ok` on `delete_asset/1` success (idempotent on 404 per Phase 33).

    @impl true
    def create_asset(params) when is_map(params) do
      with {:ok, client} <- build_client() do
        case Assets.create(client, params) do
          {:ok, asset, _env} -> {:ok, asset}
          {:error, msg, env} -> {:error, msg, env}
        end
      end
    end

    @impl true
    def create_upload(params) when is_map(params) do
      with {:ok, client} <- build_client() do
        case Uploads.create(client, params) do
          {:ok, upload, _env} -> {:ok, upload}
          {:error, msg, env} -> {:error, msg, env}
        end
      end
    end

    @impl true
    def get_asset(provider_asset_id) when is_binary(provider_asset_id) do
      with {:ok, client} <- build_client() do
        case Assets.get(client, provider_asset_id) do
          {:ok, asset, _env} -> {:ok, asset}
          {:error, msg, env} -> {:error, msg, env}
        end
      end
    end

    @impl true
    def delete_asset(provider_asset_id) when is_binary(provider_asset_id) do
      with {:ok, client} <- build_client() do
        case Assets.delete(client, provider_asset_id) do
          {:ok, _body, _env} -> :ok
          # Idempotent on :not_found per Phase 33 contract — `delete_asset/1`
          # returns `:ok` for both successful delete and already-deleted assets.
          {:error, _msg, %{status: 404}} -> :ok
          {:error, msg, env} -> {:error, msg, env}
        end
      end
    end

    @impl true
    def cancel_upload(upload_id) when is_binary(upload_id) do
      with {:ok, client} <- build_client() do
        case Uploads.cancel(client, upload_id) do
          {:ok, _body, _env} ->
            :ok

          {:error, _msg, %{status: status}} when status in [403, 404] ->
            :ok

          {:error, msg, env} ->
            {:error, msg, env}
        end
      end
    end

    defp build_client do
      cfg = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])

      with {:ok, token_id} <- fetch_required(cfg, :token_id),
           {:ok, token_secret} <- fetch_required(cfg, :token_secret) do
        {:ok, Mux.Base.new(token_id, token_secret)}
      end
    end

    defp fetch_required(cfg, key) do
      case Keyword.get(cfg, key) do
        v when is_binary(v) and v != "" -> {:ok, v}
        _ -> {:error, {:missing_config, key}}
      end
    end
  end
end
