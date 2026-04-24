defmodule Rindle.Processor do
  @moduledoc """
  Behaviour contract for media processors that generate variants.

  Implementations may read from and write to storage paths, but storage I/O
  must never occur inside database transactions.
  """

  @callback process(source :: Path.t(), variant_spec :: map(), destination :: Path.t()) ::
              {:ok, Path.t()} | {:error, term()}
end
