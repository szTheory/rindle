defmodule Rindle.Processor do
  @moduledoc """
  Behaviour contract for media processors that generate variants.

  Implementations may read from and write to storage paths, but storage I/O
  must never occur inside database transactions.
  """

  @doc """
  Processes a source file according to a variant spec, writing the result to
  `destination`.

  The `variant_spec` is the recipe map declared by the profile's `variants/0`
  configuration. Implementations should write the processed output to
  `destination` and return `{:ok, destination}` on success. Storage I/O (such
  as downloading the source or uploading the result) MUST happen outside DB
  transactions; this callback operates on local paths only.
  """
  @callback process(source :: Path.t(), variant_spec :: map(), destination :: Path.t()) ::
              {:ok, Path.t()} | {:error, term()}
end
