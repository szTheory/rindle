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
  @closure_heading "## Plans 38–42 Gap-Closure Addendum"
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
         {:ok, summary_state} <- validate_summaries_and_roadmap(root, mode) do
      IO.puts(success_message(mode, summary_state, length(expected)))

      :ok
    else
      :printed -> :ok
      {:error, _message} = error -> error
    end
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
      write_addendum: :boolean
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
               write_addendum: values[:write_addendum] || false
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

  defp validation_mode(%{expect_execution_complete: true}), do: :execution_complete
  defp validation_mode(_options), do: :execution

  defp success_message(:historical_snapshot, _completed, pair_count),
    do:
      "phase 133 reconciliation valid: 10 completed, 7 pending plans, #{pair_count} verification pairs"

  defp success_message(mode, summary_state, pair_count)
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
    total = total_plans(mode)
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
        :historical_snapshot -> 11..17
        mode when mode in [:repair_execution, :repair_execution_complete] -> 28..32
        mode when mode in [:branch_execution, :branch_execution_complete] -> 28..37
        _ -> 28..42
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

        _ ->
          {options.active_ref || @branch_ref, options.active_sha || @branch_sha256}
      end

    case git(root, ["show", "#{ref}:#{@validation_path}"], trim: false) do
      {:ok, bytes} ->
        if sha256(bytes) == expected_sha do
          {:ok, bytes}
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
       when mode in [
              :execution,
              :execution_complete,
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
         :ok <- validate_global_mapping_keys(current),
         body <- binary_part(rest, byte_size(heading), byte_size(rest) - byte_size(heading)) do
      {:ok, bounded_addendum(body, mode)}
    else
      {:error, _message} = error -> error
      _count -> {:error, "addendum heading must appear exactly once"}
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

  defp bounded_addendum(body, :historical_snapshot), do: before_heading(body, @active_heading)

  defp bounded_addendum(body, mode) when mode in [:repair_execution, :repair_execution_complete],
    do: before_heading(body, @branch_heading)

  defp bounded_addendum(body, mode)
       when mode in [
              :execution,
              :execution_complete,
              :branch_execution,
              :branch_execution_complete
            ],
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
          {33..37, []}
      end

    Enum.reduce_while(plans, {:ok, initial}, fn plan, {:ok, all} ->
      path = Path.join(root, Path.join(@phase_dir, "133-#{plan}-PLAN.md"))

      case File.read(path) do
        {:ok, contents} ->
          case parse_plan(contents, plan, mode) do
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
      credit: @halted_credit
    }
  end

  defp parse_plan(contents, plan, mode) do
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
             [plan_verification] <-
               Regex.scan(
                 ~r/^\s*<verification>\s*\n(.*?)^\s*<\/verification>\s*$/ms,
                 outside_tasks,
                 capture: :all_but_first
               ),
             [body] <- plan_verification,
             {:ok, pairs} <- parse_plan_pairs(body),
             plan_records <-
               records_for(
                 "133-#{plan}-plan-verification",
                 pairs,
                 "pending",
                 record_state(plan)
               ) do
          {:ok, task_records ++ plan_records ++ post_summary_records}
        else
          {:error, message} -> {:error, message}
          _ -> {:error, "contains ambiguous plan-level verification markup"}
        end
    end
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

              {:cont, {:ok, all ++ records_for(source, pairs, credit, record_state(plan))}}

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

  defp record_state(plan) when plan in [33, 34], do: @executed_state
  defp record_state(_plan), do: @pending_state

  defp records_for(source, pairs, credit, state \\ @pending_state) do
    pairs
    |> Enum.with_index(1)
    |> Enum.map(fn {{command, failure}, pair} ->
      %{
        key: "#{source}:#{pair}",
        command: command,
        failure: failure,
        state: state,
        credit: credit
      }
    end)
  end

  defp parse_addendum(addendum) do
    record_pattern =
      ~r/<pending-validation key="([^"]+)">\s*<automated>\s*(.*?)\s*<\/automated>\s*<fails_when>\s*(.*?)\s*<\/fails_when>\s*<state>(.*?)<\/state>\s*<acceptance-credit>(.*?)<\/acceptance-credit>\s*<\/pending-validation>/s

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
          Enum.map(captures, fn [key, command, failure, state, credit] ->
            %{
              key: String.trim(key),
              command: String.trim(command),
              failure: String.trim(failure),
              state: String.trim(state),
              credit: String.trim(credit)
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
              {:halt, {:error, "mapping failure text differs for #{wanted.key}"}}

            got.state != wanted.state ->
              {:halt, {:error, "pending state differs for #{wanted.key}"}}

            got.credit != wanted.credit ->
              {:halt, {:error, "acceptance credit differs for #{wanted.key}"}}

            true ->
              {:cont, :ok}
          end
        end)
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
    with {:ok, summary_state} <- summary_state(root, total_plans(mode), mode),
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

            {:ok, %{status: "halted"} = document} when plan in 33..42 ->
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
    halt_reason = Map.get(document.metadata, "halt_reason")

    if is_binary(halt_reason) and String.contains?(halt_reason, "immutable"),
      do: :ok,
      else: {:error, "must preserve an immutable terminal failure in halt_reason"}
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
            :ok

          {:ok, _lifecycle} when mode == :execution_complete ->
            {:error, "execution-complete requires the qualified Plan 42 success state"}

          {:ok, _lifecycle} ->
            :ok

          {:error, _message} = error ->
            error
        end
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
         :ok <- validate_plan_42_qualification(root, lifecycle) do
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

  defp validate_plan_41_decision(_root, lifecycle)
       when lifecycle in [:post_38, :post_39, :post_40],
       do: :ok

  defp validate_plan_41_decision(root, lifecycle) do
    expected = if lifecycle == :stopped_42, do: "stop", else: "authorize"

    with {:ok, summary} <- File.read(summary_path(root, 41)),
         {:ok, document} <- summary_document(summary),
         true <-
           Map.get(document.metadata, "decision") == expected or
             {:error, "Plan 41 summary must record decision: #{expected}"} do
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
           Map.get(decoded, "subject_sha") == subject or
             {:error, "canonical receipt subject differs from Plan 42 qualification"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 42 qualified canonical receipt metadata is malformed"}
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
    total = total_plans(mode)

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
             lifecycle
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
         _lifecycle
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
         _mode,
         lifecycle
       ) do
    expected = branch_roadmap_detail(lifecycle, summarized_count, completed_count, pending_count)

    if String.contains?(section, expected) do
      :ok
    else
      {:error,
       "roadmap detail must report exactly the #{lifecycle} branch at " <>
         "#{summarized_count}/#{total_plans_for_lifecycle(lifecycle)} summarized"}
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

        _ when plan in [27, 32, 37] ->
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
    total = total_plans(mode)

    with :ok <- validate_state(root, summarized_count, lifecycle, total),
         :ok <- validate_requirements(root, requirements_complete?) do
      :ok
    end
  end

  defp validate_state(root, summarized_count, lifecycle, total) do
    {expected_status, expected_plan} =
      case lifecycle do
        :qualified_success -> {"complete", 37}
        :qualified_success_42 -> {"complete", 42}
        lifecycle when lifecycle in [:stopped_42, :failed_42] -> {"blocked", 42}
        lifecycle when lifecycle in [:stopped, :failed] -> {"blocked", 37}
        _ -> {"executing", summarized_count + 1}
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

  defp total_plans(:historical_snapshot), do: 17
  defp total_plans(mode) when mode in [:repair_execution, :repair_execution_complete], do: 32
  defp total_plans(mode) when mode in [:branch_execution, :branch_execution_complete], do: 37
  defp total_plans(mode) when mode in [:execution, :execution_complete], do: 42

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
       when mode in [
              :execution,
              :execution_complete,
              :branch_execution,
              :branch_execution_complete
            ] do
    intro =
      "Plans 01–32 and their earlier validation addenda remain immutable. The records below map every runnable automated command/failure pair for branch-aware Plans 133-33 through 133-37 in source order. Plans 33–34 are executed; Plans 35–37 remain pending until their own summaries exist. The Plan 36 human decision is authorization-only and never acceptance evidence."

    @branch_heading <> "\n\n" <> intro <> "\n\n" <> Enum.map_join(records, "\n", &render_record/1)
  end

  defp render_record(record) do
    """
    <pending-validation key="#{record.key}">
    <automated>
    #{record.command}
    </automated>
    <fails_when>
    #{record.failure}
    </fails_when>
    <state>#{record.state}</state>
    <acceptance-credit>#{record.credit}</acceptance-credit>
    </pending-validation>
    """
  end

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
