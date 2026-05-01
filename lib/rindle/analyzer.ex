defmodule Rindle.Analyzer do
  @moduledoc """
  Behaviour contract for metadata analyzers.

  Analyzer callbacks produce normalized metadata maps and must be orchestrated
  so any storage I/O remains outside database transactions.
  """

  @doc """
  Analyzes the file at `source` and returns enrichment metadata.

  Implementations may inspect the file at `source` and return adapter-specific
  metadata (dimensions, EXIF, content fingerprints, etc.) as a normalized map.
  Storage I/O involved in fetching the source MUST happen outside DB
  transactions; the analyzer itself receives a local path.
  """
  @callback analyze(source :: Path.t()) ::
              {:ok, map()} | {:error, term()}
end
