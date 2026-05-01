defmodule Rindle.Storage do
  @moduledoc """
  Behaviour contract for all storage adapters used by Rindle.

  Storage I/O must never happen inside database transactions. Callers should
  persist domain state first, then execute storage side effects in separate
  steps.
  """

  @typedoc """
  Shared storage capability vocabulary exposed by adapters via `c:capabilities/0`.

  Current adapters only need to advertise the capabilities they actually
  support. Additional resumable-oriented atoms are reserved additively for
  future adapters.
  """
  @type capability ::
          :presigned_put
          | :multipart_upload
          | :signed_url
          | :head
          | :local
          | :resumable_upload
          | :resumable_upload_session

  @typedoc "Successful storage write metadata. Adapters MUST include `:key`; other fields are adapter-specific."
  @type put_result :: %{:key => String.t(), optional(atom()) => term()}

  @typedoc "Successful storage delete metadata. Adapters MUST include `:key` when known."
  @type delete_result :: %{optional(:key) => String.t(), optional(atom()) => term()}

  @typedoc "Resolved delivery URL string."
  @type url_result :: String.t()

  @typedoc "Presigned upload payload. `:url`, `:method`, and `:headers` are required; multipart variants add `:part_number` and `:upload_id`."
  @type presign_result :: %{
          required(:url) => String.t(),
          required(:method) => atom() | String.t(),
          required(:headers) => map() | list(),
          optional(:part_number) => pos_integer(),
          optional(:upload_id) => String.t()
        }

  @typedoc "Multipart-upload initiation metadata. `:upload_id` is required; other fields are adapter-specific."
  @type multipart_init_result :: %{
          required(:upload_id) => String.t(),
          optional(:upload_key) => String.t(),
          optional(:bucket) => String.t(),
          optional(:part_size) => pos_integer(),
          optional(atom()) => term()
        }

  @typedoc "Multipart-upload completion metadata. `:upload_id` and `:upload_key` are required."
  @type multipart_complete_result :: %{
          required(:upload_id) => String.t(),
          required(:upload_key) => String.t(),
          optional(atom()) => term()
        }

  @typedoc "Storage object metadata returned by HEAD. `:size` is required; `:content_type` is best-effort."
  @type head_result :: %{
          required(:size) => non_neg_integer(),
          optional(:content_type) => String.t() | nil,
          optional(atom()) => term()
        }

  @callback store(key :: String.t(), source :: Path.t(), opts :: keyword()) ::
              {:ok, put_result()} | {:error, term()}

  @callback download(key :: String.t(), destination :: Path.t(), opts :: keyword()) ::
              {:ok, Path.t()} | {:error, term()}

  @callback delete(key :: String.t(), opts :: keyword()) ::
              {:ok, delete_result()} | {:error, term()}

  @callback url(key :: String.t(), opts :: keyword()) ::
              {:ok, url_result()} | {:error, term()}

  @callback presigned_put(key :: String.t(), expires_in :: pos_integer(), opts :: keyword()) ::
              {:ok, presign_result()} | {:error, term()}

  @callback initiate_multipart_upload(
              key :: String.t(),
              part_size :: pos_integer(),
              opts :: keyword()
            ) :: {:ok, multipart_init_result()} | {:error, term()}

  @callback presigned_upload_part(
              key :: String.t(),
              upload_id :: String.t(),
              part_number :: pos_integer(),
              expires_in :: pos_integer(),
              opts :: keyword()
            ) :: {:ok, presign_result()} | {:error, term()}

  @callback complete_multipart_upload(
              key :: String.t(),
              upload_id :: String.t(),
              parts :: [map() | {pos_integer(), String.t()}],
              opts :: keyword()
            ) :: {:ok, multipart_complete_result()} | {:error, term()}

  @callback abort_multipart_upload(
              key :: String.t(),
              upload_id :: String.t(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @callback head(key :: String.t(), opts :: keyword()) ::
              {:ok, head_result()} | {:error, term()}

  @doc """
  Returns the adapter's supported capability atoms.

  Values must come from `t:capability/0`.
  """
  @callback capabilities() :: [capability()]
end
