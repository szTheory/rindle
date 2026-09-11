defmodule Rindle.ValidatePhase133Reconciliation do
  @moduledoc false

  @phase_dir ".planning/phases/133-evidence-charter-and-live-truth"
  @validation_path Path.join(@phase_dir, "133-VALIDATION.md")
  @roadmap_path ".planning/ROADMAP.md"
  @historical_ref "6e0d96117dc26d51764a21804bd86a977784a661"
  @historical_blob "59eb44c23e693d04d579c200c1e9057d3138c72d"
  @historical_bytes 13_899
  @historical_sha256 "c3df0a578a2337f81d4539d5e8b0bc1d8ed4638d80ef1b4ce7fb424e43469bec"
  @historical_heading "## Pending Gap-Closure Validation Addendum (Plans 11–17)"
  @active_ref "31d62831f63081ef399f6b6c9cd0923ecb2e0753"
  @active_bytes 35_039
  @active_sha256 "dd2969dd61588c3738a4cdf580ca65ead6335e46b4885ca83ba0532c193d23ac"
  @active_heading "## Pending Gap-Closure Validation Addendum (Plans 18–22)"
  @pending_state "pending — not executed"

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
         {:ok, completed} <- validate_summaries_and_roadmap(root, mode) do
      IO.puts(success_message(mode, completed, length(expected)))

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

          true ->
            {:ok,
             %{
               root: values[:root],
               fixture_ref: fixture_ref,
               fixture_sha: fixture_sha,
               active_ref: active_ref,
               active_sha: active_sha,
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
  defp validation_mode(%{expect_execution_complete: true}), do: :execution_complete
  defp validation_mode(_options), do: :execution

  defp success_message(:historical_snapshot, _completed, pair_count),
    do:
      "phase 133 reconciliation valid: 10 completed, 7 pending plans, #{pair_count} verification pairs"

  defp success_message(mode, completed, pair_count)
       when mode in [:execution, :execution_complete] do
    "phase 133 reconciliation valid: #{completed} completed, #{22 - completed} pending plans, " <>
      "#{pair_count} pending verification pairs"
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
    plans = if mode == :historical_snapshot, do: 11..17, else: 11..22

    paths =
      [@roadmap_path, @validation_path] ++
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

        _ ->
          {options.active_ref || @active_ref, options.active_sha || @active_sha256}
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
       when mode in [:execution, :execution_complete] and is_binary(ref) do
    if byte_size(prefix) > 0, do: :ok, else: {:error, "historical validation prefix is empty"}
  end

  defp validate_prefix_metadata(root, _options, mode, prefix)
       when mode in [:execution, :execution_complete] do
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

  defp validate_validation(root, prefix, mode) do
    path = Path.join(root, @validation_path)
    heading = if mode == :historical_snapshot, do: @historical_heading, else: @active_heading

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
         1 <- length(:binary.matches(current, heading)) do
      {:ok, binary_part(rest, byte_size(heading), byte_size(rest) - byte_size(heading))}
    else
      {:error, _message} = error -> error
      _count -> {:error, "addendum heading must appear exactly once"}
    end
  end

  defp expected_records(root, mode) do
    plans = if mode == :historical_snapshot, do: 11..17, else: 18..22

    Enum.reduce_while(plans, {:ok, []}, fn plan, {:ok, all} ->
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
             plan_records <- records_for("133-#{plan}-plan-verification", pairs, "pending") do
          {:ok, task_records ++ plan_records ++ post_summary_records}
        else
          {:error, message} -> {:error, message}
          _ -> {:error, "contains ambiguous plan-level verification markup"}
        end
    end
  end

  defp parse_post_summary(contents, 22, mode) when mode in [:execution, :execution_complete] do
    pattern = ~r/<post_summary_phase_gate\b[^>]*>(.*?)<\/post_summary_phase_gate>/s

    case Regex.scan(pattern, contents, capture: :all_but_first) do
      [[body]] ->
        with {:ok, pairs} <- parse_plan_pairs(body),
             true <-
               length(pairs) == 1 or {:error, "post-summary gate must contain exactly one pair"} do
          {:ok, records_for("133-22-post-summary", pairs, "pending"),
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

              {:cont, {:ok, all ++ records_for(source, pairs, credit)}}

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

  defp records_for(source, pairs, credit) do
    pairs
    |> Enum.with_index(1)
    |> Enum.map(fn {{command, failure}, pair} ->
      %{
        key: "#{source}:#{pair}",
        command: command,
        failure: failure,
        state: @pending_state,
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
        {:error, "extra mapping is not present in Plans 11-17: #{hd(extra)}"}

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

            got.state != @pending_state ->
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
       when mode in [:execution, :execution_complete] do
    with {:ok, completed} <- completed_summary_set(root),
         :ok <- validate_execution_summary_set(completed, mode),
         :ok <- validate_execution_roadmap(root, completed, mode) do
      {:ok, MapSet.size(completed)}
    end
  end

  defp completed_summary_set(root) do
    Enum.reduce_while(1..22, {:ok, MapSet.new()}, fn plan, {:ok, completed} ->
      plan_id = String.pad_leading(Integer.to_string(plan), 2, "0")
      path = Path.join(root, Path.join(@phase_dir, "133-#{plan_id}-SUMMARY.md"))

      case File.read(path) do
        {:ok, summary} ->
          if Regex.match?(~r/^status:\s*complete\s*$/m, summary) do
            {:cont, {:ok, MapSet.put(completed, plan)}}
          else
            {:halt, {:error, "completed summary 133-#{plan_id} is not status: complete"}}
          end

        {:error, :enoent} ->
          {:cont, {:ok, completed}}

        {:error, _reason} ->
          {:halt, {:error, "completed summary 133-#{plan_id} is unreadable"}}
      end
    end)
  end

  defp validate_execution_summary_set(completed, :execution) do
    cond do
      not MapSet.subset?(MapSet.new(1..17), completed) ->
        {:error, "historical completed summaries 133-01 through 133-17 must remain complete"}

      MapSet.member?(completed, 22) ->
        {:error, "Plan 22 must remain pending until the post-summary phase gate"}

      true ->
        :ok
    end
  end

  defp validate_execution_summary_set(completed, :execution_complete) do
    missing = Enum.reject(1..22, &MapSet.member?(completed, &1))

    case missing do
      [] ->
        :ok

      [plan | _] ->
        {:error,
         "completed summary 133-#{String.pad_leading(Integer.to_string(plan), 2, "0")} is missing or unreadable"}
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

  defp validate_execution_roadmap(root, completed, mode) do
    expected_count = MapSet.size(completed)

    with {:ok, roadmap} <- File.read(Path.join(root, @roadmap_path)),
         [section] <-
           Regex.run(
             ~r/### Phase 133: Evidence Charter and Live Truth(.*?)(?=\n### Phase 134:|\z)/s,
             roadmap,
             capture: :all_but_first
           ),
         :ok <- validate_execution_detail(section, expected_count),
         :ok <- validate_execution_checkboxes(section, completed, mode),
         :ok <- validate_execution_progress_row(roadmap, expected_count) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "roadmap Phase 133 section is missing or ambiguous"}
    end
  end

  defp validate_execution_detail(section, expected_count) do
    expected = "**Plans**: #{expected_count}/22 plans executed"

    if length(Regex.scan(~r/^#{Regex.escape(expected)}$/m, section)) == 1 do
      :ok
    else
      {:error, "roadmap detail must report exactly #{expected_count}/22 plans executed"}
    end
  end

  defp validate_execution_checkboxes(section, completed, mode) do
    Enum.reduce_while(1..22, :ok, fn plan, :ok ->
      id = "133-#{String.pad_leading(Integer.to_string(plan), 2, "0")}-PLAN.md"

      captures =
        Regex.scan(~r/^- \[([ x])\] #{Regex.escape(id)}(?:\s| |$)/m, section,
          capture: :all_but_first
        )

      expected_checked = MapSet.member?(completed, plan)

      case captures do
        [[checkbox]] when checkbox == "x" == expected_checked ->
          {:cont, :ok}

        _ when plan == 22 and mode == :execution ->
          {:halt, {:error, "Plan 22 must remain pending until the post-summary phase gate"}}

        _ ->
          {:halt, {:error, "summary/checkbox mismatch for #{id}"}}
      end
    end)
  end

  defp validate_execution_progress_row(roadmap, expected_count) do
    pattern =
      ~r/^\|\s*133\.\s*Evidence Charter and Live Truth\s*\|\s*(\d+)\/22\s*\|\s*([^|]+)\|\s*([^|]*)\|$/m

    case Regex.scan(pattern, roadmap, capture: :all_but_first) do
      [[count, status, completed]] ->
        if count == Integer.to_string(expected_count) and String.trim(status) == "In Progress" and
             String.trim(completed) == "" do
          :ok
        else
          {:error,
           "roadmap Progress row must agree at #{expected_count}/22 with In Progress and blank completion date"}
        end

      _ ->
        {:error, "roadmap Progress row is missing or ambiguous"}
    end
  end

  defp render_addendum(records, :historical_snapshot) do
    intro =
      "Plans 01–10 remain the immutable historical 19/19 green record above. The records below describe unexecuted Plans 11–17 only; every runnable command/failure pair stays pending, and the Plan 17 authorization checkpoint carries no acceptance credit."

    @historical_heading <>
      "\n\n" <> intro <> "\n\n" <> Enum.map_join(records, "\n", &render_record/1)
  end

  defp render_addendum(records, mode) when mode in [:execution, :execution_complete] do
    intro =
      "Plans 01–17 remain immutable historical validation. The records below preserve the planned verification pairs for Plans 18–22 after execution; every pair remains pending evidence history, and the Plan 22 checkpoint carries authorization-only acceptance credit."

    @active_heading <> "\n\n" <> intro <> "\n\n" <> Enum.map_join(records, "\n", &render_record/1)
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
