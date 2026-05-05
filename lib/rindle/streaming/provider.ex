defmodule Rindle.Streaming.Provider do
  @moduledoc """
  Reserved behaviour for future non-progressive streaming providers.

  Phase 26 intentionally reserves this namespace without introducing runtime
  dispatch, adapter lookup, or configuration coupling in core delivery paths.
  """

  @typedoc "Future streaming resolution result."
  @type result :: {:ok, %{url: String.t(), kind: atom(), mime: String.t()}} | {:error, term()}

  @callback streaming_url(profile :: module(), key :: String.t(), opts :: keyword()) :: result()
  @callback capabilities() :: [atom()]
end
