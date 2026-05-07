defmodule Rindle.Ops.RuntimeChecksTest do
  use ExUnit.Case, async: true

  alias Rindle.Ops.RuntimeChecks
  alias Rindle.Storage.Local

  defmodule ImageProfile do
    use Rindle.Profile,
      storage: Rindle.Storage.S3,
      variants: [thumb: [mode: :fit, width: 64, height: 64]]
  end

  defmodule VideoProfile do
    use Rindle.Profile.Presets.Web,
      storage: Rindle.Storage.S3,
      allow_mime: ["video/mp4"],
      max_bytes: 10_000_000
  end

  defmodule PrivateLocalImageProfile do
    use Rindle.Profile,
      storage: Local,
      variants: [thumb: [mode: :fit, width: 64, height: 64]]
  end

  defmodule PublicLocalVideoProfile do
    use Rindle.Profile,
      storage: Local,
      delivery: [public: true],
      variants: [web: [kind: :video, preset: :web_720p]]
  end

  describe "run/2" do
    test "returns deterministic stable check ids" do
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [ImageProfile, VideoProfile],
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
          local_playback_route: [base_url: "http://example.test/rindle/local", secret_key_base: "secret"]
        )

      assert Enum.map(report.checks, & &1.id) == [
               "doctor.delivery_support",
               "doctor.ffmpeg_runtime",
               "doctor.local_playback",
               "doctor.migrations.pending",
               "doctor.migrations.unresolved",
               "doctor.oban_default_instance",
               "doctor.oban_required_queues",
               "doctor.profile_runtime_fit",
               "doctor.streaming_credentials",
               "doctor.streaming_signing_key",
               "doctor.streaming_smoke_ping",
               "doctor.streaming_webhook_secrets"
             ]

      assert report.success?
      assert report.failed == 0
    end

    test "does not require rindle_media for image-only profiles" do
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [ImageProfile],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: []
        )

      assert report.success?

      queues_check = fetch_check(report, "doctor.oban_required_queues")
      assert queues_check.status == :ok
      refute queues_check.summary =~ "rindle_media"
    end

    test "requires rindle_media when AV-capable profiles are present" do
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [VideoProfile],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: []
        )

      refute report.success?

      queues_check = fetch_check(report, "doctor.oban_required_queues")
      assert queues_check.status == :error
      assert queues_check.summary =~ "rindle_media"
      assert queues_check.fix =~ "config"
    end

    test "flags private delivery on adapters without signed_url support" do
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [PrivateLocalImageProfile],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: []
        )

      check = fetch_check(report, "doctor.delivery_support")
      assert check.status == :error
      assert check.summary =~ "PrivateLocalImageProfile"
      assert check.fix =~ "signed_url"
    end

    test "flags local playback route drift only for local AV profiles" do
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [PublicLocalVideoProfile],
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
          local_playback_route: nil
        )

      check = fetch_check(report, "doctor.local_playback")
      assert check.status == :error
      assert check.summary =~ "PublicLocalVideoProfile"
      assert check.fix =~ "local_playback_route"
      assert check.fix =~ "Rindle.Delivery.LocalPlug"
    end

    test "distinguishes pending and unresolved migration drift" do
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: [
            {:down, 20_260_502_120_000, "extend_media_for_av.exs"},
            {:up, 20_260_425_090_000, "** FILE NOT FOUND **"}
          ]
        )

      pending = fetch_check(report, "doctor.migrations.pending")
      unresolved = fetch_check(report, "doctor.migrations.unresolved")

      assert pending.status == :error
      assert pending.summary =~ "20260502120000"
      assert pending.fix =~ "mix ecto.migrate"

      assert unresolved.status == :error
      assert unresolved.summary =~ "20260425090000"
      assert unresolved.fix =~ "missing from local code"
    end
  end

  describe "GCS doctor checks (Phase 37 / D-13)" do
    defmodule LocalProfile do
      use Rindle.Profile,
        storage: Rindle.Storage.Local,
        variants: [thumb: [mode: :fit, width: 32]]
    end

    defmodule GCSProfile do
      use Rindle.Profile,
        storage: Rindle.Storage.GCS,
        variants: [thumb: [mode: :fit, width: 32]]
    end

    # WARNING 3 / D-13 LOCK: image-only adopters see ZERO gcs_* rows.
    # The check fn-refs are appended at the splice point ONLY when
    # gcs_profiles(profiles) != []. NOT three silent-OK rows — literal absence.
    test "S3-only adopter sees zero gcs_ rows in doctor.checks" do
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [LocalProfile],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: []
        )

      gcs_rows = Enum.filter(report.checks, &String.starts_with?(&1.id, "doctor.gcs_"))

      assert gcs_rows == [],
             "Expected zero gcs_* rows for S3-only adopters (D-13 lock); got: #{inspect(gcs_rows)}"
    end

    test "S3-only adopter mixed with non-storage profiles: still zero gcs_ rows" do
      # Defensive — confirms `Rindle.Capability.configured_gcs_profiles/1` filters
      # the LocalProfile out before fn-refs splice in.
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [LocalProfile],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: []
        )

      refute Enum.any?(report.checks, &(&1.component == :gcs))
    end

    test "GCS profile present: three gcs_ rows are emitted (one per check)" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)
      Application.put_env(:rindle, Rindle.Storage.GCS, [])

      try do
        report =
          RuntimeChecks.run([],
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
            oban_config: [
              repo: Rindle.Repo,
              queues: [
                rindle_promote: 1,
                rindle_process: 1,
                rindle_purge: 1,
                rindle_maintenance: 1
              ]
            ],
            migration_statuses: []
          )

        ids =
          report.checks
          |> Enum.filter(&String.starts_with?(&1.id, "doctor.gcs_"))
          |> Enum.map(& &1.id)
          |> Enum.sort()

        assert ids == [
                 "doctor.gcs_bucket_reachable",
                 "doctor.gcs_goth_running",
                 "doctor.gcs_signing_key"
               ]
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_goth_running: error when GCS profile exists and named Goth instance is not started" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        goth: :rindle_doctor_test_unstarted_goth,
        signing_key: %{"private_key" => "x", "client_email" => "x@y"}
      )

      try do
        report =
          RuntimeChecks.run([],
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
            oban_config: [
              repo: Rindle.Repo,
              queues: [
                rindle_promote: 1,
                rindle_process: 1,
                rindle_purge: 1,
                rindle_maintenance: 1
              ]
            ],
            migration_statuses: []
          )

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_goth_running"))
        assert check.status == :error
        assert check.component == :gcs
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_bucket_reachable: error when GCS profile exists but no bucket is configured" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)
      Application.put_env(:rindle, Rindle.Storage.GCS, [])

      try do
        report =
          RuntimeChecks.run([],
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
            oban_config: [
              repo: Rindle.Repo,
              queues: [
                rindle_promote: 1,
                rindle_process: 1,
                rindle_purge: 1,
                rindle_maintenance: 1
              ]
            ],
            migration_statuses: []
          )

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_bucket_reachable"))
        assert check.status == :error
        assert check.component == :gcs
        assert check.summary =~ ~r/bucket/i
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_bucket_reachable: error_result with precondition_missing when Finch is not configured (HONEST about why no probe ran)" do
      # BLOCKER 2 / D-13 LOCK: when preconditions are missing, doctor MUST surface
      # an error_result naming the missing precondition — NOT a silent OK that masks
      # the fact that no probe actually ran. The fix message should be actionable
      # ("start `MyApp.Finch` and `MyApp.Goth` in your supervision tree").
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket"
        # Note: no :finch and no :goth keys — preconditions missing
      )

      try do
        report =
          RuntimeChecks.run([],
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
            oban_config: [
              repo: Rindle.Repo,
              queues: [
                rindle_promote: 1,
                rindle_process: 1,
                rindle_purge: 1,
                rindle_maintenance: 1
              ]
            ],
            migration_statuses: []
          )

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_bucket_reachable"))
        assert check.status == :error
        assert check.component == :gcs

        # Honest about WHY no probe ran:
        assert check.summary =~ ~r/finch|goth|supervision tree|not configured/i,
               "Expected fix-oriented summary about missing Finch/Goth precondition; got: #{inspect(check.summary)}"

        # Security parity:
        refute check.summary =~ ~r/Bearer ey/
        refute check.summary =~ ~r/-----BEGIN/
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_signing_key: error when signing key is malformed; summary echoes only the exception struct name (security parity with Phase 36 WR-10)" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        signing_key: "not-a-valid-key-or-path"
      )

      try do
        report =
          RuntimeChecks.run([],
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
            oban_config: [
              repo: Rindle.Repo,
              queues: [
                rindle_promote: 1,
                rindle_process: 1,
                rindle_purge: 1,
                rindle_maintenance: 1
              ]
            ],
            migration_statuses: []
          )

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_signing_key"))
        assert check.status == :error
        assert check.component == :gcs

        # Security parity with Phase 36 WR-10: only inspect the exception STRUCT NAME,
        # never echo PEM body or JSON content into doctor output.
        refute check.summary =~ ~r/-----BEGIN/
        refute check.summary =~ ~r/private_key/
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_signing_key: ok when signing key is a valid decoded JSON map" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        signing_key: Rindle.Storage.GCS.SigningKeyFixture.fixture_json()
      )

      try do
        report =
          RuntimeChecks.run([],
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
            oban_config: [
              repo: Rindle.Repo,
              queues: [
                rindle_promote: 1,
                rindle_process: 1,
                rindle_purge: 1,
                rindle_maintenance: 1
              ]
            ],
            migration_statuses: []
          )

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_signing_key"))
        assert check.status == :ok
        assert check.component == :gcs
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end
  end

  # BLOCKER 2 — Bypass-mocked unit tests for `do_probe/4` covering all 5 return
  # shapes. These tests exercise the probe directly without going through run/2,
  # mocking the GCS JSON API endpoint with Bypass and substituting the
  # Goth.fetch/1 source via a per-test Goth instance using a fresh fixture.
  describe "probe_gcs_bucket/4 + do_probe/4 (Bypass-mocked HTTP probe — BLOCKER 2 D-13 lock)" do
    alias Rindle.Storage.GCS.SigningKeyFixture

    defmodule GCSProbeProfile do
      use Rindle.Profile,
        storage: Rindle.Storage.GCS,
        variants: [thumb: [mode: :fit, width: 32]]
    end

    setup do
      bypass = Bypass.open()
      finch_name = :"rindle_probe_test_finch_#{System.unique_integer([:positive])}"
      {:ok, _} = Finch.start_link(name: finch_name)

      goth_name = :"rindle_probe_test_goth_#{System.unique_integer([:positive])}"
      fake_creds = SigningKeyFixture.fixture_json()
      {:ok, _} = Goth.start_link(name: goth_name, source: {:service_account, fake_creds, []})

      base_url = "http://localhost:#{bypass.port}"

      {:ok, bypass: bypass, finch_name: finch_name, goth_name: goth_name, base_url: base_url}
    end

    test "200 → :ok", %{bypass: bypass, finch_name: f, goth_name: g, base_url: u} do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"name":"my-bucket"}))
      end)

      assert RuntimeChecks.do_probe("my-bucket", f, g, base_url: u) == :ok
    end

    test "403 → :ok (bucket exists; ACL-restricted; name resolution healthy per RESEARCH §7)",
         %{bypass: bypass, finch_name: f, goth_name: g, base_url: u} do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        Plug.Conn.resp(conn, 403, ~s({"error":{"code":403,"message":"Forbidden"}}))
      end)

      assert RuntimeChecks.do_probe("my-bucket", f, g, base_url: u) == :ok
    end

    test "404 → {:bucket_missing, 404}", %{
      bypass: bypass,
      finch_name: f,
      goth_name: g,
      base_url: u
    } do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        Plug.Conn.resp(conn, 404, ~s({"error":{"code":404,"message":"Not Found"}}))
      end)

      assert RuntimeChecks.do_probe("my-bucket", f, g, base_url: u) ==
               {:bucket_missing, 404}
    end

    test "500 → {:unexpected_status, 500}",
         %{bypass: bypass, finch_name: f, goth_name: g, base_url: u} do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        Plug.Conn.resp(conn, 500, "Internal Server Error")
      end)

      assert RuntimeChecks.do_probe("my-bucket", f, g, base_url: u) ==
               {:unexpected_status, 500}
    end

    test "Bypass.down → {:probe_error, _}", %{
      bypass: bypass,
      finch_name: f,
      goth_name: g,
      base_url: u
    } do
      Bypass.down(bypass)

      assert {:probe_error, _reason} =
               RuntimeChecks.do_probe("my-bucket", f, g, base_url: u)
    end

    test "precondition: nil finch_name → {:precondition_missing, :finch_not_configured}",
         %{goth_name: g} do
      assert RuntimeChecks.probe_gcs_bucket("my-bucket", nil, g) ==
               {:precondition_missing, :finch_not_configured}
    end

    test "precondition: nil goth_name → {:precondition_missing, :goth_not_configured}",
         %{finch_name: f} do
      assert RuntimeChecks.probe_gcs_bucket("my-bucket", f, nil) ==
               {:precondition_missing, :goth_not_configured}
    end

    # Security invariants — apply across all error-path return shapes that surface
    # through error_result/4. Verified at the doctor-row level (NOT do_probe/4
    # directly) because do_probe/4 returns raw tuples; error_result/4 stringifies
    # them via inspect/1.
    test "doctor row: probe error_result NEVER echoes bearer token (security invariant)",
         %{bypass: bypass, finch_name: f, goth_name: g, base_url: u} do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        # Server replies with body that includes a bogus bearer-shaped string —
        # the probe MUST NOT include the body in the error tuple, only the status.
        Plug.Conn.resp(conn, 500, ~s({"error":"Bearer eyJleavAk-this-must-not-leak"}))
      end)

      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        finch: f,
        goth: g,
        base_url: u
      )

      try do
        report =
          RuntimeChecks.run([],
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProbeProfile],
            oban_config: [
              repo: Rindle.Repo,
              queues: [
                rindle_promote: 1,
                rindle_process: 1,
                rindle_purge: 1,
                rindle_maintenance: 1
              ]
            ],
            migration_statuses: []
          )

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_bucket_reachable"))
        assert check.status == :error

        refute check.summary =~ ~r/Bearer ey/,
               "Bearer token leaked into doctor summary: #{inspect(check.summary)}"

        refute check.summary =~ ~r/-----BEGIN/
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end
  end

  defp fetch_check(report, id) do
    Enum.find(report.checks, &(&1.id == id)) ||
      flunk("expected check #{inspect(id)} to be present")
  end
end
