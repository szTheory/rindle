defmodule Rindle.RuntimeStatusTaskTest do
  use Rindle.DataCase, async: false

  alias Mix.Tasks.Rindle.RuntimeStatus, as: RuntimeStatusTask
  alias Rindle.Domain.{MediaAsset, MediaVariant}

  defmodule TaskProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [thumb: [mode: :fit, width: 32, height: 32]],
      allow_mime: ["image/png"],
      max_bytes: 10_485_760
  end

  setup do
    previous_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)

    on_exit(fn -> Mix.shell(previous_shell) end)
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

    RuntimeStatusTask.run(["--format", "json", "--limit", "1"])

    assert_received {:mix_shell, :info, [output]}
    assert output =~ "\"variants\""
    assert output =~ "\"recommendations\""
    assert output =~ "\"failed_work\""
  end

  test "exits non-zero on invalid format after surfacing the failure" do
    assert catch_exit(RuntimeStatusTask.run(["--format", "yaml"])) == {:shutdown, 1}

    assert_received {:mix_shell, :error, [message]}
    assert message =~ "Rindle.RuntimeStatus failed"
    assert message =~ "invalid_format"
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
      upload_sessions: %{counts: %{total: 0}, findings: []},
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

  defp age_ago(seconds) do
    DateTime.utc_now()
    |> DateTime.add(-seconds, :second)
    |> DateTime.to_naive()
  end
end
