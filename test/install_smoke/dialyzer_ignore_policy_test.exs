defmodule Rindle.InstallSmoke.DialyzerIgnorePolicyTest do
  use ExUnit.Case, async: true

  @ignore_path Path.expand("../../.dialyzer_ignore.exs", __DIR__)
  @approved_filters [
    {"lib/rindle/html.ex", :pattern_match},
    {"lib/rindle/ops/runtime_status.ex", :pattern_match_cov},
    {"lib/rindle/workers/process_variant.ex", :pattern_match},
    {"lib/rindle/workers/process_variant.ex", :pattern_match_cov},
    {"lib/mix/tasks/rindle.batch_owner_erasure.ex",
     "The function call message will not succeed."},
    {"lib/rindle/admin/live/actions_live.ex",
     "The pattern pattern {'error', _} can never match the type, because it is covered by previous clauses."},
    {"lib/rindle/migration.ex", "Function up/0 has no local return."},
    {"lib/rindle/migration.ex", "Function up/1 has no local return."},
    {"lib/rindle/migration.ex", "Function down/0 has no local return."},
    {"lib/rindle/migration.ex", "Function down/1 has no local return."},
    {"lib/rindle/migration.ex", "The function call move_public_to_rindle will not succeed."},
    {"lib/rindle/migration.ex", "Function move_public_to_rindle/0 has no local return."},
    {"lib/rindle/migration.ex", "The function call move_rindle_to_public will not succeed."},
    {"lib/rindle/migration.ex", "Function move_rindle_to_public/0 has no local return."},
    {"lib/rindle/migration.ex", "The function call up will not succeed."},
    {"lib/rindle/migration.ex", "Function dispatch/2 has no local return."},
    {"lib/rindle/migration.ex", "The function call down will not succeed."},
    {"lib/rindle/migration/v1.ex", "Function raise_preflight_error!/1 has no local return."},
    {"lib/rindle/migration/v1.ex",
     "The pattern can never match the type \n  :database_create_denied\n  | :mixed_state\n  | :public_incomplete\n  | :public_marker_invalid\n  | :public_not_empty\n  | :public_unusable\n  | :rindle_incomplete\n  | :rindle_marker_invalid\n  | :rindle_not_empty\n  | :rindle_unusable\n  | :source_not_owned\n."},
    {"lib/rindle/ops/runtime_checks.ex",
     "The pattern can never match the type :ok | {:already, :allowed | :owner}."},
    {"lib/rindle/storage/gcs/client.ex", "The function call stream! will not succeed."},
    {"lib/rindle/storage/gcs/client.ex",
     "The pattern can never match the type :resumable_upload, _, _, Keyword.t()."},
    {"lib/rindle/storage/local.ex", "Function upload_part_stream/5 has no local return."},
    {"lib/rindle/storage/local.ex", "The function call stream! will not succeed."},
    {"lib/rindle/storage/local.ex", "The created anonymous function has no local return."},
    {"lib/rindle/storage/s3.ex", "The pattern can never match the type {:error, atom()}."},
    {"lib/rindle/storage/s3.ex", "The function call stream! will not succeed."},
    {"lib/rindle/storage/s3.ex", "Function drain_tail_parts/7 will never be called."},
    {"lib/rindle/storage/s3.ex", "Function read_leading_part/1 will never be called."},
    {"lib/rindle/storage/s3.ex", "Function truncate_tail_head/2 will never be called."},
    {"lib/rindle/storage/s3.ex", "Function open_rest/2 will never be called."},
    {"lib/rindle/storage/s3.ex", "Function copy_rest/2 will never be called."},
    {"test/support/host_rindle_migration.ex", "Function up/0 has no local return."},
    {"test/support/host_rindle_migration.ex", "Function down/0 has no local return."},
    {"test/support/host_rindle_migration.ex", "Function install!/0 has no local return."}
  ]

  test "TYPE-02: the live curated ignore list is a unique, owned, approved subset" do
    ignores = Code.eval_file(@ignore_path) |> elem(0)

    assert valid_ignore_list?(ignores)
  end

  test "TYPE-02: approved filters may be removed without freezing the live count" do
    ignores = Code.eval_file(@ignore_path) |> elem(0)

    assert valid_ignore_list?(List.delete_at(ignores, 0))
  end

  test "TYPE-02: invalid fixtures are rejected without freezing the live count" do
    assert_invalid([{"lib/rindle.ex", :unapproved_atom}])
    assert_invalid([{"lib/rindle.ex", "The function call new_exact_filter/0 will not succeed."}])
    assert_invalid([{"lib/rindle.ex", "specific"}, {"lib/rindle.ex", "specific"}])
    assert_invalid([{"lib/missing.ex", "specific"}])
    assert_invalid([{"lib/rindle.ex", ""}])
    assert_invalid([{"lib/rindle.ex", ~r/specific/}])
    assert_invalid([{"lib/rindle.ex"}])
  end

  defp assert_invalid(ignores), do: refute(valid_ignore_list?(ignores))

  defp valid_ignore_list?(ignores) when is_list(ignores) do
    Enum.uniq(ignores) == ignores and
      Enum.all?(ignores, &valid_filter?/1) and
      MapSet.subset?(MapSet.new(ignores), MapSet.new(@approved_filters))
  end

  defp valid_ignore_list?(_), do: false

  defp valid_filter?({path, discriminator}) when is_binary(path) do
    valid_owner?(path) and valid_discriminator?({path, discriminator})
  end

  defp valid_filter?(_), do: false

  defp valid_discriminator?({_path, description}) when is_binary(description),
    do: String.trim(description) != ""

  defp valid_discriminator?(filter) when is_tuple(filter), do: filter in @approved_filters
  defp valid_discriminator?(_), do: false

  defp valid_owner?(path) do
    String.starts_with?(path, ["lib/", "test/support/"]) and
      File.regular?(Path.expand("../..", __DIR__) |> Path.join(path))
  end
end
