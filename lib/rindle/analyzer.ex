defmodule Rindle.Analyzer do
  @moduledoc """
  Behaviour contract for metadata analyzers.

  Analyzer callbacks produce normalized metadata maps and must be orchestrated
  so any storage I/O remains outside database transactions.
  """

  @callback analyze(source :: Path.t()) ::
              {:ok, map()} | {:error, term()}
end
