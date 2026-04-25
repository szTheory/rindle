defmodule Rindle.Storage do
  @moduledoc """
  Behaviour contract for all storage adapters used by Rindle.

  Storage I/O must never happen inside database transactions. Callers should
  persist domain state first, then execute storage side effects in separate
  steps.
  """

  @callback store(key :: String.t(), source :: Path.t(), opts :: keyword()) ::
              {:ok, term()} | {:error, term()}

  @callback download(key :: String.t(), destination :: Path.t(), opts :: keyword()) ::
              {:ok, Path.t()} | {:error, term()}

  @callback delete(key :: String.t(), opts :: keyword()) ::
              {:ok, term()} | {:error, term()}

  @callback url(key :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}

  @callback presigned_put(key :: String.t(), expires_in :: pos_integer(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback head(key :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback capabilities() :: [atom()]
end
