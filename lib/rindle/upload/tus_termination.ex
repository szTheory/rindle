defmodule Rindle.Upload.TusTermination do
  @moduledoc false

  require Logger

  alias Rindle.Domain.MediaUploadSession
  alias Rindle.Ops.UploadMaintenance

  @tus_abort_marker_prefix "tus_abort_failed:"
  @tus_abort_marker_max_reason 64

  @doc false
  @spec abort_attrs(MediaUploadSession.t(), keyword()) :: %{failure_reason: String.t() | nil}
  def abort_attrs(session, opts) do
    case UploadMaintenance.abort_tus_backing(session,
           adapter: opts[:adapter],
           root: opts[:root],
           upload_id: session.multipart_upload_id
         ) do
      :ok ->
        %{failure_reason: nil}

      {:error, reason} ->
        Logger.warning("rindle.tus.delete_backing_abort_failed",
          session_id: session.id,
          multipart_upload_id: session.multipart_upload_id,
          reason: inspect(reason)
        )

        %{failure_reason: abort_marker(reason)}
    end
  end

  defp abort_marker(reason) when is_atom(reason) and not is_nil(reason) do
    @tus_abort_marker_prefix <>
      (reason |> Atom.to_string() |> String.slice(0, @tus_abort_marker_max_reason))
  end

  defp abort_marker(_reason), do: @tus_abort_marker_prefix <> "transport"
end
