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
  @historical_ref "6e0d96117dc26d51764a21804bd86a977784a661"
  @historical_blob "59eb44c23e693d04d579c200c1e9057d3138c72d"
  @historical_bytes 13_899
  @historical_sha256 "c3df0a578a2337f81d4539d5e8b0bc1d8ed4638d80ef1b4ce7fb424e43469bec"
  @historical_heading "## Pending Gap-Closure Validation Addendum (Plans 11–17)"
  @active_ref "9adf7c74dd32239a373963ad0d30d00a6d143b93"
  @active_bytes 68_572
  @active_sha256 "a2ae3b34457aabf84ba9d18d1f2f099e1266e3e1e12f0381539f16bf8988b9c0"
  @active_heading "## Gap-Repair Validation Addendum (Plans 28–32)"
  @pending_state "pending — not executed"
  @halted_state "halted — immutable failed evidence"
  @halted_credit "failure-history-only"
  @failed_run "34661043059"
  @failed_subject "0f8189ddeed7e7a52b5c7464f17b70ab44596c33"
  @failed_ref "phase-133-evidence-0f8189ddeed7"
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

  defp success_message(mode, summary_state, pair_count)
       when mode in [:execution, :execution_complete] do
    completed = MapSet.size(summary_state.completed)
    halted = MapSet.size(summary_state.halted)
    summarized = completed + halted
    pending = 32 - summarized

    "phase 133 reconciliation valid: #{completed} completed, #{halted} halted, " <>
      "#{pending} pending plans, #{summarized}/32 summarized, " <>
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
    plans = if mode == :historical_snapshot, do: 11..17, else: 28..32

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
    plans = if mode == :historical_snapshot, do: 11..17, else: 28..32
    initial = if mode == :historical_snapshot, do: [], else: [halted_history_record()]

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
             plan_records <- records_for("133-#{plan}-plan-verification", pairs, "pending") do
          {:ok, task_records ++ plan_records ++ post_summary_records}
        else
          {:error, message} -> {:error, message}
          _ -> {:error, "contains ambiguous plan-level verification markup"}
        end
    end
  end

  defp parse_post_summary(contents, 27, mode) when mode in [:execution, :execution_complete] do
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
       when mode in [:execution, :execution_complete] do
    with {:ok, summary_state} <- summary_state(root),
         :ok <- validate_execution_summary_state(summary_state, mode),
         :ok <- validate_execution_roadmap(root, summary_state) do
      {:ok, summary_state}
    end
  end

  defp summary_state(root) do
    initial = %{completed: MapSet.new(), halted: MapSet.new()}

    Enum.reduce_while(1..32, {:ok, initial}, fn plan, {:ok, state} ->
      plan_id = String.pad_leading(Integer.to_string(plan), 2, "0")
      path = Path.join(root, Path.join(@phase_dir, "133-#{plan_id}-SUMMARY.md"))

      case File.read(path) do
        {:ok, summary} ->
          case summary_document(summary) do
            {:ok, %{status: "complete"}} when plan == 27 ->
              {:halt, {:error, "Plan 27 must remain halted and cannot be status: complete"}}

            {:ok, %{status: "complete"}} ->
              {:cont, {:ok, %{state | completed: MapSet.put(state.completed, plan)}}}

            {:ok, %{status: "halted"} = document} when plan == 27 ->
              case validate_halted_summary(document) do
                :ok -> {:cont, {:ok, %{state | halted: MapSet.put(state.halted, plan)}}}
                {:error, reason} -> {:halt, {:error, "halted summary 133-27 #{reason}"}}
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

  defp validate_halted_summary(document) do
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
    with true <-
           MapSet.subset?(MapSet.new(1..26), summary_state.completed) or
             {:error, "historical completed summaries 133-01 through 133-26 must remain complete"},
         true <-
           summary_state.halted == MapSet.new([27]) or
             {:error, "Plan 27 must remain the sole halted summary"},
         :ok <- validate_repair_dependencies(summary_state.completed),
         :ok <- validate_execution_complete_state(summary_state, mode) do
      :ok
    else
      {:error, _message} = error -> error
      false -> {:error, "Phase 133 summary state differs from the required topology"}
    end
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

  defp validate_execution_complete_state(_summary_state, :execution), do: :ok

  defp validate_execution_complete_state(summary_state, :execution_complete) do
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

  defp validate_execution_roadmap(root, summary_state) do
    completed_count = MapSet.size(summary_state.completed)
    halted_count = MapSet.size(summary_state.halted)
    summarized_count = completed_count + halted_count
    pending_count = 32 - summarized_count

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
             pending_count
           ),
         :ok <- validate_execution_checkboxes(section, summary_state.completed),
         :ok <- validate_execution_progress_row(roadmap, summarized_count) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "roadmap Phase 133 section is missing or ambiguous"}
    end
  end

  defp validate_execution_detail(section, summarized_count, completed_count, pending_count) do
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

  defp validate_execution_checkboxes(section, completed) do
    Enum.reduce_while(1..32, :ok, fn plan, :ok ->
      id = "133-#{String.pad_leading(Integer.to_string(plan), 2, "0")}-PLAN.md"

      captures =
        Regex.scan(~r/^- \[([ x])\] #{Regex.escape(id)}(?:\s| |$)/m, section,
          capture: :all_but_first
        )

      expected_checked = MapSet.member?(completed, plan)

      case captures do
        [[checkbox]] when checkbox == "x" == expected_checked ->
          {:cont, :ok}

        _ when plan == 27 ->
          {:halt, {:error, "Plan 27 must remain unchecked while halted"}}

        _ ->
          {:halt, {:error, "summary/checkbox mismatch for #{id}"}}
      end
    end)
  end

  defp validate_execution_progress_row(roadmap, summarized_count) do
    pattern =
      ~r/^\|\s*133\.\s*Evidence Charter and Live Truth\s*\|\s*(\d+)\/32\s*\|\s*([^|]+)\|\s*([^|]*)\|$/m

    case Regex.scan(pattern, roadmap, capture: :all_but_first) do
      [[count, status, completed]] ->
        if count == Integer.to_string(summarized_count) and
             String.trim(status) == "In Progress" and
             String.trim(completed) == "" do
          :ok
        else
          {:error,
           "roadmap Progress row must agree at #{summarized_count}/32 with In Progress and blank completion date"}
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
      "Plans 01–27 remain immutable validation history. Plan 133-27 stays halted on its exact failed run, attempt, subject, and ref with no acceptance credit. The records below preserve every automated command/failure pair for repair Plans 133-28 through 133-32 in source order; their execution state remains separate from this ownership ledger."

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
