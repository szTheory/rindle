defmodule Rindle.ValidatePhase133Reconciliation do
  @moduledoc false

  @phase_dir ".planning/phases/133-evidence-charter-and-live-truth"
  @validation_path Path.join(@phase_dir, "133-VALIDATION.md")
  @roadmap_path ".planning/ROADMAP.md"
  @historical_ref "6e0d96117dc26d51764a21804bd86a977784a661"
  @historical_blob "59eb44c23e693d04d579c200c1e9057d3138c72d"
  @historical_bytes 13_899
  @historical_sha256 "c3df0a578a2337f81d4539d5e8b0bc1d8ed4638d80ef1b4ce7fb424e43469bec"
  @heading "## Pending Gap-Closure Validation Addendum (Plans 11–17)"
  @pending_state "pending — not executed"

  def run(argv) do
    with {:ok, options} <- parse_options(argv),
         {:ok, root} <- resolve_root(options.root),
         {:ok, expected} <- expected_records(root),
         result <- maybe_print_addendum(options, expected),
         :continue <- result,
         :ok <- require_tracked_inputs(root),
         {:ok, historical} <- historical_preimage(root, options),
         :ok <- validate_historical_metadata(root, options, historical),
         :ok <- maybe_write_addendum(root, options, historical, expected),
         {:ok, addendum} <- validate_validation(root, historical),
         {:ok, actual} <- parse_addendum(addendum),
         :ok <- compare_records(expected, actual),
         :ok <- validate_roadmap(root) do
      IO.puts(
        "phase 133 reconciliation valid: 10 completed, 7 pending plans, #{length(expected)} verification pairs"
      )

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
      print_addendum: :boolean,
      write_addendum: :boolean
    ]

    case OptionParser.parse(argv, strict: switches) do
      {options, [], []} ->
        values = Map.new(options)
        fixture_ref = values[:fixture_historical_ref]
        fixture_sha = values[:fixture_historical_sha256]

        cond do
          is_nil(fixture_ref) != is_nil(fixture_sha) ->
            {:error, "fixture historical ref and digest must be supplied together"}

          not is_nil(fixture_sha) and not Regex.match?(~r/\A[0-9a-f]{64}\z/, fixture_sha) ->
            {:error, "fixture historical digest must be lowercase SHA-256"}

          true ->
            {:ok,
             %{
               root: values[:root],
               fixture_ref: fixture_ref,
               fixture_sha: fixture_sha,
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

  defp maybe_print_addendum(%{print_addendum: true}, records) do
    IO.write(render_addendum(records))
    :printed
  end

  defp maybe_print_addendum(_options, _records), do: :continue

  defp maybe_write_addendum(root, %{write_addendum: true}, historical, records) do
    path = Path.join(root, @validation_path)

    case File.read(path) do
      {:ok, ^historical} -> File.write(path, historical <> render_addendum(records))
      {:ok, _other} -> {:error, "historical prefix gate requires the untouched committed validation preimage"}
      {:error, _reason} -> {:error, "validation input is unreadable"}
    end
  end

  defp maybe_write_addendum(_root, _options, _historical, _records), do: :ok

  defp require_tracked_inputs(root) do
    paths =
      [@roadmap_path, @validation_path] ++
        Enum.map(11..17, &Path.join(@phase_dir, "133-#{&1}-PLAN.md"))

    case git(root, ["ls-files", "--error-unmatch" | paths]) do
      {:ok, _output} -> :ok
      {:error, _message} -> {:error, "production reconciliation input is missing or untracked"}
    end
  end

  defp historical_preimage(root, options) do
    ref = options.fixture_ref || @historical_ref

    case git(root, ["show", "#{ref}:#{@validation_path}"], trim: false) do
      {:ok, bytes} ->
        expected_sha = options.fixture_sha || @historical_sha256

        if sha256(bytes) == expected_sha do
          {:ok, bytes}
        else
          {:error, "historical prefix digest differs from recorded preimage"}
        end

      {:error, _message} ->
        {:error, "historical commit:path preimage is unreadable"}
    end
  end

  defp validate_historical_metadata(_root, %{fixture_ref: ref}, historical) when is_binary(ref) do
    if byte_size(historical) > 0, do: :ok, else: {:error, "historical prefix is empty"}
  end

  defp validate_historical_metadata(root, _options, historical) do
    with {:ok, blob} <- git(root, ["rev-parse", "#{@historical_ref}:#{@validation_path}"]),
         true <- blob == @historical_blob or {:error, "historical Git blob identity differs"},
         true <- byte_size(historical) == @historical_bytes or {:error, "historical prefix byte length differs"},
         true <- String.contains?(historical, "19/19 automated implementation tasks") or
                   {:error, "historical 19/19 result is missing"},
         true <- Regex.match?(~r/\| Gaps found \| 0 \|/, historical) or
                   {:error, "historical zero-gap audit is missing"} do
      :ok
    else
      {:error, _message} = error -> error
      false -> {:error, "historical metadata differs"}
    end
  end

  defp validate_validation(root, historical) do
    path = Path.join(root, @validation_path)

    with {:ok, current} <- File.read(path),
         true <- String.starts_with?(current, historical) or
                   {:error, "historical prefix differs byte-for-byte from recorded preimage"},
         rest <- binary_part(current, byte_size(historical), byte_size(current) - byte_size(historical)),
         true <- String.starts_with?(rest, @heading) or
                   {:error, "historical prefix boundary does not begin with the exact addendum heading"},
         1 <- length(:binary.matches(current, @heading)) do
      {:ok, binary_part(rest, byte_size(@heading), byte_size(rest) - byte_size(@heading))}
    else
      {:error, _message} = error -> error
      _count -> {:error, "addendum heading must appear exactly once"}
    end
  end

  defp expected_records(root) do
    Enum.reduce_while(11..17, {:ok, []}, fn plan, {:ok, all} ->
      path = Path.join(root, Path.join(@phase_dir, "133-#{plan}-PLAN.md"))

      case File.read(path) do
        {:ok, contents} ->
          case parse_plan(contents, plan) do
            {:ok, records} -> {:cont, {:ok, all ++ records}}
            {:error, message} -> {:halt, {:error, "133-#{plan} #{message}"}}
          end

        {:error, _reason} ->
          {:halt, {:error, "missing plan 133-#{plan}"}}
      end
    end)
  end

  defp parse_plan(contents, plan) do
    task_matches = Regex.scan(~r/<task\b([^>]*)>(.*?)<\/task>/s, contents, capture: :all_but_first)
    task_openers = length(Regex.scan(~r/<task\b/s, contents))
    task_closers = length(Regex.scan(~r/<\/task>/s, contents))

    cond do
      task_matches == [] ->
        {:error, "has no parseable tasks"}

      task_openers != length(task_matches) or task_closers != length(task_matches) ->
        {:error, "contains malformed task markup"}

      true ->
        with {:ok, task_records} <- parse_tasks(task_matches, plan),
             outside_tasks <- Regex.replace(~r/<task\b[^>]*>.*?<\/task>/s, contents, ""),
             [plan_verification] <-
               Regex.scan(~r/^\s*<verification>\s*\n(.*?)^\s*<\/verification>\s*$/ms, outside_tasks,
                 capture: :all_but_first
               ),
             [body] <- plan_verification,
             {:ok, pairs} <- parse_plan_pairs(body),
             plan_records <- records_for("133-#{plan}-plan-verification", pairs, "pending") do
          {:ok, task_records ++ plan_records}
        else
          {:error, message} -> {:error, message}
          _ -> {:error, "contains ambiguous plan-level verification markup"}
        end
    end
  end

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
              credit = if String.contains?(attributes, "checkpoint:"), do: "authorization-only", else: "pending"
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
        normalized = Enum.map(pairs, fn [command, failure] -> {String.trim(command), String.trim(failure)} end)

        if Enum.any?(normalized, fn {command, failure} -> command == "" or failure == "" end) do
          {:error, "verification markup contains an empty command or failure direction"}
        else
          {:ok, normalized}
        end
    end
  end

  defp parse_pairs(body, pairs) do
    if String.trim(body) == "" do
      if pairs == [], do: {:error, "verification markup has no pairs"}, else: {:ok, Enum.reverse(pairs)}
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
      %{key: "#{source}:#{pair}", command: command, failure: failure, state: @pending_state, credit: credit}
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
            got.command != wanted.command -> {:halt, {:error, "command text differs for #{wanted.key}"}}
            got.failure != wanted.failure -> {:halt, {:error, "failure text differs for #{wanted.key}"}}
            got.state != @pending_state -> {:halt, {:error, "pending state differs for #{wanted.key}"}}
            got.credit != wanted.credit -> {:halt, {:error, "acceptance credit differs for #{wanted.key}"}}
            true -> {:cont, :ok}
          end
        end)
    end
  end

  defp validate_roadmap(root) do
    with {:ok, roadmap} <- File.read(Path.join(root, @roadmap_path)),
         [section] <-
           Regex.run(
             ~r/### Phase 133: Evidence Charter and Live Truth(.*?)(?=\n### Phase 134:|\z)/s,
             roadmap,
             capture: :all_but_first
           ),
         true <- String.contains?(section, "**Plans**: 10/17 plans executed; 7 pending gap closure") or
                   {:error, "roadmap status must report 10/17 plans executed; 7 pending gap closure"},
         :ok <- validate_roadmap_plans(section) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "roadmap Phase 133 section is missing or ambiguous"}
    end
  end

  defp validate_roadmap_plans(section) do
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

             cond do
               length(Regex.scan(~r/^- \[ \] #{Regex.escape(id)}(?:\s| |$)/m, section)) == 1 ->
                 {:cont, :ok}

               true ->
                 {:halt, {:error, "pending plan #{id} must remain unchecked exactly once"}}
             end
           end) do
      :ok
    end
  end

  defp render_addendum(records) do
    intro =
      "Plans 01–10 remain the immutable historical 19/19 green record above. The records below describe unexecuted Plans 11–17 only; every runnable command/failure pair stays pending, and the Plan 17 authorization checkpoint carries no acceptance credit."

    @heading <> "\n\n" <> intro <> "\n\n" <> Enum.map_join(records, "\n", &render_record/1)
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
      {output, 0} -> {:ok, if(Keyword.get(options, :trim, true), do: String.trim(output), else: output)}
      {_output, _status} -> {:error, "git command failed"}
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
