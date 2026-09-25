defmodule Rindle.ValidatePhase133ThreatInventory do
  @ids ~w(T-133-71 T-133-102 T-133-33-SC T-133-34-05 T-133-34-SC T-133-35-SC T-133-36-05 T-133-36-SC T-133-37-SC T-133-38-SC T-133-39-SC T-133-40-SC T-133-41-05 T-133-41-SC T-133-42-SC)
  @high_ids ~w(T-133-32 T-133-53 T-133-74 T-133-85 T-133-91 T-133-105 T-133-39-03 T-133-42-03)
  @proofs %{
    "T-133-71" =>
      {"scripts/ci/test_verify_nightly_run.sh", "bash scripts/ci/test_verify_nightly_run.sh",
       "zero exact matches poll until timeout without a receipt"},
    "T-133-102" =>
      {"test/install_smoke/phase_133_security_disclosure_test.exs",
       "MIX_ENV=test mix test test/install_smoke/phase_133_security_disclosure_test.exs --seed 0",
       "T-133-102: Plan 26 documentation contains no credential canary"},
    "T-133-33-SC" =>
      {"scripts/ci/test_phase_133_package_manager_guards.sh",
       "scripts/ci/test_phase_133_package_manager_guards.sh", "T-133-33-SC"},
    "T-133-34-05" =>
      {"test/install_smoke/phase_133_reconciliation_test.exs",
       "MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs --only disclosure_canary --seed 0",
       "T-133-34-05: reconciliation diagnostics never echo raw planning canaries"},
    "T-133-34-SC" =>
      {"scripts/ci/test_phase_133_package_manager_guards.sh",
       "scripts/ci/test_phase_133_package_manager_guards.sh", "T-133-34-SC"},
    "T-133-35-SC" =>
      {"scripts/ci/test_phase_133_package_manager_guards.sh",
       "scripts/ci/test_phase_133_package_manager_guards.sh", "T-133-35-SC"},
    "T-133-36-05" =>
      {"test/install_smoke/phase_133_security_disclosure_test.exs",
       "MIX_ENV=test mix test test/install_smoke/phase_133_security_disclosure_test.exs --seed 0",
       "T-133-36-05 and T-133-41-05: checkpoint records expose only safe public text"},
    "T-133-36-SC" =>
      {"scripts/ci/test_phase_133_package_manager_guards.sh",
       "scripts/ci/test_phase_133_package_manager_guards.sh", "T-133-36-SC"},
    "T-133-37-SC" =>
      {"scripts/ci/test_phase_133_package_manager_guards.sh",
       "scripts/ci/test_phase_133_package_manager_guards.sh", "T-133-37-SC"},
    "T-133-38-SC" =>
      {"scripts/ci/test_phase_133_package_manager_guards.sh",
       "scripts/ci/test_phase_133_package_manager_guards.sh", "T-133-38-SC"},
    "T-133-39-SC" =>
      {"scripts/ci/test_phase_133_package_manager_guards.sh",
       "scripts/ci/test_phase_133_package_manager_guards.sh", "T-133-39-SC"},
    "T-133-40-SC" =>
      {"scripts/ci/test_phase_133_package_manager_guards.sh",
       "scripts/ci/test_phase_133_package_manager_guards.sh", "T-133-40-SC"},
    "T-133-41-05" =>
      {"test/install_smoke/phase_133_security_disclosure_test.exs",
       "MIX_ENV=test mix test test/install_smoke/phase_133_security_disclosure_test.exs --seed 0",
       "T-133-36-05 and T-133-41-05: checkpoint records expose only safe public text"},
    "T-133-41-SC" =>
      {"scripts/ci/test_phase_133_package_manager_guards.sh",
       "scripts/ci/test_phase_133_package_manager_guards.sh", "T-133-41-SC"},
    "T-133-42-SC" =>
      {"scripts/ci/test_phase_133_package_manager_guards.sh",
       "scripts/ci/test_phase_133_package_manager_guards.sh", "T-133-42-SC"}
  }
  @subject "87bd35cdcf040018a854a0e8c5a6ebc0b9438e53"
  @report_commit "35c94a50c861d2bf84f16172be20a97d20d685e2"
  @report_sha "706bd2bf5b1162907ab60a7cf910f40a5242cc203190f5578f098dd4647a9a65"
  @record_sha "3818feb8ba37b4291de53f9da5b245cc861a8719f8fc4cc0f4afe8d0fb4adf09"
  @phase ".planning/phases/133-evidence-charter-and-live-truth"

  def main(argv) do
    with {:ok, root, inventory_path, security_path} <- options(argv),
         {:ok, data} <- read_json(inventory_path),
         :ok <- validate(root, data, security_path) do
      IO.puts(
        "phase 133 threat inventory valid: 15 exact-ID findings have current executable disposition proofs"
      )

      0
    else
      {:error, message} ->
        IO.puts(:stderr, "[validate-phase-133-threat-inventory] #{message}")
        1
    end
  end

  defp options(argv) do
    case OptionParser.parse(argv,
           strict: [root: :string, inventory: :string, security_report: :string]
         ) do
      {[root: root], [], []} ->
        root = Path.expand(root)

        {:ok, root, Path.join(root, Path.join(@phase, "133-SECURITY-INVENTORY.json")),
         Path.join(root, Path.join(@phase, "133-SECURITY.md"))}

      {[root: root, inventory: inventory], [], []} ->
        root = Path.expand(root)
        {:ok, root, Path.expand(inventory), Path.join(root, Path.join(@phase, "133-SECURITY.md"))}

      {[root: root, security_report: security_report], [], []} ->
        root = Path.expand(root)

        {:ok, root, Path.join(root, Path.join(@phase, "133-SECURITY-INVENTORY.json")),
         Path.expand(security_report)}

      {[root: root, inventory: inventory, security_report: security_report], [], []} ->
        {:ok, Path.expand(root), Path.expand(inventory), Path.expand(security_report)}

      _ ->
        {:error, "expected --root ROOT [--inventory FILE] [--security-report FILE]"}
    end
  end

  defp validate(root, data, security_path) do
    provenance = data["provenance"] || %{}
    items = data["items"] || []

    with true <- data["schema_version"] == 1 or {:error, "unsupported schema version"},
         true <- data["mode"] == "recovered" or {:error, "provenance mode must be recovered"},
         true <- data["audited_subject"] == @subject or {:error, "audited subject mismatch"},
         :ok <- valid_current_binding(root, data["binding"]),
         :ok <- valid_provenance(root, provenance),
         true <-
           data["unresolved_high_ids"] == ["T-133-53", "T-133-91"] or
             {:error, "unresolved high threats changed"},
         true <-
           Enum.sort(Enum.map(items, & &1["id"])) == Enum.sort(@ids) or
             {:error, "finding universe is missing, duplicated, or contains a synthetic ID"},
         :ok <- validate_items(root, items, data["binding"]),
         :ok <- current_security_verified(security_path, data["binding"], items),
         :ok <- execute_proof_commands(root, items, data["binding"]) do
      :ok
    else
      {:error, message} -> {:error, message}
      false -> {:error, "inventory contract failed"}
      _ -> {:error, "malformed inventory"}
    end
  end

  defp valid_current_binding(root, binding) when is_map(binding) do
    ledger_path = Path.join(root, Path.join(@phase, "133-EVIDENCE-CENSUS.json"))

    with {:ok, census} <- File.read(ledger_path),
         {:ok, ledger} <- Jason.decode(census),
         true <-
           binding["subject_sha"] == ledger["subject_sha"] or
             {:error, "bound subject differs from census"},
         true <-
           binding["census_sha256"] ==
             :crypto.hash(:sha256, census) |> Base.encode16(case: :lower) or
             {:error, "bound census digest differs"} do
      :ok
    else
      {:error, message} -> {:error, message}
      _ -> {:error, "inventory subject/census binding is malformed"}
    end
  end

  defp valid_current_binding(_root, _),
    do: {:error, "inventory subject/census binding is malformed"}

  defp valid_provenance(root, provenance) do
    with true <-
           provenance["report_commit"] == @report_commit or
             {:error, "auditor report commit mismatch"},
         true <-
           provenance["report_parent_subject"] == @subject or
             {:error, "auditor subject binding mismatch"},
         true <-
           provenance["report_sha256"] == @report_sha or
             {:error, "auditor report digest mismatch"},
         true <-
           provenance["raw_record_sha256"] == @record_sha or
             {:error, "auditor record digest mismatch"},
         true <-
           provenance["record_ordinal"] == 348 or {:error, "auditor record location mismatch"},
         true <-
           provenance["auditor_role"] == "gsd-security-auditor" or
             {:error, "auditor role missing"},
         {:ok, parent} <- git(root, ["show", "-s", "--format=%P", @report_commit]),
         true <-
           String.trim(parent) == @subject or
             {:error, "auditor report commit is not parented to audited subject"},
         {:ok, report} <- git(root, ["show", "#{@report_commit}:#{@phase}/133-SECURITY.md"]),
         true <-
           (String.contains?(report, "threats_open: 8") and
              String.contains?(report, "threats_open_total: 23")) or
             {:error, "committed audit report lacks aggregate provenance"} do
      :ok
    else
      {:error, message} -> {:error, message}
      false -> {:error, "auditor provenance invalid"}
      _ -> {:error, "auditor provenance cannot be read"}
    end
  end

  defp validate_items(root, items, binding) do
    Enum.reduce_while(items, :ok, fn item, :ok ->
      source = item["source"] || %{}
      evidence = item["evidence"] || %{}
      id = item["id"]

      result =
        with true <- item["severity"] == "low" or {:error, "#{id}: severity mismatch"},
             true <-
               item["historical_disposition"] == "accept" or
                 {:error, "#{id}: historical disposition changed"},
             true <-
               item["current_disposition"] in ["closed", "dispositioned"] or
                 {:error, "#{id}: current disposition is open or unsupported"},
             true <-
               (evidence["auditor_report_commit"] == @report_commit and
                  is_binary(evidence["reason"]) and byte_size(evidence["reason"]) > 20) or
                 {:error, "#{id}: missing disposition evidence"},
             :ok <- validate_executable_proof(root, id, evidence["proof"], binding),
             true <-
               (source["commit"] == @subject and is_integer(source["line"]) and source["line"] > 0) or
                 {:error, "#{id}: source location mismatch"},
             {:ok, blob} <- git(root, ["rev-parse", "#{@subject}:#{source["path"]}"]),
             true <-
               String.trim(blob) == source["blob_sha"] or {:error, "#{id}: source blob mismatch"},
             {:ok, body} <- git(root, ["show", "#{@subject}:#{source["path"]}"]),
             row when is_binary(row) <- Enum.at(String.split(body, "\n"), source["line"] - 1),
             true <- row == source["row"] or {:error, "#{id}: source row text mismatch"},
             true <-
               :crypto.hash(:sha256, row) |> Base.encode16(case: :lower) == source["row_sha256"] or
                 {:error, "#{id}: source row digest mismatch"},
             true <-
               (String.starts_with?(row, "| #{id} |") and
                  String.contains?(row, "| low | accept |")) or
                 {:error, "#{id}: source row does not back finding"} do
          :ok
        else
          {:error, message} -> {:error, message}
          _ -> {:error, "#{id}: source row missing, changed, or has no executable evidence"}
        end

      case result do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_executable_proof(root, id, proof, binding) when is_map(proof) do
    {path, command, assertion} = Map.fetch!(@proofs, id)
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

  defp execute_proof_commands(root, items, binding) do
    subject = binding["subject_sha"]

    audit_root =
      Path.join(
        System.tmp_dir!(),
        "phase133-security-proof-#{System.unique_integer([:positive])}"
      )

    try do
      with {_, 0} <-
             System.cmd(
               "git",
               ["clone", "--quiet", "--shared", "--no-checkout", root, audit_root],
               stderr_to_stdout: true
             ),
           {_, 0} <-
             System.cmd("git", ["checkout", "--quiet", "--detach", subject],
               cd: audit_root,
               stderr_to_stdout: true
             ) do
        build_cache = Path.join(root, "_build")

        if File.dir?(build_cache) do
          File.ln_s!(build_cache, Path.join(audit_root, "_build"))
        end

        commands =
          items
          |> Enum.map(&get_in(&1, ["evidence", "proof", "command"]))
          |> Enum.uniq()

        Enum.reduce_while(commands, :ok, fn command, :ok ->
          case System.cmd("bash", ["-lc", command],
                 cd: audit_root,
                 env: [
                   {"ASDF_ERLANG_VERSION", "27.3.4.15"},
                   {"ASDF_ELIXIR_VERSION", "1.17.3-otp-27"},
                   {"MIX_ENV", "test"},
                   {"MIX_DEPS_PATH", Path.join(root, "deps")},
                   {"MIX_BUILD_PATH", Path.join(audit_root, "_build")}
                 ],
                 stderr_to_stdout: true
               ) do
            {_output, 0} ->
              {:cont, :ok}

            {output, status} ->
              {:halt,
               {:error,
                "exact-subject executable proof command failed (#{status}): #{command}: #{String.trim(output)}"}}
          end
        end)
      else
        {output, status} ->
          {:error,
           "could not prepare clean proof checkout at #{subject} (#{status}): #{String.trim(output)}"}
      end
    after
      File.rm_rf(audit_root)
    end
  end

  defp current_security_verified(path, binding, items) do
    case File.read(path) do
      {:ok, body} ->
        with {:ok, frontmatter} <- strict_frontmatter(body),
             true <-
               frontmatter["status"] == "verified" or {:error, "security status is not verified"},
             true <-
               frontmatter["subject_sha"] == binding["subject_sha"] or
                 {:error, "security subject binding mismatch"},
             true <-
               frontmatter["census_sha256"] == binding["census_sha256"] or
                 {:error, "security census binding mismatch"},
             true <-
               frontmatter["threats_open"] == "0" or {:error, "security report has open threats"},
             true <-
               all_rows_dispositioned?(body, @high_ids, ["closed"]) or
                 {:error, "security report leaves a named high threat open"},
             true <-
               all_rows_dispositioned?(body, @ids, ["closed", "dispositioned"]) or
                 {:error, "security report leaves an inventory finding open"},
             true <-
               Enum.all?(items, &(&1["current_disposition"] in ["closed", "dispositioned"])) or
                 {:error, "inventory still has open findings"} do
          :ok
        else
          {:error, message} -> {:error, message}
          _ -> {:error, "current security report is malformed or incomplete"}
        end

      _ ->
        {:error, "current security report missing"}
    end
  end

  defp strict_frontmatter(body) do
    with [text] <- Regex.run(~r/\A---\s*\n(.*?)\n---/s, body, capture: :all_but_first),
         fields <- ["status", "subject_sha", "census_sha256", "threats_open"],
         values <-
           Map.new(fields, fn field ->
             matches =
               Regex.scan(~r/^#{Regex.escape(field)}:\s*(.*?)\s*$/m, text,
                 capture: :all_but_first
               )

             {field,
              case matches do
                [[value]] -> value
                _ -> nil
              end}
           end),
         true <- Enum.all?(fields, &is_binary(values[&1])) do
      {:ok, values}
    else
      _ -> {:error, "security report frontmatter missing or ambiguous"}
    end
  end

  defp all_rows_dispositioned?(body, ids, accepted) do
    with {:ok, table} <- threat_register_table(body) do
      lines = String.split(table, "\n")

      Enum.all?(ids, fn id ->
        rows = Enum.filter(lines, &Regex.match?(~r/^\|\s*#{Regex.escape(id)}\s*\|/i, &1))

        case rows do
          [row] ->
            columns =
              row
              |> String.split("|")
              |> Enum.map(&String.trim/1)
              |> Enum.reject(&(&1 == ""))

            expected_severity = if id in @high_ids, do: "high", else: "low"
            Enum.at(columns, 3) == expected_severity and List.last(columns) in accepted

          _ ->
            false
        end
      end)
    else
      _ -> false
    end
  end

  defp threat_register_table(body) do
    headings = Regex.scan(~r/^## Threat Register\s*$/m, body)

    sections =
      Regex.scan(~r/^## Threat Register\s*\n(.*?)(?=^## |\z)/ms, body, capture: :all_but_first)

    case {headings, sections} do
      {[_], [[section]]} ->
        visible =
          section
          |> then(&Regex.replace(~r/<!--.*?-->/s, &1, ""))
          |> then(&Regex.replace(~r/^```[^\n]*\n.*?^```[ \t]*$/ms, &1, ""))
          |> then(&Regex.replace(~r/^~~~[^\n]*\n.*?^~~~[ \t]*$/ms, &1, ""))

        {:ok, visible}

      _ ->
        {:error, "security report must contain one threat-register table"}
    end
  end

  defp read_json(path) do
    with {:ok, body} <- File.read(path),
         {:ok, data} <- Jason.decode(body),
         do: {:ok, data},
         else: (_ -> {:error, "inventory missing or invalid JSON"})
  end

  defp git(root, args) do
    case System.cmd("git", args, cd: root, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {_, _} -> {:error, "git provenance lookup failed: #{Enum.join(args, " ")}"}
    end
  end
end

System.halt(Rindle.ValidatePhase133ThreatInventory.main(System.argv()))
