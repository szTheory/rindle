# Compiled only when {:mux, "~> 3.2"} is loaded.
# Adopters who do not configure streaming pay zero transitive cost.
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Streaming.Provider.Mux.HTTP do
    @moduledoc false

    @behaviour Rindle.Streaming.Provider.Mux.Client

    # Real HTTP-client implementation for the Mux REST adapter. Delegates to the
    # `mux` SDK's `Mux.Video.Assets` module. The `Mux.Base.new/2` Tesla client is
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
      case Mux.Video.Assets.create(build_client(), params) do
        {:ok, asset, _env} -> {:ok, asset}
        {:error, msg, env} -> {:error, msg, env}
        other -> {:error, other}
      end
    end

    @impl true
    def get_asset(provider_asset_id) when is_binary(provider_asset_id) do
      case Mux.Video.Assets.get(build_client(), provider_asset_id) do
        {:ok, asset, _env} -> {:ok, asset}
        {:error, msg, env} -> {:error, msg, env}
        other -> {:error, other}
      end
    end

    @impl true
    def delete_asset(provider_asset_id) when is_binary(provider_asset_id) do
      case Mux.Video.Assets.delete(build_client(), provider_asset_id) do
        {:ok, _body, _env} -> :ok
        # Idempotent on :not_found per Phase 33 contract — `delete_asset/1`
        # returns `:ok` for both successful delete and already-deleted assets.
        {:error, _msg, %{status: 404}} -> :ok
        {:error, msg, env} -> {:error, msg, env}
        other -> {:error, other}
      end
    end

    defp build_client do
      cfg = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])
      Mux.Base.new(Keyword.fetch!(cfg, :token_id), Keyword.fetch!(cfg, :token_secret))
    end
  end
end
