defmodule Rindle.Ops.RuntimeChecks.GCSTest do
  use ExUnit.Case, async: false

  alias Rindle.Ops.RuntimeChecks
  alias Rindle.Ops.RuntimeChecks.IntegrationChecks.GCS, as: GCSChecks
  alias Rindle.Storage.GCS.SigningKeyFixture

  @rindle_tables ~w(
    media_assets
    media_attachments
    media_variants
    media_upload_sessions
    media_processing_runs
    media_provider_assets
  )

  describe "GCS configuration and doctor checks" do
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

    # Image-only adopters see no GCS rows; absence is different from silent success.
    # The check fn-refs are appended at the splice point ONLY when
    # gcs_profiles(profiles) != []. NOT three silent-OK rows — literal absence.
    test "S3-only adopter sees zero gcs_ rows in doctor.checks" do
      report =
        run_runtime_checks(
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
             "expected no gcs_* rows for S3-only adopters; got: #{inspect(gcs_rows)}"
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

    test "a non-resumable adapter schedules only the three base GCS diagnostics" do
      ids =
        [LocalProfile]
        |> GCSChecks.schedule([], fn -> [] end)
        |> Enum.map(fn check -> check.() |> elem(2) end)

      assert ids == [
               "doctor.gcs_goth_running",
               "doctor.gcs_bucket_reachable",
               "doctor.gcs_signing_key"
             ]
    end

    test "GCS profile present: four gcs_ rows are emitted (one per check)" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)
      Application.put_env(:rindle, Rindle.Storage.GCS, [])

      try do
        report =
          run_runtime_checks(
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
                 "doctor.gcs_resumable_cors",
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
          run_runtime_checks(
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
          run_runtime_checks(
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
      # Missing preconditions must produce an explicit error rather than
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
          run_runtime_checks(
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

    test "check_gcs_signing_key: error when signing key is a non-PEM binary; summary does not echo secret material" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        signing_key: "not-a-valid-key-or-path"
      )

      try do
        report =
          run_runtime_checks(
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
        assert check.summary =~ "non-PEM binary"

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
        signing_key: SigningKeyFixture.fixture_json()
      )

      try do
        report =
          run_runtime_checks(
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

    test "check_gcs_signing_key: ok when signing key is a raw PEM string and client_email is configured" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        signing_key: SigningKeyFixture.fixture_pem(),
        client_email: SigningKeyFixture.fixture_client_email()
      )

      try do
        report =
          run_runtime_checks(
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
        assert check.summary =~ "raw PEM string"
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_signing_key: error when signing key is a raw PEM string without client_email" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        signing_key: SigningKeyFixture.fixture_pem()
      )

      try do
        report =
          run_runtime_checks(
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
        assert check.summary =~ "client_email"
        refute check.summary =~ ~r/-----BEGIN/
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_signing_key: error when signing key looks like a file path because file-path loading is unsupported" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        signing_key: "/path/to/service-account.json"
      )

      try do
        report =
          run_runtime_checks(
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
        assert check.summary =~ "file-path loading is not supported"
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_resumable_cors: absent when no resumable GCS profile exists" do
      report =
        run_runtime_checks(
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

      refute Enum.any?(report.checks, &(&1.id == "doctor.gcs_resumable_cors"))
    end

    test "check_gcs_resumable_cors: warns when bucket CORS shape is missing required resumable rules" do
      bypass = Bypass.open()
      finch_name = :"rindle_cors_warn_finch_#{System.unique_integer([:positive])}"
      goth_name = :"rindle_cors_warn_goth_#{System.unique_integer([:positive])}"
      {:ok, _} = Finch.start_link(name: finch_name)

      {:ok, _} =
        Goth.start_link(
          name: goth_name,
          source: gcs_fixture_goth_source("http://localhost:#{bypass.port}/token")
        )

      Bypass.stub(bypass, "POST", "/token", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          ~s({"access_token":"test-token","token_type":"Bearer","expires_in":3600})
        )
      end)

      Bypass.stub(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        body =
          case conn.query_string do
            "fields=cors" ->
              ~s({"cors":[{"origin":["https://app.example.test"],"method":["GET"],"responseHeader":["Content-Type"]}]})

            _ ->
              ~s({"name":"my-bucket"})
          end

        Plug.Conn.resp(conn, 200, body)
      end)

      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        finch: finch_name,
        goth: goth_name,
        base_url: "http://localhost:#{bypass.port}",
        signing_key: SigningKeyFixture.fixture_json()
      )

      try do
        report =
          run_runtime_checks(
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

        check = fetch_check(report, "doctor.gcs_resumable_cors")
        assert check.status == :warn
        assert check.summary =~ "missing `PUT`/`PATCH`"
        assert check.summary =~ "missing `Content-Range`/`x-goog-resumable`"
        assert check.fix =~ "app origins"
        assert check.fix =~ "PUT"
        assert check.fix =~ "PATCH"
        assert check.fix =~ "Content-Range"
        assert check.fix =~ "x-goog-resumable"
        assert check.fix =~ "session_uri"
        assert check.fix =~ "one week"
        assert check.fix =~ "region pinning"
        assert report.failed == 0
        assert report.success?
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "warnings do not increment failure count, but errors still do" do
      report =
        run_runtime_checks(
          probe: fn -> raise RuntimeError, "ffmpeg missing" end,
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
          migration_statuses: [],
          gcs_bucket_cors: [
            %{
              "origin" => ["https://app.example.test"],
              "method" => ["PUT"],
              "responseHeader" => ["x-goog-resumable"]
            }
          ]
        )

      assert fetch_check(report, "doctor.gcs_resumable_cors").status == :warn
      assert report.failed == Enum.count(report.checks, &(&1.status == :error))
      assert report.failed > 0
      refute report.success?
    end
  end

  # Bypass exercises every public probe result without contacting Google.
  # shapes. These tests exercise the probe directly without going through run/2,
  # mocking the GCS JSON API endpoint with Bypass and substituting the
  # Goth.fetch/1 source via a per-test Goth instance using a fresh fixture.
  describe "probe_gcs_bucket/4 and do_probe/4 HTTP behavior" do
    alias Rindle.Storage.GCS.SigningKeyFixture
    alias SigningKeyFixture

    defmodule GCSProbeProfile do
      use Rindle.Profile,
        storage: Rindle.Storage.GCS,
        variants: [thumb: [mode: :fit, width: 32]]
    end

    setup do
      bypass = Bypass.open()
      finch_name = :"rindle_probe_test_finch_#{System.unique_integer([:positive])}"
      {:ok, _} = Finch.start_link(name: finch_name)

      # `:token` opt is the test-only seam — Bypass-mocked unit tests cannot
      # round-trip through Google's real OAuth endpoint to exchange a fake
      # service-account JWT for a token, so we inject a fixed bearer instead.
      # `goth_name` is still passed through for the precondition-presence check
      # in probe_gcs_bucket/4 (nil goth_name → {:precondition_missing, ...}).
      goth_name = :rindle_probe_test_fake_goth_name

      base_url = "http://localhost:#{bypass.port}"
      fake_token = "test-bearer-token-#{System.unique_integer([:positive])}"

      _ = SigningKeyFixture

      {:ok,
       bypass: bypass,
       finch_name: finch_name,
       goth_name: goth_name,
       base_url: base_url,
       token: fake_token}
    end

    test "200 → :ok", %{bypass: bypass, finch_name: f, goth_name: g, base_url: u, token: t} do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"name":"my-bucket"}))
      end)

      assert RuntimeChecks.do_probe("my-bucket", f, g, base_url: u, token: t) == :ok
    end

    test "403 → :ok because an ACL-restricted response still proves the bucket exists",
         %{bypass: bypass, finch_name: f, goth_name: g, base_url: u, token: t} do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        Plug.Conn.resp(conn, 403, ~s({"error":{"code":403,"message":"Forbidden"}}))
      end)

      assert RuntimeChecks.do_probe("my-bucket", f, g, base_url: u, token: t) == :ok
    end

    test "404 → {:bucket_missing, 404}", %{
      bypass: bypass,
      finch_name: f,
      goth_name: g,
      base_url: u,
      token: t
    } do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        Plug.Conn.resp(conn, 404, ~s({"error":{"code":404,"message":"Not Found"}}))
      end)

      assert RuntimeChecks.do_probe("my-bucket", f, g, base_url: u, token: t) ==
               {:bucket_missing, 404}
    end

    test "500 → {:unexpected_status, 500}",
         %{bypass: bypass, finch_name: f, goth_name: g, base_url: u, token: t} do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        Plug.Conn.resp(conn, 500, "Internal Server Error")
      end)

      assert RuntimeChecks.do_probe("my-bucket", f, g, base_url: u, token: t) ==
               {:unexpected_status, 500}
    end

    test "Bypass.down → {:probe_error, _}", %{
      bypass: bypass,
      finch_name: f,
      goth_name: g,
      base_url: u,
      token: t
    } do
      Bypass.down(bypass)

      assert {:probe_error, _reason} =
               RuntimeChecks.do_probe("my-bucket", f, g, base_url: u, token: t)
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
         %{bypass: bypass, finch_name: f, goth_name: g, base_url: u, token: t} do
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
        base_url: u,
        token: t
      )

      try do
        report =
          run_runtime_checks(
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

  defp fresh_marker_catalog_fixture do
    %{
      marker_versions: [1],
      tables: @rindle_tables,
      legacy_packaged_install?: false,
      prefix: "public"
    }
  end

  defp fetch_check(report, id) do
    Enum.find(report.checks, &(&1.id == id)) ||
      flunk("expected check #{inspect(id)} to be present")
  end

  defp oban_jobs_ready_fixture do
    %{exists?: true, owner: :host, setup: "Oban.Migration"}
  end

  defp run_runtime_checks(opts) do
    RuntimeChecks.run(
      [],
      opts
      |> Keyword.put_new(:rindle_schema_catalog, fresh_marker_catalog_fixture())
      |> Keyword.put_new(:oban_jobs_catalog, oban_jobs_ready_fixture())
      |> Keyword.put_new(:resumable_session_schema_catalog, resumable_session_schema_fixture())
    )
  end

  defp resumable_session_schema_fixture do
    %{
      columns: %{
        "session_uri" => %{is_nullable: "YES", column_default: nil},
        "session_uri_expires_at" => %{is_nullable: "YES", column_default: nil},
        "last_known_offset" => %{is_nullable: "NO", column_default: "0"},
        "region_hint" => %{is_nullable: "YES", column_default: nil}
      },
      indexes: [
        "CREATE INDEX media_upload_sessions_resumable_expiry_idx ON public.media_upload_sessions USING btree (session_uri_expires_at) WHERE ((upload_strategy = 'resumable'::text))"
      ]
    }
  end

  defp gcs_fixture_goth_source(token_url) do
    {:service_account, SigningKeyFixture.fixture_json(), url: token_url}
  end
end
