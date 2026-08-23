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

  @doc false
  @spec concatenate(String.t(), module(), [String.t()], keyword()) ::
          {:ok,
           %{session: MediaUploadSession.t(), upload_url: String.t(), expires_at: DateTime.t()}}
          | {:error, term()}
  def concatenate(base_path, profile, urls, opts)
      when is_binary(base_path) and is_atom(profile) and is_list(urls) and is_list(opts) do
    with {:ok, tokens} <- extract_tokens_from_urls(urls),
         {:ok, claims_list} <- verify_tokens_for_concat(tokens, opts),
         {:ok, %{session: final_session}} <-
           Broker.concatenate_tus_sessions(profile, claims_list, opts),
         {:ok, upload_url, signed_session} <-
           sign_and_persist(base_path, final_session, Keyword.put(opts, :is_partial, false)) do
      {:ok,
       %{session: signed_session, upload_url: upload_url, expires_at: signed_session.expires_at}}
    end
  end

  defp extract_tokens_from_urls(urls) do
    tokens = Enum.map(urls, &(String.split(&1, "/") |> List.last()))

    if Enum.all?(tokens, &(&1 != nil and &1 != "")),
      do: {:ok, tokens},
      else: {:error, :invalid_urls}
  end

  defp verify_tokens_for_concat(tokens, opts) do
    secret_key_base = Keyword.fetch!(opts, :secret_key_base)
    now_seconds = Keyword.get(opts, :now_seconds, fn -> System.system_time(:second) end)

    Enum.reduce_while(tokens, {:ok, []}, fn token, {:ok, acc} ->
      with {:ok, claims} <- Plug.Crypto.verify(secret_key_base, @tus_url_salt, token),
           {:ok, claims} <- check_not_expired(claims, now_seconds) do
        {:cont, {:ok, [claims | acc]}}
      else
        _ -> {:halt, {:error, :invalid_token}}
      end
    end)
    |> case do
      {:ok, reversed_claims} -> {:ok, Enum.reverse(reversed_claims)}
      error -> error
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

  defp check_not_expired(%{"exp" => exp} = claims, now_seconds)
       when is_integer(exp) and is_function(now_seconds, 0) do
    if exp >= now_seconds.(), do: {:ok, claims}, else: {:error, :expired_token}
  end

  defp check_not_expired(_claims, _now_seconds), do: {:error, :invalid_token}
end
