defmodule Rindle.RuntimeStatusTaskTest do
  use Rindle.DataCase, async: false

  alias Mix.Tasks.Rindle.RuntimeStatus, as: RuntimeStatusTask
  alias Mix.Tasks.Rindle.RuntimeStatus.Formatter
  alias Rindle.Domain.{MediaAsset, MediaUploadSession, MediaVariant}

  @runtime_status_config Rindle.Ops.RuntimeStatus

  defmodule TaskProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [thumb: [mode: :fit, width: 32, height: 32]],
      allow_mime: ["image/png"],
      max_bytes: 10_485_760
  end

  setup do
    previous_shell = Mix.shell()
    previous_runtime_status_config = Application.get_env(:rindle, @runtime_status_config)
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(previous_shell)

      if previous_runtime_status_config do
        Application.put_env(:rindle, @runtime_status_config, previous_runtime_status_config)
      else
        Application.delete_env(:rindle, @runtime_status_config)
      end
    end)

    :ok
  end

  test "prints deterministic text output first with counts, findings, and done" do
    asset = insert_asset()
    _failed = insert_variant(asset, %{state: "failed", updated_at: age_ago(700)})

    RuntimeStatusTask.run(["--limit", "1"])

    assert_received {:mix_shell, :info, ["Rindle: runtime status report..."]}
    assert_received {:mix_shell, :info, ["Variants:"]}
    assert_received {:mix_shell, :info, ["Findings:"]}
    assert_received {:mix_shell, :info, ["Recommendations:"]}
    assert_received {:mix_shell, :info, ["Done."]}
  end

  test "emits JSON output when requested" do
    asset = insert_asset()
    _failed = insert_variant(asset, %{state: "failed", updated_at: age_ago(700)})
    _session = insert_resumable_session(asset)

    RuntimeStatusTask.run(["--format", "json", "--limit", "1"])

    assert_received {:mix_shell, :info, [output]}
    assert output =~ "\"variants\""
    assert output =~ "\"recommendations\""
    assert output =~ "\"failed_work\""
    assert output =~ "\"resumable_sessions_pending\""
    refute output =~ "\"session_uri\":"
    refute output =~ "secret.example"
  end

  test "exits non-zero on invalid format after surfacing the failure" do
    assert catch_exit(RuntimeStatusTask.run(["--format", "yaml"])) == {:shutdown, 1}

    assert_received {:mix_shell, :error, [message]}
    assert message =~ "Rindle.RuntimeStatus failed"
    assert message =~ "invalid_format"
  end

  test "exits non-zero with host-owned Oban.Migration copy when oban_jobs is missing" do
    put_setup_readiness(%{
      rindle_schema: %{ready?: true},
      oban_jobs: %{ready?: false, setup: "Oban.Migration"}
    })

    assert catch_exit(RuntimeStatusTask.run(["--limit", "1"])) == {:shutdown, 1}

    assert_received {:mix_shell, :error, [message]}
    assert message =~ "setup_incomplete"
    assert message =~ "oban_jobs"
    assert message =~ "mix rindle.doctor"
    assert message =~ "Oban.Migration"
    assert message =~ "Rindle no longer manages `oban_jobs`"
  end

  test "formats bounded snapshot refusals safely for text and JSON" do
    sentinel = "postgres://rindle:credential@db.example/Rindle SQL SELECT secret"

    for {reason, classification, component} <- [
          {{:rindle_prefix_mismatch,
            %{
              component: :rindle,
              expected_prefix: sentinel,
              observed_prefix: "public",
              owner: :rindle
            }}, "rindle_prefix_mismatch", "rindle"},
          {{:oban_binding_drift,
            %{
              component: :oban,
              expected_prefix: "host_oban",
              observed_prefix: sentinel,
              owner: :host
            }}, "oban_binding_drift", "oban"},
          {{:rindle_prefix_mismatch,
            %{
              component: :postgres_adapter,
              expected_prefix: "rindle",
              observed_prefix: "public",
              owner: :credential_owner
            }}, "rindle_prefix_mismatch", nil},
          {{:inspection_failed, %{component: :rindle, owner: :rindle}}, "inspection_failed",
           "rindle"}
        ] do
      text = RuntimeStatusTask.format_error(reason)
      json = RuntimeStatusTask.format_json_error(reason) |> Jason.encode!()

      assert text =~ "no report queries ran"
      assert text =~ "mix rindle.doctor"
      assert json =~ ~s("status":"error")
      assert json =~ ~s("classification":"#{classification}")
      if component, do: assert(json =~ ~s("component":"#{component}"))
      refute text =~ "postgres://"
      refute json =~ "postgres://"
      refute text =~ sentinel
      refute json =~ sentinel
      refute text =~ "credential_owner"
      refute json =~ "credential_owner"
    end
  end

  test "uses constant safe copy for unknown runtime errors" do
    sentinel = {:raw_adapter_failure, "postgres://user:credential@host SQL sentinel"}

    text = RuntimeStatusTask.format_error(sentinel)
    json = RuntimeStatusTask.format_json_error(sentinel) |> Jason.encode!()

    assert text =~ "mix rindle.doctor"
    assert text =~ "no report queries ran"
    assert json =~ ~s("classification":"unknown")
    refute text =~ "credential"
    refute json =~ "credential"
    refute text =~ "SQL sentinel"
    refute json =~ "SQL sentinel"
  end

  test "formatter preserves the task's bounded unknown-error copy" do
    sentinel = {:raw_adapter_failure, "postgres://user:credential@host SQL sentinel"}

    assert Formatter.format_error(sentinel) == RuntimeStatusTask.format_error(sentinel)
    assert Formatter.format_json_error(sentinel) == RuntimeStatusTask.format_json_error(sentinel)
  end

  test "emits a bounded JSON refusal and exits non-zero" do
    Application.put_env(:rindle, @runtime_status_config,
      ownership_snapshot: %{
        rindle: %{
          classification: :rindle_prefix_mismatch,
          expected_prefix: "postgres://rindle:credential@db.example/Rindle SQL SELECT secret",
          observed_prefix: "public",
          owner: :rindle
        },
        oban: %{
          classification: :ready,
          expected_prefix: "public",
          observed_prefix: "public",
          owner: :host
        }
      },
      report_query: fn _operation, _query, _prefix -> raise "REPORT_QUERY_REACHED" end
    )

    assert catch_exit(RuntimeStatusTask.run(["--format", "json"])) == {:shutdown, 1}

    assert_received {:mix_shell, :info, [output]}
    assert output =~ ~s("classification":"rindle_prefix_mismatch")
    assert output =~ ~s("expected_prefix":"unknown")
    refute output =~ "postgres://"
    refute output =~ "credential"
    refute output =~ "REPORT_QUERY_REACHED"
  end

  describe "--provider-stuck (MUX-14)" do
    test "the --provider-stuck flag is parsed and surfaces in filters" do
      RuntimeStatusTask.run(["--provider-stuck", "--limit", "1"])

      assert_received {:mix_shell, :info, ["Provider asset findings:"]}
    end

    test "format_provider_findings/1 with empty list returns 'none' line" do
      assert RuntimeStatusTask.format_provider_findings([]) == [
               "Provider asset findings:",
               "  none"
             ]
    end

    test "format_provider_findings/1 with one finding includes asset_id and redacted provider_asset_id" do
      findings = [build_provider_finding()]
      lines = RuntimeStatusTask.format_provider_findings(findings)

      assert "Provider asset findings:" in lines
      assert Enum.any?(lines, &(&1 =~ "provider_stuck: 1"))
      assert Enum.any?(lines, &(&1 =~ "(oldest_age_seconds=9000)"))

      assert Enum.any?(lines, fn line ->
               line =~ "11111111-2222-3333-4444-555555555555" and line =~ "(...dddd)"
             end)
    end

    test "format_text_report/1 includes the Provider asset findings: section" do
      report = build_report_with_provider_findings([build_provider_finding()])
      lines = RuntimeStatusTask.format_text_report(report)

      assert "Provider asset findings:" in lines
    end

    test "format_text_report/1 places provider findings AFTER upload_sessions and BEFORE recommendations" do
      report = build_report_with_provider_findings([build_provider_finding()])
      lines = RuntimeStatusTask.format_text_report(report)

      provider_idx = Enum.find_index(lines, &(&1 == "Provider asset findings:"))
      upload_idx = Enum.find_index(lines, &(&1 == "Upload session findings:"))
      rec_idx = Enum.find_index(lines, &(&1 == "Recommendations:"))

      assert is_integer(provider_idx)
      assert is_integer(upload_idx)
      assert is_integer(rec_idx)
      assert upload_idx < provider_idx
      assert provider_idx < rec_idx
    end

    test "format_text_report/1 renders resumable counters inside the Upload sessions section" do
      report = build_report_with_provider_findings([])
      lines = RuntimeStatusTask.format_text_report(report)

      upload_idx = Enum.find_index(lines, &(&1 == "Upload sessions:"))
      resumable_idx = Enum.find_index(lines, &(&1 =~ "resumable_sessions_pending: 2"))
      provider_idx = Enum.find_index(lines, &(&1 == "Provider asset findings:"))

      assert is_integer(upload_idx)
      assert is_integer(resumable_idx)
      assert is_integer(provider_idx)
      assert upload_idx < resumable_idx
      assert resumable_idx < provider_idx
    end

    test "redacted provider_asset_id appears in the rendered text output" do
      report = build_report_with_provider_findings([build_provider_finding()])
      lines = RuntimeStatusTask.format_text_report(report)

      assert Enum.any?(lines, &(&1 =~ ~r/\(\.\.\.dddd\)/))
    end
  end

  defp build_provider_finding do
    %{
      class: :provider_stuck,
      count: 1,
      oldest_age_seconds: 9000,
      samples: [
        %{
          asset_id: "11111111-2222-3333-4444-555555555555",
          provider_asset_id: "...dddd",
          profile: "MyApp.Profiles.Web",
          provider: "mux",
          state: "processing",
          updated_at: ~U[2026-05-06 00:00:00Z],
          last_event_at: nil,
          last_sync_error: "stuck waiting for ready signal",
          reason: "row stuck in processing for 9000s"
        }
      ]
    }
  end

  defp build_report_with_provider_findings(findings) do
    %{
      generated_at: ~U[2026-05-06 12:00:00Z],
      filters: %{
        profile: nil,
        older_than: nil,
        limit: 5,
        format: :text,
        provider_stuck: true
      },
      runtime_checks: %{counts: %{total: 0}, findings: []},
      assets: %{counts: %{total: 0}},
      variants: %{counts: %{total: 0}, findings: []},
      upload_sessions: %{
        counts: %{total: 0},
        findings: [],
        resumable: %{
          resumable_sessions_pending: 2,
          resumable_sessions_expired: 1,
          resumable_session_uris_stale: 1
        }
      },
      provider_assets: %{
        counts: %{total: 1, processing: 1},
        threshold_seconds: 7200,
        findings: findings
      },
      recommendations: []
    }
  end

  defp insert_asset do
    %MediaAsset{}
    |> MediaAsset.changeset(%{
      state: "available",
      profile: to_string(TaskProfile),
      storage_key: "assets/#{System.unique_integer([:positive])}.png",
      kind: "image",
      content_type: "image/png"
    })
    |> Rindle.Repo.insert!()
  end

  defp insert_variant(asset, attrs) do
    params =
      %{
        asset_id: asset.id,
        name: "thumb",
        state: "ready",
        recipe_digest: TaskProfile.recipe_digest(:thumb),
        output_kind: "image"
      }
      |> Map.merge(attrs)

    %MediaVariant{}
    |> MediaVariant.changeset(params)
    |> Rindle.Repo.insert!()
  end

  defp insert_resumable_session(asset) do
    %MediaUploadSession{}
    |> MediaUploadSession.changeset(%{
      asset_id: asset.id,
      state: "signed",
      upload_key: "uploads/#{System.unique_integer([:positive])}.bin",
      upload_strategy: "resumable",
      session_uri: "https://secret.example/runtime-status-session",
      session_uri_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    })
    |> Rindle.Repo.insert!()
  end

  defp put_setup_readiness(readiness) do
    Application.put_env(:rindle, @runtime_status_config, setup_readiness: readiness)
  end

  defp age_ago(seconds) do
    DateTime.utc_now()
    |> DateTime.add(-seconds, :second)
    |> DateTime.to_naive()
  end
end
