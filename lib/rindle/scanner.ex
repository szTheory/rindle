defmodule Rindle.Scanner do
  @moduledoc """
  Behaviour contract for security scanning before promotion.

  Scanner implementations may inspect file contents, and any storage I/O must
  stay outside database transactions.
  """

  @callback scan(path :: Path.t()) :: :ok | {:quarantine, term()}
end
