defmodule Rindle.Upload.Broker.SessionValidation do
  @moduledoc false

  alias Rindle.Domain.MediaUploadSession

  @doc false
  def multipart(%MediaUploadSession{upload_strategy: "multipart", multipart_upload_id: upload_id})
      when is_binary(upload_id) and upload_id != "",
      do: :ok

  def multipart(%MediaUploadSession{upload_strategy: "multipart"}),
    do: {:error, :multipart_upload_not_initialized}

  def multipart(_session), do: {:error, {:upload_unsupported, :multipart_upload}}

  @doc false
  def resumable(%MediaUploadSession{upload_strategy: "resumable", session_uri: session_uri})
      when is_binary(session_uri) and session_uri != "",
      do: :ok

  def resumable(%MediaUploadSession{upload_strategy: "resumable"}),
    do: {:error, :resumable_upload_not_initialized}

  def resumable(_session), do: {:error, {:upload_unsupported, :resumable_upload_session}}

  @doc false
  def profile_module(name) do
    {:ok, String.to_existing_atom(name)}
  rescue
    ArgumentError -> {:error, :unknown_profile}
  end

  @doc false
  def normalize_parts(parts) when is_list(parts) do
    parts
    |> Enum.reduce_while({:ok, []}, fn part, {:ok, acc} ->
      case normalize_part(part) do
        {:ok, normalized_part} -> {:cont, {:ok, [normalized_part | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized_parts} -> {:ok, Enum.sort_by(normalized_parts, & &1.part_number)}
      {:error, reason} -> {:error, reason}
    end
  end

  def normalize_parts(_parts), do: {:error, :invalid_multipart_parts}

  @doc false
  def encode_parts(parts) do
    Enum.map(parts, fn %{part_number: part_number, etag: etag} ->
      %{"part_number" => part_number, "etag" => etag}
    end)
  end

  @doc false
  def resumable_status_attrs(session, status) do
    %{
      last_known_offset: status.committed_bytes,
      session_uri_expires_at:
        Map.get(status, :expires_at) || Map.get(status, :session_uri_expires_at) ||
          session.session_uri_expires_at,
      region_hint: Map.get(status, :region_hint) || session.region_hint
    }
  end

  defp normalize_part(%{part_number: part_number, etag: etag})
       when is_integer(part_number) and part_number > 0 and is_binary(etag),
       do: {:ok, %{part_number: part_number, etag: etag}}

  defp normalize_part(%{"part_number" => part_number, "etag" => etag})
       when is_integer(part_number) and part_number > 0 and is_binary(etag),
       do: {:ok, %{part_number: part_number, etag: etag}}

  defp normalize_part(_part), do: {:error, :invalid_multipart_parts}
end
