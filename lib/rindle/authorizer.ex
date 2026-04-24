defmodule Rindle.Authorizer do
  @moduledoc """
  Behaviour contract for delivery authorization hooks.

  Authorization decisions must be made before URL issuance, and any storage I/O
  involved in delivery should occur outside database transactions.
  """

  @callback authorize(actor :: term(), action :: atom(), subject :: term()) ::
              :ok | {:error, :unauthorized | term()}
end
