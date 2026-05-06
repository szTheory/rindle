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
