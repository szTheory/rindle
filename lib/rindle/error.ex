defmodule Rindle.Error do
  @moduledoc """
  Exception raised by bang variants on the `Rindle` facade when an
  operation fails for a non-changeset reason.

  Fields:

    * `:action` — atom identifying the failing operation
      (`:attach`, `:detach`, `:upload`, `:url`, `:variant_url`)
    * `:reason` — the underlying error term returned by the non-bang variant

  For changeset validation failures, bangs raise `Ecto.InvalidChangesetError`
  instead. For storage adapter exceptions, bangs re-raise the original
  exception directly.

  ## Examples

      iex> try do
      ...>   raise Rindle.Error, action: :attach, reason: :not_found
      ...> rescue
      ...>   e in Rindle.Error -> Exception.message(e)
      ...> end
      "could not attach: not found"

  """

  defexception [:action, :reason]

  @typedoc "A `Rindle.Error` exception struct."
  @type t :: %__MODULE__{action: atom(), reason: term()}

  @doc """
  Returns a human-readable message describing the failure.

  Branches on three common reason shapes:

    * `:not_found` — `"could not <action>: not found"`
    * `{:quarantine, why}` — `"could not <action>: upload quarantined (<inspect why>)"`
    * any other — `"could not <action>: <inspect reason>"`

  """
  @impl true
  @spec message(t()) :: String.t()
  def message(%{action: action, reason: :not_found}) do
    "could not #{action}: not found"
  end

  def message(%{action: action, reason: {:quarantine, why}}) do
    "could not #{action}: upload quarantined (#{inspect(why)})"
  end

  def message(%{action: action, reason: reason}) do
    "could not #{action}: #{inspect(reason)}"
  end
end
