defmodule Rindle.Upload.TusCreation do
  @moduledoc false

  alias Rindle.Config
  alias Rindle.Domain.MediaUploadSession
  alias Rindle.Upload.Broker

  @tus_url_salt "rindle:tus:url"

  @doc false
  @spec create(String.t(), module(), keyword()) ::
          {:ok,
           %{session: MediaUploadSession.t(), upload_url: String.t(), expires_at: DateTime.t()}}
          | {:error, term()}
  def create(base_path, profile, opts)
      when is_binary(base_path) and is_atom(profile) and is_list(opts) do
    filename = Keyword.get(opts, :filename, "unknown")
    expires_in = Keyword.get(opts, :expires_in, 3600)

    with {:ok, %{session: session}} <-
           Broker.initiate_tus_upload(profile, filename: filename, expires_in: expires_in),
         {:ok, upload_url, signed_session} <- sign_and_persist(base_path, session, opts) do
      {:ok,
       %{session: signed_session, upload_url: upload_url, expires_at: signed_session.expires_at}}
    end
  end

  defp sign_and_persist(base_path, session, opts) do
    length = Keyword.get(opts, :length, session.upload_length)
    content_type = Keyword.get(opts, :content_type)
    secret_key_base = Keyword.fetch!(opts, :secret_key_base)
    actor = Keyword.get(opts, :actor, "anonymous")
    is_partial = Keyword.get(opts, :is_partial, false)

    claims =
      %{
        "session_id" => session.id,
        "actor" => actor,
        "exp" => DateTime.to_unix(session.expires_at),
        "length" => length
      }
      |> maybe_put_content_type(content_type)

    token = Plug.Crypto.sign(secret_key_base, @tus_url_salt, claims)
    location = join_upload_url(base_path, token)

    attrs =
      %{session_uri: location, session_uri_expires_at: session.expires_at}
      |> maybe_mark_partial(is_partial)

    session
    |> MediaUploadSession.changeset(attrs)
    |> Config.repo().update()
    |> case do
      {:ok, updated} -> {:ok, location, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp maybe_mark_partial(attrs, true),
    do: Map.put(attrs, :multipart_parts, %{"is_partial" => true})

  defp maybe_mark_partial(attrs, false), do: attrs

  defp maybe_put_content_type(payload, content_type)
       when is_binary(content_type) and content_type != "" do
    Map.put(payload, "content_type", content_type)
  end

  defp maybe_put_content_type(payload, _content_type), do: payload

  defp join_upload_url(base_path, token) do
    String.trim_trailing(base_path, "/") <> "/" <> token
  end
end
