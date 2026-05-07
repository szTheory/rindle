defmodule Rindle.Delivery.WebhookPlug do
  @moduledoc """
  Mountable provider-aware Plug for streaming-provider webhooks.

  ## Adopter wiring

  Step 1 — install the body reader globally in `endpoint.ex` (BEFORE `Plug.Parsers`):

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        body_reader: {Rindle.Delivery.WebhookBodyReader, :read_body, []},
        json_decoder: Jason

  Step 2 — mount the Plug in `router.ex`, one `forward` per provider:

      forward "/webhooks/rindle/mux", Rindle.Delivery.WebhookPlug,
        provider: Rindle.Streaming.Provider.Mux,
        secrets: {:application, :rindle, [Rindle.Streaming.Provider.Mux, :webhook_secrets]}

  Step 3 — set `RINDLE_MUX_WEBHOOK_SECRETS` (comma-separated) in your runtime
  config, and configure your Mux dashboard webhook to POST to
  `https://yourapp.example.com/webhooks/rindle/mux`.

  ## Secrets resolver shapes (D-02)

  The `:secrets` option supports four shapes, resolved at every `call/2`
  (NOT `init/1`) so runtime rotation works without a restart:

    * `[binary()]` — direct list (tests).
    * `{:system, env_var :: String.t()}` — comma-split env var.
    * `{:application, app :: atom(), [atom()]}` — `Application.get_env` getter
      with optional path traversal into nested keyword lists / maps.
    * `(-> [binary()])` — 0-arity function.

  ## Response codes (D-12..D-16)

  | Status | Body | When |
  |--------|------|------|
  | 202 Accepted | empty | Verified + enqueued. |
  | 200 OK | empty | Verified but dropped (event not in adapter dispatch table). |
  | 400 Bad Request | `provider_webhook_invalid` | Signature mismatch, replay-window failure, missing secrets, callback raised. |
  | 405 Method Not Allowed | `method not allowed` | Non-POST request. |
  | 500 Internal Server Error | `server_misconfigured` | Body reader assign missing AND fallback empty. |
  | 503 Service Unavailable | empty | Oban enqueue raised (transient downstream failure — Mux retries). |

  ## Telemetry (Plug edge)

  Events under `[:rindle, :provider, :webhook, _]`:

    * `:verified` — verify path returned `{:ok, event}`. Metadata:
      `%{provider, event_type, event_id, kind}` where
      `kind: :enqueued | :dropped`.
    * `:rejected` — verification or pre-verify check failed. Metadata:
      `%{provider, reason, ...}` where `reason: :method_not_allowed |
      :body_reader_missing | :no_secrets_configured |
      :provider_callback_raised | :sig_mismatch | :oban_unavailable`.

  Provider-internal telemetry under
  `[:rindle, :provider, :mux, :webhook_attempt, _]` (emitted from inside
  `Rindle.Streaming.Provider.Mux.verify_webhook/3`):

    * `:secret_used` — metadata `%{secret_index}`.
    * `:rejected` — metadata `%{secret_index, sdk_reason}`.
  """

  @behaviour Plug

  # `Rindle.Workers.IngestProviderWebhook` ships in Plan 02; the module reference
  # compiles fine because Elixir resolves modules lazily at runtime.
  @compile {:no_warn_undefined, Rindle.Workers.IngestProviderWebhook}

  import Plug.Conn

  require Logger

  @doc """
  `init/1` validates the provider module exposes `verify_webhook/3` and that
  the secrets resolver shape is one of the four locked forms. Raises
  `ArgumentError` for misconfigurations so deployment-time mistakes surface
  immediately, not at first webhook delivery.
  """
  @impl true
  def init(opts) do
    provider = Keyword.fetch!(opts, :provider)
    secrets = Keyword.fetch!(opts, :secrets)

    unless Code.ensure_loaded?(provider) and function_exported?(provider, :verify_webhook, 3) do
      raise ArgumentError,
            "Rindle.Delivery.WebhookPlug requires `:provider` to be a module exporting `verify_webhook/3`; got #{inspect(provider)}"
    end

    unless valid_secrets_resolver?(secrets) do
      raise ArgumentError,
            "Rindle.Delivery.WebhookPlug `:secrets` must be one of: [binary()], {:system, env_var}, {:application, app, [atom()]}, or 0-arity fn; got #{inspect(secrets)}"
    end

    [provider: provider, secrets: secrets]
  end

  @impl true
  def call(%Plug.Conn{method: method} = conn, _opts) when method != "POST" do
    emit_rejected(:method_not_allowed, %{})

    conn
    |> send_resp(405, "method not allowed")
    |> halt()
  end

  def call(conn, opts) do
    provider = Keyword.fetch!(opts, :provider)
    secrets_resolver = Keyword.fetch!(opts, :secrets)
    secrets = resolve_secrets(secrets_resolver)

    if secrets == [] do
      emit_rejected(:no_secrets_configured, %{provider: provider_atom(provider)})
      send_invalid(conn)
    else
      verify_and_dispatch(conn, provider, secrets)
    end
  end

  defp verify_and_dispatch(conn, provider, secrets) do
    with {:ok, raw_body, conn} <- fetch_raw_body(conn),
         headers = Enum.into(conn.req_headers, %{}),
         {:ok, event} <- safe_verify(provider, raw_body, headers, secrets) do
      dispatch_event(conn, provider, event)
    else
      {:error, :body_missing} ->
        emit_rejected(:body_reader_missing, %{provider: provider_atom(provider)})

        conn
        |> send_resp(500, "server_misconfigured")
        |> halt()

      {:error, :provider_webhook_invalid} ->
        emit_rejected(:sig_mismatch, %{provider: provider_atom(provider)})
        send_invalid(conn)

      {:error, :callback_raised, message} ->
        emit_rejected(:provider_callback_raised, %{
          provider: provider_atom(provider),
          error: message
        })

        send_invalid(conn)
    end
  end

  defp dispatch_event(conn, provider, event) do
    raw = Map.get(event, :raw, %{})
    event_id = Map.get(raw, "id")
    event_type = Map.get(raw, "type")

    case provider.dispatch_kind(event_type) do
      :drop ->
        emit_verified(%{
          provider: provider_atom(provider),
          event_type: event_type,
          event_id: event_id,
          kind: :dropped
        })

        conn |> send_resp(200, "") |> halt()

      :dispatch ->
        try do
          args = %{
            "event_id" => event_id,
            "provider" => provider_atom_string(provider),
            "event_type" => event_type,
            "event" => stringify_event(event)
          }

          # Mirror Rindle.Workers.IngestProviderWebhook.unique_job_opts/0 (D-20).
          # `:available` MUST be in the states list — Oban inserts newly-enqueued
          # jobs in `:available` first; without it, the unique constraint never
          # fires for the most common re-delivery dedup case (the second webhook
          # arrives before the worker picks up the first job).
          unique_opts = [
            fields: [:args],
            keys: [:event_id],
            states: [:available, :scheduled, :executing, :retryable],
            period: 86_400
          ]

          {:ok, _job} =
            args
            |> Rindle.Workers.IngestProviderWebhook.new(unique: unique_opts)
            |> Oban.insert()

          emit_verified(%{
            provider: provider_atom(provider),
            event_type: event_type,
            event_id: event_id,
            kind: :enqueued
          })

          conn |> send_resp(202, "") |> halt()
        rescue
          error ->
            emit_rejected(:oban_unavailable, %{
              provider: provider_atom(provider),
              event_type: event_type,
              event_id: event_id,
              error: Exception.message(error)
            })

            conn |> send_resp(503, "") |> halt()
        end
    end
  end

  defp safe_verify(provider, raw_body, headers, secrets) do
    try do
      provider.verify_webhook(raw_body, headers, secrets)
    rescue
      e ->
        {:error, :callback_raised, Exception.message(e)}
    end
  end

  defp fetch_raw_body(conn) do
    case Rindle.Delivery.WebhookBodyReader.raw_body(conn) do
      binary when is_binary(binary) and byte_size(binary) > 0 ->
        {:ok, binary, conn}

      _ ->
        # Fallback for the "Plug mounted before Plug.Parsers" case Stripe
        # documents (D-10). If THIS also yields empty, the adopter's
        # `endpoint.ex` is misconfigured (D-16).
        case Plug.Conn.read_body(conn) do
          {:ok, body, conn} when byte_size(body) > 0 -> {:ok, body, conn}
          _ -> {:error, :body_missing}
        end
    end
  end

  # Secrets resolver — D-02. Resolution at call time, NOT init time.
  defp resolve_secrets(list) when is_list(list), do: list

  defp resolve_secrets({:system, env_var}) when is_binary(env_var) do
    env_var |> System.get_env("") |> String.split(",", trim: true)
  end

  defp resolve_secrets({:application, app, [key | rest]}) do
    case Application.get_env(app, key, []) do
      value -> get_in_path(value, rest) |> normalize_secrets_list()
    end
  end

  defp resolve_secrets(fun) when is_function(fun, 0), do: fun.()
  defp resolve_secrets(_), do: []

  defp normalize_secrets_list(list) when is_list(list) do
    Enum.filter(list, &is_binary/1)
  end

  defp normalize_secrets_list(_), do: []

  defp get_in_path(value, []), do: value

  defp get_in_path(kw, [key | rest]) when is_list(kw) do
    if Keyword.keyword?(kw) do
      kw |> Keyword.get(key) |> get_in_path(rest)
    else
      nil
    end
  end

  defp get_in_path(map, [key | rest]) when is_map(map) do
    map |> Map.get(key) |> get_in_path(rest)
  end

  defp get_in_path(_, _), do: nil

  defp valid_secrets_resolver?(secrets) when is_list(secrets),
    do: Enum.all?(secrets, &is_binary/1)

  defp valid_secrets_resolver?({:system, env}) when is_binary(env), do: true

  defp valid_secrets_resolver?({:application, app, path})
       when is_atom(app) and is_list(path),
       do: Enum.all?(path, &is_atom/1)

  defp valid_secrets_resolver?(fun) when is_function(fun, 0), do: true
  defp valid_secrets_resolver?(_), do: false

  defp send_invalid(conn) do
    conn
    |> send_resp(400, "provider_webhook_invalid")
    |> halt()
  end

  defp emit_rejected(reason, extra_metadata) do
    :telemetry.execute(
      [:rindle, :provider, :webhook, :rejected],
      %{system_time: System.system_time()},
      Map.put(extra_metadata, :reason, reason)
    )
  end

  defp emit_verified(metadata) do
    :telemetry.execute(
      [:rindle, :provider, :webhook, :verified],
      %{system_time: System.system_time()},
      metadata
    )
  end

  # Normalize the `provider_event` map (atom keys) into stringified-key map
  # for Oban jsonb storage. Atoms in `:type` are stringified; DateTime values
  # are ISO8601-encoded.
  defp stringify_event(event) when is_map(event) do
    Map.new(event, fn
      {:type, v} when is_atom(v) -> {"type", Atom.to_string(v)}
      {k, %DateTime{} = v} when is_atom(k) -> {Atom.to_string(k), DateTime.to_iso8601(v)}
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  # Provider atom shorthand — Phase 35 only Mux exists. The adapter exposes
  # the atom via its `:capabilities/0` callback indirectly; we use the
  # module's last segment for telemetry consistency.
  defp provider_atom(Rindle.Streaming.Provider.Mux), do: :mux

  defp provider_atom(other) when is_atom(other) do
    other
    |> Module.split()
    |> List.last()
    |> String.downcase()
    |> String.to_atom()
  end

  defp provider_atom_string(provider), do: provider |> provider_atom() |> Atom.to_string()
end
