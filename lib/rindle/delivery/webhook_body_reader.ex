defmodule Rindle.Delivery.WebhookBodyReader do
  @moduledoc """
  Raw-body cache for `Rindle.Delivery.WebhookPlug`.

  Adopters wire this into their endpoint via the `Plug.Parsers` `:body_reader`
  option:

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        body_reader: {Rindle.Delivery.WebhookBodyReader, :read_body, []},
        json_decoder: Jason

  The reader drains the request body (looping over `{:more, _, conn}` reads
  that `Plug.Parsers.JSON.decode/3` does NOT loop on), caps total bytes at
  1 MiB, and stores the body in `conn.assigns[:raw_body]` as a list of
  binaries (most-recent first; multipart-safe).

  `raw_body/1` is the public accessor `Rindle.Delivery.WebhookPlug` calls to
  retrieve the verified raw body for HMAC signature checks.

  ## Body cap (D-08)

  Mux webhooks are <10 KB in practice; 1 MiB is 100× headroom and matches
  Stripe's documented recommendation. Over-limit returns `{:error, :too_large}`,
  which `Plug.Parsers` translates to `Plug.Parsers.RequestTooLargeError` → 413.

  ## Multipart safety (D-06)

  `Plug.Parsers.MULTIPART` invokes the body reader once per part; chunked
  transfers may produce multiple `{:more, _}` reads. The cache stores each
  drained body as one element of `conn.assigns[:raw_body]`, most-recent first.
  `raw_body/1` reverses and joins on read.
  """

  alias Plug.Conn

  @max_body_bytes 1_048_576

  @doc """
  `Plug.Parsers` `:body_reader` MFA contract. Drains the body, caps at 1 MiB,
  caches the chunks in `conn.assigns[:raw_body]`.

  Returns `{:ok, binary, conn}` on success, `{:error, :too_large}` if the
  accumulated chunks exceed 1 MiB, or any `{:error, term()}` `Plug.Conn.read_body/2`
  surfaces.
  """
  @spec read_body(Conn.t(), Keyword.t()) ::
          {:ok, binary(), Conn.t()} | {:error, :too_large} | {:error, term()}
  def read_body(conn, opts \\ []) do
    do_read_body(conn, opts, [], 0)
  end

  defp do_read_body(conn, opts, acc, total_bytes) do
    case Conn.read_body(conn, opts) do
      {:ok, chunk, conn} ->
        new_total = total_bytes + byte_size(chunk)

        if new_total > @max_body_bytes do
          {:error, :too_large}
        else
          chunks = [chunk | acc]
          body = chunks |> Enum.reverse() |> IO.iodata_to_binary()
          existing = conn.assigns[:raw_body] || []
          conn = Conn.assign(conn, :raw_body, [body | existing])
          {:ok, body, conn}
        end

      {:more, chunk, conn} ->
        new_total = total_bytes + byte_size(chunk)

        if new_total > @max_body_bytes do
          {:error, :too_large}
        else
          do_read_body(conn, opts, [chunk | acc], new_total)
        end

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Returns the cached raw body from `conn.assigns[:raw_body]`.

  Handles the canonical list-of-binaries shape:

    * single-element list → `List.first/1`
    * multi-element list (multipart / multi-chunk) → `Enum.reverse |> IO.iodata_to_binary`
    * missing assign → `nil` (caller falls back to `Plug.Conn.read_body/2`)
  """
  @spec raw_body(Conn.t()) :: binary() | nil
  def raw_body(%Conn{assigns: %{raw_body: [single]}}) when is_binary(single), do: single

  def raw_body(%Conn{assigns: %{raw_body: chunks}}) when is_list(chunks) do
    chunks |> Enum.reverse() |> IO.iodata_to_binary()
  end

  def raw_body(_conn), do: nil
end
