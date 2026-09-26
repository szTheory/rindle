unless Code.ensure_loaded?(YamlElixir) do
  repo_root = Path.expand("../..", __DIR__)

  ebin_paths =
    ["test", "dev"]
    |> Enum.map(&Path.join([repo_root, "_build", &1, "lib"]))
    |> Enum.find_value(fn build_lib ->
      paths = Path.wildcard(Path.join(build_lib, "*/ebin"))

      if Enum.any?(paths, &File.exists?(Path.join(&1, "Elixir.YamlElixir.beam"))),
        do: paths
    end)

  if is_nil(ebin_paths) do
    raise "[validate-phase-133-reconciliation] compiled YAML dependency is unavailable under the repository build root"
  end

  Enum.each(ebin_paths, &Code.prepend_path/1)
end

defmodule Rindle.ValidatePhase133Reconciliation do
  @moduledoc false

  @phase_dir ".planning/phases/133-evidence-charter-and-live-truth"
  @validation_path Path.join(@phase_dir, "133-VALIDATION.md")
  @roadmap_path ".planning/ROADMAP.md"
  @state_path ".planning/STATE.md"
  @requirements_path ".planning/REQUIREMENTS.md"
  @receipt_path Path.join(@phase_dir, "133-NIGHTLY-EVIDENCE.json")
  @historical_ref "6e0d96117dc26d51764a21804bd86a977784a661"
  @historical_blob "59eb44c23e693d04d579c200c1e9057d3138c72d"
  @historical_bytes 13_899
  @historical_sha256 "c3df0a578a2337f81d4539d5e8b0bc1d8ed4638d80ef1b4ce7fb424e43469bec"
  @historical_heading "## Pending Gap-Closure Validation Addendum (Plans 11–17)"
  @active_ref "9adf7c74dd32239a373963ad0d30d00a6d143b93"
  @active_bytes 68_572
  @active_sha256 "a2ae3b34457aabf84ba9d18d1f2f099e1266e3e1e12f0381539f16bf8988b9c0"
  @active_heading "## Gap-Repair Validation Addendum (Plans 28–32)"
  @branch_ref "a3020d78cdb2ccc2f1a0b9dd2a6fcf108507965e"
  @branch_bytes 90_993
  @branch_sha256 "2b1cfd85d43a1a478fc9d842af7184d826b545a605feda06c945ce638fc2649f"
  @branch_heading "## Branch-Aware Validation Addendum (Plans 33–37)"
  @execution_ref "87bd35cdcf040018a854a0e8c5a6ebc0b9438e53"
  @execution_blob "1573dfb6431eae92566754644e10640a2f59cb5e"
  @execution_bytes 90_994
  @execution_sha256 "9147e95250bc9c287a9c66d15ced923c4cf18fb9b73f29a0b5104ac5ea4450c7"
  @closure_heading "## Plans 38–42 Gap-Closure Addendum"
  @latest_heading "## Plans 43–49 Gap-Closure Addendum"
  @plans_50_heading "## Plans 50–52 Gap-Closure Addendum"
  @pending_state "pending — not executed"
  @executed_state "passed — executed"
  @halted_state "halted — immutable failed evidence"
  @halted_credit "failure-history-only"
  @failed_run "34661043059"
  @failed_subject "0f8189ddeed7e7a52b5c7464f17b70ab44596c33"
  @failed_ref "phase-133-evidence-0f8189ddeed7"
  @rate_limited_run "34670574306"
  @rate_limited_subject "e70623e9ea956c750904af574f47221cc472d2f2"
  @rate_limited_ref "phase-133-evidence-e70623e9ea95"
  @phase_requirements ~w(EVID-01 EVID-02 EVID-03 EVID-04 TRUTH-08)
  @repair_dependencies %{30 => [28, 29], 31 => [30], 32 => [31]}

  def run(argv) do
    with {:ok, options} <- parse_options(argv),
         {:ok, root} <- resolve_root(options.root),
         mode <- validation_mode(options),
         {:ok, expected} <- expected_records(root, mode),
         result <- maybe_print_addendum(options, expected, mode),
         :continue <- result,
         :ok <- require_tracked_inputs(root, mode),
         {:ok, prefix} <- validation_prefix(root, options, mode),
         :ok <- validate_prefix_metadata(root, options, mode, prefix),
         :ok <- maybe_write_addendum(root, options, prefix, expected, mode),
         {:ok, addendum} <- validate_validation(root, prefix, mode),
         {:ok, actual} <- parse_addendum(addendum),
         :ok <- compare_records(expected, actual),
         :ok <- validate_closure_flags(addendum, mode),
         {:ok, summary_state} <- validate_summaries_and_roadmap(root, mode),
         :ok <- if(options.check_repair_inventory, do: validate_repair_inventory(root), else: :ok) do
      IO.puts(success_message(mode, summary_state, length(expected), total_plans(root, mode)))

      :ok
    else
      :printed -> :ok
      {:error, _message} = error -> error
    end
  end

  defp validate_repair_inventory(root) do
    with {:ok, validation} <- File.read(Path.join(root, @validation_path)),
         inventories <-
           Regex.scan(
             ~r/<repair-inventory>\s*<parent-sha>([0-9a-f]{40})<\/parent-sha>\s*<repair-sha>([0-9a-f]{40})<\/repair-sha>(.*?)<\/repair-inventory>/s,
             validation,
             capture: :all_but_first
           ),
         true <- inventories != [] or {:error, "repair inventory is missing"},
         {:ok, plan} <- File.read(Path.join(root, Path.join(@phase_dir, "133-47-PLAN.md"))),
         [[task_one]] <-
           Regex.scan(~r/<task\b[^>]*>(.*?)<\/task>/s, plan, capture: :all_but_first)
           |> Enum.take(1),
         [task_one_files] <-
           Regex.run(~r/<files>(.*?)<\/files>/s, task_one, capture: :all_but_first),
         declared <-
           String.split(task_one_files, ~r/[,\s]+/, trim: true) |> Enum.uniq(),
         {:ok, listed} <- validate_repair_ranges(root, inventories, declared),
         true <-
           length(listed) == length(Enum.uniq(listed)) or
             {:error, "repair inventory contains duplicate path mappings"} do
      :ok
    else
      {:error, _message} = error ->
        error

      _ ->
        {:error, "repair inventory is missing, malformed, or not byte-bound to its commit pair"}
    end
  end

  defp validate_repair_ranges(root, inventories, declared) do
    Enum.reduce_while(inventories, {:ok, []}, fn [parent, repair, paths_block], {:ok, paths} ->
      with true <- parent != repair or {:error, "repair inventory commit range is empty"},
           mappings <- parse_repair_mappings(paths_block),
           listed <- Enum.map(mappings, & &1.path) |> Enum.sort(),
           true <-
             Enum.all?(mappings, &(&1.task == "133-47-01" and &1.kind != "")) or
               {:error, "repair inventory mappings must name Task 133-47-01 and a kind"},
           true <- listed != [] or {:error, "repair inventory has no changed-file mappings"},
           {:ok, changed_text} <- git(root, ["diff", "--name-only", parent, repair]),
           changed <- String.split(changed_text, "\n", trim: true) |> Enum.sort(),
           true <-
             changed == listed or
               {:error, "repair inventory file set differs from the exact commit range"},
           undeclared <-
             Enum.reject(changed, fn path ->
               path in declared or not source_or_test_path?(path)
             end),
           true <-
             undeclared == [] or
               {:error, "repair inventory includes undeclared path: #{List.first(undeclared)}"} do
        {:cont, {:ok, paths ++ listed}}
      else
        {:error, _message} = error ->
          {:halt, error}

        _ ->
          {:halt,
           {:error,
            "repair inventory is missing, malformed, or not byte-bound to its commit pair"}}
      end
    end)
  end

  defp source_or_test_path?(path) do
    Path.extname(path) in [".ex", ".exs", ".exf", ".sh"]
  end

  defp parse_repair_mappings(block) do
    Regex.scan(
      ~r/<mapping>\s*<path>([^<]+)<\/path>\s*<task>([^<]+)<\/task>\s*<kind>([^<]+)<\/kind>\s*<\/mapping>/s,
      block,
      capture: :all_but_first
    )
    |> Enum.map(fn [path, task, kind] -> %{path: path, task: task, kind: kind} end)
  end

  defp parse_options(argv) do
    switches = [
      root: :string,
      fixture_historical_ref: :string,
      fixture_historical_sha256: :string,
      fixture_active_prefix_ref: :string,
      fixture_active_prefix_sha256: :string,
      fixture_topology: :string,
      expect_execution_complete: :boolean,
      print_addendum: :boolean,
      write_addendum: :boolean,
      check_repair_inventory: :boolean
    ]

    case OptionParser.parse(argv, strict: switches) do
      {options, [], []} ->
        values = Map.new(options)
        fixture_ref = values[:fixture_historical_ref]
        fixture_sha = values[:fixture_historical_sha256]
        active_ref = values[:fixture_active_prefix_ref]
        active_sha = values[:fixture_active_prefix_sha256]
        fixture_topology = values[:fixture_topology]

        cond do
          is_nil(fixture_ref) != is_nil(fixture_sha) ->
            {:error, "fixture historical ref and digest must be supplied together"}

          not is_nil(fixture_sha) and not Regex.match?(~r/\A[0-9a-f]{64}\z/, fixture_sha) ->
            {:error, "fixture historical digest must be lowercase SHA-256"}

          is_nil(active_ref) != is_nil(active_sha) ->
            {:error, "fixture active prefix ref and digest must be supplied together"}

          not is_nil(active_sha) and not Regex.match?(~r/\A[0-9a-f]{64}\z/, active_sha) ->
            {:error, "fixture active prefix digest must be lowercase SHA-256"}

          not is_nil(fixture_ref) and not is_nil(active_ref) ->
            {:error, "historical and active fixture modes are mutually exclusive"}

          fixture_topology not in [nil, "repair-32", "branch-37", "branch-42"] ->
            {:error, "fixture topology must be repair-32, branch-37, or branch-42"}

          true ->
            {:ok,
             %{
               root: values[:root],
               fixture_ref: fixture_ref,
               fixture_sha: fixture_sha,
               active_ref: active_ref,
               active_sha: active_sha,
               fixture_topology: fixture_topology,
               expect_execution_complete: values[:expect_execution_complete] || false,
               print_addendum: values[:print_addendum] || false,
               write_addendum: values[:write_addendum] || false,
               check_repair_inventory: values[:check_repair_inventory] || false
             }}
        end

      {_options, positional, invalid} ->
        {:error, "unexpected arguments: #{inspect(positional ++ invalid)}"}
    end
  end

  defp resolve_root(nil) do
    case System.cmd("git", ["rev-parse", "--show-toplevel"], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output |> String.trim() |> Path.expand()}
      {_output, _status} -> {:error, "git toplevel lookup failed"}
    end
  end

  defp resolve_root(root), do: {:ok, Path.expand(root)}

  defp validation_mode(%{fixture_ref: ref}) when is_binary(ref), do: :historical_snapshot

  defp validation_mode(%{fixture_topology: "repair-32", expect_execution_complete: true}),
    do: :repair_execution_complete

  defp validation_mode(%{fixture_topology: "repair-32"}), do: :repair_execution

  defp validation_mode(%{fixture_topology: "branch-37", expect_execution_complete: true}),
    do: :branch_execution_complete

  defp validation_mode(%{fixture_topology: "branch-37"}), do: :branch_execution

  defp validation_mode(%{fixture_topology: "branch-42", expect_execution_complete: true}),
    do: :execution_complete

  defp validation_mode(%{fixture_topology: "branch-42"}), do: :execution

  defp validation_mode(%{expect_execution_complete: true}), do: :execution_complete
  defp validation_mode(_options), do: :execution

  defp success_message(:historical_snapshot, _summary_state, pair_count, _total),
    do:
      "phase 133 reconciliation valid: 10 completed, 7 pending plans, #{pair_count} verification pairs"

  defp success_message(mode, summary_state, pair_count, total)
       when mode in [
              :execution,
              :execution_complete,
              :branch_execution,
              :branch_execution_complete,
              :repair_execution,
              :repair_execution_complete
            ] do
    completed = MapSet.size(summary_state.completed)
    halted = MapSet.size(summary_state.halted)
    summarized = completed + halted
    pending = total - summarized

    "phase 133 reconciliation valid: #{completed} completed, #{halted} halted, " <>
      "#{pending} pending plans, #{summarized}/#{total} summarized, " <>
      "#{pair_count} validation records"
  end

  defp maybe_print_addendum(%{print_addendum: true}, records, mode) do
    IO.write(render_addendum(records, mode))
    :printed
  end

  defp maybe_print_addendum(_options, _records, _mode), do: :continue

  defp maybe_write_addendum(root, %{write_addendum: true}, prefix, records, mode) do
    path = Path.join(root, @validation_path)

    case File.read(path) do
      {:ok, ^prefix} ->
        File.write(path, prefix <> render_addendum(records, mode))

      {:ok, _other} ->
        {:error, "validation prefix gate requires the untouched committed preimage"}

      {:error, _reason} ->
        {:error, "validation input is unreadable"}
    end
  end

  defp maybe_write_addendum(_root, _options, _prefix, _records, _mode), do: :ok

  defp require_tracked_inputs(root, mode) do
    plans =
      case mode do
        :historical_snapshot ->
          11..17

        mode when mode in [:repair_execution, :repair_execution_complete] ->
          28..32

        mode when mode in [:branch_execution, :branch_execution_complete] ->
          28..37

        _ ->
          if File.regular?(Path.join(root, Path.join(@phase_dir, "133-43-PLAN.md"))),
            do:
              if(File.regular?(Path.join(root, Path.join(@phase_dir, "133-50-PLAN.md"))),
                do: 28..52,
                else: 28..49
              ),
            else: 28..42
      end

    paths =
      [@roadmap_path, @validation_path] ++
        if(
          mode in [:execution, :execution_complete, :branch_execution, :branch_execution_complete],
          do: [@state_path, @requirements_path],
          else: []
        ) ++
        Enum.map(plans, &Path.join(@phase_dir, "133-#{&1}-PLAN.md"))

    case git(root, ["ls-files", "--error-unmatch" | paths]) do
      {:ok, _output} -> :ok
      {:error, _message} -> {:error, "production reconciliation input is missing or untracked"}
    end
  end

  defp validation_prefix(root, options, mode) do
    {ref, expected_sha} =
      case mode do
        :historical_snapshot ->
          {options.fixture_ref || @historical_ref, options.fixture_sha || @historical_sha256}

        mode when mode in [:repair_execution, :repair_execution_complete] ->
          {options.active_ref || @active_ref, options.active_sha || @active_sha256}

        mode when mode in [:execution, :execution_complete] ->
          {options.active_ref || @execution_ref, options.active_sha || @execution_sha256}

        _ ->
          {options.active_ref || @branch_ref, options.active_sha || @branch_sha256}
      end

    case git(root, ["show", "#{ref}:#{@validation_path}"], trim: false) do
      {:ok, bytes} ->
        selected =
          if mode in [:execution, :execution_complete],
            do: before_heading(bytes, @branch_heading),
            else: bytes

        if sha256(selected) == expected_sha do
          {:ok, selected}
        else
          {:error, "historical validation prefix digest differs from recorded preimage"}
        end

      {:error, _message} ->
        {:error, "historical validation prefix commit:path preimage is unreadable"}
    end
  end

  defp validate_prefix_metadata(_root, %{fixture_ref: ref}, :historical_snapshot, prefix)
       when is_binary(ref) do
    if byte_size(prefix) > 0, do: :ok, else: {:error, "historical validation prefix is empty"}
  end

  defp validate_prefix_metadata(root, _options, :historical_snapshot, prefix) do
    with {:ok, blob} <- git(root, ["rev-parse", "#{@historical_ref}:#{@validation_path}"]),
         true <- blob == @historical_blob or {:error, "historical Git blob identity differs"},
         true <-
           byte_size(prefix) == @historical_bytes or
             {:error, "historical prefix byte length differs"},
         true <-
           String.contains?(prefix, "19/19 automated implementation tasks") or
             {:error, "historical 19/19 result is missing"},
         true <-
           Regex.match?(~r/\| Gaps found \| 0 \|/, prefix) or
             {:error, "historical zero-gap audit is missing"} do
      :ok
    else
      {:error, _message} = error -> error
      false -> {:error, "historical metadata differs"}
    end
  end

  defp validate_prefix_metadata(_root, %{active_ref: ref}, mode, prefix)
       when mode in [
              :execution,
              :execution_complete,
              :branch_execution,
              :branch_execution_complete,
              :repair_execution,
              :repair_execution_complete
            ] and is_binary(ref) do
    if byte_size(prefix) > 0, do: :ok, else: {:error, "historical validation prefix is empty"}
  end

  defp validate_prefix_metadata(root, _options, mode, prefix)
       when mode in [:repair_execution, :repair_execution_complete] do
    with true <-
           byte_size(prefix) == @active_bytes or
             {:error, "historical validation prefix byte length differs"},
         true <-
           sha256(prefix) == @active_sha256 or
             {:error, "historical validation prefix digest differs"},
         {:ok, committed} <-
           git(root, ["show", "#{@active_ref}:#{@validation_path}"], trim: false),
         true <-
           committed == prefix or
             {:error, "historical validation prefix differs from recorded ref"} do
      :ok
    else
      {:error, _message} = error -> error
      false -> {:error, "historical validation prefix metadata differs"}
    end
  end

  defp validate_prefix_metadata(root, _options, mode, prefix)
       when mode in [:execution, :execution_complete] do
    with {:ok, blob} <- git(root, ["rev-parse", "#{@execution_ref}:#{@validation_path}"]),
         true <-
           blob == @execution_blob or {:error, "execution validation Git blob identity differs"},
         true <-
           byte_size(prefix) == @execution_bytes or
             {:error, "execution prefix byte length differs"},
         true <-
           sha256(prefix) == @execution_sha256 or {:error, "execution prefix digest differs"},
         {:ok, committed} <-
           git(root, ["show", "#{@execution_ref}:#{@validation_path}"], trim: false),
         true <-
           before_heading(committed, @branch_heading) == prefix or
             {:error, "execution prefix differs from recorded ref"} do
      :ok
    else
      {:error, _message} = error -> error
      false -> {:error, "execution prefix metadata differs"}
    end
  end

  defp validate_prefix_metadata(root, _options, mode, prefix)
       when mode in [
              :branch_execution,
              :branch_execution_complete
            ] do
    with true <-
           byte_size(prefix) == @branch_bytes or
             {:error, "branch validation prefix byte length differs"},
         true <-
           sha256(prefix) == @branch_sha256 or
             {:error, "branch validation prefix digest differs"},
         {:ok, committed} <-
           git(root, ["show", "#{@branch_ref}:#{@validation_path}"], trim: false),
         true <-
           committed == prefix or
             {:error, "branch validation prefix differs from recorded ref"} do
      :ok
    else
      {:error, _message} = error -> error
      false -> {:error, "branch validation prefix metadata differs"}
    end
  end

  defp validate_validation(root, prefix, mode) do
    path = Path.join(root, @validation_path)

    heading =
      case mode do
        :historical_snapshot -> @historical_heading
        mode when mode in [:repair_execution, :repair_execution_complete] -> @active_heading
        _ -> @branch_heading
      end

    prefix_error =
      if mode == :historical_snapshot,
        do: "historical prefix differs byte-for-byte from recorded preimage",
        else: "historical validation prefix differs byte-for-byte from recorded preimage"

    with {:ok, current} <- File.read(path),
         true <-
           String.starts_with?(current, prefix) or
             {:error, prefix_error},
         rest <- binary_part(current, byte_size(prefix), byte_size(current) - byte_size(prefix)),
         true <-
           String.starts_with?(rest, heading) or
             {:error, "historical prefix boundary does not begin with the exact addendum heading"},
         1 <- length(:binary.matches(current, heading)),
         :ok <- validate_latest_heading(root, current),
         :ok <- validate_global_mapping_keys(current),
         body <- binary_part(rest, byte_size(heading), byte_size(rest) - byte_size(heading)) do
      {:ok, bounded_addendum(body, mode)}
    else
      {:error, _message} = error -> error
      _count -> {:error, "addendum heading must appear exactly once"}
    end
  end

  defp validate_latest_heading(root, current) do
    cond do
      File.regular?(Path.join(root, Path.join(@phase_dir, "133-43-PLAN.md"))) and
          length(:binary.matches(current, @latest_heading)) != 1 ->
        {:error, "Plans 43–49 validation addendum heading must appear exactly once"}

      File.regular?(Path.join(root, Path.join(@phase_dir, "133-50-PLAN.md"))) and
          length(:binary.matches(current, @plans_50_heading)) != 1 ->
        {:error, "Plans 50–52 validation addendum heading must appear exactly once"}

      true ->
        :ok
    end
  end

  defp validate_global_mapping_keys(validation) do
    keys =
      Regex.scan(~r/<pending-validation key="([^"]+)">/, validation, capture: :all_but_first)
      |> List.flatten()

    if keys == Enum.uniq(keys),
      do: :ok,
      else: {:error, "duplicate mapping key in validation addenda"}
  end

  defp validate_closure_flags(_addendum, mode)
       when mode not in [:execution, :execution_complete],
       do: :ok

  defp validate_closure_flags(addendum, _mode) do
    keys =
      Regex.scan(~r/<flagged-unresolved key="([^"]+)">/, addendum, capture: :all_but_first)
      |> List.flatten()

    expected = [
      "133-38-specless-startup-boundary",
      "133-38-specless-context-boundary"
    ]

    if keys == expected,
      do: :ok,
      else:
        {:error, "Plans 38–42 flagged-unresolved boundaries differ from the exact authority set"}
  end

  defp bounded_addendum(body, :historical_snapshot), do: before_heading(body, @active_heading)

  defp bounded_addendum(body, mode) when mode in [:repair_execution, :repair_execution_complete],
    do: before_heading(body, @branch_heading)

  defp bounded_addendum(body, mode)
       when mode in [
              :execution,
              :execution_complete
            ],
       do: body

  defp bounded_addendum(body, mode)
       when mode in [:branch_execution, :branch_execution_complete],
       do: before_heading(body, @closure_heading)

  defp bounded_addendum(body, _mode), do: body

  defp before_heading(body, heading) do
    case :binary.match(body, heading) do
      {offset, _length} -> binary_part(body, 0, offset)
      :nomatch -> body
    end
  end

  defp expected_records(root, mode) do
    {plans, initial} =
      case mode do
        :historical_snapshot ->
          {11..17, []}

        mode when mode in [:repair_execution, :repair_execution_complete] ->
          {28..32, [halted_history_record()]}

        mode when mode in [:branch_execution, :branch_execution_complete] ->
          {33..37, []}

        _ ->
          if File.regular?(Path.join(root, Path.join(@phase_dir, "133-43-PLAN.md"))),
            do:
              if(File.regular?(Path.join(root, Path.join(@phase_dir, "133-50-PLAN.md"))),
                do: {33..52, []},
                else: {33..49, []}
              ),
            else: {33..42, []}
      end

    Enum.reduce_while(plans, {:ok, initial}, fn plan, {:ok, all} ->
      path = Path.join(root, Path.join(@phase_dir, "133-#{plan}-PLAN.md"))

      case File.read(path) do
        {:ok, contents} ->
          case parse_plan(contents, plan, mode, root) do
            {:ok, records} -> {:cont, {:ok, all ++ records}}
            {:error, message} -> {:halt, {:error, "133-#{plan} #{message}"}}
          end

        {:error, _reason} ->
          {:halt, {:error, "missing plan 133-#{plan}"}}
      end
    end)
  end

  defp halted_history_record do
    %{
      key: "133-27-halted-history:1",
      command:
        "mix test test/install_smoke/phase_133_completed_validation_test.exs --seed 0 # immutable run #{@failed_run} attempt 1 subject #{@failed_subject} ref #{@failed_ref}",
      failure:
        "non-zero exit, zero ExUnit tests, Plan 133-27 is complete or checked, or its exact immutable run, attempt, subject, or ref differs",
      state: @halted_state,
      credit: @halted_credit,
      requirements: nil,
      validation_level: nil,
      branch_status: nil
    }
  end

  defp parse_plan(contents, plan, _mode, root) when plan in 43..52 do
    task_matches =
      Regex.scan(~r/<task\b([^>]*)>(.*?)<\/task>/s, contents, capture: :all_but_first)

    task_openers = length(Regex.scan(~r/<task\b/s, contents))
    task_closers = length(Regex.scan(~r/<\/task>/s, contents))

    cond do
      task_matches == [] ->
        {:error, "has no parseable tasks"}

      task_openers != length(task_matches) or task_closers != length(task_matches) ->
        {:error, "contains malformed task markup"}

      true ->
        parser = if plan in 50..52, do: &parse_inventory_gap_tasks/3, else: &parse_gap_tasks/3
        parser.(task_matches, plan, root)
    end
  end

  defp parse_plan(contents, plan, mode, _root) do
    task_matches =
      Regex.scan(~r/<task\b([^>]*)>(.*?)<\/task>/s, contents, capture: :all_but_first)

    task_openers = length(Regex.scan(~r/<task\b/s, contents))
    task_closers = length(Regex.scan(~r/<\/task>/s, contents))

    cond do
      task_matches == [] ->
        {:error, "has no parseable tasks"}

      task_openers != length(task_matches) or task_closers != length(task_matches) ->
        {:error, "contains malformed task markup"}

      true ->
        with {:ok, task_records} <- parse_tasks(task_matches, plan),
             {:ok, post_summary_records, contents} <- parse_post_summary(contents, plan, mode),
             outside_tasks <- Regex.replace(~r/<task\b[^>]*>.*?<\/task>/s, contents, ""),
             [[body]] <-
               Regex.scan(
                 ~r/^\s*<verification>\s*\n(.*?)^\s*<\/verification>\s*$/ms,
                 outside_tasks,
                 capture: :all_but_first
               ),
             {:ok, pairs} <- parse_plan_pairs(body),
             plan_records <-
               records_for("133-#{plan}-plan-verification", pairs, "pending", record_state(plan)) do
          {:ok, task_records ++ plan_records ++ post_summary_records}
        else
          {:error, message} -> {:error, message}
          _ -> {:error, "contains ambiguous plan-level verification markup"}
        end
    end
  end

  defp legacy_gap_done(48, 1, _current),
    do:
      "Fresh independent reports show no blocking code findings, `nyquist_compliant: true` with production-path mutation proof, and security sign-off with no unresolved high threat; all requirements remain pending."

  defp legacy_gap_done(_plan, _ordinal, current), do: String.trim(current)

  defp parse_inventory_gap_tasks(task_matches, plan, root) do
    task_matches
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {[attributes, body], ordinal}, {:ok, all} ->
      pairs =
        Regex.scan(
          ~r/<automated>(.*?)<\/automated>\s*<fails_when>(.*?)<\/fails_when>/s,
          body,
          capture: :all_but_first
        )
        |> Enum.map(fn [command, failure] -> {String.trim(command), String.trim(failure)} end)

      if pairs == [] do
        {:halt, {:error, "task #{ordinal} must contain adjacent automated/fails_when pairs"}}
      else
        source = "133-#{plan}-#{String.pad_leading(Integer.to_string(ordinal), 2, "0")}"

        credit =
          if String.contains?(attributes, "checkpoint:"),
            do: "authorization-only",
            else: "pending"

        records =
          records_for(source, pairs, credit, record_state(plan, root))
          |> enrich_gap_records(plan, ordinal, attributes)

        {:cont, {:ok, all ++ records}}
      end
    end)
  end

  defp parse_gap_tasks(task_matches, plan, root) do
    task_matches
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {[attributes, body], ordinal}, {:ok, all} ->
      commands =
        Regex.scan(~r/<verify\b[^>]*>(.*?)<\/verify>/s, body, capture: :all_but_first)
        |> Enum.flat_map(fn [verification] ->
          Regex.scan(~r/<automated>(.*?)<\/automated>/s, verification, capture: :all_but_first)
        end)

      done = Regex.run(~r/<done>(.*?)<\/done>/s, body, capture: :all_but_first)

      case {commands, done} do
        {[[command] | rest], [done_text]} ->
          effective_done = legacy_gap_done(plan, ordinal, done_text)

          pairs =
            Enum.map([[command] | rest], fn [value] ->
              {String.trim(value), effective_done}
            end)

          source = "133-#{plan}-#{String.pad_leading(Integer.to_string(ordinal), 2, "0")}"

          credit =
            if String.contains?(attributes, "checkpoint:"),
              do: "authorization-only",
              else: "pending"

          records =
            records_for(source, pairs, credit, record_state(plan, root))
            |> enrich_gap_records(plan, ordinal, attributes)

          {:cont, {:ok, all ++ records}}

        _ ->
          {:halt,
           {:error,
            "task #{ordinal} must contain automated commands and one explicit done condition"}}
      end
    end)
  end

  defp parse_post_summary(contents, 27, mode)
       when mode in [
              :execution,
              :execution_complete,
              :branch_execution,
              :branch_execution_complete
            ] do
    pattern = ~r/<post_summary_phase_gate\b[^>]*>(.*?)<\/post_summary_phase_gate>/s

    case Regex.scan(pattern, contents, capture: :all_but_first) do
      [[body]] ->
        with {:ok, pairs} <- parse_plan_pairs(body),
             true <-
               length(pairs) == 1 or {:error, "post-summary gate must contain exactly one pair"} do
          {:ok, records_for("133-27-post-summary", pairs, "pending"),
           Regex.replace(pattern, contents, "")}
        end

      _ ->
        {:error, "contains missing or ambiguous post-summary phase gate"}
    end
  end

  defp parse_post_summary(contents, _plan, _mode), do: {:ok, [], contents}

  defp parse_tasks(task_matches, plan) do
    task_matches
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {[attributes, body], ordinal}, {:ok, all} ->
      case Regex.scan(~r/^\s*<verify>\s*\n(.*?)^\s*<\/verify>\s*$/ms, body,
             capture: :all_but_first
           ) do
        [[verify_body]] ->
          case parse_pairs(verify_body) do
            {:ok, pairs} ->
              source = "133-#{plan}-#{String.pad_leading(Integer.to_string(ordinal), 2, "0")}"

              credit =
                if String.contains?(attributes, "checkpoint:"),
                  do: "authorization-only",
                  else: "pending"

              records =
                records_for(source, pairs, credit, record_state(plan))
                |> enrich_closure_records(plan, attributes)
                |> enrich_gap_records(plan, ordinal, attributes)

              {:cont, {:ok, all ++ records}}

            {:error, message} ->
              {:halt, {:error, "task #{ordinal} #{message}"}}
          end

        _ ->
          {:halt, {:error, "task #{ordinal} contains ambiguous verification markup"}}
      end
    end)
  end

  defp parse_pairs(body), do: parse_pairs(body, [])

  defp parse_plan_pairs(body) do
    pattern = ~r/<automated>(.*?)<\/automated>\s*<fails_when>(.*?)<\/fails_when>/s
    pairs = Regex.scan(pattern, body, capture: :all_but_first)
    opens = length(Regex.scan(~r/<automated>/, body))
    closes = length(Regex.scan(~r/<\/automated>/, body))
    failure_opens = length(Regex.scan(~r/<fails_when>/, body))
    failure_closes = length(Regex.scan(~r/<\/fails_when>/, body))

    cond do
      opens != closes or failure_opens != failure_closes or opens != failure_opens ->
        {:error, "verification markup has orphan or malformed tags"}

      length(pairs) != opens ->
        {:error, "verification markup does not contain adjacent automated/fails_when pairs"}

      true ->
        normalized =
          Enum.map(pairs, fn [command, failure] ->
            {String.trim(command), String.trim(failure)}
          end)

        if Enum.any?(normalized, fn {command, failure} -> command == "" or failure == "" end) do
          {:error, "verification markup contains an empty command or failure direction"}
        else
          {:ok, normalized}
        end
    end
  end

  defp parse_pairs(body, pairs) do
    if String.trim(body) == "" do
      if pairs == [],
        do: {:error, "verification markup has no pairs"},
        else: {:ok, Enum.reverse(pairs)}
    else
      pattern =
        ~r/\A\s*<automated>(.*?)<\/automated>\s*<fails_when>(.*?)<\/fails_when>(.*)\z/s

      case Regex.run(pattern, body, capture: :all_but_first) do
        [command, failure, rest] ->
          command = String.trim(command)
          failure = String.trim(failure)

          if command == "" or failure == "" do
            {:error, "verification markup contains an empty command or failure direction"}
          else
            parse_pairs(rest, [{command, failure} | pairs])
          end

        _ ->
          {:error, "verification markup does not contain adjacent automated/fails_when pairs"}
      end
    end
  end

  defp record_state(plan) when plan in [33, 34, 38, 39, 43, 44, 45, 46], do: @executed_state
  defp record_state(_plan), do: @pending_state

  defp record_state(plan, root) when plan in 43..52 do
    plan_id = String.pad_leading(Integer.to_string(plan), 2, "0")
    path = Path.join(root, Path.join(@phase_dir, "133-#{plan_id}-SUMMARY.md"))

    case File.read(path) do
      {:ok, summary} ->
        case summary_document(summary) do
          {:ok, %{status: "complete"}} ->
            @executed_state

          {:ok, %{status: "halted", metadata: metadata}} ->
            if plan == 48 and Map.get(metadata, "report-gate") == "blocked",
              do: @pending_state,
              else: @halted_state

          _ ->
            @pending_state
        end

      _ ->
        @pending_state
    end
  end

  defp record_state(plan, _root), do: record_state(plan)

  defp records_for(source, pairs, credit, state \\ @pending_state) do
    pairs
    |> Enum.with_index(1)
    |> Enum.map(fn {{command, failure}, pair} ->
      %{
        key: "#{source}:#{pair}",
        command: command,
        failure: failure,
        state: state,
        credit: credit,
        requirements: nil,
        validation_level: nil,
        branch_status: nil
      }
    end)
  end

  defp enrich_closure_records(records, plan, attributes) when plan in 38..42 do
    Enum.map(records, fn record ->
      credit =
        cond do
          String.contains?(attributes, "checkpoint:") -> "authorization-only"
          plan == 42 and record.key == "133-42-02:6" -> "terminal-completion"
          true -> "pending"
        end

      Map.merge(record, %{
        credit: credit,
        requirements: Enum.join(@phase_requirements, ","),
        validation_level: closure_validation_level(plan),
        branch_status:
          cond do
            record.key == "133-42-02:6" -> "sole-terminal-completion-path"
            plan in [38, 39] -> "passed — executed"
            true -> "pending — not executed"
          end
      })
    end)
  end

  defp enrich_closure_records(records, _plan, _attributes), do: records

  defp closure_validation_level(38), do: "repair-backstop"
  defp closure_validation_level(39), do: "reconciliation-authority"
  defp closure_validation_level(40), do: "exact-subject-qualification"
  defp closure_validation_level(41), do: "authorization-only"
  defp closure_validation_level(42), do: "terminal-attempt"

  defp enrich_gap_records(records, plan, ordinal, attributes) when plan in 43..52 do
    Enum.map(records, fn record ->
      credit =
        cond do
          String.contains?(attributes, "checkpoint:") -> "authorization-only"
          plan == 49 and ordinal == 2 -> "terminal-completion"
          true -> "pending"
        end

      Map.merge(record, %{
        credit: credit,
        requirements: Enum.join(@phase_requirements, ","),
        validation_level: "gap-closure",
        branch_status:
          case record.state do
            @executed_state -> "passed — executed"
            @halted_state -> "halted — immutable failed evidence"
            _ -> "pending — not executed"
          end
      })
    end)
  end

  defp enrich_gap_records(records, _plan, _ordinal, _attributes), do: records

  defp parse_addendum(addendum) do
    record_pattern =
      ~r/<pending-validation key="([^"]+)">\s*<automated>\s*(.*?)\s*<\/automated>\s*<fails_when>\s*(.*?)\s*<\/fails_when>\s*(?:<requirements>(.*?)<\/requirements>\s*)?(?:<validation-level>(.*?)<\/validation-level>\s*)?(?:<branch-status>(.*?)<\/branch-status>\s*)?<state>(.*?)<\/state>\s*<acceptance-credit>(.*?)<\/acceptance-credit>\s*<\/pending-validation>/s

    captures = Regex.scan(record_pattern, addendum, capture: :all_but_first)
    stripped = Regex.replace(record_pattern, addendum, "")

    cond do
      captures == [] ->
        {:error, "pending mapping addendum contains no records"}

      String.contains?(stripped, "<pending-validation") or
          String.contains?(stripped, "</pending-validation>") ->
        {:error, "pending mapping markup is malformed"}

      true ->
        records =
          Enum.map(captures, fn [
                                  key,
                                  command,
                                  failure,
                                  requirements,
                                  level,
                                  branch,
                                  state,
                                  credit
                                ] ->
            %{
              key: String.trim(key),
              command: String.trim(command),
              failure: String.trim(failure),
              state: String.trim(state),
              credit: String.trim(credit),
              requirements: trim_optional(requirements),
              validation_level: trim_optional(level),
              branch_status: trim_optional(branch)
            }
          end)

        {:ok, records}
    end
  end

  defp compare_records(expected, actual) do
    expected_keys = Enum.map(expected, & &1.key)
    actual_keys = Enum.map(actual, & &1.key)
    missing = expected_keys -- actual_keys
    extra = actual_keys -- expected_keys

    cond do
      actual_keys != Enum.uniq(actual_keys) ->
        {:error, "duplicate mapping key in pending addendum"}

      missing != [] ->
        {:error, "pending mapping is missing: #{hd(missing)}"}

      extra != [] ->
        {:error, "extra mapping is not present in the selected plan range: #{hd(extra)}"}

      actual_keys != expected_keys ->
        {:error, "mapping order or within-source pair ordinal is not contiguous"}

      true ->
        Enum.zip(expected, actual)
        |> Enum.reduce_while(:ok, fn {wanted, got}, :ok ->
          cond do
            got.command != wanted.command ->
              {:halt, {:error, "mapping command text differs for #{wanted.key}"}}

            got.failure != wanted.failure ->
              {:halt,
               {:error,
                "mapping failure text differs for #{wanted.key}: expected=#{inspect(wanted.failure)} actual=#{inspect(got.failure)}"}}

            got.state != wanted.state ->
              {:halt, {:error, "pending state differs for #{wanted.key}"}}

            got.credit != wanted.credit ->
              {:halt, {:error, "acceptance credit differs for #{wanted.key}"}}

            got.requirements != wanted.requirements ->
              {:halt, {:error, "requirement IDs differ for #{wanted.key}"}}

            got.validation_level != wanted.validation_level ->
              {:halt, {:error, "validation level differs for #{wanted.key}"}}

            got.branch_status != wanted.branch_status ->
              {:halt, {:error, "branch status differs for #{wanted.key}"}}

            true ->
              {:cont, :ok}
          end
        end)
    end
  end

  defp trim_optional(nil), do: nil

  defp trim_optional(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp validate_summaries_and_roadmap(root, :historical_snapshot) do
    case validate_historical_roadmap(root) do
      :ok -> {:ok, 10}
      {:error, _message} = error -> error
    end
  end

  defp validate_summaries_and_roadmap(root, mode)
       when mode in [
              :execution,
              :execution_complete,
              :branch_execution,
              :branch_execution_complete,
              :repair_execution,
              :repair_execution_complete
            ] do
    with {:ok, summary_state} <- summary_state(root, total_plans(root, mode), mode),
         :ok <- validate_execution_summary_state(summary_state, mode),
         :ok <- validate_branch_terminal_summaries(root, summary_state, mode),
         :ok <- validate_execution_roadmap(root, summary_state, mode),
         :ok <- validate_live_authorities(root, summary_state, mode) do
      {:ok, summary_state}
    end
  end

  defp summary_state(root, total, mode) do
    initial = %{completed: MapSet.new(), halted: MapSet.new()}

    Enum.reduce_while(1..total, {:ok, initial}, fn plan, {:ok, state} ->
      plan_id = String.pad_leading(Integer.to_string(plan), 2, "0")
      path = Path.join(root, Path.join(@phase_dir, "133-#{plan_id}-SUMMARY.md"))

      case File.read(path) do
        {:ok, summary} ->
          case summary_document(summary) do
            {:ok, %{status: "complete"}}
            when plan == 27 or
                   (plan == 32 and
                      mode in [
                        :execution,
                        :execution_complete,
                        :branch_execution,
                        :branch_execution_complete
                      ]) or
                   (plan == 37 and mode in [:execution, :execution_complete]) ->
              {:halt, {:error, "Plan #{plan} must remain halted and cannot be status: complete"}}

            {:ok, %{status: "complete"}} ->
              {:cont, {:ok, %{state | completed: MapSet.put(state.completed, plan)}}}

            {:ok, %{status: "halted"} = document}
            when plan == 27 or
                   (plan == 32 and
                      mode in [
                        :execution,
                        :execution_complete,
                        :branch_execution,
                        :branch_execution_complete
                      ]) or
                   (plan == 37 and mode in [:execution, :execution_complete]) ->
              case validate_halted_summary(plan, document) do
                :ok -> {:cont, {:ok, %{state | halted: MapSet.put(state.halted, plan)}}}
                {:error, reason} -> {:halt, {:error, "halted summary 133-#{plan} #{reason}"}}
              end

            {:ok, %{status: "halted"} = document} when plan in 33..49 ->
              case validate_branch_halted_summary(plan, document) do
                :ok -> {:cont, {:ok, %{state | halted: MapSet.put(state.halted, plan)}}}
                {:error, reason} -> {:halt, {:error, "halted summary 133-#{plan} #{reason}"}}
              end

            {:ok, %{status: status}} ->
              {:halt, {:error, "summary 133-#{plan_id} has unsupported status: #{status}"}}

            {:error, reason} ->
              {:halt, {:error, "summary 133-#{plan_id} #{reason}"}}
          end

        {:error, :enoent} ->
          {:cont, {:ok, state}}

        {:error, _reason} ->
          {:halt, {:error, "summary 133-#{plan_id} is unreadable"}}
      end
    end)
  end

  defp summary_document(summary) do
    with {:ok, frontmatter, body} <- bounded_frontmatter(summary),
         :ok <- reject_second_frontmatter(body),
         :ok <- require_one_status_key(frontmatter),
         {:ok, decoded} <- decode_frontmatter(frontmatter),
         true <- is_map(decoded) or {:error, "frontmatter must decode to a mapping"},
         status when is_binary(status) <- Map.get(decoded, "status") do
      {:ok, %{status: status, metadata: decoded, body: body}}
    else
      {:error, _reason} = error -> error
      nil -> {:error, "frontmatter status is missing"}
      _non_scalar -> {:error, "frontmatter status must be a scalar string"}
    end
  end

  defp validate_halted_summary(27, document) do
    halt_reason = Map.get(document.metadata, "halt_reason")

    requirements = [
      {is_binary(halt_reason) and String.contains?(halt_reason, @failed_run),
       "must retain failed run #{@failed_run} in halt_reason"},
      {is_binary(halt_reason) and String.contains?(halt_reason, "attempt 1"),
       "must retain failed attempt 1 in halt_reason"},
      {String.contains?(document.body, "`#{@failed_run}`"),
       "must retain exact failed run #{@failed_run}"},
      {String.contains?(document.body, "attempt `1`"), "must retain exact failed attempt 1"},
      {String.contains?(document.body, "`#{@failed_subject}`"),
       "must retain exact failed subject #{@failed_subject}"},
      {String.contains?(document.body, "`refs/heads/#{@failed_ref}`"),
       "must retain exact failed ref #{@failed_ref}"}
    ]

    case Enum.find(requirements, fn {valid?, _message} -> not valid? end) do
      nil -> :ok
      {_valid?, message} -> {:error, message}
    end
  end

  defp validate_halted_summary(32, document) do
    halt_reason = Map.get(document.metadata, "halt_reason")

    requirements = [
      {is_binary(halt_reason) and String.contains?(halt_reason, @rate_limited_run),
       "must retain rate-limited run #{@rate_limited_run} in halt_reason"},
      {String.contains?(document.body, "`#{@rate_limited_run}`"),
       "must retain exact rate-limited run #{@rate_limited_run}"},
      {String.contains?(document.body, "`#{@rate_limited_subject}`"),
       "must retain exact rate-limited subject #{@rate_limited_subject}"},
      {String.contains?(document.body, "`refs/heads/#{@rate_limited_ref}`"),
       "must retain exact rate-limited ref #{@rate_limited_ref}"}
    ]

    case Enum.find(requirements, fn {valid?, _message} -> not valid? end) do
      nil -> :ok
      {_valid?, message} -> {:error, message}
    end
  end

  defp validate_halted_summary(37, document),
    do: validate_branch_halted_summary(37, document)

  defp validate_branch_halted_summary(48, document) do
    metadata = document.metadata

    explicit_stop? =
      Map.get(metadata, "decision") == "stop" and
        Map.get(metadata, "requirements-completed") == []

    blocked_before_decision? =
      is_nil(Map.get(metadata, "decision")) and
        Map.get(metadata, "report-gate") == "blocked" and
        is_binary(Map.get(metadata, "halt_reason")) and
        String.contains?(Map.get(metadata, "halt_reason"), "report gate") and
        Map.get(metadata, "requirements-completed") == [] and
        is_nil(Map.get(metadata, "authorized_ref")) and
        is_nil(Map.get(metadata, "authorized_sha"))

    if explicit_stop? or blocked_before_decision? do
      :ok
    else
      {:error,
       "must record decision: stop or a report-gate halt before decision, with zero requirement credit"}
    end
  end

  defp validate_branch_halted_summary(49, document) do
    if Map.get(document.metadata, "decision") != "authorize" and
         Map.get(document.metadata, "requirements-completed") == [] and
         is_binary(Map.get(document.metadata, "halt_reason")) and
         String.contains?(Map.get(document.metadata, "halt_reason"), "immutable") do
      :ok
    else
      {:error, "must preserve an immutable failed attempt with zero requirement credit"}
    end
  end

  defp validate_branch_halted_summary(36, document) do
    if Map.get(document.metadata, "decision") == "stop",
      do: :ok,
      else: {:error, "must record decision: stop"}
  end

  defp validate_branch_halted_summary(37, document) do
    halt_reason = Map.get(document.metadata, "halt_reason")

    if is_binary(halt_reason) and String.contains?(halt_reason, "immutable"),
      do: :ok,
      else: {:error, "must preserve an immutable terminal failure in halt_reason"}
  end

  defp validate_branch_halted_summary(41, document) do
    if Map.get(document.metadata, "decision") == "stop",
      do: :ok,
      else: {:error, "must record decision: stop"}
  end

  defp validate_branch_halted_summary(42, document) do
    expected = %{
      "qualification" => "failed",
      "terminal_automation" => "halted",
      "requirements_completed" => [],
      "subject_sha" => "c83f61379ad5033efef9afa7b5bc88913080bae2",
      "published_ref" => "refs/heads/phase-133-evidence-c83f61379ad5",
      "run_id" => 34_768_317_696,
      "run_attempt" => 1,
      "receipt_sha256" => "1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4"
    }

    if Enum.all?(expected, fn {key, value} -> Map.get(document.metadata, key) == value end) and
         String.contains?(Map.get(document.metadata, "halt_reason", ""), "34768317696") do
      :ok
    else
      {:error, "must preserve the exact immutable Plan 42 failure tuple and prior receipt digest"}
    end
  end

  defp validate_branch_halted_summary(_plan, _document), do: :ok

  defp bounded_frontmatter(summary) do
    lines = String.split(summary, "\n", trim: false)

    case lines do
      ["---" | rest] ->
        case Enum.find_index(rest, &(&1 == "---")) do
          nil ->
            {:error, "frontmatter closing delimiter is missing"}

          closing_index ->
            frontmatter = rest |> Enum.take(closing_index) |> Enum.join("\n")
            body = rest |> Enum.drop(closing_index + 1) |> Enum.join("\n")
            {:ok, frontmatter, body}
        end

      _ ->
        {:error, "frontmatter must be the leading document block"}
    end
  end

  defp reject_second_frontmatter(body) do
    lines = String.split(body, "\n", trim: false)

    if second_frontmatter?(lines) do
      {:error, "contains more than one frontmatter block"}
    else
      :ok
    end
  end

  defp second_frontmatter?(["---" | rest]) do
    case Enum.find_index(rest, &(&1 == "---")) do
      nil ->
        false

      closing_index ->
        rest
        |> Enum.take(closing_index)
        |> Enum.any?(&Regex.match?(~r/^[A-Za-z_][A-Za-z0-9_-]*[ \t]*:/, &1))
    end
  end

  defp second_frontmatter?([_line | rest]), do: second_frontmatter?(rest)
  defp second_frontmatter?([]), do: false

  defp require_one_status_key(frontmatter) do
    case length(Regex.scan(~r/^status[ \t]*:/m, frontmatter)) do
      1 -> :ok
      0 -> {:error, "frontmatter must contain exactly one status key"}
      _count -> {:error, "frontmatter contains duplicate status keys"}
    end
  end

  defp decode_frontmatter(frontmatter) do
    case YamlElixir.read_from_string(frontmatter) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _reason} -> {:error, "frontmatter YAML is malformed"}
    end
  end

  defp validate_execution_summary_state(summary_state, mode) do
    cond do
      mode in [:repair_execution, :repair_execution_complete] ->
        validate_repair_summary_state(summary_state, mode)

      mode in [:branch_execution, :branch_execution_complete] ->
        validate_branch_summary_state(summary_state, mode)

      true ->
        validate_closure_summary_state(summary_state, mode)
    end
  end

  defp validate_repair_summary_state(summary_state, mode) do
    summary_state = %{
      summary_state
      | completed: MapSet.filter(summary_state.completed, &(&1 <= 32)),
        halted: MapSet.filter(summary_state.halted, &(&1 <= 32))
    }

    with true <-
           MapSet.subset?(MapSet.new(1..26), summary_state.completed) or
             {:error, "historical completed summaries 133-01 through 133-26 must remain complete"},
         true <-
           summary_state.halted == MapSet.new([27]) or
             {:error, "Plan 27 must remain the sole halted summary"},
         :ok <- validate_repair_dependencies(summary_state.completed),
         :ok <- validate_repair_complete_state(summary_state, mode) do
      :ok
    else
      {:error, _message} = error -> error
      false -> {:error, "Phase 133 summary state differs from the required topology"}
    end
  end

  defp validate_branch_summary_state(summary_state, mode) do
    cond do
      not MapSet.member?(summary_state.halted, 32) ->
        {:error, "Plan 32 must remain halted with its immutable rate-limited attempt"}

      true ->
        case branch_lifecycle(summary_state) do
          {:ok, :qualified_success} when mode == :branch_execution_complete ->
            :ok

          {:ok, _lifecycle} when mode == :branch_execution_complete ->
            {:error, "execution-complete requires the qualified Plan 37 success state"}

          {:ok, _lifecycle} ->
            :ok

          {:error, _message} = error ->
            error
        end
    end
  end

  defp validate_closure_summary_state(summary_state, mode) do
    cond do
      not MapSet.subset?(MapSet.new([27, 32, 37]), summary_state.halted) ->
        {:error, "Plans 27, 32, and 37 must remain immutable halted history"}

      true ->
        case closure_lifecycle(summary_state) do
          {:ok, :qualified_success_42} when mode == :execution_complete ->
            validate_gap_plan_lifecycle(summary_state)

          {:ok, _lifecycle} when mode == :execution_complete ->
            {:error, "execution-complete requires the qualified Plan 42 success state"}

          {:ok, _lifecycle} ->
            validate_gap_plan_lifecycle(summary_state)

          {:error, _message} = error ->
            error
        end
    end
  end

  defp validate_gap_plan_lifecycle(summary_state) do
    completed = summary_state.completed
    summarized = MapSet.union(completed, summary_state.halted)
    later_plans = Enum.filter(47..52, &MapSet.member?(summarized, &1))

    cond do
      later_plans != [] and not MapSet.subset?(MapSet.new(43..46), completed) ->
        {:error, "Plans 43–46 must be complete before Plan 47 can be summarized"}

      MapSet.member?(summarized, 48) and not MapSet.member?(completed, 47) ->
        {:error, "Plan 47 must be complete before Plan 48 can be summarized"}

      MapSet.member?(summarized, 49) and not MapSet.member?(completed, 48) ->
        {:error, "Plan 48 must complete authorization before Plan 49 can be summarized"}

      MapSet.member?(summarized, 50) and
          not MapSet.subset?(MapSet.new([43, 44, 45, 46, 47]), completed) ->
        {:error, "Plans 43–47 must be complete before Plan 50 can be summarized"}

      MapSet.member?(summarized, 51) and not MapSet.member?(completed, 50) ->
        {:error, "Plan 50 must be complete before Plan 51 can be summarized"}

      MapSet.member?(summarized, 52) and not MapSet.member?(completed, 51) ->
        {:error, "Plan 51 must be complete before Plan 52 can be summarized"}

      MapSet.member?(summarized, 48) and not MapSet.member?(completed, 52) ->
        {:error, "Plan 52 must be complete before Plan 48 can be summarized"}

      true ->
        :ok
    end
  end

  defp branch_lifecycle(summary_state) do
    base = Enum.to_list(1..26) ++ [28, 29, 30, 31]

    states = [
      {:post_33, [33], [27, 32]},
      {:post_34, [33, 34], [27, 32]},
      {:post_35, [33, 34, 35], [27, 32]},
      {:authorized, [33, 34, 35, 36], [27, 32]},
      {:stopped, [33, 34, 35], [27, 32, 36]},
      {:failed, [33, 34, 35, 36], [27, 32, 37]},
      {:qualified_success, [33, 34, 35, 36, 37], [27, 32]}
    ]

    case Enum.find(states, fn {_name, completed_tail, halted} ->
           summary_state.completed == MapSet.new(base ++ completed_tail) and
             summary_state.halted == MapSet.new(halted)
         end) do
      {name, _completed, _halted} ->
        {:ok, name}

      nil ->
        if summary_state.halted == MapSet.new([27, 32]) do
          {:error, "completed set must match an exact Plans 33–37 lifecycle state"}
        else
          {:error, "halted set must match an exact Plans 33–37 lifecycle branch"}
        end
    end
  end

  defp closure_lifecycle(summary_state) do
    summary_state = %{
      summary_state
      | completed: MapSet.filter(summary_state.completed, &(&1 <= 42)),
        halted: MapSet.filter(summary_state.halted, &(&1 <= 42))
    }

    base = Enum.to_list(1..26) ++ [28, 29, 30, 31, 33, 34, 35, 36, 38]

    states = [
      {:post_38, [], [27, 32, 37]},
      {:post_39, [39], [27, 32, 37]},
      {:post_40, [39, 40], [27, 32, 37]},
      {:authorized_42, [39, 40, 41], [27, 32, 37]},
      {:stopped_42, [39, 40], [27, 32, 37, 41]},
      {:failed_42, [39, 40, 41], [27, 32, 37, 42]},
      {:qualified_success_42, [39, 40, 41, 42], [27, 32, 37]}
    ]

    case Enum.find(states, fn {_name, completed_tail, halted} ->
           summary_state.completed == MapSet.new(base ++ completed_tail) and
             summary_state.halted == MapSet.new(halted)
         end) do
      {name, _completed, _halted} ->
        {:ok, name}

      nil ->
        if summary_state.halted == MapSet.new([27, 32, 37]) do
          {:error, "completed set must match an exact Plans 38–42 lifecycle state"}
        else
          {:error, "halted set must match an exact Plans 38–42 lifecycle branch"}
        end
    end
  end

  defp validate_branch_terminal_summaries(_root, _summary_state, mode)
       when mode in [:repair_execution, :repair_execution_complete],
       do: :ok

  defp validate_branch_terminal_summaries(root, summary_state, mode)
       when mode in [:execution, :execution_complete] do
    with {:ok, lifecycle} <- closure_lifecycle(summary_state),
         :ok <- validate_plan_41_decision(root, lifecycle),
         :ok <- validate_plan_42_qualification(root, lifecycle),
         :ok <- validate_plan_48_authorization(root, summary_state) do
      :ok
    end
  end

  defp validate_branch_terminal_summaries(root, summary_state, _mode) do
    with {:ok, lifecycle} <- branch_lifecycle(summary_state),
         :ok <- validate_plan_36_decision(root, lifecycle),
         :ok <- validate_plan_37_qualification(root, lifecycle) do
      :ok
    end
  end

  defp validate_plan_48_authorization(root, summary_state) do
    summary_path = summary_path(root, 48)

    summarized_49 =
      MapSet.member?(summary_state.completed, 49) or MapSet.member?(summary_state.halted, 49)

    cond do
      not File.regular?(summary_path) and summarized_49 ->
        {:error, "Plan 49 requires a literal Plan 48 authorization"}

      not File.regular?(summary_path) ->
        :ok

      true ->
        with {:ok, summary} <- File.read(summary_path),
             {:ok, document} <- summary_document(summary),
             true <-
               Map.get(document.metadata, "requirements-completed") == [] or
                 {:error, "Plan 48 must grant zero requirement credit"},
             :ok <- validate_plan_48_decision(document, summarized_49) do
          :ok
        else
          {:error, _message} = error ->
            error

          _ ->
            {:error, "Plan 48 must record authorize, stop, or a report-gate halt before decision"}
        end
    end
  end

  defp validate_plan_48_decision(%{status: "halted", metadata: metadata}, summarized_49) do
    if is_nil(Map.get(metadata, "decision")) do
      if summarized_49 or metadata["report-gate"] != "blocked" or
           not is_binary(metadata["halt_reason"]) or
           not String.contains?(metadata["halt_reason"], "report gate") or
           not is_nil(metadata["authorized_ref"]) or not is_nil(metadata["authorized_sha"]) do
        {:error, "Plan 48 pre-decision halt must identify its blocked report gate and no pair"}
      else
        :ok
      end
    else
      validate_plan_48_recorded_decision(metadata, summarized_49)
    end
  end

  defp validate_plan_48_decision(%{metadata: metadata}, summarized_49) do
    validate_plan_48_recorded_decision(metadata, summarized_49)
  end

  defp validate_plan_48_recorded_decision(metadata, summarized_49) do
    decision = Map.get(metadata, "decision")

    if decision in ["authorize", "stop"] and
         if(decision == "authorize",
           do: valid_authorized_pair?(metadata),
           else: not summarized_49 and is_nil(Map.get(metadata, "authorized_ref"))
         ) and
         (not summarized_49 or decision == "authorize") do
      :ok
    else
      {:error, "Plan 48 literal SHA/ref authorization or stop branch differs"}
    end
  end

  defp valid_authorized_pair?(metadata) do
    subject = Map.get(metadata, "subject_sha")
    ref = Map.get(metadata, "authorized_ref")

    is_binary(subject) and Regex.match?(~r/\A[0-9a-f]{40}\z/, subject) and
      ref == "refs/heads/phase-133-evidence-#{String.slice(subject, 0, 12)}"
  end

  defp validate_plan_41_decision(_root, lifecycle)
       when lifecycle in [:post_38, :post_39, :post_40],
       do: :ok

  defp validate_plan_41_decision(root, lifecycle) do
    expected = if lifecycle == :stopped_42, do: "stop", else: "authorize"

    with {:ok, summary} <- File.read(summary_path(root, 41)),
         {:ok, document} <- summary_document(summary),
         true <-
           Map.get(document.metadata, "decision") == expected or
             {:error, "Plan 41 summary must record decision: #{expected}"},
         true <-
           expected != "authorize" or
             (Map.get(document.metadata, "subject_sha") ==
                "c83f61379ad5033efef9afa7b5bc88913080bae2" and
                Map.get(document.metadata, "authorized_ref") ==
                  "refs/heads/phase-133-evidence-c83f61379ad5" and
                Map.get(document.metadata, "requirements-completed") == []) or
             {:error, "Plan 41 authorization SHA/ref or zero-credit record differs"} do
      :ok
    else
      {:error, _message} = error -> error
      false -> {:error, "Plan 41 decision metadata differs"}
    end
  end

  defp validate_plan_42_qualification(_root, lifecycle)
       when lifecycle != :qualified_success_42,
       do: :ok

  defp validate_plan_42_qualification(root, :qualified_success_42) do
    with {:ok, summary} <- File.read(summary_path(root, 42)),
         {:ok, document} <- summary_document(summary),
         true <-
           Map.get(document.metadata, "qualification") == "verified" or
             {:error, "Plan 42 success summary qualification must be verified"},
         true <-
           Map.get(document.metadata, "terminal_automation") == "passed" or
             {:error, "Plan 42 terminal automation must be passed"},
         requirements when is_list(requirements) <-
           Map.get(document.metadata, "requirements_completed"),
         true <-
           MapSet.new(requirements) == MapSet.new(@phase_requirements) or
             {:error, "Plan 42 success summary must qualify every Phase 133 requirement"},
         :ok <- validate_qualified_receipt(root, document.metadata) do
      :ok
    else
      {:error, _message} = error -> error
      nil -> {:error, "Plan 42 success summary requirements_completed is missing"}
      _ -> {:error, "Plan 42 success summary qualification metadata is malformed"}
    end
  end

  defp validate_qualified_receipt(root, metadata) do
    with subject when is_binary(subject) <- Map.get(metadata, "subject_sha"),
         digest when is_binary(digest) <- Map.get(metadata, "receipt_sha256"),
         {:ok, receipt} <- File.read(Path.join(root, @receipt_path)),
         true <- sha256(receipt) == digest or {:error, "canonical receipt digest differs"},
         {:ok, decoded} <- Jason.decode(receipt),
         true <-
           canonical_receipt_shape?(decoded) or {:error, "canonical receipt schema is incomplete"},
         true <-
           Map.get(decoded, "subject_sha") == subject or
             {:error, "canonical receipt subject differs from Plan 42 qualification"},
         ref when is_binary(ref) <- Map.get(metadata, "published_ref"),
         true <-
           Map.get(decoded, "remote_ref") == ref or
             {:error, "canonical receipt ref differs from Plan 42 qualification"},
         true <-
           Map.get(decoded, "run_id") == Map.get(metadata, "run_id") or
             {:error, "canonical receipt run differs from Plan 42 qualification"},
         true <-
           Map.get(decoded, "run_attempt") == Map.get(metadata, "run_attempt") or
             {:error, "canonical receipt attempt differs from Plan 42 qualification"},
         :ok <- verify_canonical_receipt(root) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 42 qualified canonical receipt metadata is malformed"}
    end
  end

  defp canonical_receipt_shape?(receipt) when is_map(receipt) do
    required =
      ~w(conclusion created_at dialyzer event incident_snapshot_after incident_snapshot_before jobs local_authorities preflight remote_ref repository run_attempt run_id schema_version strict_verdict subject_sha workflow)

    Enum.sort(Map.keys(receipt)) == Enum.sort(required) and
      Map.get(receipt, "schema_version") == 2 and
      is_binary(Map.get(receipt, "subject_sha")) and
      is_binary(Map.get(receipt, "remote_ref")) and
      is_list(Map.get(receipt, "jobs")) and
      is_map(Map.get(receipt, "strict_verdict")) and
      is_integer(Map.get(receipt, "run_attempt")) and
      is_integer(Map.get(receipt, "run_id"))
  end

  defp canonical_receipt_shape?(_), do: false

  defp verify_canonical_receipt(root) do
    script = Path.join(root, "scripts/ci/verify_nightly_run.sh")

    if File.regular?(script) do
      case System.cmd(script, ["verify-receipt", "--receipt", Path.join(root, @receipt_path)],
             cd: root,
             stderr_to_stdout: true
           ) do
        {_output, 0} -> :ok
        {_output, _status} -> {:error, "canonical verify-receipt reconstruction failed"}
      end
    else
      {:error, "canonical verify-receipt adapter is unavailable"}
    end
  end

  defp validate_plan_36_decision(_root, lifecycle)
       when lifecycle in [:post_33, :post_34, :post_35],
       do: :ok

  defp validate_plan_36_decision(root, lifecycle) do
    expected = if lifecycle == :stopped, do: "stop", else: "authorize"

    with {:ok, summary} <- File.read(summary_path(root, 36)),
         {:ok, document} <- summary_document(summary),
         true <-
           Map.get(document.metadata, "decision") == expected or
             {:error, "Plan 36 summary must record decision: #{expected}"} do
      :ok
    else
      {:error, _message} = error -> error
      false -> {:error, "Plan 36 decision metadata differs"}
    end
  end

  defp validate_plan_37_qualification(_root, lifecycle)
       when lifecycle != :qualified_success,
       do: :ok

  defp validate_plan_37_qualification(root, :qualified_success) do
    with {:ok, summary} <- File.read(summary_path(root, 37)),
         {:ok, document} <- summary_document(summary),
         true <-
           Map.get(document.metadata, "qualification") == "verified" or
             {:error, "Plan 37 success summary qualification must be verified"},
         true <-
           Map.get(document.metadata, "terminal_automation") == "passed" or
             {:error, "Plan 37 terminal automation must be passed"},
         requirements when is_list(requirements) <-
           Map.get(document.metadata, "requirements_completed"),
         true <-
           MapSet.new(requirements) == MapSet.new(@phase_requirements) or
             {:error, "Plan 37 success summary must qualify every Phase 133 requirement"} do
      :ok
    else
      {:error, _message} = error -> error
      nil -> {:error, "Plan 37 success summary requirements_completed is missing"}
      _ -> {:error, "Plan 37 success summary qualification metadata is malformed"}
    end
  end

  defp summary_path(root, plan) do
    id = String.pad_leading(Integer.to_string(plan), 2, "0")
    Path.join(root, Path.join(@phase_dir, "133-#{id}-SUMMARY.md"))
  end

  defp validate_repair_dependencies(completed) do
    Enum.reduce_while(@repair_dependencies, :ok, fn {plan, dependencies}, :ok ->
      if MapSet.member?(completed, plan) and
           Enum.any?(dependencies, &(not MapSet.member?(completed, &1))) do
        {:halt, {:error, "repair dependency is missing for completed Plan #{plan}"}}
      else
        {:cont, :ok}
      end
    end)
  end

  defp validate_repair_complete_state(_summary_state, :repair_execution), do: :ok

  defp validate_repair_complete_state(summary_state, :repair_execution_complete) do
    missing = Enum.reject(28..32, &MapSet.member?(summary_state.completed, &1))

    case missing do
      [] -> :ok
      [plan | _] -> {:error, "execution-complete summary 133-#{plan} is missing or incomplete"}
    end
  end

  defp validate_historical_roadmap(root) do
    with {:ok, roadmap} <- File.read(Path.join(root, @roadmap_path)),
         [section] <-
           Regex.run(
             ~r/### Phase 133: Evidence Charter and Live Truth(.*?)(?=\n### Phase 134:|\z)/s,
             roadmap,
             capture: :all_but_first
           ),
         :ok <- validate_historical_roadmap_status(section),
         :ok <- validate_historical_roadmap_plans(section) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "roadmap Phase 133 section is missing or ambiguous"}
    end
  end

  defp validate_historical_roadmap_status(section) do
    if String.contains?(section, "**Plans**: 10/17 plans executed; 7 pending gap closure"),
      do: :ok,
      else: {:error, "roadmap status must report 10/17 plans executed; 7 pending gap closure"}
  end

  defp validate_historical_roadmap_plans(section) do
    with :ok <-
           Enum.reduce_while(1..10, :ok, fn plan, :ok ->
             id = "133-#{String.pad_leading(Integer.to_string(plan), 2, "0")}-PLAN.md"

             if length(Regex.scan(~r/^- \[x\] #{Regex.escape(id)}(?:\s| |$)/m, section)) == 1 do
               {:cont, :ok}
             else
               {:halt, {:error, "historical plan #{id} must remain checked exactly once"}}
             end
           end),
         :ok <-
           Enum.reduce_while(11..17, :ok, fn plan, :ok ->
             id = "133-#{plan}-PLAN.md"

             if length(Regex.scan(~r/^- \[ \] #{Regex.escape(id)}(?:\s| |$)/m, section)) == 1 do
               {:cont, :ok}
             else
               {:halt, {:error, "pending plan #{id} must be checked correctly exactly once"}}
             end
           end) do
      :ok
    end
  end

  defp validate_execution_roadmap(root, summary_state, mode) do
    completed_count = MapSet.size(summary_state.completed)
    halted_count = MapSet.size(summary_state.halted)
    summarized_count = completed_count + halted_count
    total = total_plans(root, mode)

    lifecycle =
      cond do
        mode in [:execution, :execution_complete] ->
          elem(closure_lifecycle(summary_state), 1)

        mode in [:branch_execution, :branch_execution_complete] ->
          elem(branch_lifecycle(summary_state), 1)

        true ->
          :repair
      end

    with {:ok, roadmap} <- File.read(Path.join(root, @roadmap_path)),
         [section] <-
           Regex.run(
             ~r/### Phase 133: Evidence Charter and Live Truth(.*?)(?=\n### Phase 134:|\z)/s,
             roadmap,
             capture: :all_but_first
           ),
         :ok <-
           validate_execution_detail(
             section,
             summarized_count,
             completed_count,
             total - summarized_count,
             mode,
             lifecycle,
             summary_state.halted
           ),
         :ok <- validate_execution_checkboxes(section, summary_state.completed, total),
         :ok <- validate_execution_progress_row(roadmap, summarized_count, total, lifecycle) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "roadmap Phase 133 section is missing or ambiguous"}
    end
  end

  defp validate_execution_detail(
         section,
         summarized_count,
         completed_count,
         pending_count,
         mode,
         _lifecycle,
         _halted
       )
       when mode in [:repair_execution, :repair_execution_complete] do
    expected =
      "**Plans**: #{summarized_count}/32 plans executed summarized; #{completed_count} completed, " <>
        "Plan 133-27 halted with its failed immutable attempt preserved, #{pending_count} pending"

    if length(Regex.scan(~r/^#{Regex.escape(expected)}$/m, section)) == 1 do
      :ok
    else
      {:error,
       "roadmap detail must report exactly #{summarized_count}/32 summarized, " <>
         "#{completed_count} completed, one halted, and #{pending_count} pending"}
    end
  end

  defp validate_execution_detail(
         section,
         summarized_count,
         completed_count,
         pending_count,
         mode,
         lifecycle,
         halted
       ) do
    total = total_plans_from_detail(section)

    expected =
      if mode in [:execution, :execution_complete] and total > 42 do
        pre_decision_halt? = MapSet.member?(halted, 48)
        immutable_halts = if pre_decision_halt?, do: MapSet.delete(halted, 48), else: halted
        halted_text = halted_plan_text(immutable_halts)
        gate_text = if pre_decision_halt?, do: ", Plan 133-48 halted before a decision", else: ""

        "**Plans**: #{summarized_count}/#{total} plans executed summarized; #{completed_count} completed, " <>
          "#{halted_text} halted with immutable attempts preserved#{gate_text}, " <>
          "#{pending_count} gap-closure plans pending."
      else
        branch_roadmap_detail(lifecycle, summarized_count, completed_count, pending_count)
      end

    if String.contains?(section, expected) do
      :ok
    else
      {:error,
       "roadmap detail must report exactly the #{lifecycle} branch at " <>
         "#{summarized_count}/#{if(total > 42, do: total, else: total_plans_for_lifecycle(lifecycle))} summarized; expected #{inspect(expected)} actual #{inspect(Regex.run(~r/^\*\*Plans.*$/m, section))}"}
    end
  end

  defp halted_plan_text(halted) do
    ids = Enum.sort(MapSet.to_list(halted)) |> Enum.map(&"133-#{&1}")

    case ids do
      [one] -> "Plan #{one}"
      [first, second] -> "Plans #{first} and #{second}"
      [first, second, third] -> "Plans #{first}, #{second}, and #{third}"
      [first, second, third, fourth] -> "Plans #{first}, #{second}, #{third}, and #{fourth}"
      many -> "Plans " <> Enum.join(many, ", ")
    end
  end

  defp total_plans_for_lifecycle(lifecycle)
       when lifecycle in [
              :post_38,
              :post_39,
              :post_40,
              :authorized_42,
              :stopped_42,
              :failed_42,
              :qualified_success_42
            ],
       do: 42

  defp total_plans_for_lifecycle(_lifecycle), do: 37

  defp branch_roadmap_detail(:stopped, _summarized, _completed, _pending) do
    "**Plans**: 36/37 plans summarized; 33 completed, Plans 133-27, 133-32, and 133-36 " <>
      "halted with immutable attempts preserved, Plan 133-37 blocked."
  end

  defp branch_roadmap_detail(:failed, _summarized, _completed, _pending) do
    "**Plans**: 37/37 plans summarized; 34 completed, Plans 133-27, 133-32, and 133-37 " <>
      "halted with immutable attempts preserved, 0 pending."
  end

  defp branch_roadmap_detail(:stopped_42, _summarized, _completed, _pending) do
    "**Plans**: 41/42 plans summarized; 37 completed, Plans 133-27, 133-32, 133-37, " <>
      "and 133-41 halted with immutable attempts preserved, Plan 133-42 blocked."
  end

  defp branch_roadmap_detail(:failed_42, _summarized, _completed, _pending) do
    "**Plans**: 42/42 plans summarized; 38 completed, Plans 133-27, 133-32, 133-37, " <>
      "and 133-42 halted with immutable attempts preserved, 0 pending."
  end

  defp branch_roadmap_detail(lifecycle, summarized, completed, pending)
       when lifecycle in [:post_38, :post_39, :post_40, :authorized_42, :qualified_success_42] do
    "**Plans**: #{summarized}/42 plans summarized; #{completed} completed, " <>
      "Plans 133-27, 133-32, and 133-37 halted with immutable attempts preserved, " <>
      "#{pending} pending."
  end

  defp branch_roadmap_detail(lifecycle, summarized, completed, pending)
       when lifecycle in [:post_33, :post_34, :post_35, :authorized, :qualified_success] do
    "**Plans**: #{summarized}/37 plans summarized; #{completed} completed, " <>
      "Plans 133-27 and 133-32 halted with their immutable attempts preserved, " <>
      "#{pending} pending."
  end

  defp total_plans_from_detail(section),
    do: length(Regex.scan(~r/^- \[([ x])\] 133-\d+-PLAN\.md(?:\s| |$)/m, section))

  defp validate_execution_checkboxes(section, completed, total) do
    Enum.reduce_while(1..total, :ok, fn plan, :ok ->
      id = "133-#{String.pad_leading(Integer.to_string(plan), 2, "0")}-PLAN.md"

      captures =
        Regex.scan(~r/^- \[([ x])\] #{Regex.escape(id)}(?:\s| |$)/m, section,
          capture: :all_but_first
        )

      expected_checked = MapSet.member?(completed, plan)

      case captures do
        [[checkbox]] when checkbox == "x" == expected_checked ->
          {:cont, :ok}

        _ when plan in [27, 32, 37, 42] ->
          {:halt, {:error, "Plan #{plan} must remain unchecked while halted"}}

        _ ->
          {:halt, {:error, "summary/checkbox mismatch for #{id}"}}
      end
    end)
  end

  defp validate_execution_progress_row(roadmap, summarized_count, total, lifecycle) do
    pattern =
      ~r/^\|\s*133\.\s*Evidence Charter and Live Truth\s*\|\s*(\d+)\/#{total}\s*\|\s*([^|]+)\|\s*([^|]*)\|$/m

    case Regex.scan(pattern, roadmap, capture: :all_but_first) do
      [[count, status, completed]] ->
        {expected_status, completion_valid?} =
          if lifecycle in [:qualified_success, :qualified_success_42] do
            {"Complete", Regex.match?(~r/\A\d{4}-\d{2}-\d{2}\z/, String.trim(completed))}
          else
            {"In Progress", String.trim(completed) == ""}
          end

        if count == Integer.to_string(summarized_count) and
             String.trim(status) == expected_status and completion_valid? do
          :ok
        else
          {:error,
           "roadmap Progress row must agree at #{summarized_count}/#{total} with #{expected_status} and its completion date contract"}
        end

      _ ->
        {:error, "roadmap Progress row is missing or ambiguous"}
    end
  end

  defp validate_live_authorities(_root, _summary_state, mode)
       when mode in [:repair_execution, :repair_execution_complete],
       do: :ok

  defp validate_live_authorities(root, summary_state, mode)
       when mode in [
              :execution,
              :execution_complete,
              :branch_execution,
              :branch_execution_complete
            ] do
    summarized_count = MapSet.size(summary_state.completed) + MapSet.size(summary_state.halted)

    {:ok, lifecycle} =
      if mode in [:execution, :execution_complete],
        do: closure_lifecycle(summary_state),
        else: branch_lifecycle(summary_state)

    requirements_complete? = lifecycle in [:qualified_success, :qualified_success_42]
    total = total_plans(root, mode)

    with :ok <- validate_state(root, summarized_count, lifecycle, total),
         :ok <- validate_requirements(root, requirements_complete?) do
      :ok
    end
  end

  defp validate_state(root, summarized_count, lifecycle, total) do
    {expected_status, expected_plan} =
      cond do
        total > 42 and stopped_at_plan48?(root) ->
          {"blocked", 49}

        total > 42 and summarized_count >= 49 and not File.regular?(summary_path(root, 48)) ->
          {"executing", 48}

        total > 42 ->
          {"executing", summarized_count + 1}

        true ->
          case lifecycle do
            :qualified_success -> {"complete", 37}
            :qualified_success_42 -> {"complete", 42}
            lifecycle when lifecycle in [:stopped_42, :failed_42] -> {"blocked", 42}
            lifecycle when lifecycle in [:stopped, :failed] -> {"blocked", 37}
            _ -> {"executing", summarized_count + 1}
          end
      end

    with {:ok, contents} <- File.read(Path.join(root, @state_path)),
         {:ok, frontmatter, body} <- bounded_frontmatter(contents),
         {:ok, decoded} <- decode_frontmatter(frontmatter),
         %{"progress" => progress} <- decoded do
      cond do
        Map.get(progress, "total_plans") != total ->
          {:error, "STATE total_plans must be #{total}"}

        Map.get(progress, "completed_plans") != summarized_count ->
          {:error, "STATE completed_plans must equal #{summarized_count}"}

        Map.get(decoded, "status") != expected_status ->
          {:error, "STATE status must be #{expected_status} for the #{lifecycle} branch"}

        not Regex.match?(~r/^Plan:\s*#{expected_plan} of #{total}$/m, body) ->
          {:error, "STATE current Plan position contradicts summarized count"}

        true ->
          :ok
      end
    else
      {:error, _message} = error ->
        error

      %{} ->
        {:error, "STATE progress mapping is missing"}

      _ ->
        {:error, "STATE authority is malformed"}
    end
  end

  defp stopped_at_plan48?(root) do
    case File.read(summary_path(root, 48)) do
      {:ok, summary} ->
        case summary_document(summary) do
          {:ok, %{status: "halted"}} -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  defp validate_requirements(root, completed?) do
    with {:ok, contents} <- File.read(Path.join(root, @requirements_path)) do
      result =
        Enum.reduce_while(@phase_requirements, :ok, fn id, :ok ->
          checkbox = if completed?, do: "x", else: " "
          status = if completed?, do: "Complete", else: "Pending"
          bullet = ~r/^- \[#{Regex.escape(checkbox)}\] \*\*#{Regex.escape(id)}\*\*:/m
          trace = ~r/^\|\s*#{Regex.escape(id)}\s*\|\s*Phase 133\s*\|\s*#{status}\s*\|$/m

          if length(Regex.scan(bullet, contents)) == 1 and
               length(Regex.scan(trace, contents)) == 1 do
            {:cont, :ok}
          else
            {:halt,
             {:error,
              "requirement #{id} must remain #{String.downcase(status)} in checkbox and traceability"}}
          end
        end)

      case result do
        {:error, message} when completed? ->
          {:error, "requirements must be complete after qualified success: #{message}"}

        other ->
          other
      end
    else
      {:error, _reason} -> {:error, "requirements authority is unreadable"}
    end
  end

  defp total_plans(_root, :historical_snapshot), do: 17

  defp total_plans(_root, mode) when mode in [:repair_execution, :repair_execution_complete],
    do: 32

  defp total_plans(_root, mode) when mode in [:branch_execution, :branch_execution_complete],
    do: 37

  defp total_plans(root, mode) when mode in [:execution, :execution_complete] do
    with {:ok, roadmap} <- File.read(Path.join(root, @roadmap_path)),
         [section] <-
           Regex.run(
             ~r/### Phase 133: Evidence Charter and Live Truth(.*?)(?=\n### Phase 134:|\z)/s,
             roadmap,
             capture: :all_but_first
           ) do
      count = length(Regex.scan(~r/^- \[([ x])\] 133-\d+-PLAN\.md(?:\s| |$)/m, section))
      if count >= 42, do: count, else: 42
    else
      _ -> 42
    end
  end

  defp render_addendum(records, :historical_snapshot) do
    intro =
      "Plans 01–10 remain the immutable historical 19/19 green record above. The records below describe unexecuted Plans 11–17 only; every runnable command/failure pair stays pending, and the Plan 17 authorization checkpoint carries no acceptance credit."

    @historical_heading <>
      "\n\n" <> intro <> "\n\n" <> Enum.map_join(records, "\n", &render_record/1)
  end

  defp render_addendum(records, mode)
       when mode in [:repair_execution, :repair_execution_complete] do
    intro =
      "Plans 01–27 remain immutable validation history. Plan 133-27 stays halted on its exact failed run, attempt, subject, and ref with no acceptance credit. The records below preserve every automated command/failure pair for repair Plans 133-28 through 133-32 in source order; their execution state remains separate from this ownership ledger."

    @active_heading <> "\n\n" <> intro <> "\n\n" <> Enum.map_join(records, "\n", &render_record/1)
  end

  defp render_addendum(records, mode)
       when mode in [:execution, :execution_complete] do
    selected =
      Enum.filter(records, &String.starts_with?(&1.key, ["133-50-", "133-51-", "133-52-"]))

    intro =
      "Plans 50–52 execute in repair-first order after the existing immutable validation history. Plan 50 precedes 51 and 52; Plans 48–49 remain pending until Plan 52 and independent authorization gates complete. These records grant no acceptance credit."

    @plans_50_heading <>
      "\n\n" <> intro <> "\n\n" <> Enum.map_join(selected, "\n", &render_record/1)
  end

  defp render_addendum(records, mode)
       when mode in [:branch_execution, :branch_execution_complete] do
    intro =
      "Plans 01–32 and their earlier validation addenda remain immutable. The records below map every runnable automated command/failure pair for branch-aware Plans 133-33 through 133-37 in source order. Plans 33–34 are executed; Plans 35–37 remain pending until their own summaries exist. The Plan 36 human decision is authorization-only and never acceptance evidence."

    @branch_heading <> "\n\n" <> intro <> "\n\n" <> Enum.map_join(records, "\n", &render_record/1)
  end

  defp render_record(record) do
    metadata =
      [
        optional_tag("requirements", record.requirements),
        optional_tag("validation-level", record.validation_level),
        optional_tag("branch-status", record.branch_status)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    """
    <pending-validation key="#{record.key}">
    <automated>
    #{record.command}
    </automated>
    <fails_when>
    #{record.failure}
    </fails_when>
    #{metadata}
    <state>#{record.state}</state>
    <acceptance-credit>#{record.credit}</acceptance-credit>
    </pending-validation>
    """
  end

  defp optional_tag(_name, nil), do: nil
  defp optional_tag(name, value), do: "<#{name}>#{value}</#{name}>"

  defp git(root, args, options \\ []) do
    case System.cmd("git", args, cd: root, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, if(Keyword.get(options, :trim, true), do: String.trim(output), else: output)}

      {_output, _status} ->
        {:error, "git command failed"}
    end
  end

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end

case Rindle.ValidatePhase133Reconciliation.run(System.argv()) do
  :ok ->
    :ok

  {:error, message} ->
    IO.puts(:stderr, "[validate-phase-133-reconciliation] #{message}")
    System.halt(1)
end
