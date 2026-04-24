defmodule Rindle.Profile do
  @moduledoc """
  Profile DSL used to declare upload policy and variant recipes.

  Profiles are validated at compile time so invalid configuration fails fast
  before runtime upload and processing flows execute.
  """

  @type variant_spec :: %{required(atom()) => term()}
  @type variant_entry :: {atom(), variant_spec()}

  defmacro __using__(opts) do
    expanded_opts = Macro.expand_literals(opts, __CALLER__)
    validated = Rindle.Profile.Validator.validate!(expanded_opts)

    storage = Map.fetch!(validated, :storage)
    variants = Map.fetch!(validated, :variants)

    upload_policy =
      validated
      |> Map.take([:allow_mime, :allow_extensions, :max_bytes, :max_pixels])

    quote bind_quoted: [
            storage: storage,
            variants: Macro.escape(variants),
            upload_policy: Macro.escape(upload_policy)
          ] do
      @rindle_storage storage
      @rindle_variants variants
      @rindle_upload_policy upload_policy

      @spec storage_adapter() :: module()
      def storage_adapter, do: @rindle_storage

      @spec variants() :: [Rindle.Profile.variant_entry()]
      def variants do
        @rindle_variants
        |> Enum.to_list()
        |> Enum.sort_by(fn {variant_name, _spec} -> Atom.to_string(variant_name) end)
      end

      @spec validate_upload(map()) :: {:ok, map()} | {:error, term()}
      def validate_upload(upload) do
        Rindle.Profile.Validator.validate_upload(upload, @rindle_upload_policy)
      end

      @spec recipe_digest(atom()) :: String.t()
      def recipe_digest(variant_name) do
        if Enum.any?(@rindle_variants, fn {name, _spec} -> name == variant_name end) do
          Rindle.Profile.Digest.for_variant(__MODULE__, variant_name)
        else
          raise ArgumentError,
                "unknown variant #{inspect(variant_name)} for profile #{inspect(__MODULE__)}"
        end
      end
    end
  end
end
