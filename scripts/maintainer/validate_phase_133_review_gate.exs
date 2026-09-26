defmodule Rindle.ValidatePhase133ReviewGate do
  @moduledoc false
  @phase ".planning/phases/133-evidence-charter-and-live-truth"
  @inventory_ids ~w(T-133-71 T-133-102 T-133-33-SC T-133-34-05 T-133-34-SC T-133-35-SC T-133-36-05 T-133-36-SC T-133-37-SC T-133-38-SC T-133-39-SC T-133-40-SC T-133-41-05 T-133-41-SC T-133-42-SC)
  @high_ids ~w(T-133-32 T-133-53 T-133-74 T-133-85 T-133-91 T-133-105 T-133-39-03 T-133-42-03)
  @review_ids ~w(CR-01 CR-02 CR-03 CR-04 CR-05 CR-06 CR-07 CR-08 CR-09 CR-10 WR-01 WR-02 WR-03)
  @package_proof_ids ~w(T-133-33-SC T-133-34-SC T-133-35-SC T-133-36-SC T-133-37-SC T-133-38-SC T-133-39-SC T-133-40-SC T-133-41-SC T-133-42-SC)
  @package_proof_path "scripts/ci/test_phase_133_package_manager_guards.sh"
  @package_proof_command "scripts/ci/test_phase_133_package_manager_guards.sh"
  @frozen_validation_bytes 148_104
  @frozen_validation_sha256 "57eb4b1f46b7852bdda6cfbc399b62eb0fe35d6283d0139c892c4a8310698a5d"

  def main(argv) do
    with {:ok, root, report_root, subject} <- options(argv),
         :ok <- validate(root, report_root, subject) do
      IO.puts("phase 133 independent review gate valid for #{subject}")
      0
    else
      {:error, message} ->
        IO.puts(:stderr, "[validate-phase-133-review-gate] #{message}")
        1
    end
  end

  defp options(argv) do
    case OptionParser.parse(argv, strict: [root: :string, report_root: :string, subject: :string]) do
      {opts, [], []} when is_list(opts) ->
        root = Keyword.get(opts, :root)
        subject = Keyword.get(opts, :subject)

        if is_binary(root) and is_binary(subject) and Regex.match?(~r/\A[0-9a-f]{40}\z/, subject) do
          root = Path.expand(root)

          report_root =
            Keyword.get(opts, :report_root) |> then(&if(&1, do: Path.expand(&1), else: root))

          {:ok, root, report_root, subject}
        else
          {:error, "subject must be a lowercase 40-character commit SHA and root is required"}
        end

      _ ->
        {:error, "expected --root ROOT [--report-root DIR] --subject SHA"}
    end
  end

  defp validate(root, reports, subject) do
    with {:ok, census} <- read(reports, "133-EVIDENCE-CENSUS.json"),
         {:ok, ledger} <- Jason.decode(census),
         true <- ledger["subject_sha"] == subject or {:error, "census subject mismatch"},
         digest <- :crypto.hash(:sha256, census) |> Base.encode16(case: :lower),
         {:ok, summary} <- read(reports, "133-52-SUMMARY.md"),
         :ok <- bound_metadata(summary, subject, digest, "Plan 52 summary"),
         {:ok, review} <- read(reports, "133-REVIEW.md"),
         :ok <- strict_frontmatter(review, subject, digest, "review"),
         :ok <- review_contract(review),
         {:ok, validation} <- read(reports, "133-VALIDATION.md"),
         :ok <- safe_validation_contract(validation, subject, digest),
         {:ok, security} <- read(reports, "133-SECURITY.md"),
         :ok <- strict_frontmatter(security, subject, digest, "security"),
         :ok <- security_contract(security, reports),
         :ok <- inventory_matches(root, reports, security) do
      :ok
    else
      {:error, message} -> {:error, message}
      false -> {:error, "census subject mismatch"}
      _ -> {:error, "malformed report set"}
    end
  end

  defp strict_frontmatter(body, subject, digest, label) do
    with {:ok, fields} <- frontmatter(body),
         true <-
           fields["subject_sha"] == subject or {:error, "#{label} subject binding mismatch"},
         true <-
           fields["census_sha256"] == digest or {:error, "#{label} census binding mismatch"},
         true <-
           Regex.scan(~r/^subject_sha:\s*[0-9a-f]{40}\s*$/m, frontmatter_text(body)) |> length() ==
             1 or {:error, "#{label} subject binding is ambiguous"},
         true <-
           Regex.scan(~r/^census_sha256:\s*[0-9a-f]{64}\s*$/m, frontmatter_text(body)) |> length() ==
             1 or {:error, "#{label} census binding is ambiguous"} do
      :ok
    else
      {:error, message} -> {:error, message}
      _ -> {:error, "#{label} frontmatter is missing or malformed"}
    end
  end

  defp frontmatter_text(body) do
    case Regex.run(~r/\A---\s*\n(.*?)\n---/s, body, capture: :all_but_first) do
      [text] -> text
      _ -> ""
    end
  end

  defp frontmatter(body) do
    text = frontmatter_text(body)

    blocks =
      Regex.scan(~r/(?:\A|\n)---[ \t]*\n.*?\n---[ \t]*(?=\n|\z)/s, body)

    cond do
      text == "" -> {:error, "frontmatter missing"}
      length(blocks) != 1 -> {:error, "report must contain exactly one bounded frontmatter block"}
      true -> {:ok, parse_yaml_subset(text)}
    end
  end

  defp strict_report_fields(body, fields) do
    text = frontmatter_text(body)
    body_text = remove_frontmatter(body, text)

    Enum.reduce_while(fields, {:ok, %{}}, fn field, {:ok, parsed} ->
      matches =
        Regex.scan(~r/^#{Regex.escape(field)}:\s*(.*?)\s*$/m, text, capture: :all_but_first)
        |> List.flatten()

      case matches do
        [value] ->
          contradictory =
            Regex.scan(~r/^\s*#{Regex.escape(field)}:\s*(.*?)\s*$/m, body_text,
              capture: :all_but_first
            )
            |> List.flatten()
            |> Enum.any?(&(&1 != value))

          if contradictory do
            {:halt, {:error, "report contains contradictory #{field} values outside frontmatter"}}
          else
            {:cont, {:ok, Map.put(parsed, field, value)}}
          end

        _ ->
          {:halt, {:error, "frontmatter must contain exactly one #{field} field"}}
      end
    end)
  end

  defp remove_frontmatter(body, text) do
    Regex.replace(
      ~r/\A---[ \t]*\n.*?\n---[ \t]*(?:\n|\z)/s,
      body,
      "",
      global: false
    )
    |> then(fn remainder -> if remainder == body, do: text, else: remainder end)
  end

  defp parse_yaml_subset(text) do
    text
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ":", parts: 2) do
        [key, value] -> Map.put(acc, String.trim(key), String.trim(value) |> String.trim("\\\""))
        _ -> acc
      end
    end)
  end

  defp bound_metadata(body, subject, digest, label) do
    fields =
      Regex.scan(~r/^\*\*Subject SHA:\*\* ([0-9a-f]{40})\s*$/m, body, capture: :all_but_first)
      |> List.flatten()

    digests =
      Regex.scan(~r/^\*\*Census SHA-256:\*\* ([0-9a-f]{64})\s*$/m, body, capture: :all_but_first)
      |> List.flatten()

    if fields == [subject] and digests == [digest],
      do: :ok,
      else:
        {:error, "#{label} has absent, stale, duplicate, or mismatched subject/census binding"}
  end

  defp review_contract(body) do
    signoff = signoff_section(body)

    with {:ok, fields} <- strict_report_fields(body, ["status", "blocking"]),
         {:ok, visible_body} <-
           visible_markdown(remove_frontmatter(body, frontmatter_text(body))),
         failures <- review_disposition_failures(visible_body),
         true <- fields["status"] == "approved" or {:error, "review is not approved"},
         true <- fields["blocking"] == "0" or {:error, "review has blocking findings"},
         true <-
           failures == [] or
             {:error, "review dispositions are incomplete: #{Enum.join(failures, ", ")}"},
         true <-
           Regex.match?(~r/^- \[x\] No blocking findings\s*$/mi, signoff) or
             {:error, "review sign-off is incomplete"} do
      :ok
    else
      {:error, message} ->
        {:error, message}

      _ ->
        {:error, "review frontmatter, dispositions, or sign-off is malformed"}
    end
  end

  defp review_disposition_failures(body) do
    Enum.reject(@review_ids, fn id ->
      Regex.match?(
        ~r/^\|?\s*#{Regex.escape(id)}\s*\|[^\n]*(?:closed|fixed|dispositioned)(?:[^\n]*)$/im,
        body
      ) or
        Regex.match?(
          ~r/^[-*]\s*#{Regex.escape(id)}\b[^\n]*(?:closed|fixed|dispositioned)/im,
          body
        )
    end)
  end

  # Finding dispositions are evidence, so examples inside Markdown code fences
  # cannot satisfy the report gate. An unclosed fence is malformed evidence.
  defp visible_markdown(body) do
    body
    |> String.split("\n")
    |> Enum.reduce_while({:ok, [], nil}, fn line, {:ok, visible, fence} ->
      case {fence, Regex.run(~r/^\s*(`{3,}|~{3,})(.*)$/, line)} do
        {nil, [_, marker, _info]} ->
          {:cont, {:ok, visible, {String.first(marker), byte_size(marker)}}}

        {{char, size}, [_, marker, info]} ->
          if String.first(marker) == char and byte_size(marker) >= size and
               String.trim(info) == "" do
            {:cont, {:ok, visible, nil}}
          else
            {:cont, {:ok, visible, fence}}
          end

        {nil, nil} ->
          {:cont, {:ok, [line | visible], nil}}

        {_open_fence, _} ->
          {:cont, {:ok, visible, fence}}
      end
    end)
    |> case do
      {:ok, _visible, fence} when not is_nil(fence) ->
        {:error, "review contains an unclosed code fence"}

      {:ok, visible, nil} ->
        {:ok, visible |> Enum.reverse() |> Enum.join("\n")}
    end
  end

  defp safe_validation_contract(body, subject, digest) do
    try do
      validation_contract(body, subject, digest)
    catch
      {:validation_prefix, message} -> {:error, message}
    end
  end

  defp validation_contract(body, subject, digest) do
    prefix =
      if byte_size(body) >= @frozen_validation_bytes,
        do: binary_part(body, 0, @frozen_validation_bytes),
        else: ""

    prefix_digest = :crypto.hash(:sha256, prefix) |> Base.encode16(case: :lower)

    if prefix_digest != @frozen_validation_sha256,
      do:
        throw(
          {:validation_prefix,
           "frozen validation prefix changed (#{byte_size(body)} bytes; digest #{prefix_digest})"}
        )

    headings = Regex.scan(~r/^## Current Independent Validation Verdict\s*$/m, body)

    sections =
      Regex.scan(~r/^## Current Independent Validation Verdict\s*\n(.*?)(?=^## |\z)/ms, body,
        capture: :all_but_first
      )

    case {headings, sections} do
      {[_], [[section]]} ->
        checks = [
          {Regex.scan(~r/^subject_sha:\s*#{Regex.escape(subject)}\s*$/m, section), "subject_sha"},
          {Regex.scan(~r/^census_sha256:\s*#{Regex.escape(digest)}\s*$/m, section),
           "census_sha256"},
          {Regex.scan(~r/^nyquist_compliant:\s*true\s*$/m, section), "nyquist_compliant"},
          {Regex.scan(~r/^production_path_mutation_proof:\s*passed\s*$/m, section),
           "production_path_mutation_proof"},
          {Regex.scan(~r/^- \[x\] Production path mutation proof passed\s*$/m, section),
           "sign-off"}
        ]

        case Enum.find(checks, fn {matches, _} -> length(matches) != 1 end) do
          nil ->
            :ok

          {_matches, label} ->
            {:error, "current validation verdict missing or ambiguous #{label}"}
        end

      _ ->
        {:error, "current independent validation verdict section must appear exactly once"}
    end
  end

  defp security_contract(body, reports) do
    with {:ok, fields} <- strict_report_fields(body, ["status", "threats_open"]),
         true <- fields["status"] == "verified" or {:error, "security report is not verified"},
         true <- fields["threats_open"] == "0" or {:error, "security report has open threats"},
         :ok <- require_disposition_rows(body, @high_ids),
         {:ok, inventory_text} <- read(reports, "133-SECURITY-INVENTORY.json"),
         {:ok, inventory} <- Jason.decode(inventory_text),
         {:ok, census} <- read(reports, "133-EVIDENCE-CENSUS.json"),
         {:ok, ledger} <- Jason.decode(census),
         binding when is_map(binding) <- inventory["binding"],
         true <-
           binding["subject_sha"] == ledger["subject_sha"] or
             {:error, "security inventory subject binding mismatch"},
         true <-
           binding["census_sha256"] ==
             :crypto.hash(:sha256, census) |> Base.encode16(case: :lower) or
             {:error, "security inventory census binding mismatch"},
         true <-
           inventory["mode"] == "recovered" or
             {:error, "security inventory is not source-recovered"},
         items when is_list(items) <- inventory["items"],
         true <-
           Enum.sort(Enum.map(items, & &1["id"])) == Enum.sort(@inventory_ids) or
             {:error, "security inventory identities are incomplete, duplicated, or synthetic"},
         :ok <- require_disposition_rows(body, @inventory_ids),
         true <-
           not Regex.match?(~r/^\|\s*T-133-OTHER[^|]*\|/m, body) or
             {:error, "synthetic security finding identifier is forbidden"} do
      :ok
    else
      {:error, message} -> {:error, message}
      false -> {:error, "security inventory disposition contract failed"}
      _ -> {:error, "security inventory is malformed"}
    end
  end

  defp inventory_matches(root, reports, security) do
    with {:ok, text} <- read(reports, "133-SECURITY-INVENTORY.json"),
         {:ok, data} <- Jason.decode(text),
         items when is_list(items) <- data["items"] do
      result =
        Enum.reduce_while(items, :ok, fn item, :ok ->
          source = item["source"] || %{}
          id = item["id"]
          status = item["current_disposition"]
          row_status = if status in ["closed", "dispositioned"], do: status, else: "__open__"

          with true <-
                 item["historical_disposition"] == "accept" or
                   {:error, "#{id}: source disposition mismatch"},
               true <- row_status != "__open__" or {:error, "#{id}: inventory still open"},
               proof when is_binary(proof) and byte_size(proof) > 12 <-
                 get_in(item, ["evidence", "disposition_proof"]) ||
                   {:error, "#{id}: disposition proof missing"},
               :ok <-
                 validate_executable_proof(root, id, item["evidence"]["proof"], data["binding"]),
               {:ok, blob} <- git(root, ["rev-parse", "#{source["commit"]}:#{source["path"]}"]),
               true <-
                 String.trim(blob) == source["blob_sha"] or
                   {:error, "#{id}: source blob mismatch"},
               {:ok, body} <- git(root, ["show", "#{source["commit"]}:#{source["path"]}"]),
               row when is_binary(row) <- Enum.at(String.split(body, "\n"), source["line"] - 1),
               true <-
                 (row == source["row"] and String.starts_with?(row, "| #{id} |")) or
                   {:error, "#{id}: source row mismatch"},
               true <-
                 :crypto.hash(:sha256, row) |> Base.encode16(case: :lower) == source["row_sha256"] or
                   {:error, "#{id}: source row digest mismatch"},
               true <-
                 Regex.match?(
                   ~r/^\|\s*#{Regex.escape(id)}\s*\|[^\n]*\|\s*#{Regex.escape(status)}\s*\|\s*$/im,
                   security
                 ) or {:error, "#{id}: report and inventory disposition disagree"} do
            {:cont, :ok}
          else
            {:error, message} -> {:halt, {:error, message}}
            _ -> {:halt, {:error, "#{id}: source evidence is invalid"}}
          end
        end)

      with :ok <- result do
        run_inventory_validator(root, reports)
      end
    else
      {:error, message} -> {:error, message}
      _ -> {:error, "security inventory source evidence is malformed"}
    end
  end

  defp validate_executable_proof(root, id, proof, binding) when is_map(proof) do
    {path, command, assertion} = expected_proof(id)
    subject = binding["subject_sha"]

    with true <- proof["subject_sha"] == subject or {:error, "#{id}: proof subject mismatch"},
         true <-
           proof["census_sha256"] == binding["census_sha256"] or
             {:error, "#{id}: proof census mismatch"},
         true <- proof["path"] == path or {:error, "#{id}: proof file mismatch"},
         true <- proof["command"] == command or {:error, "#{id}: proof command mismatch"},
         true <- proof["assertion"] == assertion or {:error, "#{id}: proof assertion mismatch"},
         true <- proof["result"] == "passed" or {:error, "#{id}: proof result is not passing"},
         {:ok, body} <- File.read(Path.join(root, path)),
         digest <- :crypto.hash(:sha256, body) |> Base.encode16(case: :lower),
         true <- digest == proof["file_sha256"] or {:error, "#{id}: proof file digest mismatch"},
         {:ok, committed_body} <- git(root, ["show", "#{subject}:#{path}"]),
         true <-
           committed_body == body or {:error, "#{id}: proof file differs from census subject"},
         true <-
           String.contains?(body, assertion) or
             {:error, "#{id}: proof assertion missing from source"} do
      :ok
    else
      {:error, message} -> {:error, message}
      false -> {:error, "#{id}: executable proof metadata is invalid"}
      _ -> {:error, "#{id}: executable proof source cannot be read"}
    end
  end

  defp validate_executable_proof(_root, id, _proof, _binding),
    do: {:error, "#{id}: executable proof metadata is required"}

  defp run_inventory_validator(root, reports) do
    inventory = Path.join(reports, Path.join(@phase, "133-SECURITY-INVENTORY.json"))
    security = Path.join(reports, Path.join(@phase, "133-SECURITY.md"))

    case System.cmd(
           "mix",
           [
             "run",
             "--no-start",
             "--no-deps-check",
             "--no-compile",
             "scripts/maintainer/validate_phase_133_threat_inventory.exs",
             "--root",
             root,
             "--inventory",
             inventory,
             "--security-report",
             security
           ],
           cd: root,
           env: [
             {"ASDF_ERLANG_VERSION", "27.3.4.15"},
             {"ASDF_ELIXIR_VERSION", "1.17.3-otp-27"},
             {"MIX_ENV", "test"}
           ],
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        :ok

      {output, status} ->
        {:error,
         "executable security inventory validation failed (#{status}): #{String.trim(output)}"}
    end
  end

  defp expected_proof(id) when id in @package_proof_ids,
    do: {@package_proof_path, @package_proof_command, id}

  defp expected_proof("T-133-71"),
    do:
      {"scripts/ci/test_verify_nightly_run.sh", "bash scripts/ci/test_verify_nightly_run.sh",
       "zero exact matches poll until timeout without a receipt"}

  defp expected_proof("T-133-102"),
    do:
      {"test/install_smoke/phase_133_security_disclosure_test.exs",
       "MIX_ENV=test mix test test/install_smoke/phase_133_security_disclosure_test.exs --seed 0",
       "T-133-102: Plan 26 documentation contains no credential canary"}

  defp expected_proof("T-133-34-05"),
    do:
      {"test/install_smoke/phase_133_reconciliation_test.exs",
       "MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs --only disclosure_canary --seed 0",
       "T-133-34-05: reconciliation diagnostics never echo raw planning canaries"}

  defp expected_proof(id) when id in ["T-133-36-05", "T-133-41-05"],
    do:
      {"test/install_smoke/phase_133_security_disclosure_test.exs",
       "MIX_ENV=test mix test test/install_smoke/phase_133_security_disclosure_test.exs --seed 0",
       "T-133-36-05 and T-133-41-05: checkpoint records expose only safe public text"}

  defp git(root, args) do
    case System.cmd("git", args, cd: root, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      _ -> {:error, "security source Git lookup failed"}
    end
  end

  defp require_disposition_rows(body, ids) do
    missing =
      Enum.reject(ids, fn id ->
        Regex.match?(
          ~r/^\|\s*#{Regex.escape(id)}\s*\|[^\n]*\|\s*(?:closed|dispositioned)\s*\|\s*$/im,
          body
        )
      end)

    if missing == [],
      do: :ok,
      else: {:error, "security dispositions missing or open: #{Enum.join(missing, ", ")}"}
  end

  defp signoff_section(body) do
    case Regex.run(~r/^## Sign-Off\s*\n(.*?)(?=^## |\z)/ms, body, capture: :all_but_first) do
      [section] -> section
      _ -> ""
    end
  end

  defp read(root, name) do
    case File.read(Path.join(root, Path.join(@phase, name))) do
      {:ok, body} -> {:ok, body}
      _ -> {:error, "required report is missing or unreadable: #{name}"}
    end
  end
end

System.halt(Rindle.ValidatePhase133ReviewGate.main(System.argv()))
