# Compiled only when {:mux, "~> 3.2"} is loaded.
# Adopters who do not configure streaming pay zero transitive cost.
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Streaming.Provider.Mux do
    require Logger

    @moduledoc """
    Mux REST adapter implementing `Rindle.Streaming.Provider`.

    ## Configuration

    Credentials and tunables are resolved from the application environment on
    every call (D-30 — no caching at module load time; adopters using
    `config/runtime.exs` are unaffected):

        config :rindle, Rindle.Streaming.Provider.Mux,
          token_id: System.get_env("RINDLE_MUX_TOKEN_ID"),
          token_secret: System.get_env("RINDLE_MUX_TOKEN_SECRET"),
          signing_key_id: System.get_env("RINDLE_MUX_SIGNING_KEY_ID"),
          signing_private_key: System.get_env("RINDLE_MUX_SIGNING_PRIVATE_KEY"),
          webhook_secrets:
            System.get_env("RINDLE_MUX_WEBHOOK_SECRETS", "")
            |> String.split(",", trim: true),
          webhook_tolerance_seconds: 300,
          provider_polling_floor_seconds: 30,
          provider_stuck_threshold_seconds: 7200

    ## DSL ↔ Mux REST translation (D-04 memo correction)

    Phase 33 ships the DSL atom `:playback_policy` (singular) and the schema
    column `playback_policy` (singular). The Phase 33 schema also defines
    `field :playback_ids, {:array, :string}` (PLURAL ARRAY).

    At the SDK boundary this adapter translates to the **current Mux REST API
    keys**: `inputs` (PLURAL list of objects) and `playback_policies` (PLURAL
    string list). The Mux singular keys are deprecated as of 2026-05 — always
    use plural here. Param construction lives in a single private helper
    (`build_create_params/2`) so workers never duplicate this logic.

    The Phase 33 callback contract returns `playback_ids: [playback_id()]` (a
    list); the row schema persists `playback_ids` as `{:array, :string}`. The
    adapter writes the array verbatim; reads use `List.first/1` only when a
    single id is needed (e.g., for URL minting).

    ## Test wiring

    Tests configure the adapter to route HTTP calls through
    `Rindle.Streaming.Provider.Mux.ClientMock` by overriding the
    `:http_client` key on the same `:rindle, __MODULE__` config keyspace
    (see `test/rindle/streaming/provider/mux/mux_test.exs` for the canonical
    setup). The default `:http_client` is `Rindle.Streaming.Provider.Mux.HTTP`.

    ## Security invariants

    * `provider_asset_id` never crosses into adopter-facing URLs, log lines, or
      telemetry metadata. Only the public-side `playback_id` is embedded in
      URLs. Telemetry emit sites use `Rindle.Domain.MediaProviderAsset.redact_id/1`
      (security invariant 14).
    * `signed_playback_url/3` ALWAYS passes `:expiration` explicitly to
      `Mux.Token.sign_playback_id/2`. The SDK default is 7 days (Pitfall 1) —
      relying on it would silently mint over-long tokens.

    ## Telemetry Contract

    The adapter and its companion workers emit the following events. All
    events with `metadata.asset_id` redact the value to its last-4-char tag
    (`"...abcd"`) via `Rindle.Domain.MediaProviderAsset.redact_id/1`
    (security invariant 14). Adopters writing telemetry handlers MUST treat
    `asset_id` as a redacted identifier — it is not a stable correlation key.

      * `[:rindle, :provider, :ingest, :start | :stop | :exception]` — emitted
        by `Rindle.Workers.MuxIngestVariant` (Phase 34).
        - measurements: `%{system_time, duration?}` (`duration` only on `:stop`/`:exception`)
        - metadata: `%{profile, provider, asset_id, variant_name, kind?, reason?}`
        - `kind: :error | :cancelled` is added on `:exception` to distinguish
          genuine errors (`{:error, _}`) from atomic-promote cancellations
          (`{:cancel, {:stale_source, _}}`).

      * `[:rindle, :provider, :sync, :resolved | :stuck]` — emitted by
        `Rindle.Workers.MuxSyncProviderAsset` (Phase 34).
        - measurements: `%{system_time}`
        - metadata: `%{profile, provider, asset_id, provider_state, age_ms}`
        - `:stuck` fires when a row in `:processing`/`:uploading` exceeds
          `:provider_stuck_threshold_seconds` (default 7200).

      * `[:rindle, :delivery, :streaming, :resolved]` — already shipped by
        Phase 33's `dispatch_streaming/4`. No new event from Phase 34 on this
        path; the metadata extension is the documented v1.4-contract addition.

    Phase 35 will add `[:rindle, :provider, :webhook, _]` events. Phase 34
    does not emit them.
    """

    @behaviour Rindle.Streaming.Provider

    alias Rindle.Streaming.Provider.Mux.Event

    @impl Rindle.Streaming.Provider
    def capabilities, do: [:signed_playback, :webhook_ingest, :server_push_ingest]

    @doc """
    Server-push ingest entry point. Translates DSL `:playback_policy` (singular,
    via `opts`) to the Mux REST PLURAL `playback_policies` key. Returns the
    Phase 33 contract shape `{:ok, %{provider_asset_id: _, playback_ids: [_]}}`
    (PLURAL array, even with a single element).

    Errors are normalized to the Phase 33 atom set:

      * `:provider_quota_exceeded` (HTTP 429) — caller can extract `Retry-After`
        from `%Tesla.Env{}.headers` via `create_asset_with_retry_hint/3` if it
        needs the snooze duration (Plan 02 worker uses that variant).
      * `:provider_sync_failed` (HTTP 4xx/5xx other than 429).
    """
    @impl Rindle.Streaming.Provider
    def create_asset(profile, source_url, opts \\ [])
        when is_atom(profile) and is_binary(source_url) and is_list(opts) do
      policy_atom = Keyword.get(opts, :playback_policy, :signed)
      params = build_create_params(source_url, policy_atom, opts)

      case http_client().create_asset(params) do
        {:ok, %{"id" => provider_asset_id, "playback_ids" => playback_ids}} ->
          {:ok,
           %{
             provider_asset_id: provider_asset_id,
             playback_ids: extract_playback_id_strings(playback_ids)
           }}

        {:ok, %{"id" => provider_asset_id}} ->
          # Defensive — older fixtures may lack "playback_ids".
          {:ok, %{provider_asset_id: provider_asset_id, playback_ids: []}}

        {:error, _msg, %{status: 429}} ->
          {:error, :provider_quota_exceeded}

        {:error, _msg, %{status: status}} when status in 500..599 ->
          {:error, :provider_sync_failed}

        {:error, _msg, %{status: status}} when status in 400..499 ->
          {:error, :provider_sync_failed}

        {:error, reason} ->
          {:error, reason}
      end
    end

    @doc """
    Worker-facing variant of `create_asset/3` that exposes the 429 `Retry-After`
    seconds value so the Plan 02 worker can snooze cleanly. Param construction
    (PLURAL keys) lives ONLY here in the adapter — never duplicated in workers.

    Returns:

      * `{:ok, %{provider_asset_id: _, playback_ids: [_]}}` — happy path.
      * `{:error, :provider_quota_exceeded, retry_after_seconds}` — HTTP 429
        with parsed `Retry-After` (60-second floor when header is missing or
        unparseable).
      * `{:error, :provider_sync_failed}` — other 4xx/5xx.
      * `{:error, term()}` — transport/lower-level error.
    """
    @spec create_asset_with_retry_hint(module(), String.t(), keyword()) ::
            {:ok, %{provider_asset_id: String.t(), playback_ids: [String.t()]}}
            | {:error, :provider_quota_exceeded, non_neg_integer()}
            | {:error, atom()}
            | {:error, term()}
    def create_asset_with_retry_hint(profile, source_url, opts \\ [])
        when is_atom(profile) and is_binary(source_url) and is_list(opts) do
      policy_atom = Keyword.get(opts, :playback_policy, :signed)
      params = build_create_params(source_url, policy_atom, opts)

      case http_client().create_asset(params) do
        {:ok, %{"id" => provider_asset_id, "playback_ids" => playback_ids}} ->
          {:ok,
           %{
             provider_asset_id: provider_asset_id,
             playback_ids: extract_playback_id_strings(playback_ids)
           }}

        {:ok, %{"id" => provider_asset_id}} ->
          {:ok, %{provider_asset_id: provider_asset_id, playback_ids: []}}

        # Pitfall 3 / SDK Issue #42: read Retry-After from %Tesla.Env{}.headers
        # directly because the Mux SDK swallows it in `simplify_response/1`.
        {:error, _msg, %{status: 429, headers: headers}} ->
          {:error, :provider_quota_exceeded, retry_after_from(headers)}

        {:error, _msg, %{status: 429}} ->
          {:error, :provider_quota_exceeded, 60}

        {:error, _msg, %{status: status}} when status in 500..599 ->
          {:error, :provider_sync_failed}

        {:error, _msg, %{status: status}} when status in 400..499 ->
          {:error, :provider_sync_failed}

        {:error, reason} ->
          {:error, reason}
      end
    end

    # SDK-boundary param construction — PLURAL keys, single source of truth.
    # NEVER duplicate this in workers (D-04 memo correction).
    #
    # `:passthrough` (CR-01) — when supplied, stamped onto the create-asset
    # request as the Mux REST `passthrough` field. The soak install-smoke
    # lane sets this to `"rindle_soak"` so the layer-3 cleanup script can
    # filter on a tag that the producer actually writes (the previously-used
    # `meta.rindle_soak` tag was never written by any code path).
    defp build_create_params(source_url, policy_atom, opts) do
      base = %{
        "inputs" => [%{"url" => source_url}],
        "playback_policies" => [Atom.to_string(policy_atom)],
        "mp4_support" => "standard",
        "max_resolution_tier" => "1080p"
      }

      case Keyword.get(opts, :passthrough) do
        nil -> base
        passthrough when is_binary(passthrough) -> Map.put(base, "passthrough", passthrough)
      end
    end

    @impl Rindle.Streaming.Provider
    def get_asset(provider_asset_id) when is_binary(provider_asset_id) do
      case http_client().get_asset(provider_asset_id) do
        {:ok, %{"id" => _, "status" => status, "playback_ids" => pids} = raw} ->
          {:ok,
           %{
             state: normalize_state(status),
             playback_ids: extract_playback_id_strings(pids),
             raw: raw
           }}

        {:ok, %{"id" => _, "status" => status} = raw} ->
          {:ok,
           %{
             state: normalize_state(status),
             playback_ids: [],
             raw: raw
           }}

        {:error, _msg, %{status: 404}} ->
          {:error, :not_found}

        {:error, _msg, %{status: status}} when status in 500..599 ->
          {:error, :provider_sync_failed}

        {:error, _msg, %{status: status}} when status in 400..499 ->
          {:error, :provider_sync_failed}

        {:error, reason} ->
          {:error, reason}
      end
    end

    @impl Rindle.Streaming.Provider
    def delete_asset(provider_asset_id) when is_binary(provider_asset_id) do
      case http_client().delete_asset(provider_asset_id) do
        :ok -> :ok
        {:error, _msg, %{status: 404}} -> :ok
        {:error, _msg, _env} = err -> err
        {:error, _reason} = err -> err
      end
    end

    @impl Rindle.Streaming.Provider
    def signed_playback_url(profile, playback_id, _opts \\ [])
        when is_atom(profile) and is_binary(playback_id) do
      with {:ok, key_id} <- fetch_required(:signing_key_id),
           {:ok, private_key} <- fetch_required(:signing_private_key) do
        ttl = Rindle.Delivery.signed_url_ttl_seconds(profile)
        # WAIVED (POLISH-01/D-13): IN-03 — playback_id is a documented URL-safe
        # alphanumeric (Mux contract); the `URI.encode_www_form/1` here is
        # belt-and-suspenders only. No behavior change required.
        encoded_playback_id = URI.encode_www_form(playback_id)

        jwt =
          Mux.Token.sign_playback_id(encoded_playback_id,
            type: :video,
            # MUST pass :expiration explicitly — SDK default is 7 days (Pitfall 1).
            expiration: ttl,
            token_id: key_id,
            token_secret: private_key
          )

        url = "https://stream.mux.com/#{encoded_playback_id}.m3u8?token=#{jwt}"

        {:ok, %{url: url, kind: :hls, mime: "application/vnd.apple.mpegurl"}}
      end
    end

    @impl Rindle.Streaming.Provider
    def verify_webhook(raw_body, headers, secrets)
        when is_binary(raw_body) and is_map(headers) and is_list(secrets) do
      case fetch_sig_header(headers) do
        {:ok, sig_header} ->
          tolerance = get_tolerance()

          # D-17: provider-internal telemetry. The PUBLIC callback contract
          # (`{:ok, provider_event()} | {:error, :provider_webhook_invalid}`)
          # is UNCHANGED; this telemetry is additive and lets operators
          # distinguish secret-rotation issues from upstream queue lag.
          secrets
          |> Enum.with_index()
          |> Enum.find_value({:error, :provider_webhook_invalid}, fn {secret, index} ->
            case Mux.Webhooks.verify_header(raw_body, sig_header, secret, tolerance) do
              :ok ->
                :telemetry.execute(
                  [:rindle, :provider, :mux, :webhook_attempt, :secret_used],
                  %{system_time: System.system_time()},
                  %{secret_index: index}
                )

                with {:ok, decoded} <- Jason.decode(raw_body),
                     {:ok, evt} <- Event.normalize(decoded) do
                  {:ok, evt}
                else
                  _ -> {:error, :provider_webhook_invalid}
                end

              {:error, sdk_reason} ->
                :telemetry.execute(
                  [:rindle, :provider, :mux, :webhook_attempt, :rejected],
                  %{system_time: System.system_time()},
                  %{secret_index: index, sdk_reason: inspect(sdk_reason)}
                )

                nil
            end
          end)

        :error ->
          :telemetry.execute(
            [:rindle, :provider, :mux, :webhook_attempt, :rejected],
            %{system_time: System.system_time()},
            %{secret_index: nil, sdk_reason: ":missing_header"}
          )

          {:error, :provider_webhook_invalid}
      end
    end

    @doc false
    # Internal helper consumed by `Rindle.Delivery.WebhookPlug` to decide whether
    # a verified Mux event should be enqueued (`:dispatch`) or acknowledged with
    # 200 OK and dropped (`:drop`).
    #
    # Phase 35 dispatches: `video.asset.{ready,errored,deleted,created}` and
    # `video.upload.asset_created` (forward-compat for Phase 37; worker no-ops).
    # Everything else drops — Mux ships event types Rindle does not act on
    # (master files, tracks, static renditions, live-stream, etc.). Returning
    # 200 OK ensures Mux does not retry; the verified-but-dropped events surface
    # in `[:rindle, :provider, :webhook, :verified]` telemetry with `kind: :dropped`.
    #
    # Default for unknown event types is `:drop` (forward-compat safety — Mux
    # ships new types regularly; the library should not crash or queue work for
    # types Rindle does not recognize).
    @spec dispatch_kind(String.t() | nil) :: :dispatch | :drop
    def dispatch_kind("video.asset.ready"), do: :dispatch
    def dispatch_kind("video.asset.errored"), do: :dispatch
    def dispatch_kind("video.asset.deleted"), do: :dispatch
    def dispatch_kind("video.asset.created"), do: :dispatch
    def dispatch_kind("video.upload.asset_created"), do: :dispatch

    # DROP table — events Rindle v1.6 does not act on (Mux 2026 catalog).
    def dispatch_kind("video.asset.updated"), do: :drop
    def dispatch_kind("video.asset.warning"), do: :drop
    def dispatch_kind("video.asset.non_standard_input_detected"), do: :drop
    def dispatch_kind("video.asset.master." <> _), do: :drop
    def dispatch_kind("video.asset.track." <> _), do: :drop
    def dispatch_kind("video.asset.static_rendition." <> _), do: :drop
    def dispatch_kind("video.asset.live_stream_completed"), do: :drop
    def dispatch_kind("video.upload." <> _), do: :drop
    def dispatch_kind("video.live_stream." <> _), do: :drop

    # Forward-compat default — unknown events drop. Mux ships novelty regularly.
    def dispatch_kind(_other), do: :drop

    # WR-02 (POLISH-01/D-13): HTTP header names are case-insensitive (RFC 7230).
    # Plug.Conn lowercases request headers per the HTTP/2 spec, but adopter
    # wrappers, edge proxies, or future libraries may pass other casings
    # (`MUX-SIGNATURE`, `Mux-Signature`, ...). Downcase the entire header map
    # once, then `Map.fetch("mux-signature")` so a valid signature under any
    # casing resolves instead of silently failing signature verification.
    defp fetch_sig_header(headers) do
      downcased = Map.new(headers, fn {k, v} -> {String.downcase(to_string(k)), v} end)

      case Map.fetch(downcased, "mux-signature") do
        {:ok, value} -> {:ok, value}
        :error -> :error
      end
    end

    # Mux uses "preparing" while transcoding; Phase 33 FSM uses "processing".
    defp normalize_state("preparing"), do: "processing"
    defp normalize_state("ready"), do: "ready"
    defp normalize_state("errored"), do: "errored"
    defp normalize_state("deleted"), do: "deleted"

    defp normalize_state(other) when is_binary(other) do
      Logger.warning("rindle.mux.unknown_status", status: other)
      nil
    end

    defp normalize_state(_), do: nil

    defp extract_playback_id_strings(list) when is_list(list) do
      list
      |> Enum.map(fn
        %{"id" => id} when is_binary(id) -> id
        id when is_binary(id) -> id
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)
    end

    defp extract_playback_id_strings(_), do: []

    defp retry_after_from(headers) when is_list(headers) do
      candidate =
        Enum.find(headers, fn
          {k, _v} when is_binary(k) -> String.downcase(k) == "retry-after"
          _ -> false
        end)

      case candidate do
        {_, v} when is_binary(v) ->
          case Integer.parse(v) do
            {n, _} when n > 0 -> n
            _ -> 60
          end

        _ ->
          60
      end
    end

    defp retry_after_from(_), do: 60

    @doc false
    def http_client do
      config(:http_client, Rindle.Streaming.Provider.Mux.HTTP)
    end

    defp get_tolerance do
      case config(:webhook_tolerance_seconds, 300) do
        n when is_integer(n) and n > 0 -> n
        _ -> 300
      end
    end

    defp config(key, default) do
      :rindle
      |> Application.get_env(__MODULE__, [])
      |> Keyword.get(key, default)
    end

    defp fetch_required(key) do
      cfg = Application.get_env(:rindle, __MODULE__, [])

      case Keyword.get(cfg, key) do
        v when is_binary(v) and v != "" -> {:ok, v}
        _ -> {:error, {:missing_config, key}}
      end
    end
  end
end
