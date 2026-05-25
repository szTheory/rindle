defmodule Rindle.TusResumeAuthorizer do
  @moduledoc """
  Behaviour contract for optional tus resume authorization hooks.

  This hook runs after a tus URL signature has been verified and the upload
  session row has been loaded, but before any body or storage I/O is performed
  for `HEAD`, `PATCH`, or `DELETE`.
  """

  alias Rindle.Domain.MediaUploadSession

  @type resume_method :: :head | :patch | :delete

  @type subject :: %{
          required(:token_actor) => term(),
          required(:session) => MediaUploadSession.t(),
          required(:profile) => module(),
          required(:method) => resume_method()
        }

  @doc """
  Authorizes a resume-capable tus request.

  Return `:ok` to allow the request or `:reject` to deny it with `401`.
  """
  @callback authorize(actor :: term(), action :: :resume, subject()) :: :ok | :reject
end
