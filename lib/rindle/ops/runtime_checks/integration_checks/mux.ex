defmodule Rindle.Ops.RuntimeChecks.IntegrationChecks.Mux do
  @moduledoc false

  alias Mux.Video.Assets, as: MuxAssets

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

  @doc false
  def schedule(streaming_profiles, env, opts, config_reader) do
    [
      fn -> check_streaming_credentials(streaming_profiles, env) end,
      fn -> check_streaming_signing_key(streaming_profiles, env) end,
      fn -> check_streaming_webhook_secrets(streaming_profiles, env) end,
      fn -> check_streaming_smoke_ping(streaming_profiles, env, opts, config_reader) end
    ]
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

  # JOSE.JWK.from_pem/1 returns `[]` rather than raising for some malformed PEM,
  # so success requires the concrete JWK struct. Rescue remains defensive against
  # parser behavior changing in a future JOSE release.
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
      # Surface the exception class, never the message: the message could echo
      # PEM content. The struct name is non-sensitive
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
    if streaming_profiles == [] do
      ok_result(
        "doctor.streaming_webhook_secrets",
        :streaming,
        "No streaming-enabled profiles discovered.",
        @streaming_webhook_secrets_fix
      )
    else
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

  # Task shutdown supplies a hard wall-clock ceiling while preserving Mux's
  # response shape for the result classifier.
  defp run_smoke_ping_with_timeout(mux_config_reader) do
    task = Task.async(fn -> perform_smoke_ping(mux_config_reader) end)
    task |> await_smoke_ping() |> smoke_ping_result()
  end

  defp perform_smoke_ping(config_reader) do
    config = config_reader.()
    token_id = Keyword.get(config, :token_id)
    token_secret = Keyword.get(config, :token_secret)

    if is_binary(token_id) and is_binary(token_secret) do
      token_id |> Mux.Base.new(token_secret) |> MuxAssets.list(%{limit: 1})
    else
      {:error, :no_credentials}
    end
  rescue
    exception -> {:rescue, exception}
  catch
    kind, reason -> {:catch, kind, reason}
  end

  defp await_smoke_ping(task),
    do: Task.yield(task, 5_000) || Task.shutdown(task, :brutal_kill)

  defp smoke_ping_result({:ok, {:ok, _list, _env}}) do
    ok_result(
      "doctor.streaming_smoke_ping",
      :streaming,
      "Mux.Video.Assets.list/1 returned 200 (smoke ping OK).",
      @streaming_smoke_ping_fix
    )
  end

  defp smoke_ping_result({:ok, {:error, _message, %{status: status}}})
       when status in [401, 403] do
    error_result(
      "doctor.streaming_smoke_ping",
      :streaming,
      "Mux smoke ping returned #{status}.",
      "Verify RINDLE_MUX_TOKEN_ID and RINDLE_MUX_TOKEN_SECRET in your runtime config."
    )
  end

  defp smoke_ping_result({:ok, {:error, _message, %{status: 429}}}) do
    error_result(
      "doctor.streaming_smoke_ping",
      :streaming,
      "Mux smoke ping returned 429.",
      "Mux rate-limited the smoke ping; retry in a few seconds."
    )
  end

  defp smoke_ping_result({:ok, {:error, _message, %{status: status}}}) do
    error_result(
      "doctor.streaming_smoke_ping",
      :streaming,
      "Mux smoke ping returned status #{status}.",
      @streaming_smoke_ping_fix
    )
  end

  defp smoke_ping_result({:ok, {:error, :no_credentials}}) do
    error_result(
      "doctor.streaming_smoke_ping",
      :streaming,
      "Mux smoke ping skipped: RINDLE_MUX_TOKEN_ID / RINDLE_MUX_TOKEN_SECRET are not configured.",
      @streaming_credentials_fix
    )
  end

  defp smoke_ping_result(nil) do
    error_result(
      "doctor.streaming_smoke_ping",
      :streaming,
      "Mux smoke ping timed out after 5s.",
      "Could not reach api.mux.com within 5s; check network / proxy / DNS."
    )
  end

  defp smoke_ping_result({:ok, _other}) do
    error_result(
      "doctor.streaming_smoke_ping",
      :streaming,
      "Mux smoke ping returned an unexpected shape.",
      @streaming_smoke_ping_fix
    )
  end

  defp ok_result(id, component, summary, fix),
    do: {:runtime_check, :ok, id, component, summary, fix, %{}}

  defp error_result(id, component, summary, fix),
    do: {:runtime_check, :error, id, component, summary, fix, %{}}
end
