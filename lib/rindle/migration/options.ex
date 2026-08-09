defmodule Rindle.Migration.Options do
  @moduledoc false

  @supported_versions [1]
  @supported_prefixes ["rindle", "public"]

  @schema [
    version: [
      type: {:in, @supported_versions},
      default: 1,
      doc: "Versioned Rindle migration to run."
    ],
    prefix: [
      type: :any,
      default: "rindle",
      doc: "Postgres schema prefix for Rindle-owned tables."
    ]
  ]

  @type options :: %{
          version: 1,
          prefix: String.t()
        }

  @spec validate!(keyword() | map()) :: options()
  def validate!(opts) when is_map(opts) do
    opts
    |> Enum.to_list()
    |> validate!()
  end

  def validate!(opts) when is_list(opts) do
    opts
    |> NimbleOptions.validate!(@schema)
    |> Keyword.new()
    |> then(fn validated ->
      %{
        version: Keyword.fetch!(validated, :version),
        prefix: validate_prefix!(Keyword.fetch!(validated, :prefix))
      }
    end)
  rescue
    error in NimbleOptions.ValidationError ->
      reraise ArgumentError, Exception.message(error), __STACKTRACE__
  end

  defp validate_prefix!(prefix) when prefix in @supported_prefixes, do: prefix

  defp validate_prefix!(prefix) do
    raise ArgumentError,
          "expected :prefix to be one of \"rindle\" or \"public\", got: #{inspect(prefix)}"
  end
end
