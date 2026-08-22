defmodule Rindle.Schema do
  @moduledoc false

  @supported_prefixes ["rindle", "public"]
  @owned_schema_modules [
    "Elixir.Rindle.Domain.MediaAsset",
    "Elixir.Rindle.Domain.MediaAttachment",
    "Elixir.Rindle.Domain.MediaProcessingRun",
    "Elixir.Rindle.Domain.MediaProviderAsset",
    "Elixir.Rindle.Domain.MediaUploadSession",
    "Elixir.Rindle.Domain.MediaVariant"
  ]
  @rindle_prefix Application.compile_env(:rindle, :rindle_prefix, "rindle")

  unless @rindle_prefix in @supported_prefixes do
    raise ArgumentError,
          "expected :rindle_prefix to be one of \"rindle\" or \"public\", got: #{inspect(@rindle_prefix)}"
  end

  @doc false
  @spec prefix() :: String.t()
  def prefix, do: @rindle_prefix

  @doc false
  @spec supported_prefixes() :: [String.t()]
  def supported_prefixes, do: @supported_prefixes

  defmacro __using__(_opts) do
    validate_owned_schema!(__CALLER__.module)
    prefix = Rindle.Schema.prefix()

    quote bind_quoted: [prefix: prefix] do
      use Ecto.Schema
      import Ecto.Schema, except: [schema: 2]
      import Rindle.Schema, only: [schema: 2]

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @schema_prefix prefix
      @after_compile Rindle.Schema
    end
  end

  @doc false
  defmacro schema(source, do: block) do
    prefix = Rindle.Schema.prefix()

    quote do
      @schema_prefix unquote(prefix)

      Ecto.Schema.schema unquote(source) do
        unquote(block)
      end
    end
  end

  @doc false
  @spec __after_compile__(Macro.Env.t(), binary()) :: :ok
  def __after_compile__(%Macro.Env{module: module}, _bytecode) do
    expected_prefix = prefix()
    actual_prefix = module.__schema__(:prefix)

    if actual_prefix != expected_prefix do
      raise ArgumentError,
            "Rindle.Schema prefix mismatch for #{inspect(module)}: expected #{inspect(expected_prefix)}, got #{inspect(actual_prefix)}"
    end

    :ok
  end

  @doc false
  @spec validate_prefix!(term()) :: String.t()
  def validate_prefix!(prefix) when prefix in @supported_prefixes, do: prefix

  def validate_prefix!(prefix) do
    raise ArgumentError,
          "expected :rindle_prefix to be one of \"rindle\" or \"public\", got: #{inspect(prefix)}"
  end

  defp validate_owned_schema!(module) when is_atom(module) do
    if Atom.to_string(module) in @owned_schema_modules,
      do: :ok,
      else: reject_unsupported_schema!(module)
  end

  defp reject_unsupported_schema!(module) do
    raise ArgumentError,
          "Rindle.Schema is internal to Rindle-owned domain schemas; unsupported caller #{inspect(module)}"
  end
end
