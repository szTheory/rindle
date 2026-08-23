defmodule Rindle.Ops.RuntimeChecks.IntegrationChecks do
  @moduledoc false

  @streaming_required_env_vars ~w(RINDLE_MUX_TOKEN_ID RINDLE_MUX_TOKEN_SECRET
                                  RINDLE_MUX_SIGNING_KEY_ID RINDLE_MUX_SIGNING_PRIVATE_KEY
                                  RINDLE_MUX_WEBHOOK_SECRETS)

  @streaming_credentials_fix """
  Set RINDLE_MUX_TOKEN_ID, RINDLE_MUX_TOKEN_SECRET, RINDLE_MUX_SIGNING_KEY_ID, RINDLE_MUX_SIGNING_PRIVATE_KEY, and RINDLE_MUX_WEBHOOK_SECRETS in your runtime config. See guides/streaming_providers.md for setup.
  """

  @streaming_signing_key_fix """
  Verify RINDLE_MUX_SIGNING_PRIVATE_KEY is a valid PEM-encoded RSA private key (re-download from Mux Dashboard -> Settings -> Signing Keys if unsure; Mux does not allow re-downloading the same key, so creating a fresh one is safest).
  """

  @streaming_webhook_secrets_fix """
  Set RINDLE_MUX_WEBHOOK_SECRETS to a comma-separated list of webhook secrets, each at least 32 characters. See Mux Dashboard -> Settings -> Webhooks.
  """

  @streaming_smoke_ping_fix """
  Pass --streaming to enable a live 5s smoke ping to Mux.Video.Assets.list/1. Re-run with `mix rindle.doctor --streaming` once credentials are configured.
  """

  @streaming_dep_missing_fix ~s(Add {:mux, "~> 3.2", optional: true} and {:jose, "~> 1.11", optional: true} to your deps.)

  @gcs_dep_missing_fix ~s(Add {:goth, "~> 1.4", optional: true}, {:finch, "~> 0.21", optional: true}, and {:gcs_signed_url, "~> 0.6", optional: true} to your deps and run mix deps.get.)

  @gcs_goth_fix """
  Add {Goth, name: MyApp.Goth, source: {:service_account, creds}} to your supervision tree, then set config :rindle, Rindle.Storage.GCS, goth: MyApp.Goth.
  """

  @gcs_bucket_fix """
  Verify config :rindle, Rindle.Storage.GCS, bucket: "my-bucket" matches a bucket your service account can access.
  """

  @gcs_signing_key_fix """
  Verify the signing_key config is either a decoded service-account JSON map (preferred) or a raw PEM string with `client_email:` configured separately. File-path loading is not supported here; decode the service-account JSON at boot via `Jason.decode!(File.read!("path/to/key.json"))` and pass the resulting map.
  """

  @gcs_precondition_fix """
  Start `MyApp.Finch` and `MyApp.Goth` in your application supervision tree, then set config :rindle, Rindle.Storage.GCS, finch: MyApp.Finch, goth: MyApp.Goth.
  """

  @gcs_resumable_cors_fix """
  Configure bucket CORS for your app origins with `PUT` and `PATCH`, and allow `Content-Range` plus `x-goog-resumable` in the browser-facing response/header policy. Keep `session_uri` secret because it is a bearer credential, expect resumable sessions to expire within one week, and treat region pinning as normal when you choose the bucket location.
  """

  @doc false
  def schedule(profile_groups, env, opts, readers) do
    gcs_checks =
      if profile_groups.gcs == [] do
        []
      else
        base_checks = [
          fn -> check_gcs_goth_running(readers.gcs_config.()) end,
          fn -> check_gcs_bucket_reachable(readers.gcs_config.()) end,
          fn -> check_gcs_signing_key(readers.gcs_config.()) end
        ]

        if resumable_gcs_profiles(profile_groups.gcs) == [] do
          base_checks
        else
          base_checks ++ [fn -> check_gcs_resumable_cors(opts, readers.gcs_config.()) end]
        end
      end

    tus_checks =
      if profile_groups.tus == [] do
        []
      else
        [fn -> check_tus_capability(profile_groups.tus) end]
      end

    [
      fn -> check_streaming_credentials(profile_groups.streaming, env) end,
      fn -> check_streaming_signing_key(profile_groups.streaming, env) end,
      fn -> check_streaming_webhook_secrets(profile_groups.streaming, env) end,
      fn ->
        check_streaming_smoke_ping(profile_groups.streaming, env, opts, readers.mux_config)
      end
    ] ++ gcs_checks ++ tus_checks
  end

  defp check_tus_capability(tus_profiles) do
    mismatches =
      Enum.filter(tus_profiles, fn profile ->
        adapter = safely_storage_adapter(profile)
        not is_atom(adapter) or not Rindle.Storage.Capabilities.supports?(adapter, :tus_upload)
      end)

    if mismatches == [] do
      ok_result(
        "doctor.tus_capability",
        :profiles,
        "Configured tus profiles advertise :tus_upload support.",
        "Keep `config :rindle, :tus_profiles, [...]` aligned with profiles whose adapters support tus."
      )
    else
      error_result(
        "doctor.tus_capability",
        :profiles,
        "Tus is configured for #{Enum.map_join(mismatches, ", ", &inspect/1)}, but the storage adapter does not advertise :tus_upload.",
        "Either mount TusPlug only for profiles backed by a :tus_upload-capable adapter, or remove the profile from `config :rindle, :tus_profiles, [...]`."
      )
    end
  end

  defp check_streaming_credentials(streaming_profiles, env) do
    cond do
      streaming_profiles == [] ->
        ok_result(
          "doctor.streaming_credentials",
          :streaming,
          "No streaming-enabled profiles discovered.",
          @streaming_credentials_fix
        )

      not Code.ensure_loaded?(Mux.Video.Assets) ->
        error_result(
          "doctor.streaming_credentials",
          :streaming,
          "Streaming-enabled profile detected but :mux dep is not loaded.",
          @streaming_dep_missing_fix
        )

      true ->
        case missing_streaming_credentials(env) do
          [] ->
            ok_result(
              "doctor.streaming_credentials",
              :streaming,
              "All five RINDLE_MUX_* credentials are set.",
              @streaming_credentials_fix
            )

          missing ->
            error_result(
              "doctor.streaming_credentials",
              :streaming,
              "Missing RINDLE_MUX_* credentials: #{Enum.join(missing, ", ")}.",
              @streaming_credentials_fix
            )
        end
    end
  end

  defp missing_streaming_credentials(env) do
    Enum.filter(@streaming_required_env_vars, fn name ->
      case Map.get(env, name) do
        nil -> true
        "" -> true
        _ -> false
      end
    end)
  end

  defp check_streaming_signing_key(streaming_profiles, env) do
    cond do
      streaming_profiles == [] ->
        ok_result(
          "doctor.streaming_signing_key",
          :streaming,
          "No streaming-enabled profiles discovered.",
          @streaming_signing_key_fix
        )

      not Code.ensure_loaded?(JOSE.JWK) ->
        error_result(
          "doctor.streaming_signing_key",
          :streaming,
          "Streaming-enabled profile detected but :jose dep is not loaded.",
          @streaming_dep_missing_fix
        )

      true ->
        case Map.get(env, "RINDLE_MUX_SIGNING_PRIVATE_KEY", "") do
          "" ->
            error_result(
              "doctor.streaming_signing_key",
              :streaming,
              "RINDLE_MUX_SIGNING_PRIVATE_KEY is not set.",
              @streaming_signing_key_fix
            )

          value ->
            verify_signing_key_pem(value)
        end
    end
  end

  # Pitfall 1: JOSE.JWK.from_pem/1 returns `[]` (NOT raises) on malformed PEM.
  # MUST pattern-match against %JOSE.JWK{}, not just truthy. We also rescue
  # exceptions defensively in case a future jose version changes behavior.
  defp verify_signing_key_pem(value) do
    case JOSE.JWK.from_pem(value) do
      %{__struct__: JOSE.JWK} ->
        ok_result(
          "doctor.streaming_signing_key",
          :streaming,
          "RINDLE_MUX_SIGNING_PRIVATE_KEY parses as a valid JOSE JWK.",
          @streaming_signing_key_fix
        )

      _other ->
        error_result(
          "doctor.streaming_signing_key",
          :streaming,
          "RINDLE_MUX_SIGNING_PRIVATE_KEY did not parse as a JOSE JWK (malformed PEM).",
          @streaming_signing_key_fix
        )
    end
  rescue
    exception ->
      # Phase 36 WR-10: surface the exception class (NOT the message — the
      # message could echo PEM content). The struct name is non-sensitive
      # and unlocks "is it MatchError or FunctionClauseError?" diagnosis
      # for `mix rindle.doctor --raise` without leaking key material.
      error_result(
        "doctor.streaming_signing_key",
        :streaming,
        "RINDLE_MUX_SIGNING_PRIVATE_KEY parse raised: " <>
          inspect(exception.__struct__) <> " (malformed PEM).",
        @streaming_signing_key_fix
      )
  end

  defp check_streaming_webhook_secrets(streaming_profiles, env) do
    cond do
      streaming_profiles == [] ->
        ok_result(
          "doctor.streaming_webhook_secrets",
          :streaming,
          "No streaming-enabled profiles discovered.",
          @streaming_webhook_secrets_fix
        )

      true ->
        raw = Map.get(env, "RINDLE_MUX_WEBHOOK_SECRETS", "")
        secrets = raw |> String.split(",", trim: true) |> Enum.map(&String.trim/1)

        cond do
          secrets == [] ->
            error_result(
              "doctor.streaming_webhook_secrets",
              :streaming,
              "RINDLE_MUX_WEBHOOK_SECRETS is empty.",
              @streaming_webhook_secrets_fix
            )

          Enum.any?(secrets, &(String.length(&1) < 32)) ->
            error_result(
              "doctor.streaming_webhook_secrets",
              :streaming,
              "At least one RINDLE_MUX_WEBHOOK_SECRETS entry is shorter than the 32-character Mux minimum.",
              @streaming_webhook_secrets_fix
            )

          true ->
            ok_result(
              "doctor.streaming_webhook_secrets",
              :streaming,
              "RINDLE_MUX_WEBHOOK_SECRETS has #{length(secrets)} secret(s), all >= 32 chars.",
              @streaming_webhook_secrets_fix
            )
        end
    end
  end

  defp check_streaming_smoke_ping(streaming_profiles, _env, opts, mux_config_reader) do
    streaming? = Keyword.get(opts, :streaming, false)

    cond do
      streaming_profiles == [] ->
        ok_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "No streaming-enabled profiles discovered.",
          @streaming_smoke_ping_fix
        )

      not streaming? ->
        ok_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Smoke ping skipped (pass --streaming to enable live API check).",
          @streaming_smoke_ping_fix
        )

      not Code.ensure_loaded?(Mux.Video.Assets) ->
        error_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Streaming-enabled profile detected but :mux dep is not loaded.",
          @streaming_dep_missing_fix
        )

      true ->
        run_smoke_ping_with_timeout(mux_config_reader)
    end
  end

  # Hard 5s wall-clock ceiling via Task.yield + Task.shutdown(:brutal_kill)
  # (RESEARCH "Don't hand-roll" — defer to OTP). The task body returns the
  # raw {:ok, _, _} | {:error, _, _} shape from Mux.Video.Assets.list/2, with
  # exceptions and exits captured into uniform tuples for the case below.
  defp run_smoke_ping_with_timeout(mux_config_reader) do
    task =
      Task.async(fn ->
        try do
          cfg = mux_config_reader.()
          token_id = Keyword.get(cfg, :token_id)
          token_secret = Keyword.get(cfg, :token_secret)

          if is_binary(token_id) and is_binary(token_secret) do
            client = Mux.Base.new(token_id, token_secret)
            Mux.Video.Assets.list(client, %{limit: 1})
          else
            {:error, :no_credentials}
          end
        rescue
          e -> {:rescue, e}
        catch
          kind, reason -> {:catch, kind, reason}
        end
      end)

    case Task.yield(task, 5_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, _list, _env}} ->
        ok_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Mux.Video.Assets.list/1 returned 200 (smoke ping OK).",
          @streaming_smoke_ping_fix
        )

      {:ok, {:error, _msg, %{status: status}}} when status in [401, 403] ->
        error_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Mux smoke ping returned #{status}.",
          "Verify RINDLE_MUX_TOKEN_ID and RINDLE_MUX_TOKEN_SECRET in your runtime config."
        )

      {:ok, {:error, _msg, %{status: 429}}} ->
        error_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Mux smoke ping returned 429.",
          "Mux rate-limited the smoke ping; retry in a few seconds."
        )

      {:ok, {:error, _msg, %{status: status}}} ->
        error_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Mux smoke ping returned status #{status}.",
          @streaming_smoke_ping_fix
        )

      {:ok, {:error, :no_credentials}} ->
        error_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Mux smoke ping skipped: RINDLE_MUX_TOKEN_ID / RINDLE_MUX_TOKEN_SECRET are not configured.",
          @streaming_credentials_fix
        )

      nil ->
        error_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Mux smoke ping timed out after 5s.",
          "Could not reach api.mux.com within 5s; check network / proxy / DNS."
        )

      {:ok, _other} ->
        error_result(
          "doctor.streaming_smoke_ping",
          :streaming,
          "Mux smoke ping returned an unexpected shape.",
          @streaming_smoke_ping_fix
        )
    end
  end

  defp safely_storage_adapter(profile) do
    if function_exported?(profile, :storage_adapter, 0), do: profile.storage_adapter(), else: nil
  rescue
    _ -> nil
  end

  defp resumable_gcs_profiles(gcs_profiles) do
    Enum.filter(gcs_profiles, fn profile ->
      case profile.storage_adapter() do
        adapter when is_atom(adapter) ->
          function_exported?(adapter, :capabilities, 0) and
            :resumable_upload_session in adapter.capabilities()

        _other ->
          false
      end
    end)
  end

  # Two-branch cond — the profile-aware short-circuit moved to the splice site
  # in run/2 per WARNING 3.
  defp check_gcs_goth_running(app_env) do
    cond do
      not Code.ensure_loaded?(Goth) ->
        error_result(
          "doctor.gcs_goth_running",
          :gcs,
          "GCS-enabled profile detected but :goth dep is not loaded.",
          @gcs_dep_missing_fix
        )

      true ->
        goth_name = app_env[:goth]

        case fetch_gcs_goth_token(goth_name) do
          :ok ->
            ok_result(
              "doctor.gcs_goth_running",
              :gcs,
              "Goth instance #{inspect(goth_name)} is running and minting tokens.",
              @gcs_goth_fix
            )

          {:error, :no_goth_configured} ->
            error_result(
              "doctor.gcs_goth_running",
              :gcs,
              "config :rindle, Rindle.Storage.GCS, goth: ... is not set.",
              @gcs_goth_fix
            )

          {:error, reason} ->
            error_result(
              "doctor.gcs_goth_running",
              :gcs,
              "Goth instance #{inspect(goth_name)} is not minting tokens: #{inspect(reason)}.",
              @gcs_goth_fix
            )
        end
    end
  end

  defp fetch_gcs_goth_token(nil), do: {:error, :no_goth_configured}

  defp fetch_gcs_goth_token(name) do
    # RESEARCH Pitfall 6: Goth.fetch/1 raises ArgumentError when the named
    # instance is not in the supervision tree (NOT `:exit, :noproc`). The
    # load-bearing trap is `rescue ArgumentError`. The `catch :exit, _reason`
    # branch is retained as defense-in-depth for older Goth versions or
    # unexpected exit propagation but is NOT the primary trap.
    try do
      case Goth.fetch(name) do
        {:ok, _token} -> :ok
        {:error, exception} when is_struct(exception) -> {:error, exception.__struct__}
        {:error, reason} -> {:error, reason}
      end
    rescue
      ArgumentError -> {:error, :argument_error}
    catch
      :exit, _reason -> {:error, :noproc}
    end
  end

  defp check_gcs_bucket_reachable(app_env) do
    cond do
      not Code.ensure_loaded?(Finch) ->
        error_result(
          "doctor.gcs_bucket_reachable",
          :gcs,
          "GCS-enabled profile detected but :finch dep is not loaded.",
          @gcs_dep_missing_fix
        )

      true ->
        case app_env[:bucket] do
          nil ->
            error_result(
              "doctor.gcs_bucket_reachable",
              :gcs,
              "config :rindle, Rindle.Storage.GCS, bucket: \"...\" is not set.",
              @gcs_bucket_fix
            )

          bucket ->
            finch_name = app_env[:finch]
            goth_name = app_env[:goth]
            base_url = app_env[:base_url]
            token = app_env[:token]

            opts =
              []
              |> then(fn acc -> if base_url, do: [{:base_url, base_url} | acc], else: acc end)
              |> then(fn acc -> if token, do: [{:token, token} | acc], else: acc end)

            case probe_gcs_bucket(bucket, finch_name, goth_name, opts) do
              :ok ->
                ok_result(
                  "doctor.gcs_bucket_reachable",
                  :gcs,
                  "Bucket #{inspect(bucket)} is reachable (HTTP 200/403 from /storage/v1/b/$BUCKET).",
                  @gcs_bucket_fix
                )

              {:precondition_missing, which} ->
                error_result(
                  "doctor.gcs_bucket_reachable",
                  :gcs,
                  "GCS bucket reachability could not be probed (#{which}). Start Finch + Goth in your supervision tree and configure their names.",
                  @gcs_precondition_fix
                )

              {:bucket_missing, _status} ->
                error_result(
                  "doctor.gcs_bucket_reachable",
                  :gcs,
                  "GCS bucket #{inspect(bucket)} not found (404).",
                  @gcs_bucket_fix
                )

              {:unexpected_status, status} ->
                error_result(
                  "doctor.gcs_bucket_reachable",
                  :gcs,
                  "GCS API returned unexpected status #{status} for bucket #{inspect(bucket)}.",
                  @gcs_bucket_fix
                )

              {:probe_error, reason} ->
                # Security invariant: Finch.request errors are atoms / Mint
                # transport structs — never raw response bodies. Goth errors
                # surface as exception struct names. Bearer tokens NEVER
                # appear in `reason`.
                error_result(
                  "doctor.gcs_bucket_reachable",
                  :gcs,
                  "GCS bucket #{inspect(bucket)} probe failed: #{inspect(reason)}.",
                  @gcs_bucket_fix
                )
            end
        end
    end
  end

  # BLOCKER 2 — D-13 LOCK: real HTTP probe with explicit precondition guards.
  # Public (def) so Bypass-mocked unit tests can exercise it directly.
  # @doc false marks it as not part of the documented public API.
  @doc false
  def probe_gcs_bucket(bucket, finch_name, goth_name, opts \\ []) do
    cond do
      not Code.ensure_loaded?(Finch) ->
        {:precondition_missing, :finch_unavailable}

      finch_name == nil ->
        {:precondition_missing, :finch_not_configured}

      not Code.ensure_loaded?(Goth) ->
        {:precondition_missing, :goth_unavailable}

      goth_name == nil ->
        {:precondition_missing, :goth_not_configured}

      true ->
        do_probe(bucket, finch_name, goth_name, opts)
    end
  end

  # BLOCKER 2 — D-13 LOCK: actual HTTP request issuance. Public (def) for
  # testability; @doc false. `:base_url` opt allows Bypass redirection in unit
  # tests; `:token` opt is a test-only seam that bypasses Goth.fetch/1 (which
  # would otherwise call Google's real OAuth endpoint with the fake fixture
  # credentials and fail). Both seams mirror Plan 01's Client conventions.
  @doc false
  def do_probe(bucket, finch_name, goth_name, opts \\ []) do
    base_url = Keyword.get(opts, :base_url, "https://storage.googleapis.com")
    encoded_bucket = URI.encode(bucket)
    url = "#{base_url}/storage/v1/b/#{encoded_bucket}"

    with {:ok, token} <- probe_token(goth_name, opts),
         req = Finch.build(:get, url, [{"Authorization", "Bearer " <> token}]),
         {:ok, %{__struct__: Finch.Response, status: status}} <- Finch.request(req, finch_name) do
      case status do
        s when s in [200, 403] -> :ok
        404 -> {:bucket_missing, 404}
        s -> {:unexpected_status, s}
      end
    else
      {:error, reason} -> {:probe_error, reason}
    end
  catch
    :exit, reason -> {:probe_error, {:exit, reason}}
  end

  # `:token` opt is a test-only seam (mirrors Plan 01 Client `:token` opt) so
  # Bypass-mocked unit tests do not have to round-trip through Google's real
  # OAuth endpoint with fake fixture credentials. Production callers do not
  # set `:token` and the Goth path runs.
  defp probe_token(goth_name, opts) do
    case Keyword.get(opts, :token) do
      token when is_binary(token) ->
        {:ok, token}

      _ ->
        case Goth.fetch(goth_name) do
          {:ok, %{__struct__: Goth.Token, token: token}} -> {:ok, token}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp check_gcs_signing_key(app_env) do
    if not Code.ensure_loaded?(GcsSignedUrl.Client) do
      error_result(
        "doctor.gcs_signing_key",
        :gcs,
        "GCS-enabled profile detected but :gcs_signed_url dep is not loaded.",
        @gcs_dep_missing_fix
      )
    else
      case app_env[:signing_key] do
        nil ->
          error_result(
            "doctor.gcs_signing_key",
            :gcs,
            "config :rindle, Rindle.Storage.GCS, signing_key: ... is not set.",
            @gcs_signing_key_fix
          )

        signing_key ->
          verify_gcs_signing_key(signing_key, app_env)
      end
    end
  end

  # Pattern mirrors verify_signing_key_pem/1 at lines 612-643 (Phase 36 WR-10
  # security parity): emit only inspect(exception.__struct__), NEVER
  # Exception.message/1 — so PEM body / JSON content never echo into doctor
  # output even on failure.
  defp verify_gcs_signing_key(%{"private_key" => _, "client_email" => _} = json_map, _app_env) do
    try do
      _client = GcsSignedUrl.Client.load(json_map)

      ok_result(
        "doctor.gcs_signing_key",
        :gcs,
        "GCS signing key parses as a valid service-account JSON map.",
        @gcs_signing_key_fix
      )
    rescue
      exception ->
        error_result(
          "doctor.gcs_signing_key",
          :gcs,
          "GCS signing_key parse raised: #{inspect(exception.__struct__)} (malformed service-account JSON).",
          @gcs_signing_key_fix
        )
    end
  end

  defp verify_gcs_signing_key(path, app_env) when is_binary(path) and byte_size(path) > 0 do
    cond do
      String.starts_with?(path, "-----BEGIN ") ->
        case app_env[:client_email] do
          client_email when is_binary(client_email) and client_email != "" ->
            ok_result(
              "doctor.gcs_signing_key",
              :gcs,
              "GCS signing key is a raw PEM string and client_email is configured separately.",
              @gcs_signing_key_fix
            )

          _missing ->
            error_result(
              "doctor.gcs_signing_key",
              :gcs,
              "GCS signing_key is a raw PEM string but config :rindle, Rindle.Storage.GCS, client_email: ... is not set.",
              @gcs_signing_key_fix
            )
        end

      true ->
        error_result(
          "doctor.gcs_signing_key",
          :gcs,
          "GCS signing_key is a non-PEM binary. Doctor and the signer accept only a decoded service-account JSON map, or a raw PEM string with client_email configured separately; file-path loading is not supported.",
          @gcs_signing_key_fix
        )
    end
  end

  # WARNING 5 fix — explicit is_map/1 guard. Map.get(other, :__struct__)
  # returns the struct module name for a struct map and nil for a bare map;
  # the `|| :map_without_struct` fallback handles bare maps cleanly. NO rescue
  # clause needed.
  defp verify_gcs_signing_key(other, _app_env) when is_map(other) do
    error_result(
      "doctor.gcs_signing_key",
      :gcs,
      "GCS signing_key has unexpected shape: #{inspect(Map.get(other, :__struct__) || :map_without_struct)}.",
      @gcs_signing_key_fix
    )
  end

  # WARNING 5 fix — plain catchall for non-map / non-binary inputs (nil,
  # integers, lists, tuples). NO rescue needed.
  defp verify_gcs_signing_key(_other, _app_env) do
    error_result(
      "doctor.gcs_signing_key",
      :gcs,
      "GCS signing_key has unexpected shape (not a map or binary).",
      @gcs_signing_key_fix
    )
  end

  defp check_gcs_resumable_cors(opts, app_env) do
    bucket = app_env[:bucket]
    finch_name = app_env[:finch]
    goth_name = app_env[:goth]

    cors_source =
      Keyword.get(opts, :gcs_bucket_cors) ||
        extract_bucket_cors(Keyword.get(opts, :gcs_bucket_metadata)) ||
        app_env[:bucket_cors] ||
        extract_bucket_cors(app_env[:bucket_metadata]) ||
        app_env[:cors]

    result =
      case cors_source do
        nil ->
          fetch_gcs_bucket_cors(bucket, finch_name, goth_name, app_env, opts)

        cors_rules ->
          {:ok, cors_rules}
      end

    build_gcs_resumable_cors_result(result)
  end

  defp build_gcs_resumable_cors_result({:ok, cors_rules}) do
    issues = gcs_resumable_cors_issues(cors_rules)

    if issues == [] do
      ok_result(
        "doctor.gcs_resumable_cors",
        :gcs,
        "Bucket CORS metadata includes app origins plus resumable browser requirements for `PUT`, `PATCH`, `Content-Range`, and `x-goog-resumable`.",
        @gcs_resumable_cors_fix
      )
    else
      warn_result(
        "doctor.gcs_resumable_cors",
        :gcs,
        "Bucket CORS metadata looks incomplete for browser resumable uploads: #{Enum.join(issues, "; ")}.",
        @gcs_resumable_cors_fix
      )
    end
  end

  defp build_gcs_resumable_cors_result({:error, reason}) do
    warn_result(
      "doctor.gcs_resumable_cors",
      :gcs,
      "Bucket CORS metadata could not be inspected automatically: #{format_gcs_cors_reason(reason)}.",
      @gcs_resumable_cors_fix
    )
  end

  defp fetch_gcs_bucket_cors(nil, _finch_name, _goth_name, _app_env, _opts),
    do: {:error, :bucket_not_configured}

  defp fetch_gcs_bucket_cors(bucket, finch_name, goth_name, app_env, opts) do
    cond do
      not Code.ensure_loaded?(Finch) ->
        {:error, :finch_unavailable}

      not Code.ensure_loaded?(Goth) ->
        {:error, :goth_unavailable}

      is_nil(finch_name) ->
        {:error, :finch_not_configured}

      is_nil(goth_name) ->
        {:error, :goth_not_configured}

      not Code.ensure_loaded?(Jason) ->
        {:error, :json_unavailable}

      true ->
        base_url =
          Keyword.get(opts, :gcs_bucket_base_url) || app_env[:base_url] ||
            "https://storage.googleapis.com"

        encoded_bucket = URI.encode(bucket)
        url = "#{base_url}/storage/v1/b/#{encoded_bucket}?fields=cors"

        with {:ok, token} <- probe_token(goth_name, opts),
             req = Finch.build(:get, url, [{"Authorization", "Bearer " <> token}]),
             {:ok, %{__struct__: Finch.Response, status: 200, body: body}} <-
               Finch.request(req, finch_name),
             {:ok, decoded} <- Jason.decode(body) do
          {:ok, extract_bucket_cors(decoded) || []}
        else
          {:ok, %{__struct__: Finch.Response, status: status}} when status in [403, 404] ->
            {:error, {:unexpected_status, status}}

          {:ok, %{__struct__: Finch.Response, status: status}} ->
            {:error, {:unexpected_status, status}}

          {:error, %Jason.DecodeError{} = error} ->
            {:error, {:decode_error, inspect(error.__struct__)}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp extract_bucket_cors(%{"cors" => cors}) when is_list(cors), do: cors
  defp extract_bucket_cors(%{cors: cors}) when is_list(cors), do: cors
  defp extract_bucket_cors(_other), do: nil

  defp gcs_resumable_cors_issues(cors_rules) when is_list(cors_rules) do
    rules =
      Enum.filter(cors_rules, fn
        rule when is_map(rule) -> true
        _other -> false
      end)

    []
    |> maybe_add_cors_issue(cors_origins_present?(rules), "missing app origins")
    |> maybe_add_cors_issue(
      cors_methods_present?(rules, ["put", "patch"]),
      "missing `PUT`/`PATCH`"
    )
    |> maybe_add_cors_issue(
      cors_headers_present?(rules, ["content-range", "x-goog-resumable"]),
      "missing `Content-Range`/`x-goog-resumable`"
    )
  end

  defp gcs_resumable_cors_issues(_other),
    do: ["bucket CORS metadata is not a list of rules"]

  defp maybe_add_cors_issue(issues, true, _message), do: issues
  defp maybe_add_cors_issue(issues, false, message), do: issues ++ [message]

  defp cors_origins_present?(rules) do
    Enum.any?(rules, fn rule ->
      rule
      |> cors_rule_values(["origin", :origin])
      |> Enum.any?(&(&1 != ""))
    end)
  end

  defp cors_methods_present?(rules, required) do
    Enum.any?(rules, fn rule ->
      values = cors_rule_values(rule, ["method", :method])
      wildcard_or_superset?(values, required)
    end)
  end

  defp cors_headers_present?(rules, required) do
    Enum.any?(rules, fn rule ->
      values = cors_rule_values(rule, ["responseHeader", :responseHeader, :response_header])
      wildcard_or_superset?(values, required)
    end)
  end

  defp wildcard_or_superset?(values, required) do
    normalized =
      values
      |> Enum.map(&String.downcase/1)
      |> MapSet.new()

    MapSet.member?(normalized, "*") or
      Enum.all?(required, &MapSet.member?(normalized, &1))
  end

  defp cors_rule_values(rule, keys) do
    keys
    |> Enum.flat_map(fn key ->
      case Map.get(rule, key) do
        values when is_list(values) -> values
        value when is_binary(value) -> [value]
        _other -> []
      end
    end)
    |> Enum.map(&String.trim/1)
  end

  defp format_gcs_cors_reason({:unexpected_status, status}),
    do: "GCS bucket metadata returned status #{status}"

  defp format_gcs_cors_reason({:decode_error, detail}),
    do: "GCS bucket metadata returned unreadable JSON (#{detail})"

  defp format_gcs_cors_reason({:exit, reason}),
    do: "bucket metadata request exited: #{inspect(reason)}"

  defp format_gcs_cors_reason(reason), do: inspect(reason)

  defp ok_result(id, component, summary, fix) do
    {:runtime_check, :ok, id, component, summary, fix, %{}}
  end

  defp warn_result(id, component, summary, fix) do
    {:runtime_check, :warn, id, component, summary, fix, %{}}
  end

  defp error_result(id, component, summary, fix) do
    {:runtime_check, :error, id, component, summary, fix, %{}}
  end
end
