defmodule Rindle.Ops.RuntimeChecks.IntegrationChecks do
  @moduledoc false

  @doc false
  def schedule(profiles, env, opts, checks) do
    gcs_profiles = checks.gcs_profiles.(profiles)

    gcs_checks =
      if gcs_profiles == [] do
        []
      else
        base_checks = [
          fn -> checks.gcs_goth_running.(profiles, env) end,
          fn -> checks.gcs_bucket_reachable.(profiles, env) end,
          fn -> checks.gcs_signing_key.(profiles, env) end
        ]

        if checks.resumable_gcs_profiles.(profiles) == [] do
          base_checks
        else
          base_checks ++ [fn -> checks.gcs_resumable_cors.(profiles, opts) end]
        end
      end

    tus_checks =
      if checks.tus_profiles.(profiles) == [] do
        []
      else
        [fn -> checks.tus_capability.(profiles) end]
      end

    [
      fn -> checks.streaming_credentials.(profiles, env) end,
      fn -> checks.streaming_signing_key.(profiles, env) end,
      fn -> checks.streaming_webhook_secrets.(profiles, env) end,
      fn -> checks.streaming_smoke_ping.(profiles, env, opts) end
    ] ++ gcs_checks ++ tus_checks
  end
end
