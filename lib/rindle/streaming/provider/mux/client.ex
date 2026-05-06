defmodule Rindle.Streaming.Provider.Mux.Client do
  @moduledoc false

  # Internal HTTP-client behaviour for the Mux REST adapter.
  #
  # This behaviour is pure Elixir and is NOT wrapped in an optional-dep guard
  # (Pitfall 4) — it must compile whether or not the `:mux` dep is loaded so
  # that `Mox.defmock(..., for: __MODULE__)` always has a valid target in
  # `test/support/mocks.ex`.
  #
  # Implementations:
  #   * `Rindle.Streaming.Provider.Mux.HTTP` — real impl (wraps Mux SDK)
  #   * `Rindle.Streaming.Provider.Mux.ClientMock` — Mox mock for tests
  #
  # The return shapes intentionally match the Mux SDK's `simplify_response/1`
  # output so the adapter can reshape responses uniformly:
  #
  #   * `{:ok, asset_map}` on 2xx
  #   * `{:error, msg, %Tesla.Env{}}` on 4xx/5xx (allows the adapter to read
  #     status, headers, and Retry-After per Pitfall 3 / SDK Issue #42)
  #   * `{:error, term()}` on transport-level failure

  @callback create_asset(params :: map()) ::
              {:ok, map()} | {:error, term()} | {:error, term(), term()}

  @callback get_asset(provider_asset_id :: String.t()) ::
              {:ok, map()} | {:error, term()} | {:error, term(), term()}

  @callback delete_asset(provider_asset_id :: String.t()) ::
              :ok | {:error, term()} | {:error, term(), term()}
end
