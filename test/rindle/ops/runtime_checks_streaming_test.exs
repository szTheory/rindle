defmodule Rindle.Ops.RuntimeChecksStreamingTest do
  use ExUnit.Case, async: true

  alias Rindle.Ops.RuntimeChecks

  defmodule ImageProfile do
    @moduledoc false

    use Rindle.Profile,
      storage: Rindle.Storage.S3,
      variants: [thumb: [mode: :fit, width: 64, height: 64]]
  end

  defmodule MuxStreamingProfile do
    @moduledoc false

    use Rindle.Profile.Presets.MuxWeb,
      storage: Rindle.Storage.S3,
      allow_mime: ["video/mp4"],
      max_bytes: 100_000_000
  end

  @valid_pem File.read!("test/fixtures/mux/test_signing_private_key.pem")
  @malformed_pem "-----BEGIN RSA PRIVATE KEY-----\nGARBAGE\n-----END RSA PRIVATE KEY-----\n"
  @full_env %{
    "RINDLE_MUX_TOKEN_ID" => "tk_xxx",
    "RINDLE_MUX_TOKEN_SECRET" => "sk_xxx",
    "RINDLE_MUX_SIGNING_KEY_ID" => "skid_xxx",
    "RINDLE_MUX_SIGNING_PRIVATE_KEY" => @valid_pem,
    "RINDLE_MUX_WEBHOOK_SECRETS" =>
      "whsec_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  defp run(opts) do
    opts =
      Keyword.merge(
        [
          probe: fn -> :ok end,
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1,
              rindle_media: 1
            ]
          ],
          migration_statuses: [],
          local_playback_route: [
            base_url: "http://example.test/rindle/local",
            secret_key_base: "secret"
          ]
        ],
        opts
      )

    RuntimeChecks.run([], opts)
  end

  defp fetch(report, id), do: Enum.find(report.checks, &(&1.id == id))

  describe "profile-discovery gate (D-06)" do
    test "all four streaming checks return vacuous-OK when no streaming-enabled profile exists" do
      report = run(profiles: [ImageProfile], env: %{})

      for id <- ~w(doctor.streaming_credentials doctor.streaming_signing_key
                   doctor.streaming_webhook_secrets doctor.streaming_smoke_ping) do
        check = fetch(report, id)
        assert check, "expected check #{id} to be present"
        assert check.status == :ok, "#{id} expected :ok, got #{inspect(check)}"
        assert check.summary == "No streaming-enabled profiles discovered."
        assert check.component == :streaming
      end
    end
  end

  describe "doctor.streaming_credentials" do
    test "PASS when all five RINDLE_MUX_* env vars set" do
      report = run(profiles: [MuxStreamingProfile], env: @full_env)
      check = fetch(report, "doctor.streaming_credentials")
      assert check.status == :ok
      assert check.component == :streaming
    end

    test "FAIL listing missing names when one var is missing" do
      env = Map.delete(@full_env, "RINDLE_MUX_TOKEN_ID")
      report = run(profiles: [MuxStreamingProfile], env: env)
      check = fetch(report, "doctor.streaming_credentials")
      assert check.status == :error
      assert check.summary =~ "RINDLE_MUX_TOKEN_ID"
      # Security V7: never echo values
      refute check.summary =~ env["RINDLE_MUX_TOKEN_SECRET"]
    end

    test "FAIL when var is empty string" do
      env = Map.put(@full_env, "RINDLE_MUX_WEBHOOK_SECRETS", "")
      report = run(profiles: [MuxStreamingProfile], env: env)
      check = fetch(report, "doctor.streaming_credentials")
      assert check.status == :error
      assert check.summary =~ "RINDLE_MUX_WEBHOOK_SECRETS"
    end
  end

  describe "doctor.streaming_signing_key (Pitfall 1)" do
    test "PASS on valid fixture PEM" do
      report = run(profiles: [MuxStreamingProfile], env: @full_env)
      check = fetch(report, "doctor.streaming_signing_key")
      assert check.status == :ok
    end

    test "FAIL on malformed PEM (JOSE.JWK.from_pem returns [] — must NOT silent-pass)" do
      env = Map.put(@full_env, "RINDLE_MUX_SIGNING_PRIVATE_KEY", @malformed_pem)
      report = run(profiles: [MuxStreamingProfile], env: env)
      check = fetch(report, "doctor.streaming_signing_key")
      assert check.status == :error
      assert check.summary =~ "malformed"
    end

    test "FAIL on empty PEM" do
      env = Map.put(@full_env, "RINDLE_MUX_SIGNING_PRIVATE_KEY", "")
      report = run(profiles: [MuxStreamingProfile], env: env)
      check = fetch(report, "doctor.streaming_signing_key")
      assert check.status == :error
    end
  end

  describe "doctor.streaming_webhook_secrets" do
    test "PASS when comma-list parses to >= 32-char secrets" do
      env =
        Map.put(
          @full_env,
          "RINDLE_MUX_WEBHOOK_SECRETS",
          "whsec_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,whsec_other_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        )

      report = run(profiles: [MuxStreamingProfile], env: env)
      check = fetch(report, "doctor.streaming_webhook_secrets")
      assert check.status == :ok
      assert check.summary =~ "2 secret"
    end

    test "FAIL on too-short secret" do
      env = Map.put(@full_env, "RINDLE_MUX_WEBHOOK_SECRETS", "tooshort")
      report = run(profiles: [MuxStreamingProfile], env: env)
      check = fetch(report, "doctor.streaming_webhook_secrets")
      assert check.status == :error
      assert check.summary =~ "32-character"
    end

    test "FAIL on empty list" do
      env = Map.put(@full_env, "RINDLE_MUX_WEBHOOK_SECRETS", "")
      report = run(profiles: [MuxStreamingProfile], env: env)
      check = fetch(report, "doctor.streaming_webhook_secrets")
      assert check.status == :error
    end
  end

  describe "doctor.streaming_smoke_ping flag-gate (D-07)" do
    test "skipped without --streaming flag" do
      report = run(profiles: [MuxStreamingProfile], env: @full_env, streaming: false)
      check = fetch(report, "doctor.streaming_smoke_ping")
      assert check.status == :ok
      assert check.summary =~ "Smoke ping skipped"
      assert check.summary =~ "--streaming"
    end

    test "absent flag also skips (default false)" do
      report = run(profiles: [MuxStreamingProfile], env: @full_env)
      check = fetch(report, "doctor.streaming_smoke_ping")
      assert check.status == :ok
      assert check.summary =~ "Smoke ping skipped"
    end
  end
end
