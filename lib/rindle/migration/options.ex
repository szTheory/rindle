defmodule Rindle.Migration.Options do
  @moduledoc false

  @supported_versions [1]

  @schema [
    version: [
      type: {:in, @supported_versions},
      default: 1,
      doc: "Versioned Rindle migration to run."
    ],
    prefix: [
      type: :string,
      default: "public",
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

  defp validate_prefix!("") do
    raise ArgumentError, "expected :prefix to be a non-empty string"
  end

  defp validate_prefix!(prefix) when is_binary(prefix) do
    if String.contains?(prefix, <<0>>) do
      raise ArgumentError, "expected :prefix to be a valid Postgres identifier prefix"
    end

    prefix
  end
end
