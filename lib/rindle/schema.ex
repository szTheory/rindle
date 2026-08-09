defmodule Rindle.Schema do
  @moduledoc false

  @supported_prefixes ["rindle", "public"]
  @rindle_prefix Application.compile_env(:rindle, :rindle_prefix, "rindle")

  unless @rindle_prefix in @supported_prefixes do
    raise ArgumentError,
          "expected :rindle_prefix to be one of \"rindle\" or \"public\", got: #{inspect(@rindle_prefix)}"
  end

  @doc false
  @spec prefix() :: String.t()
  def prefix, do: @rindle_prefix

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @schema_prefix Rindle.Schema.validate_prefix!(
                       Application.compile_env(:rindle, :rindle_prefix, "rindle")
                     )
    end
  end

  @doc false
  @spec validate_prefix!(term()) :: String.t()
  def validate_prefix!(prefix) when prefix in @supported_prefixes, do: prefix

  def validate_prefix!(prefix) do
    raise ArgumentError,
          "expected :rindle_prefix to be one of \"rindle\" or \"public\", got: #{inspect(prefix)}"
  end
end
