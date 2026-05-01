defmodule Rindle.Profile do
  @moduledoc """
  Profile DSL used to declare upload policy and variant recipes.

  Profiles are validated at compile time so invalid configuration fails fast
  before runtime upload and processing flows execute.
  """

  @type variant_spec :: %{required(atom()) => term()}
  @type variant_entry :: {atom(), variant_spec()}

  alias Rindle.Profile.Digest
  alias Rindle.Profile.Validator

  @doc """
  Declares a Rindle profile.

  When `use`d, this macro validates the supplied options at compile time and
  generates the `storage_adapter/0`, `variants/0`, `upload_policy/0`,
  `validate_upload/1`, `delivery_policy/0`, and `recipe_digest/1` functions
  that the rest of Rindle dispatches through.

  ## Example

      defmodule MyApp.AvatarProfile do
        use Rindle.Profile,
          storage: Rindle.Storage.S3,
          allow_mime: ["image/png", "image/jpeg"],
          max_bytes: 10_000_000,
          delivery: %{public: false, signed_url_ttl_seconds: 900},
          variants: %{thumb: %{width: 128, height: 128, format: :webp}}
      end
  """
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(opts) do
    expanded_opts = Macro.expand_literals(opts, __CALLER__)
    validated = Validator.validate!(expanded_opts)

    storage = Map.fetch!(validated, :storage)
    variants = Map.fetch!(validated, :variants)

    upload_policy =
      validated
      |> Map.take([:allow_mime, :allow_extensions, :max_bytes, :max_pixels])

    delivery_policy = Map.fetch!(validated, :delivery)

    quote bind_quoted: [
            storage: storage,
            variants: Macro.escape(variants),
            upload_policy: Macro.escape(upload_policy),
            delivery_policy: Macro.escape(delivery_policy)
          ] do
      @rindle_storage storage
      @rindle_variants variants
      @rindle_upload_policy upload_policy
      @rindle_delivery_policy delivery_policy

      @doc """
      Returns the storage adapter module configured for this profile.
      """
      @spec storage_adapter() :: module()
      def storage_adapter, do: @rindle_storage

      @doc """
      Returns the profile's variant recipes as a list of `{name, spec}` tuples,
      sorted by variant name for deterministic iteration.
      """
      @spec variants() :: [Rindle.Profile.variant_entry()]
      def variants do
        @rindle_variants
        |> Enum.to_list()
        |> Enum.sort_by(fn {variant_name, _spec} -> Atom.to_string(variant_name) end)
      end

      @doc """
      Returns the profile's upload policy map (allowed MIME types, allowed
      extensions, max bytes, max pixels).
      """
      @spec upload_policy() :: Rindle.Profile.Validator.upload_policy()
      def upload_policy, do: @rindle_upload_policy

      @doc """
      Validates an upload metadata map against the profile's upload policy,
      returning `{:ok, normalized_upload}` or `{:error, reason}`.
      """
      @spec validate_upload(Rindle.Profile.Validator.upload_metadata()) ::
              {:ok, map()} | {:error, term()}
      def validate_upload(upload) do
        Validator.validate_upload(upload, @rindle_upload_policy)
      end

      @doc """
      Returns the profile's delivery policy map (`:public`,
      `:signed_url_ttl_seconds`, etc.).
      """
      @spec delivery_policy() :: map()
      def delivery_policy, do: @rindle_delivery_policy

      @doc """
      Returns the deterministic digest for `variant_name` derived from the
      profile module and its declared recipe. Raises `ArgumentError` if the
      profile does not declare `variant_name`.
      """
      @spec recipe_digest(atom()) :: String.t()
      def recipe_digest(variant_name) do
        if Enum.any?(@rindle_variants, fn {name, _spec} -> name == variant_name end) do
          Digest.for_variant(__MODULE__, variant_name)
        else
          raise ArgumentError,
                "unknown variant #{inspect(variant_name)} for profile #{inspect(__MODULE__)}"
        end
      end
    end
  end
end
