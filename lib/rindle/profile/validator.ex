defmodule Rindle.Profile.Validator do
  @moduledoc """
  Compile-time and runtime validation helpers for profile modules.
  """

  @profile_schema [
    storage: [
      type: :atom,
      required: true
    ],
    allow_mime: [
      type: {:list, :string},
      default: []
    ],
    allow_extensions: [
      type: {:list, :string},
      default: []
    ],
    max_bytes: [
      type: {:or, [:pos_integer, nil]},
      default: nil
    ],
    max_pixels: [
      type: {:or, [:pos_integer, nil]},
      default: nil
    ],
    variants: [
      type: :keyword_list,
      required: true
    ],
    delivery: [
      type: :keyword_list,
      default: []
    ]
  ]

  @delivery_schema [
    public: [
      type: :boolean,
      default: false
    ],
    signed_url_ttl_seconds: [
      type: {:or, [:pos_integer, nil]},
      default: nil
    ],
    authorizer: [
      type: {:or, [:atom, nil]},
      default: nil
    ]
  ]

  @variant_schema [
    mode: [
      type: {:in, [:fit, :fill, :crop]},
      required: true
    ],
    width: [
      type: {:or, [:pos_integer, nil]},
      default: nil
    ],
    height: [
      type: {:or, [:pos_integer, nil]},
      default: nil
    ],
    format: [
      type: {:in, [:jpeg, :png, :webp, :avif]},
      default: :jpeg
    ],
    quality: [
      type: {:or, [{:in, 1..100}, nil]},
      default: nil
    ]
  ]

  @type profile_options :: %{
          storage: module(),
          allow_mime: [String.t()],
          allow_extensions: [String.t()],
          max_bytes: pos_integer() | nil,
          max_pixels: pos_integer() | nil,
          variants: %{required(atom()) => map()}
        }

  @type upload_metadata :: %{
          optional(:content_type) => String.t(),
          optional(:extension) => String.t(),
          optional(:filename) => String.t(),
          optional(:byte_size) => non_neg_integer(),
          optional(:width) => pos_integer(),
          optional(:height) => pos_integer()
        }

  @spec validate!(keyword() | map()) :: profile_options()
  def validate!(opts) when is_map(opts) do
    opts
    |> Enum.to_list()
    |> validate!()
  end

  def validate!(opts) when is_list(opts) do
    validated =
      opts
      |> validate_profile_options!()
      |> Keyword.new()

    variants = validate_variants!(Keyword.fetch!(validated, :variants))
    delivery = validate_delivery!(Keyword.get(validated, :delivery, []))

    %{
      storage: Keyword.fetch!(validated, :storage),
      allow_mime: Keyword.fetch!(validated, :allow_mime),
      allow_extensions: Keyword.fetch!(validated, :allow_extensions),
      max_bytes: Keyword.fetch!(validated, :max_bytes),
      max_pixels: Keyword.fetch!(validated, :max_pixels),
      variants: variants,
      delivery: delivery
    }
  rescue
    error in NimbleOptions.ValidationError ->
      raise ArgumentError, Exception.message(error)
  end

  @spec validate_upload(upload_metadata() | map(), profile_options()) ::
          {:ok, map()} | {:error, term()}
  def validate_upload(upload, profile) when is_map(upload) do
    with :ok <- validate_mime(upload, profile.allow_mime),
         :ok <- validate_extension(upload, profile.allow_extensions),
         :ok <- validate_byte_size(upload, profile.max_bytes),
         :ok <- validate_pixel_count(upload, profile.max_pixels) do
      {:ok, upload}
    end
  end

  def validate_upload(_upload, _profile), do: {:error, :invalid_upload_metadata}

  defp validate_variants!(variants) do
    variants
    |> Enum.sort_by(fn {name, _spec} -> Atom.to_string(name) end)
    |> Enum.map(fn {name, variant_opts} -> {name, validate_variant!(name, variant_opts)} end)
    |> Map.new()
  end

  defp validate_delivery!(delivery_opts) do
    delivery_opts
    |> normalize_delivery_opts!()
    |> NimbleOptions.validate!(@delivery_schema)
    |> Keyword.new()
    |> then(fn delivery ->
      ttl =
        case Keyword.fetch!(delivery, :signed_url_ttl_seconds) do
          nil -> Rindle.Config.signed_url_ttl_seconds()
          value -> value
        end

      %{
        public: Keyword.fetch!(delivery, :public),
        signed_url_ttl_seconds: ttl,
        authorizer: Keyword.fetch!(delivery, :authorizer)
      }
    end)
  rescue
    error in NimbleOptions.ValidationError ->
      raise ArgumentError, "delivery: #{Exception.message(error)}"
  end

  defp normalize_delivery_opts!(delivery_opts) when is_list(delivery_opts), do: delivery_opts
  defp normalize_delivery_opts!(delivery_opts) when is_map(delivery_opts), do: Enum.to_list(delivery_opts)
  defp normalize_delivery_opts!(delivery_opts) do
    raise ArgumentError,
          "delivery configuration must be a keyword list or map, got: #{inspect(delivery_opts)}"
  end

  defp validate_variant!(name, variant_opts) when is_atom(name) do
    normalized_variant_opts = normalize_variant_opts!(variant_opts)

    validated_variant =
      normalized_variant_opts
      |> NimbleOptions.validate!(@variant_schema)
      |> Keyword.new()

    mode = Keyword.fetch!(validated_variant, :mode)
    width = Keyword.fetch!(validated_variant, :width)
    height = Keyword.fetch!(validated_variant, :height)

    validate_variant_dimensions!(name, mode, width, height)

    validated_variant
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  rescue
    error in NimbleOptions.ValidationError ->
      raise ArgumentError, "variant #{inspect(name)}: #{Exception.message(error)}"
  end

  defp validate_variant!(name, _variant_opts) do
    raise ArgumentError, "variant names must be atoms, got: #{inspect(name)}"
  end

  defp normalize_variant_opts!(variant_opts) when is_list(variant_opts), do: variant_opts
  defp normalize_variant_opts!(variant_opts) when is_map(variant_opts), do: Enum.to_list(variant_opts)

  defp normalize_variant_opts!(variant_opts) do
    raise ArgumentError, "variant configuration must be a keyword list or map, got: #{inspect(variant_opts)}"
  end

  defp validate_profile_options!(opts), do: NimbleOptions.validate!(opts, @profile_schema)

  defp validate_variant_dimensions!(name, :crop, nil, _height) do
    raise ArgumentError, "variant #{inspect(name)} with mode :crop requires both :width and :height"
  end

  defp validate_variant_dimensions!(name, :crop, _width, nil) do
    raise ArgumentError, "variant #{inspect(name)} with mode :crop requires both :width and :height"
  end

  defp validate_variant_dimensions!(_name, mode, nil, nil) when mode in [:fit, :fill] do
    raise ArgumentError, "variant with mode #{inspect(mode)} requires at least one dimension"
  end

  defp validate_variant_dimensions!(_name, _mode, _width, _height), do: :ok

  defp validate_mime(_upload, []), do: :ok

  defp validate_mime(upload, allow_mime) do
    mime = Map.get(upload, :content_type) || Map.get(upload, "content_type")

    if mime in allow_mime do
      :ok
    else
      {:error, {:mime_not_allowed, mime}}
    end
  end

  defp validate_extension(_upload, []), do: :ok

  defp validate_extension(upload, allow_extensions) do
    extension =
      Map.get(upload, :extension) ||
        Map.get(upload, "extension") ||
        upload
        |> Map.get(:filename, Map.get(upload, "filename", ""))
        |> Path.extname()

    if extension in allow_extensions do
      :ok
    else
      {:error, {:extension_not_allowed, extension}}
    end
  end

  defp validate_byte_size(_upload, nil), do: :ok

  defp validate_byte_size(upload, max_bytes) do
    byte_size = Map.get(upload, :byte_size) || Map.get(upload, "byte_size")

    cond do
      is_integer(byte_size) and byte_size <= max_bytes ->
        :ok

      true ->
        {:error, {:byte_size_exceeded, byte_size, max_bytes}}
    end
  end

  defp validate_pixel_count(_upload, nil), do: :ok

  defp validate_pixel_count(upload, max_pixels) do
    width = Map.get(upload, :width) || Map.get(upload, "width")
    height = Map.get(upload, :height) || Map.get(upload, "height")

    cond do
      is_integer(width) and is_integer(height) and width * height <= max_pixels ->
        :ok

      is_integer(width) and is_integer(height) ->
        {:error, {:pixel_limit_exceeded, width * height, max_pixels}}

      true ->
        {:error, {:pixel_dimensions_missing, max_pixels}}
    end
  end
end
