defmodule Rindle.Authorizer do
  @moduledoc """
  Behaviour contract for delivery authorization hooks.

  Authorization decisions must be made before URL issuance, and any storage I/O
  involved in delivery should occur outside database transactions.
  """

  @doc """
  Authorizes a delivery action for an actor against a subject.

  Implementations should return `:ok` to permit the action or
  `{:error, :unauthorized}` (or another tagged error term) to deny it.
  Authorization runs before any URL is issued and before any storage I/O is
  attempted, so denials prevent presigning and reading entirely.
  """
  @callback authorize(actor :: term(), action :: atom(), subject :: term()) ::
              :ok | {:error, :unauthorized | term()}
end
