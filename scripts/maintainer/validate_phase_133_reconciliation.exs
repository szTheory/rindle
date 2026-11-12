unless Code.ensure_loaded?(YamlElixir) do
  repo_root = Path.expand("../..", __DIR__)

  build_root =
    case System.get_env("MIX_BUILD_PATH") do
      path when is_binary(path) and path != "" -> Path.expand(path, repo_root)
      _ -> Path.join(repo_root, "_build")
    end

  ebin_paths =
    ["test", "dev", ""]
    |> Enum.map(&Path.join([build_root, &1, "lib"]))
    |> Enum.find_value(fn build_lib ->
      paths = Path.wildcard(Path.join(build_lib, "*/ebin"))

      if Enum.any?(paths, &File.exists?(Path.join(&1, "Elixir.YamlElixir.beam"))),
        do: paths
    end)

  if is_nil(ebin_paths) do
    raise "[validate-phase-133-reconciliation] compiled YAML dependency is unavailable under the configured build root"
  end

  Enum.each(ebin_paths, &Code.prepend_path/1)
end

unless Code.ensure_loaded?(Rindle.ValidateEvidenceCensus) do
  System.put_env("RINDLE_EVIDENCE_CENSUS_VALIDATOR_LIBRARY_ONLY", "1")
  Code.require_file("validate_evidence_census.exs", __DIR__)
  System.delete_env("RINDLE_EVIDENCE_CENSUS_VALIDATOR_LIBRARY_ONLY")
end

defmodule Rindle.ValidatePhase133Reconciliation do
  @moduledoc false

  @phase_dir ".planning/phases/133-evidence-charter-and-live-truth"
  @plan278_sealed_history_files_by_plan %{
    "205" => ~w(
      133-205-FIXTURE-DECISION-211.json
      133-205-FIXTURE-DECISION.json
      133-205-PLAN.md
      133-205-SUMMARY.md
    ),
    "217" => ~w(
      133-217-LOCAL.json
      133-217-PLAN.md
      133-217-SUMMARY.md
    ),
    "240" => ~w(
      133-240-CODE-REVIEW.md
      133-240-PLAN.md
      133-240-PREREQ.json
      133-240-STOP.json
      133-240-SUMMARY.md
    ),
    "243" => ~w(
      133-243-BUILD-DECISION.json
      133-243-CODE-REVIEW.md
      133-243-PLAN.md
      133-243-PREREQ.json
      133-243-REVIEW-ADMISSION.json
      133-243-REVIEW.md
      133-243-STOP.json
      133-243-SUMMARY.md
      133-243-SUPPLY.json
    ),
    "275" => ~w(
      133-275-CODE-REVIEW.md
      133-275-HOST-ATTEMPT.json
      133-275-HOST-RESULT.json
      133-275-PLAN.md
      133-275-SUMMARY.md
    )
  }
  @plan278_reviewed_files ~w(
    scripts/ci/install_ffmpeg.sh
    scripts/ci/test_verify_nightly_run.sh
    scripts/ci/verify_nightly_run.sh
    scripts/maintainer/live_residue_allowlist/automation_generators.json
    scripts/maintainer/scan_live_residue.exs
    scripts/maintainer/validate_phase_133_reconciliation.exs
    test/install_smoke/ci_cache_hygiene_test.exs
    test/install_smoke/live_residue_scan_test.exs
    test/install_smoke/phase_133_reconciliation_test.exs
  )
  @plan278_requirements ".planning/REQUIREMENTS.md"
  @plan278_census Path.join(@phase_dir, "133-EVIDENCE-CENSUS.json")
  @plan278_nightly Path.join(@phase_dir, "133-NIGHTLY-EVIDENCE.json")
  @plan278_journal Path.join(@phase_dir, "133-278-TRANSACTION.json")
  @plan278_terminal Path.join(@phase_dir, "133-278-TERMINAL.json")
  @plan279_reviewed_files ~w(
    .github/workflows/release.yml
    scripts/ci/test_readiness_runs.sh
    scripts/maintainer/validate_exact_head_readiness.exs
    scripts/maintainer/validate_live_truth.exs
    scripts/maintainer/validate_phase_133_reconciliation.exs
    test/install_smoke/ci_lane_split_test.exs
    test/install_smoke/evidence_census_test.exs
    test/install_smoke/live_truth_parity_test.exs
    test/install_smoke/phase_133_reconciliation_test.exs
    test/install_smoke/quality_signal_policy_test.exs
    test/install_smoke/release_guard_meta_test.exs
    test/rindle/admin/queries_test.exs
  )
  @plan279_journal Path.join(@phase_dir, "133-279-TRANSACTION.json")
  @plan279_terminal Path.join(@phase_dir, "133-279-TERMINAL.json")
  @validation_path Path.join(@phase_dir, "133-VALIDATION.md")
  @census_path Path.join(@phase_dir, "133-EVIDENCE-CENSUS.json")
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
  @plans_53_heading "## Plans 53–54 Gap-Closure Addendum"
  @plans_55_heading "## Plans 55–57 Gap-Closure Addendum"
  @legacy_plans_55_heading "## Plans 55–56 Gap-Closure Addendum"
  @plans_58_heading "## Plans 58–62 Independent Qualification Addendum"
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
  @plan55_subject "9bb10539a0bccd734a4921d6a0f4d072b478332e"
  @plan55_ref "refs/heads/phase-133-evidence-9bb10539a0bc"
  @plan55_census_sha256 "df484acda67c5919427449344d749a4b5b73123a51d0cda9d774f6159bd8d484"
  @plan55_receipt_sha256 "bee4299a382df8969700915b60748e37af4b80db6675370e8e217820d93704f5"
  @plan55_prior_receipt_sha256 "1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4"
  @plan62_subject_sha "d3db09b9bd6b77aefdb778db773a638374eaa386"
  @plan62_report_sha256 "15db8492bb6cd98cbbd5dd257f863a53bebe6de9e07e318b3238c0fc77ae57f4"
  @plan62_summary_sha256 "1e1b0b5a0d993b049b99ab56792e7318b4d66aa79660ca939e9de612a86457c2"
  @plan63_runner_sha "a6385e2de171ab122516067a6b16586a99a72a04"
  @plan63_runner_tree "26c807cda6a5e7c2b05338917ecc896b90192929"
  @plan63_summary_sha256 "ea47e5ff585d8301566c2644a0fe662f211119e82b477b22a3f6ac431614ef49"
  @plan64_review_prefix_sha256 "e3691a12c52597f07db276db7ca5a11530fbbf41d0b97eefe7cf9afe5b60ee04"
  @plan64_security_prefix_sha256 "323c3d86d4f5c17232596aaafa0d09593ac55b1e207bc0bee54d7e7284f26853"
  @plan64_validation_prefix_sha256 "6f73460cefaa98cec3b93b826b91bf5e6510c0a2306ff7f6d10fcfa31569a884"
  @plan64_report_filename "133-64-JOSE-REGRESSION.json"
  @plan64_source_header_path "deps/jose/include/jose_jwt.hrl"
  @plan64_staged_header_path "_build/test/lib/jose/include/jose_jwt.hrl"
  @plan114_requirements ~w(EVID-01 EVID-02 EVID-03 EVID-04 TRUTH-08)
  @plan121_dimensions [
    "correctness",
    "maintainability",
    "security",
    "performance",
    "reliability",
    "compatibility",
    "testing",
    "documentation/accessibility",
    "packaging",
    "CI/CD",
    "release engineering",
    "repository hygiene"
  ]
  @plan114_edge_rows [
    %{"requirement" => "EVID-01", "category" => "boundary", "status" => "unresolved"},
    %{"requirement" => "EVID-01", "category" => "adjacency", "status" => "unresolved"},
    %{"requirement" => "EVID-01", "category" => "empty", "status" => "unresolved"},
    %{"requirement" => "EVID-01", "category" => "ordering", "status" => "unresolved"},
    %{"requirement" => "EVID-01", "category" => "precision", "status" => "unresolved"},
    %{"requirement" => "EVID-02", "category" => "unclassified", "status" => "unresolved"},
    %{"requirement" => "EVID-03", "category" => "boundary", "status" => "unresolved"},
    %{"requirement" => "EVID-03", "category" => "precision", "status" => "unresolved"},
    %{"requirement" => "EVID-04", "category" => "idempotency", "status" => "unresolved"},
    %{"requirement" => "EVID-04", "category" => "concurrency", "status" => "unresolved"},
    %{"requirement" => "TRUTH-08", "category" => "unclassified", "status" => "unresolved"}
  ]
  @plan49_subject_sha "68b1c82390b506da343116f49b943f05442692b0"
  @plan65_source_paths [
    "scripts/maintainer/validate_phase_133_reconciliation.exs",
    "test/install_smoke/phase_133_reconciliation_test.exs",
    "test/install_smoke/phase_133_completed_validation_test.exs"
  ]
  @plan66_report_filename "133-66-LOCAL-GATES.json"
  @plan69_report_filename "133-69-LOCAL-GATES.json"
  @plan80_report_filename "133-80-LOCAL-GATES.json"
  @plan80_halted_subject "8b0f3f022fd8b4a0a16882c4d0c823e198def141"
  @plan80_halted_tree "e62de4a4f7c8f4931c5bf3ba11d9485ad5e80405"
  @plan80_halted_summary_sha256 "8a4688be23624e5931384b748b64b210c14d2486e2908aa3bfd3bce4e2a0cbb1"
  @plan80_halted_report_sha256 "04087bcaed277124c540ecd7b2770be041f99208682eb9d0fdadc4c5faa4ed43"
  @plan80_prior_receipt_sha256 "1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4"
  @plan79_source_paths [
    "scripts/maintainer/validate_phase_133_reconciliation.exs",
    "test/install_smoke/phase_133_reconciliation_test.exs",
    "scripts/maintainer/test_validate_phase_133_reconciliation.sh",
    "scripts/maintainer/phase_133_local_gates.sh"
  ]
  @plan83_requirement_ids ~w(EVID-01 EVID-02 EVID-03 EVID-04 TRUTH-08)
  @plan69_exhausted_subject "6d58a02a1e5dee97b7d24750c7a583b4f06b4236"
  @plan69_exhausted_subjects [
    @plan49_subject_sha,
    "8e56d85c4339be69ecff482c7ee9c5611c20dc3d",
    @plan62_subject_sha,
    @plan63_runner_sha,
    "321fc8409c825101bf6080348a7205f680cc7ffe",
    @plan69_exhausted_subject,
    "c61d9f077d5cf184035d3f7b0c6d9ae975b6d7cc",
    "8c77d23212fb3c9703202a41d15b1781058b9cfc",
    "e63d2c1222763732df57fdc74757720776659a44",
    @plan80_halted_subject
  ]
  @plan69_source_paths [
    "scripts/maintainer/phase_133_local_gates.sh",
    "scripts/maintainer/test_phase_133_local_gates.sh",
    "scripts/maintainer/test_phase_133_jose_structure.sh",
    "scripts/maintainer/validate_phase_133_reconciliation.exs",
    "scripts/maintainer/test_validate_phase_133_reconciliation.sh"
  ]
  @plan66_source_reused [
    @plan49_subject_sha,
    @plan62_subject_sha,
    "321fc8409c825101bf6080348a7205f680cc7ffe"
  ]
  @plan64_source_paths [
    "scripts/maintainer/phase_133_local_gates.sh",
    "scripts/maintainer/test_phase_133_local_gates.sh",
    "scripts/maintainer/test_phase_133_jose_structure.sh",
    "scripts/maintainer/validate_phase_133_reconciliation.exs",
    "test/install_smoke/phase_133_reconciliation_test.exs",
    "test/install_smoke/phase_133_completed_validation_test.exs"
  ]
  @plan59_restricted_subject "8e56d85c4339be69ecff482c7ee9c5611c20dc3d"
  @plan59_local_gate_sha256 "fcec8727bd6955937f818ec79d91ae049452c28e231463a6663551fc8ca7a022"
  @plan55_validation_prefix_bytes 173_901
  @plan55_validation_prefix_sha256 "1245d3f95b2b2e83251e740842f95ec08edbca727e4e046bf45381434a70ac1b"
  @plan55_report_digests %{
    "133-REVIEW.md" => "d36b0d12cebcb90b43a6bdf7fae2a0e156e600b92f0e05e28cd29117517620ff",
    "133-SECURITY-INVENTORY.json" =>
      "3d8bdf58656239b4d0783398e11ff3fc8a212fc4764ba9fdf94ef616951e4521",
    "133-SECURITY.md" => "b8fc5c6d8870ab2b0b6b0ad8f1d7d1a42bec06b67e1be96ea8fc15dea78863ac"
  }
  @phase_requirements ~w(EVID-01 EVID-02 EVID-03 EVID-04 TRUTH-08)
  @plan87_subject "87572a019636ba1367c0c7245ae5cb89d0ea1909"
  @plan87_tree "800e6704aaaa85b93abc0008922fd0629b6995df"
  @plan87_summary_sha256 "00a412ccca35ede712d98248ee221e34f61e8d5887b686d0963930d5e012637f"
  @plan85_summary_sha256 "755db0769d723574b57d78da4892a0bb2512f7e2794ce741d17f5f9783727a4e"
  @plan85_report_sha256 "52adf02fc53743bd6b865e408e3a16fcb64de87b1434ac936d3955ace07a39c7"
  @plan91_report_filename "133-91-LOCAL-GATES.json"
  @plan91_summary_filename "133-91-SUMMARY.md"
  @plan91_source_paths @plan79_source_paths
  @plan91_jose_command "mix run --no-start --no-deps-check --no-compile -e <focused JOSE structure and Elixir compile>"
  @plan91_coverage_command "mix coveralls.multiple --type local --type json"
  @repair_dependencies %{30 => [28, 29], 31 => [30], 32 => [31]}

  # An unkeyed local report is never an execution attestation. Only a complete
  # green report may enter the independent census / live Nightly proof route.
  def local_gate_authority(%{"terminal" => %{"status" => status}})
      when status in ["preflight_halted", "qualification_halted"],
      do:
        {:error,
         "local halt is diagnostic_only; no qualification or attempt-consumption authority"}

  def local_gate_authority(%{"status" => "preflight_halted"}),
    do:
      {:error, "local halt is diagnostic_only; no qualification or attempt-consumption authority"}

  def local_gate_authority(report) when is_map(report) do
    terminal = Map.get(report, "terminal", %{})
    stages = Map.get(terminal, "stages", %{})

    green? =
      terminal["status"] == "locally_qualified" and terminal["attempts"] == 1 and
        terminal["first_red"] == nil and terminal["mix_child_starts"] == 4 and
        Enum.all?(~w(dependencies jose_preflight ci coverage), fn name ->
          stage = Map.get(stages, name, %{})

          stage["started"] == true and stage["invocations"] == 1 and
            stage["exit_code"] == 0 and stage["effective_exit_code"] == 0
        end)

    if green?,
      do:
        {:ok,
         %{authority: "local_candidate", attempt_consumed: false, requirements_completed: []}},
      else: {:error, "complete green local gates required before independent proof"}
  end

  def local_gate_authority(_), do: {:error, "local gates are missing"}

  def run(["--historical-126" | argv]) do
    if Enum.any?(
         argv,
         &String.starts_with?(&1, ["--expect-plan121-", "--expect-plan122-", "--expect-plan123-"])
       ) do
      IO.puts(
        "Historical Plan 126 read-only consistency; no current qualification or requirement credit"
      )

      validate_historical126(fn -> run(argv) end)
    else
      {:error, "historical mode is restricted to read-only Plan 121-123 history"}
    end
  end

  def run(argv) do
    cond do
      Enum.any?(argv, &(&1 == "--expect-plan279-terminal")) ->
        run_plan279_terminal(argv)

      Enum.any?(argv, &(&1 == "--expect-plan278-terminal")) ->
        run_plan278_terminal(argv)

      Enum.any?(argv, &String.starts_with?(&1, "--expect-plan121-")) ->
        run_plan121(argv)

      Enum.any?(argv, &String.starts_with?(&1, "--expect-plan122-")) ->
        run_plan122(argv)

      Enum.any?(argv, &String.starts_with?(&1, "--expect-plan123-")) ->
        run_plan123(argv)

      Enum.any?(argv, &String.starts_with?(&1, "--expect-plan116-")) ->
        run_plan116(argv)

      Enum.any?(argv, &String.starts_with?(&1, "--expect-plan117-")) ->
        run_plan117(argv)

      Enum.any?(argv, &String.starts_with?(&1, "--expect-plan118-")) ->
        run_plan118(argv)

      Enum.any?(argv, &(&1 == "--expect-plan112-preterminal")) ->
        run_plan112_preterminal(argv)

      Enum.any?(argv, &String.starts_with?(&1, "--expect-plan113-")) ->
        run_plan113(argv)

      Enum.any?(argv, &String.starts_with?(&1, "--expect-plan111-")) ->
        run_plan111(argv)

      true ->
        run_legacy(argv)
    end
  end

  def plan278_sealed_history(root) do
    expected =
      @plan278_sealed_history_files_by_plan
      |> Enum.flat_map(fn {_plan, names} -> Enum.map(names, &Path.join(@phase_dir, &1)) end)
      |> Enum.sort()

    actual =
      @plan278_sealed_history_files_by_plan
      |> Enum.flat_map(fn {plan, _names} ->
        Path.wildcard(Path.join([root, @phase_dir, "133-#{plan}-*"]))
        |> Enum.map(&Path.relative_to(&1, root))
      end)
      |> Enum.sort()

    cond do
      actual != expected ->
        {:error, "sealed Plan 205/217/240/243/P275 history inventory is incomplete or unexpected"}

      true ->
        Enum.reduce_while(expected, {:ok, %{}}, fn relative, {:ok, sealed} ->
          path = Path.join(root, relative)

          case File.lstat(path) do
            {:ok, %File.Stat{type: :regular}} ->
              {:cont, {:ok, Map.put(sealed, relative, file_sha(path))}}

            _ ->
              {:halt, {:error, "sealed history entry is missing or not a regular file"}}
          end
        end)
    end
  end

  def plan278_sealed_history_unchanged(root, expected) when is_map(expected) do
    case plan278_sealed_history(root) do
      {:ok, ^expected} -> :ok
      _ -> {:error, "sealed Plan 205/217/240/243/P275 history changed"}
    end
  end

  def recover_plan278_transaction(root), do: plan278_recover_journal(root)

  if Code.ensure_loaded?(ExUnit) and Process.whereis(ExUnit.Server) do
    @doc false
    def plan279_reviewed_paths_for_test, do: @plan279_reviewed_files

    @doc false
    def plan279_review_binding_for_test(bytes, sha, tree),
      do: plan279_review_binding_bytes(bytes, sha, tree)

    @doc false
    def plan279_source_for_test(active_root, source_root, sha),
      do: plan279_source(active_root, source_root, sha)

    @doc false
    def plan279_census_roots_for_test(source_root, census_a_root, census_b_root, sha, tree),
      do: plan279_census_roots(source_root, census_a_root, census_b_root, sha, tree)

    @doc false
    def plan279_sealed_history_for_test(root), do: plan278_sealed_history(root)

    @doc false
    def plan279_sealed_history_paths_for_test do
      @plan278_sealed_history_files_by_plan
      |> Enum.flat_map(fn {_plan, names} -> Enum.map(names, &Path.join(@phase_dir, &1)) end)
      |> Enum.sort()
    end

    @doc false
    def plan279_apply_transaction_for_test(root, originals, updates, postcheck) do
      root = Path.expand(root)
      terminal = Path.join(root, @plan279_terminal)
      journal = Path.join(root, @plan279_journal)

      plan279_apply_transaction(
        root,
        originals,
        updates,
        terminal,
        journal,
        "journal\n",
        "terminal\n",
        postcheck,
        &atomic_write/2
      )
    end

    @doc false
    def plan279_recover_journal_for_test(root), do: plan279_recover_journal(root)
  end

  if Code.ensure_loaded?(ExUnit) and Process.whereis(ExUnit.Server) do
    @doc false
    def plan278_census_ledger_binding_for_test(canonical, candidate, sha),
      do: plan278_census_ledger_binding(canonical, candidate, sha)

    @doc false
    def plan278_census_ledger_binding_files_for_test(
          canonical_bytes,
          candidate_path,
          sha,
          digest
        ),
        do: plan278_census_ledger_binding_files(canonical_bytes, candidate_path, sha, digest)

    @doc false
    def plan278_review_binding_digest_for_test(path, sha, tree, digest),
      do: plan278_review_binding_digest(path, sha, tree, digest)

    @doc false
    def plan278_apply_transaction_for_test(root, originals, updates, postcheck) do
      plan278_apply_transaction(
        Path.expand(root),
        originals,
        updates,
        Path.join(Path.expand(root), @plan278_terminal),
        Path.join(Path.expand(root), @plan278_journal),
        "transaction journal\n",
        "terminal proof\n",
        postcheck,
        &atomic_write/2
      )
    end

    @doc false
    def plan278_review_binding_for_test(path, sha, tree),
      do: plan278_review_binding(path, sha, tree)

    @doc false
    def plan278_sealed_history_paths_for_test do
      @plan278_sealed_history_files_by_plan
      |> Enum.flat_map(fn {_plan, names} -> Enum.map(names, &Path.join(@phase_dir, &1)) end)
      |> Enum.sort()
    end

    @doc false
    def plan278_reviewed_paths_for_test, do: @plan278_reviewed_files

    @doc false
    def plan278_interrupt_transaction_for_test(root, fail_after)
        when is_integer(fail_after) and fail_after in 1..5 do
      root = Path.expand(root)
      requirements = Path.join(root, @plan278_requirements)
      census = Path.join(root, @plan278_census)
      nightly = Path.join(root, @plan278_nightly)
      terminal = Path.join(root, @plan278_terminal)
      journal = Path.join(root, @plan278_journal)
      originals = Map.new([requirements, census, nightly], &{&1, File.read!(&1)})
      updates = Map.new([requirements, census, nightly], &{&1, "promoted:#{Path.basename(&1)}\n"})

      journal_bytes =
        Jason.encode!(%{
          "schema_version" => 1,
          "plan" => "133-278",
          "status" => "applying",
          "terminal_path" => @plan278_terminal,
          "prior_bytes" =>
            Map.new(originals, fn {path, bytes} ->
              {Path.relative_to(path, root), Base.encode64(bytes)}
            end)
        })

      terminal_bytes = "terminal:plan278\n"
      counter = :atomics.new(1, [])

      write = fn path, bytes ->
        atomic_write(path, bytes)
        write_number = :atomics.add_get(counter, 1, 1)
        if write_number == fail_after, do: throw({:plan278_interrupted, write_number})
        :ok
      end

      try do
        result =
          plan278_apply_transaction(
            root,
            originals,
            updates,
            terminal,
            journal,
            journal_bytes,
            terminal_bytes,
            fn -> :ok end,
            write
          )

        {:completed, result}
      catch
        {:plan278_interrupted, write_number} -> {:interrupted, write_number}
      end
    end

    @doc false
    def plan278_remove_terminal_failure_for_test(terminal, journal) do
      remove = fn
        ^terminal -> {:error, :eacces}
        path -> File.rm(path)
      end

      plan278_remove_terminal_and_journal(terminal, journal, remove)
    end
  end

  def plan278_requirement_paragraph(bytes) when is_binary(bytes) do
    old =
      "The five Phase 133 requirements remain pending until a fresh Plan 133-37 exact-subject receipt and\n" <>
        "the terminal automated reconciliation gates both pass. The immutable halted attempts in Plans 133-27\n" <>
        "and 133-32, a Plan 133-36 authorization stop, or a failed Plan 133-37 attempt provide history but no\n" <>
        "completion credit."

    replacement =
      "The five Phase 133 requirements remain Pending until a fresh exact-subject evidence receipt and\n" <>
        "terminal reconciliation both pass. Plans 133-27, 133-32, 133-36, and 133-37 remain immutable\n" <>
        "history and provide no completion credit."

    case :binary.matches(bytes, old) do
      [{start, length}] -> {:ok, :binary.replace(bytes, old, replacement, scope: {start, length})}
      _ -> {:error, "the stale Plan 133-37 prerequisite paragraph is not present exactly once"}
    end
  end

  defp run_plan279_terminal(argv) do
    switches = [
      root: :string,
      source_root: :string,
      census_a_root: :string,
      census_b_root: :string,
      expect_plan279_terminal: :boolean
    ]

    with {opts, [], []} <- OptionParser.parse(argv, strict: switches),
         true <- length(opts) == length(Enum.uniq_by(opts, &elem(&1, 0))),
         true <- Keyword.get(opts, :expect_plan279_terminal) == true,
         {:ok, root} <- resolve_root(Keyword.get(opts, :root)),
         source_root when is_binary(source_root) <- Keyword.get(opts, :source_root),
         census_a_root when is_binary(census_a_root) <- Keyword.get(opts, :census_a_root),
         census_b_root when is_binary(census_b_root) <- Keyword.get(opts, :census_b_root),
         {:ok, result} <-
           validate_plan279_terminal(
             root,
             Path.expand(source_root),
             Path.expand(census_a_root),
             Path.expand(census_b_root)
           ) do
      IO.puts(result)
      :ok
    else
      {:error, _} = error ->
        error

      _ ->
        {:error,
         "Plan 279 requires --expect-plan279-terminal, --root, --source-root, --census-a-root, and --census-b-root"}
    end
  end

  def validate_plan279_terminal(root, source_root, census_a_root, census_b_root) do
    p = fn name -> Path.join([root, @phase_dir, name]) end
    ci = p.("133-279-CI-EVIDENCE.json")
    review = p.("133-279-CODE-REVIEW.md")
    ledger = p.("133-279-CENSUS-LEDGER.json")
    census_a = p.("133-279-CENSUS-A.json")
    census_b = p.("133-279-CENSUS-B.json")
    nightly = p.("133-279-NIGHTLY-EVIDENCE.json")
    canonical_census = Path.join(root, @census_path)
    canonical_nightly = Path.join(root, @receipt_path)
    requirements = Path.join(root, @requirements_path)
    terminal = p.("133-279-TERMINAL.json")
    journal = p.("133-279-TRANSACTION.json")

    evidence_paths =
      [
        ci,
        review,
        ledger,
        census_a,
        census_b,
        nightly,
        requirements,
        canonical_census,
        canonical_nightly
      ]

    with :ok <- plan279_recover_journal(root),
         :ok <- plan278_preflight_paths(root, evidence_paths, [journal, terminal]),
         :ok <- plan279_files(evidence_paths),
         :ok <- plan278_pending_requirements(requirements),
         {:ok, original_requirements} <- File.read(requirements),
         requirements_sha256 <- sha256(original_requirements),
         {:ok, sha} <- plan278_ci_sha(ci),
         {:ok, tree} <- plan279_source(root, source_root, sha),
         :ok <- plan279_census_roots(source_root, census_a_root, census_b_root, sha, tree),
         {:ok, review_bytes} <- File.read(review),
         :ok <- plan279_review_binding_bytes(review_bytes, sha, tree),
         review_sha256 <- sha256(review_bytes),
         {:ok, canonical_ledger_bytes} <- File.read(canonical_census),
         {:ok, canonical_ledger} <- Jason.decode(canonical_ledger_bytes),
         {:ok, original_nightly_bytes} <- File.read(canonical_nightly),
         {:ok, candidate_ledger_bytes} <- File.read(ledger),
         {:ok, candidate_ledger} <- Jason.decode(candidate_ledger_bytes),
         :ok <- plan278_census_ledger_binding(canonical_ledger, candidate_ledger, sha),
         :ok <-
           plan279_external_validators(
             root,
             source_root,
             sha,
             ci,
             ledger,
             census_a_root,
             census_b_root,
             census_a,
             census_b,
             nightly
           ),
         {:ok, bytes_a} <- File.read(census_a),
         {:ok, bytes_b} <- File.read(census_b),
         true <-
           bytes_a == bytes_b or
             {:error, "Plan 279 census A and B receipts are not byte-identical"},
         {:ok, nightly_bytes} <- File.read(nightly),
         {:ok, sealed_history} <- plan278_sealed_history(root),
         :ok <- plan279_remote_main(source_root, sha),
         {:ok, new_census} <- plan278_promote_census(canonical_ledger_bytes, sha),
         {:ok, terminal_bytes} <-
           plan279_terminal_bytes(
             sha,
             tree,
             ledger,
             ci,
             review_sha256,
             census_a,
             census_b,
             nightly,
             sealed_history
           ),
         :ok <-
           plan279_transaction(
             root,
             canonical_census,
             canonical_ledger_bytes,
             new_census,
             canonical_nightly,
             original_nightly_bytes,
             nightly_bytes,
             terminal,
             journal,
             terminal_bytes,
             fn ->
               with :ok <- plan279_remote_main(source_root, sha),
                    {:ok, post_tree} <- plan279_source(root, source_root, sha),
                    true <- post_tree == tree,
                    :ok <-
                      plan279_census_roots(
                        source_root,
                        census_a_root,
                        census_b_root,
                        sha,
                        tree
                      ),
                    :ok <- plan279_review_binding_bytes(review_bytes, sha, tree),
                    :ok <- plan278_pending_requirements(requirements),
                    {:ok, current_requirements} <- File.read(requirements),
                    true <- sha256(current_requirements) == requirements_sha256,
                    :ok <- plan278_sealed_history_unchanged(root, sealed_history),
                    {:ok, promoted} <- File.read(canonical_census),
                    :ok <-
                      plan278_census_ledger_binding_files(
                        promoted,
                        ledger,
                        sha,
                        sha256(candidate_ledger_bytes)
                      ) do
                 :ok
               else
                 {:error, _} = error -> error
                 _ -> {:error, "Plan 279 post-promotion identity check failed"}
               end
             end
           ) do
      {:ok,
       "Plan 279 exact-subject census, CI, scheduled Nightly, review, and terminal reconciliation valid; requirements remain Pending"}
    else
      {:error, _} = error -> error
      false -> {:error, "Plan 279 exact-subject validation failed"}
      _ -> {:error, "Plan 279 terminal evidence is incomplete or malformed"}
    end
  end

  defp plan279_files(paths) do
    case Enum.find(paths, &(not File.regular?(&1))) do
      nil -> :ok
      path -> {:error, "Plan 279 evidence file is missing: #{Path.basename(path)}"}
    end
  end

  defp plan279_source(active_root, source_root, expected_sha) do
    with true <- File.dir?(source_root) or {:error, "Plan 279 source root is missing"},
         {:ok, sha} <- git(source_root, ["rev-parse", "--verify", "HEAD"]),
         {:ok, tree} <- git(source_root, ["rev-parse", "HEAD^{tree}"]),
         {:ok, status} <- git(source_root, ["status", "--porcelain", "--untracked-files=all"]),
         true <- String.trim(status) == "" or {:error, "Plan 279 source root is not clean"},
         true <-
           sha == expected_sha or
             {:error, "Plan 279 source root SHA differs from exact CI evidence"},
         :ok <- plan279_active_code_parity(active_root, source_root) do
      {:ok, tree}
    else
      {:error, _} = error -> error
      _ -> {:error, "Plan 279 source identity is invalid"}
    end
  end

  defp plan279_active_code_parity(active_root, source_root) do
    Enum.reduce_while(@plan279_reviewed_files, :ok, fn relative, :ok ->
      active = Path.join(active_root, relative)
      source = Path.join(source_root, relative)

      with {:ok, active_bytes} <- File.read(active),
           {:ok, source_bytes} <- File.read(source),
           true <- active_bytes == source_bytes do
        {:cont, :ok}
      else
        _ ->
          {:halt,
           {:error, "active Plan 279 code path differs from reviewed main source: #{relative}"}}
      end
    end)
  end

  defp plan279_census_roots(source_root, census_a_root, census_b_root, sha, tree) do
    roots = [census_a_root, census_b_root]

    with {:ok, source_toplevel} <- git(source_root, ["rev-parse", "--show-toplevel"]),
         {:ok, canonical_roots} <-
           Enum.reduce_while(roots, {:ok, []}, fn root, {:ok, acc} ->
             case git(root, ["rev-parse", "--show-toplevel"]) do
               {:ok, toplevel} -> {:cont, {:ok, [Path.expand(toplevel) | acc]}}
               _ -> {:halt, {:error, "Plan 279 census root is missing or not a Git checkout"}}
             end
           end),
         true <-
           Path.expand(source_toplevel) not in canonical_roots or
             {:error, "Plan 279 census roots must be separate from the source root"},
         true <-
           length(Enum.uniq(canonical_roots)) == 2 or
             {:error, "Plan 279 census A and B require independent roots"},
         :ok <-
           Enum.reduce_while(roots, :ok, fn root_arg, :ok ->
             root = Path.expand(root_arg)

             with {:ok, actual_sha} <- git(root, ["rev-parse", "--verify", "HEAD"]),
                  {:ok, actual_tree} <- git(root, ["rev-parse", "HEAD^{tree}"]),
                  {:ok, status} <- git(root, ["status", "--porcelain", "--untracked-files=all"]),
                  true <- actual_sha == sha and actual_tree == tree,
                  true <- census_root_detached?(root),
                  true <- String.trim(status) == "" do
               {:cont, :ok}
             else
               _ ->
                 {:halt,
                  {:error, "Plan 279 census root is not a clean detached exact-subject checkout"}}
             end
           end) do
      :ok
    else
      {:error, _} = error -> error
      _ -> {:error, "Plan 279 census roots do not independently bind to the exact source"}
    end
  end

  defp census_root_detached?(root) do
    case System.cmd("git", ["symbolic-ref", "--quiet", "HEAD"], cd: root, stderr_to_stdout: true) do
      {_branch, status} when status != 0 -> true
      _ -> false
    end
  end

  defp plan279_review_binding_bytes(bytes, sha, tree) do
    with {:ok, frontmatter, body} <- bounded_frontmatter(bytes),
         :ok <- plan278_review_frontmatter_keys(frontmatter),
         :ok <- reject_second_frontmatter(body),
         {:ok, metadata} <- decode_frontmatter(frontmatter),
         true <- metadata["phase"] == "133-279",
         true <- metadata["verdict"] == "PASS",
         true <- metadata["status"] == "clean",
         true <- metadata["source_commit"] == sha,
         true <- metadata["source_tree"] == tree,
         true <- metadata["files_reviewed"] == length(@plan279_reviewed_files),
         paths when is_list(paths) <- metadata["files_reviewed_list"],
         true <- Enum.sort(paths) == Enum.sort(@plan279_reviewed_files),
         findings when is_map(findings) <- metadata["findings"],
         true <-
           Enum.sort(Map.keys(findings)) == ~w(blocker critical info necessity total warning),
         true <- Enum.all?(Map.values(findings), &(&1 == 0)) do
      :ok
    else
      _ ->
        {:error,
         "Plan 279 independent PASS review is not bound to the exact main commit/tree and code paths"}
    end
  end

  defp plan279_external_validators(
         root,
         source_root,
         sha,
         ci,
         ledger,
         census_a_root,
         census_b_root,
         census_a,
         census_b,
         nightly
       ) do
    mix_env = [
      {"MIX_ENV", "test"},
      {"MIX_DEPS_PATH", Path.join(source_root, "deps")},
      {"MIX_BUILD_PATH", Path.join(source_root, "_build")}
    ]

    checks = [
      {"bash",
       [
         "scripts/ci/verify_nightly_run.sh",
         "verify-main-ci-receipt",
         "--repo",
         "szTheory/rindle",
         "--expected-sha",
         sha,
         "--receipt",
         ci
       ]},
      {"mix",
       [
         "run",
         "--no-start",
         "--no-deps-check",
         "--no-compile",
         "scripts/maintainer/validate_evidence_census.exs",
         "--root",
         census_a_root,
         "--ledger",
         ledger,
         "--receipt",
         census_a
       ], census_a_root},
      {"mix",
       [
         "run",
         "--no-start",
         "--no-deps-check",
         "--no-compile",
         "scripts/maintainer/validate_evidence_census.exs",
         "--root",
         census_b_root,
         "--ledger",
         ledger,
         "--receipt",
         census_b
       ], census_b_root},
      {"bash",
       [
         "scripts/ci/verify_nightly_run.sh",
         "verify-scheduled-receipt",
         "--source-root",
         source_root,
         "--evidence-root",
         root,
         "--repo",
         "szTheory/rindle",
         "--workflow",
         "nightly.yml",
         "--ref",
         "main",
         "--expected-sha",
         sha,
         "--receipt",
         nightly
       ]},
      {"mix",
       [
         "run",
         "--no-start",
         "--no-deps-check",
         "--no-compile",
         "-e",
         "Code.require_file(\"scripts/maintainer/validate_live_truth.exs\"); Rindle.ValidateLiveTruth.run([\"--root\", \".\", \"--format\", \"json\"])"
       ]}
    ]

    Enum.reduce_while(checks, :ok, fn
      {command, args, cwd}, :ok ->
        {out, status} = System.cmd(command, args, cd: cwd, env: mix_env, stderr_to_stdout: true)

        if status == 0,
          do: {:cont, :ok},
          else:
            {:halt,
             {:error,
              "Plan 279 validator failed (#{Path.basename(command)}): #{String.slice(out, 0, 400)}"}}

      {command, args}, :ok ->
        {out, status} =
          System.cmd(command, args, cd: source_root, env: mix_env, stderr_to_stdout: true)

        if status == 0,
          do: {:cont, :ok},
          else:
            {:halt,
             {:error,
              "Plan 279 validator failed (#{Path.basename(command)}): #{String.slice(out, 0, 400)}"}}
    end)
  end

  defp plan279_remote_main(source_root, expected_sha) do
    case System.cmd("git", ["ls-remote", "origin", "refs/heads/main"],
           cd: source_root,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        case String.split(String.trim(output), "\t") do
          [^expected_sha, "refs/heads/main"] -> :ok
          _ -> {:error, "remote main moved away from the exact Plan 279 subject"}
        end

      {_output, _status} ->
        {:error, "could not recheck remote main before Plan 279 promotion"}
    end
  end

  defp plan279_terminal_bytes(
         sha,
         tree,
         ledger,
         ci,
         review_sha256,
         census_a,
         census_b,
         nightly,
         sealed_history
       ) do
    proof = %{
      "schema_version" => 1,
      "plan" => "133-279",
      "status" => "validated",
      "source_sha" => sha,
      "source_tree" => tree,
      "ledger_sha256" => file_sha(ledger),
      "ci_sha256" => file_sha(ci),
      "review_sha256" => review_sha256,
      "census_a_sha256" => file_sha(census_a),
      "census_b_sha256" => file_sha(census_b),
      "nightly_sha256" => file_sha(nightly),
      "sealed_history_sha256" => sealed_history,
      "requirements_pending" => true
    }

    {:ok, Jason.encode!(proof, pretty: true) <> "\n"}
  rescue
    _ -> {:error, "Plan 279 terminal proof could not be encoded"}
  end

  defp plan279_transaction(
         root,
         canonical_census,
         original_census,
         new_census,
         canonical_nightly,
         original_nightly,
         new_nightly,
         terminal,
         journal,
         terminal_bytes,
         postcheck
       ) do
    prior = %{
      @census_path => Base.encode64(original_census),
      @receipt_path => Base.encode64(original_nightly)
    }

    plan279_apply_transaction(
      root,
      %{canonical_census => original_census, canonical_nightly => original_nightly},
      %{canonical_census => new_census, canonical_nightly => new_nightly},
      terminal,
      journal,
      Jason.encode!(
        %{
          "schema_version" => 1,
          "plan" => "133-279",
          "status" => "applying",
          "terminal_path" => @plan279_terminal,
          "prior_bytes" => prior
        },
        pretty: true
      ) <> "\n",
      terminal_bytes,
      postcheck,
      &atomic_write/2
    )
  end

  defp plan279_apply_transaction(
         root,
         originals,
         updates,
         terminal,
         journal,
         journal_bytes,
         terminal_bytes,
         postcheck,
         write
       ) do
    files = Map.keys(originals) |> Enum.sort()

    with :ok <- plan278_preflight_paths(root, files, [journal, terminal]),
         true <-
           not File.exists?(terminal) or {:error, "Plan 279 terminal artifact already exists"},
         :ok <- plan279_originals_unchanged(originals) do
      try do
        write.(journal, journal_bytes)
        Enum.each(files, &write.(&1, Map.fetch!(updates, &1)))
        write.(terminal, terminal_bytes)

        case postcheck.() do
          :ok ->
            File.rm!(journal)
            :ok

          {:error, reason} ->
            case plan278_restore_backups(Map.to_list(originals)) do
              :ok ->
                case plan278_remove_terminal_and_journal(terminal, journal) do
                  :ok ->
                    {:error,
                     "Plan 279 post-promotion check failed; canonical evidence was restored: #{reason}"}

                  {:error, rollback} ->
                    {:error,
                     "Plan 279 postcheck failed and transaction cleanup failed: #{inspect(rollback)}"}
                end

              {:error, restore} ->
                {:error, "Plan 279 rollback failed: #{inspect(restore)}"}
            end
        end
      rescue
        error ->
          case plan278_restore_backups(Map.to_list(originals)) do
            :ok ->
              case plan278_remove_terminal_and_journal(terminal, journal) do
                :ok ->
                  {:error,
                   "Plan 279 terminal transaction rolled back: #{Exception.message(error)}"}

                {:error, rollback} ->
                  {:error, "Plan 279 transaction failed and cleanup failed: #{inspect(rollback)}"}
              end

            {:error, restore} ->
              {:error, "Plan 279 transaction and rollback failed: #{inspect(restore)}"}
          end
      end
    else
      {:error, _} = error -> error
      _ -> {:error, "Plan 279 terminal paths are unsafe or terminal output already exists"}
    end
  end

  defp plan279_originals_unchanged(originals) do
    unchanged? =
      Enum.all?(originals, fn {path, expected} -> File.read(path) == {:ok, expected} end)

    if unchanged?,
      do: :ok,
      else: {:error, "Plan 279 canonical evidence changed during validation"}
  end

  defp plan279_recover_journal(root) do
    root = Path.expand(root)
    journal = Path.join(root, @plan279_journal)
    terminal = Path.join(root, @plan279_terminal)
    canonical = [Path.join(root, @census_path), Path.join(root, @receipt_path)]

    with :ok <- plan278_preflight_paths(root, [], [journal, terminal | canonical]) do
      case File.lstat(journal) do
        {:error, :enoent} ->
          :ok

        {:ok, %{type: :regular}} ->
          with {:ok, bytes} <- File.read(journal),
               {:ok, doc} <- Jason.decode(bytes),
               true <- is_map(doc),
               true <-
                 Map.keys(doc) |> Enum.sort() ==
                   ~w(plan prior_bytes schema_version status terminal_path),
               1 <- doc["schema_version"],
               "133-279" <- doc["plan"],
               "applying" <- doc["status"],
               @plan279_terminal <- doc["terminal_path"],
               prior when is_map(prior) <- doc["prior_bytes"],
               true <- Map.keys(prior) |> Enum.sort() == Enum.sort([@census_path, @receipt_path]),
               {:ok, backups} <-
                 Enum.reduce_while(prior, {:ok, []}, fn {relative, encoded}, {:ok, acc} ->
                   path = Path.expand(relative, root)

                   with true <- relative in [@census_path, @receipt_path],
                        true <- String.starts_with?(path, root <> "/"),
                        true <- is_binary(encoded),
                        {:ok, original} <- Base.decode64(encoded) do
                     {:cont, {:ok, [{path, original} | acc]}}
                   else
                     _ -> {:halt, {:error, :invalid_backup}}
                   end
                 end),
               :ok <- plan278_restore_backups(backups),
               :ok <- plan278_remove_terminal_and_journal(terminal, journal) do
            :ok
          else
            _ -> {:error, "Plan 279 journal is malformed; refusing evidence recovery"}
          end

        _ ->
          {:error, "Plan 279 journal is not a regular file"}
      end
    else
      {:error, reason} -> {:error, "Plan 279 recovery paths are unsafe: #{inspect(reason)}"}
    end
  end

  defp run_plan278_terminal(argv) do
    switches = [root: :string, source_root: :string, expect_plan278_terminal: :boolean]

    with {opts, [], []} <- OptionParser.parse(argv, strict: switches),
         true <- length(opts) == length(Enum.uniq_by(opts, &elem(&1, 0))),
         true <- Keyword.get(opts, :expect_plan278_terminal) == true,
         {:ok, root} <- resolve_root(Keyword.get(opts, :root)),
         source_root when is_binary(source_root) <- Keyword.get(opts, :source_root),
         {:ok, result} <- validate_plan278_terminal(root, Path.expand(source_root)) do
      IO.puts(result)
      :ok
    else
      {:error, _} = error ->
        error

      _ ->
        {:error, "Plan 278 requires exactly --expect-plan278-terminal, --root, and --source-root"}
    end
  end

  def validate_plan278_terminal(root, source_root) do
    phase = @phase_dir
    p = fn name -> Path.join([root, phase, name]) end
    ci = p.("133-278-CI-EVIDENCE.json")
    review = p.("133-278-CODE-REVIEW.md")
    ledger = p.("133-278-CENSUS-LEDGER.json")
    census_a = p.("133-278-CENSUS-A.json")
    census_b = p.("133-278-CENSUS-B.json")
    nightly = p.("133-278-NIGHTLY-EVIDENCE.json")
    requirements = Path.join(root, @requirements_path)
    canonical_census = Path.join(root, @census_path)
    canonical_nightly = Path.join(root, @receipt_path)
    terminal = p.("133-278-TERMINAL.json")

    paths = [
      ci,
      review,
      ledger,
      census_a,
      census_b,
      nightly,
      requirements,
      canonical_census,
      canonical_nightly
    ]

    with :ok <- plan278_preflight_paths(root, paths, [p.("133-278-TRANSACTION.json"), terminal]),
         :ok <- plan278_recover_journal(root),
         :ok <- plan278_source(source_root, ci, review),
         :ok <- plan278_files(paths),
         :ok <- plan278_pending_requirements(requirements),
         {:ok, sha} <- plan278_ci_sha(ci),
         {:ok, tree} <- git(source_root, ["rev-parse", "HEAD^{tree}"]),
         {:ok, review_bytes} <- File.read(review),
         :ok <- plan278_review_binding_bytes(review_bytes, sha, tree),
         review_sha256 <- sha256(review_bytes),
         {:ok, canonical_ledger} <- File.read(canonical_census),
         {:ok, canonical_ledger_doc} <- Jason.decode(canonical_ledger),
         {:ok, candidate_ledger} <- File.read(ledger),
         {:ok, candidate_ledger_doc} <- Jason.decode(candidate_ledger),
         :ok <- plan278_census_ledger_binding(canonical_ledger_doc, candidate_ledger_doc, sha),
         candidate_ledger_sha256 <- sha256(candidate_ledger),
         :ok <-
           plan278_external_validators(
             root,
             source_root,
             sha,
             ci,
             ledger,
             census_a,
             census_b,
             nightly
           ),
         {:ok, receipt_a} <- File.read(census_a),
         {:ok, receipt_b} <- File.read(census_b),
         true <-
           receipt_a == receipt_b or {:error, "census A and B receipts are not byte-identical"},
         {:ok, original_requirements} <- File.read(requirements),
         {:ok, updated_requirements} <- plan278_requirement_paragraph(original_requirements),
         {:ok, canonical_nightly_bytes} <- File.read(canonical_nightly),
         {:ok, promoted_ledger} <- plan278_promote_census(canonical_ledger, sha),
         {:ok, nightly_receipt} <- File.read(nightly),
         {:ok, sealed_history} <- plan278_sealed_history(root),
         :ok <-
           plan278_transaction(
             root,
             requirements,
             updated_requirements,
             canonical_census,
             ledger,
             candidate_ledger_sha256,
             review_sha256,
             promoted_ledger,
             canonical_nightly,
             nightly_receipt,
             terminal,
             sha,
             tree,
             ci,
             census_a,
             nightly,
             fn ->
               with :ok <-
                      plan278_external_validators(
                        root,
                        source_root,
                        sha,
                        ci,
                        ledger,
                        census_a,
                        census_b,
                        nightly
                      ),
                    :ok <- plan278_pending_requirements(requirements),
                    :ok <- plan278_sealed_history_unchanged(root, sealed_history),
                    {:ok, promoted_census_bytes} <- File.read(canonical_census),
                    :ok <-
                      plan278_census_ledger_binding_files(
                        promoted_census_bytes,
                        ledger,
                        sha,
                        candidate_ledger_sha256
                      ),
                    :ok <- plan278_review_binding_digest(review, sha, tree, review_sha256),
                    do: :ok
             end,
             sealed_history
           ) do
      _ = canonical_nightly_bytes

      {:ok,
       "Plan 278 exact-subject census, CI, scheduled Nightly, and terminal reconciliation valid; requirements remain Pending"}
    else
      {:error, _} = error -> error
      false -> {:error, "Plan 278 exact-subject validation failed"}
      _ -> {:error, "Plan 278 terminal evidence is incomplete or malformed"}
    end
  end

  defp plan278_source(source_root, ci, review) do
    with true <- File.dir?(source_root) or {:error, "source root is missing"},
         {:ok, sha} <- git(source_root, ["rev-parse", "--verify", "HEAD"]),
         {:ok, tree} <- git(source_root, ["rev-parse", "HEAD^{tree}"]),
         {:ok, status} <- git(source_root, ["status", "--porcelain", "--untracked-files=all"]),
         true <- String.trim(status) == "" or {:error, "source root is not clean"},
         {:ok, expected_sha} <- plan278_ci_sha(ci),
         true <- sha == expected_sha or {:error, "source root HEAD differs from CI evidence"},
         true <- File.regular?(review) or {:error, "independent code review is missing"},
         true <- is_binary(tree) do
      :ok
    else
      {:error, _} = error -> error
      _ -> {:error, "Plan 278 source root identity is invalid"}
    end
  end

  defp plan278_files(paths) do
    case Enum.find(paths, &(not File.regular?(&1))) do
      nil -> :ok
      path -> {:error, "Plan 278 evidence file is missing: #{Path.basename(path)}"}
    end
  end

  defp plan278_pending_requirements(path) do
    with {:ok, bytes} <- File.read(path),
         :ok <- validate_requirements(root_from_requirements(path), false) do
      if String.contains?(bytes, "- [ ] **TRUTH-08**:") do
        :ok
      else
        {:error, "all five Phase 133 requirements must remain Pending until phase verification"}
      end
    end
  end

  defp root_from_requirements(path), do: Path.dirname(Path.dirname(path))

  defp plan278_ci_sha(path) do
    with {:ok, json} <- File.read(path),
         {:ok, doc} <- Jason.decode(json),
         sha when is_binary(sha) <- doc["subject_sha"],
         true <- valid_hex?(sha, 40) do
      {:ok, sha}
    else
      _ -> {:error, "Plan 278 CI evidence has no exact full SHA"}
    end
  end

  defp plan278_review_binding(path, sha, tree) do
    with {:ok, bytes} <- File.read(path) do
      plan278_review_binding_bytes(bytes, sha, tree)
    else
      _ -> {:error, "independent PASS review is not bound to the exact main commit/tree"}
    end
  end

  defp plan278_review_binding_bytes(bytes, sha, tree) do
    with {:ok, frontmatter, body} <- bounded_frontmatter(bytes),
         # Strict frontmatter is the machine-readable review contract.
         # Narrative body text does not determine the verdict.
         :ok <- plan278_review_frontmatter_keys(frontmatter),
         :ok <- reject_second_frontmatter(body),
         {:ok, metadata} <- decode_frontmatter(frontmatter),
         true <- metadata["phase"] == "133-278",
         true <- metadata["verdict"] == "PASS",
         true <- metadata["status"] == "clean",
         true <- metadata["source_commit"] == sha,
         true <- metadata["source_tree"] == tree,
         true <- metadata["files_reviewed"] == length(@plan278_reviewed_files),
         reviewed_files when is_list(reviewed_files) <- metadata["files_reviewed_list"],
         true <- Enum.sort(reviewed_files) == Enum.sort(@plan278_reviewed_files),
         findings when is_map(findings) <- metadata["findings"],
         true <-
           Enum.sort(Map.keys(findings)) == ~w(blocker critical info necessity total warning),
         true <- Enum.all?(Map.values(findings), &(&1 == 0)) do
      :ok
    else
      _ -> {:error, "independent PASS review is not bound to the exact main commit/tree"}
    end
  end

  defp plan278_review_binding_digest(path, sha, tree, expected_sha256) do
    with {:ok, bytes} <- File.read(path),
         true <- sha256(bytes) == expected_sha256,
         :ok <- plan278_review_binding_bytes(bytes, sha, tree) do
      :ok
    else
      _ -> {:error, "independent PASS review changed before terminal promotion completed"}
    end
  end

  defp plan278_review_frontmatter_keys(frontmatter) do
    top_level =
      ~w(findings files_reviewed files_reviewed_list phase source_commit source_tree status verdict)

    finding_fields = ~w(blocker critical info necessity total warning)

    with :ok <- require_frontmatter_keys_once(frontmatter, top_level, ""),
         :ok <- require_frontmatter_keys_once(frontmatter, finding_fields, "  ") do
      :ok
    end
  end

  defp require_frontmatter_keys_once(frontmatter, keys, indent) do
    Enum.reduce_while(keys, :ok, fn key, :ok ->
      pattern = Regex.compile!("^" <> indent <> Regex.escape(key) <> "[ \\t]*:", "m")

      if length(Regex.scan(pattern, frontmatter)) == 1 do
        {:cont, :ok}
      else
        {:halt, {:error, "review frontmatter has a missing or duplicate #{key} field"}}
      end
    end)
  end

  defp plan278_external_validators(
         root,
         source_root,
         sha,
         ci,
         ledger,
         census_a,
         census_b,
         nightly
       ) do
    mix_env = [
      {"MIX_ENV", "test"},
      {"MIX_DEPS_PATH", Path.join(source_root, "deps")},
      {"MIX_BUILD_PATH", Path.join(source_root, "_build")}
    ]

    checks = [
      {"bash",
       [
         "scripts/ci/verify_nightly_run.sh",
         "verify-main-ci-receipt",
         "--repo",
         "szTheory/rindle",
         "--expected-sha",
         sha,
         "--receipt",
         ci
       ]},
      {"mix",
       [
         "run",
         "--no-start",
         "--no-deps-check",
         "--no-compile",
         "scripts/maintainer/validate_evidence_census.exs",
         "--root",
         source_root,
         "--ledger",
         ledger,
         "--receipt",
         census_a
       ]},
      {"mix",
       [
         "run",
         "--no-start",
         "--no-deps-check",
         "--no-compile",
         "scripts/maintainer/validate_evidence_census.exs",
         "--root",
         source_root,
         "--ledger",
         ledger,
         "--receipt",
         census_b
       ]},
      {"bash",
       [
         "scripts/ci/verify_nightly_run.sh",
         "verify-scheduled-receipt",
         "--source-root",
         source_root,
         "--evidence-root",
         root,
         "--repo",
         "szTheory/rindle",
         "--workflow",
         "nightly.yml",
         "--ref",
         "main",
         "--expected-sha",
         sha,
         "--receipt",
         nightly
       ]},
      {"mix",
       [
         "run",
         "--no-start",
         "--no-deps-check",
         "--no-compile",
         "-e",
         "Code.require_file(\"scripts/maintainer/validate_live_truth.exs\"); Rindle.ValidateLiveTruth.run([\"--root\", \".\", \"--format\", \"json\"])"
       ]}
    ]

    Enum.reduce_while(checks, :ok, fn {command, args}, :ok ->
      {out, status} =
        System.cmd(command, args, cd: source_root, env: mix_env, stderr_to_stdout: true)

      if status == 0,
        do: {:cont, :ok},
        else:
          {:halt,
           {:error,
            "Plan 278 validator failed (#{Path.basename(command)}): #{String.slice(out, 0, 400)}"}}
    end)
  end

  defp plan278_census_ledger_binding(canonical, candidate, sha)
       when is_map(canonical) and is_map(candidate) do
    canonical_sha = Map.get(canonical, "subject_sha")

    with true <- valid_hex?(canonical_sha, 40),
         true <- valid_hex?(sha, 40),
         true <- Map.get(candidate, "subject_sha") == sha,
         true <- Map.put(canonical, "subject_sha", sha) == candidate do
      :ok
    else
      _ ->
        {:error,
         "Plan 278 census ledger must match canonical evidence with only the exact subject SHA changed"}
    end
  end

  defp plan278_census_ledger_binding(_canonical, _candidate, _sha),
    do:
      {:error,
       "Plan 278 census ledger must match canonical evidence with only the exact subject SHA changed"}

  defp plan278_census_ledger_binding_files(canonical_bytes, candidate_path, sha, expected_sha256) do
    with {:ok, candidate_bytes} <- File.read(candidate_path),
         true <- sha256(candidate_bytes) == expected_sha256,
         {:ok, canonical} <- Jason.decode(canonical_bytes),
         {:ok, candidate} <- Jason.decode(candidate_bytes),
         :ok <- plan278_census_ledger_binding(canonical, candidate, sha) do
      :ok
    else
      _ ->
        {:error, "Plan 278 census ledger or canonical evidence changed before promotion"}
    end
  end

  defp plan278_promote_census(bytes, sha) do
    with {:ok, doc} <- Jason.decode(bytes),
         true <- is_map(doc),
         promoted <- Map.put(doc, "subject_sha", sha) do
      {:ok, Jason.encode!(promoted, pretty: true) <> "\n"}
    else
      _ -> {:error, "canonical evidence census is malformed"}
    end
  end

  defp plan278_transaction(
         root,
         requirements,
         new_requirements,
         canonical_census,
         candidate_ledger,
         candidate_ledger_sha256,
         review_sha256,
         new_census,
         canonical_nightly,
         new_nightly,
         terminal,
         sha,
         tree,
         ci,
         census,
         nightly,
         postcheck,
         sealed_history
       ) do
    journal = Path.join(root, @plan278_journal)

    case plan278_preflight_paths(
           root,
           [requirements, canonical_census, canonical_nightly, candidate_ledger],
           [journal, terminal]
         ) do
      :ok ->
        if File.exists?(terminal) do
          {:error, "Plan 278 terminal artifact already exists"}
        else
          files = [requirements, canonical_census, canonical_nightly]
          originals = Map.new(files, &{&1, File.read!(&1)})

          with :ok <-
                 plan278_census_ledger_binding_files(
                   Map.fetch!(originals, canonical_census),
                   candidate_ledger,
                   sha,
                   candidate_ledger_sha256
                 ) do
            proof = %{
              "schema_version" => 1,
              "plan" => "133-278",
              "status" => "validated",
              "source_sha" => sha,
              "source_tree" => tree,
              "ledger_sha256" => candidate_ledger_sha256,
              "ci_sha256" => file_sha(ci),
              "review_sha256" => review_sha256,
              "census_sha256" => file_sha(census),
              "nightly_sha256" => file_sha(nightly),
              "sealed_history_sha256" => sealed_history,
              "requirements_pending" => true
            }

            journal_bytes =
              Jason.encode!(
                %{
                  "schema_version" => 1,
                  "plan" => "133-278",
                  "status" => "applying",
                  "terminal_path" => @plan278_terminal,
                  "prior_bytes" =>
                    Map.new(originals, fn {path, bytes} ->
                      {Path.relative_to(path, root), Base.encode64(bytes)}
                    end)
                },
                pretty: true
              ) <> "\n"

            plan278_apply_transaction(
              root,
              originals,
              %{
                requirements => new_requirements,
                canonical_census => new_census,
                canonical_nightly => new_nightly
              },
              terminal,
              journal,
              journal_bytes,
              Jason.encode!(proof, pretty: true) <> "\n",
              postcheck,
              &atomic_write/2
            )
          end
        end

      {:error, message} ->
        {:error, "Plan 278 evidence paths are unsafe: #{inspect(message)}"}
    end
  end

  defp plan278_apply_transaction(
         root,
         originals,
         updates,
         terminal,
         journal,
         journal_bytes,
         terminal_bytes,
         postcheck,
         write
       ) do
    case plan278_preflight_paths(root, Map.keys(originals), [journal, terminal]) do
      :ok ->
        if File.exists?(terminal) do
          {:error, "Plan 278 terminal artifact appeared during transaction preflight"}
        else
          try do
            write.(journal, journal_bytes)

            Enum.each([@plan278_requirements, @plan278_census, @plan278_nightly], fn relative ->
              path = Path.join(root, relative)
              write.(path, Map.fetch!(updates, path))
            end)

            write.(terminal, terminal_bytes)

            case postcheck.() do
              :ok ->
                File.rm!(journal)
                :ok

              {:error, message} ->
                case plan278_restore(originals, terminal, journal) do
                  :ok ->
                    {:error,
                     "post-promotion validation failed and evidence was restored: #{message}"}

                  {:error, rollback} ->
                    {:error,
                     "post-promotion validation failed; rollback is incomplete: #{inspect(rollback)}"}
                end
            end
          rescue
            error ->
              case plan278_restore(originals, terminal, journal) do
                :ok ->
                  {:error,
                   "Plan 278 terminal transaction rolled back: #{Exception.message(error)}"}

                {:error, rollback} ->
                  {:error,
                   "Plan 278 transaction failed and rollback is incomplete: #{inspect(rollback)}; #{Exception.message(error)}"}
              end
          end
        end

      {:error, reason} ->
        {:error,
         "Plan 278 evidence paths became unsafe before transaction writes: #{inspect(reason)}"}
    end
  end

  defp plan278_restore(originals, terminal, journal) do
    with :ok <- plan278_restore_backups(Map.to_list(originals)),
         :ok <- plan278_remove_terminal_and_journal(terminal, journal) do
      :ok
    end
  end

  defp plan278_recover_journal(root) do
    root = Path.expand(root)
    journal = Path.join(root, @plan278_journal)

    with :ok <- plan278_recovery_path_safety(root) do
      case File.lstat(journal) do
        {:error, :enoent} ->
          :ok

        {:ok, %{type: :regular}} ->
          with {:ok, bytes} <- File.read(journal),
               {:ok, decoded} <- Jason.decode(bytes),
               {:ok, backups, terminal} <- plan278_validate_recovery_journal(root, decoded),
               :ok <- plan278_restore_backups(backups),
               :ok <- plan278_remove_terminal_and_journal(terminal, journal) do
            :ok
          else
            {:error, _} = error ->
              error

            _ ->
              {:error, "Plan 278 transaction journal is malformed; refusing to change evidence"}
          end

        _ ->
          {:error,
           "Plan 278 transaction journal is not a regular file; refusing to change evidence"}
      end
    else
      {:error, reason} ->
        {:error, "Plan 278 recovery paths are unsafe: #{inspect(reason)}"}
    end
  end

  defp plan278_validate_recovery_journal(root, decoded) when is_map(decoded) do
    expected_journal_keys =
      MapSet.new(["schema_version", "plan", "status", "terminal_path", "prior_bytes"])

    expected_prior_paths = MapSet.new([@plan278_requirements, @plan278_census, @plan278_nightly])

    with true <- MapSet.new(Map.keys(decoded)) == expected_journal_keys,
         1 <- decoded["schema_version"],
         "133-278" <- decoded["plan"],
         "applying" <- decoded["status"],
         @plan278_terminal <- decoded["terminal_path"],
         prior when is_map(prior) <- decoded["prior_bytes"],
         true <- MapSet.new(Map.keys(prior)) == expected_prior_paths,
         {:ok, backups} <- plan278_decode_all_backups(root, prior, expected_prior_paths),
         {:ok, terminal} <-
           plan278_recovery_path(root, @plan278_terminal, expected_prior_paths, true) do
      {:ok, backups, terminal}
    else
      _ -> {:error, :invalid_journal}
    end
  end

  defp plan278_validate_recovery_journal(_root, _decoded), do: {:error, :invalid_journal}

  defp plan278_decode_all_backups(root, prior, allowed) do
    prior
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce_while({:ok, []}, fn {relative, encoded}, {:ok, decoded} ->
      with true <- is_binary(relative),
           true <- is_binary(encoded),
           {:ok, path} <- plan278_recovery_path(root, relative, allowed, false),
           {:ok, bytes} <- Base.decode64(encoded) do
        {:cont, {:ok, [{path, bytes} | decoded]}}
      else
        _ -> {:halt, {:error, :invalid_backup}}
      end
    end)
  end

  defp plan278_recovery_path(root, relative, allowed, is_terminal) when is_binary(relative) do
    segments = String.split(relative, "/", trim: true)
    expanded = Path.expand(relative, root)
    root_prefix = root <> "/"
    allowed = MapSet.member?(allowed, relative) or (is_terminal and relative == @plan278_terminal)

    cond do
      not is_binary(relative) ->
        {:error, :invalid_path}

      Path.type(relative) == :absolute ->
        {:error, :absolute_path}

      Enum.any?(segments, &(&1 in [".", "..", ""])) ->
        {:error, :traversal}

      not allowed ->
        {:error, :unexpected_path}

      expanded == root or not String.starts_with?(expanded, root_prefix) ->
        {:error, :outside_root}

      true ->
        case plan278_no_symlink_parents(root, segments) do
          :ok -> {:ok, expanded}
          error -> error
        end
    end
  end

  defp plan278_recovery_path(_root, _relative, _allowed, _is_terminal),
    do: {:error, :invalid_path}

  defp plan278_no_symlink_parents(root, segments) do
    with {:ok, %{type: :directory}} <- File.lstat(root) do
      segments
      |> Enum.drop(-1)
      |> Enum.reduce_while({:ok, root}, fn segment, {:ok, parent} ->
        path = Path.join(parent, segment)

        case File.lstat(path) do
          {:ok, %{type: :directory}} -> {:cont, {:ok, path}}
          _ -> {:halt, {:error, :unsafe_parent}}
        end
      end)
      |> case do
        {:ok, _} -> :ok
        error -> error
      end
    else
      _ -> {:error, :unsafe_root}
    end
  end

  defp plan278_recovery_path_safety(root) do
    optional =
      Enum.map(
        [
          @plan278_journal,
          @plan278_requirements,
          @plan278_census,
          @plan278_nightly,
          @plan278_terminal
        ],
        &Path.join(root, &1)
      )

    plan278_preflight_paths(root, [], optional)
  end

  defp plan278_preflight_paths(root, required, optional) do
    root = Path.expand(root)

    with {:ok, %{type: :directory}} <- File.lstat(root),
         :ok <- Enum.reduce_while(required, :ok, &plan278_preflight_one(root, &1, true, &2)),
         :ok <- Enum.reduce_while(optional, :ok, &plan278_preflight_one(root, &1, false, &2)) do
      :ok
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unsafe_root}
    end
  end

  defp plan278_preflight_one(root, path, required?, :ok) do
    expanded = Path.expand(path)
    relative = Path.relative_to(expanded, root)
    segments = String.split(relative, "/", trim: true)

    cond do
      Path.type(path) != :absolute ->
        {:halt, {:error, :non_absolute_path}}

      expanded == root or not String.starts_with?(expanded, root <> "/") ->
        {:halt, {:error, :outside_root}}

      Enum.any?(segments, &(&1 in [".", "..", ""])) ->
        {:halt, {:error, :traversal}}

      true ->
        case plan278_parent_chain(root, segments) do
          :missing when not required? ->
            {:cont, :ok}

          :missing ->
            {:halt, {:error, :missing_parent}}

          :ok ->
            case File.lstat(expanded) do
              {:ok, %{type: :regular}} -> {:cont, :ok}
              {:error, :enoent} when not required? -> {:cont, :ok}
              {:error, :enoent} -> {:halt, {:error, :missing_file}}
              _ -> {:halt, {:error, :unsafe_leaf}}
            end

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
    end
  end

  defp plan278_parent_chain(root, segments) do
    segments
    |> Enum.drop(-1)
    |> Enum.reduce_while({:ok, root}, fn segment, {:ok, parent} ->
      path = Path.join(parent, segment)

      case File.lstat(path) do
        {:ok, %{type: :directory}} -> {:cont, {:ok, path}}
        {:error, :enoent} -> {:halt, :missing}
        _ -> {:halt, {:error, :unsafe_parent}}
      end
    end)
    |> case do
      {:ok, _} -> :ok
      result -> result
    end
  end

  defp plan278_restore_backups(backups) do
    Enum.reduce_while(backups, :ok, fn {path, bytes}, :ok ->
      try do
        atomic_write(path, bytes)
        {:cont, :ok}
      rescue
        error -> {:halt, {:error, {:restore_failed, path, Exception.message(error)}}}
      end
    end)
  end

  defp plan278_remove_terminal_and_journal(terminal, journal, remove_fun \\ &File.rm/1) do
    with :ok <- plan278_remove_if_present(terminal, remove_fun),
         :ok <- plan278_remove_if_present(journal, remove_fun) do
      :ok
    end
  end

  defp plan278_remove_if_present(path, remove_fun) do
    case remove_fun.(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, {:remove_failed, path, reason}}
    end
  end

  defp atomic_write(path, bytes) do
    temp = path <> ".tmp-#{System.unique_integer([:positive])}"
    File.write!(temp, bytes, [:binary, :exclusive])
    File.rename!(temp, path)
  end

  defp file_sha(path), do: File.read!(path) |> sha256()

  def validate_plan116_authority(root, paths \\ %{}, requirement_state \\ :pending) do
    paths = Map.merge(plan114_paths(), paths)

    with {:ok, preflight} <- plan114_json(root, paths.p115_preflight),
         {:ok, supply} <- plan114_json(root, paths.p115_supply),
         {:ok, local_gates} <- plan114_json(root, paths.p115_local_gates),
         {:ok, census_a} <- plan114_json(root, paths.census_a),
         {:ok, census_b} <- plan114_json(root, paths.census_b),
         {:ok, ledger} <- plan114_json(root, paths.census),
         {:ok, authority} <- plan114_json(root, paths.p116_authority),
         :ok <- plan114_record_credit(authority),
         true <- authority["plan"] == "133-116" and authority["schema_version"] == 1,
         source when is_map(source) <- authority["source"],
         true <- valid_hex?(source["sha"], 40) and valid_hex?(source["tree"], 40),
         true <-
           source["sha"] == preflight["source"]["sha"] and
             source["tree"] == preflight["source"]["tree"],
         true <-
           source["sha"] == local_gates["subject_sha"] and
             source["tree"] == local_gates["subject_tree"],
         true <-
           source["sha"] == supply["source"]["sha"] and source["tree"] == supply["source"]["tree"],
         true <-
           local_gates["plan"] == "133-115" and
             local_gates["terminal"]["status"] == "locally_qualified",
         :ok <- plan114_census_pair(census_a, census_b, ledger, source),
         :ok <- plan114_authority_digests(root, paths, authority),
         true <- authority["flagged_edge_rows"] == @plan114_edge_rows,
         :ok <- plan114_requirements_state(root, requirement_state) do
      {:ok, "Plan 116 authority valid; zero requirement credit"}
    else
      {:error, message} when is_binary(message) ->
        {:error, message}

      false ->
        {:error,
         "Plan 116 source, local gates, census pair, authority digests, or zero-credit state differs"}

      _ ->
        {:error, "Plan 116 authority is missing or malformed"}
    end
  rescue
    _ -> {:error, "Plan 116 authority is missing or malformed"}
  end

  def validate_plan117(root, mode, paths \\ %{}, checkpoint \\ %{}, requirement_state \\ :pending)
      when mode in [:preflight, :decision, :candidate] do
    paths = Map.merge(plan114_paths(), paths)

    with {:ok, _authority} <-
           validate_plan116_authority(root, plan114_upstream_paths(paths), requirement_state),
         {:ok, preflight} <- plan114_json(root, paths.p117_preflight),
         :ok <- plan114_record_credit(preflight),
         true <- preflight["plan"] == "133-117" and preflight["schema_version"] == 1,
         source when is_map(source) <- preflight["source"],
         true <- valid_hex?(source["sha"], 40) and valid_hex?(source["tree"], 40),
         expected_ref <- "refs/heads/phase-133-evidence-" <> String.slice(source["sha"], 0, 12),
         true <- preflight["remote_ref"] == expected_ref,
         true <- preflight["remote_lookup"] == %{"exit_code" => 0, "output" => ""},
         true <- preflight["remote_commands"] == 0,
         true <- plan114_authority_map(root, paths) == preflight["authorities"],
         :ok <- plan114_plan117_branch(root, mode, paths, preflight, checkpoint) do
      {:ok, "Plan 117 #{mode} evidence valid; zero requirement credit"}
    else
      {:error, message} when is_binary(message) ->
        {:error, message}

      false ->
        {:error,
         "Plan 117 source, ref, authority digests, remote lookup, or zero-credit state differs"}

      _ ->
        {:error, "Plan 117 evidence is missing or malformed"}
    end
  rescue
    _ -> {:error, "Plan 117 evidence is missing or malformed"}
  end

  def validate_plan118(root, mode, paths \\ %{})
      when mode in [:preterminal, :provisional, :restored, :terminal] do
    paths = Map.merge(plan114_paths(), paths)

    requirement_state =
      if mode == :terminal,
        do: :complete,
        else: if(mode == :provisional, do: :either, else: :pending)

    with {:ok, _candidate} <-
           validate_plan117(
             root,
             :candidate,
             plan114_upstream_paths(paths),
             %{},
             requirement_state
           ),
         {:ok, transaction} <- plan114_optional_json(root, paths.p118_transaction),
         :ok <- plan114_plan118_state(root, mode, paths, transaction) do
      {:ok, "Plan 118 #{mode} state valid; read-only and zero requirement credit"}
    else
      {:error, message} when is_binary(message) ->
        {:error, message}

      false ->
        {:error, "Plan 118 state, candidate, upstream digest, or requirement binding differs"}

      _ ->
        {:error, "Plan 118 state is missing or malformed"}
    end
  rescue
    _ -> {:error, "Plan 118 state is missing or malformed"}
  end

  # Plan 121 is the first production authority on the fresh 174 → 121 → 122 → 123 chain.
  # The legacy 116–118 path deliberately remains intact for historical records;
  # it is never consulted by this validator.
  # Historical read-only validation is explicit. Current consumers require an
  # independently verified Plan 174 result; halted Plans 152 and 158 cannot admit a census.
  def validate_plan121_authority(root, paths \\ %{}, requirement_state \\ :pending) do
    if Process.get(:phase133_history126, false),
      do: validate_plan121_legacy_authority(root, paths, requirement_state),
      else: validate_plan121_current_authority(root, paths, requirement_state)
  end

  def validate_historical126(fun) when is_function(fun, 0) do
    old = Process.put(:phase133_history126, true)

    try do
      fun.()
    after
      if is_nil(old),
        do: Process.delete(:phase133_history126),
        else: Process.put(:phase133_history126, old)
    end
  end

  defp validate_plan121_legacy_authority(root, paths, requirement_state) do
    paths = Map.merge(plan121_paths(), paths)

    with {:ok, preflight} <- plan114_json(root, paths.p126_preflight),
         {:ok, authorization} <- plan114_json(root, paths.p126_authorization),
         {:ok, supply} <- plan114_json(root, paths.p126_supply),
         {:ok, local_gates} <- plan114_json(root, paths.p126_local_gates),
         {:ok, attempt} <- plan114_json(root, paths.p126_qualification_attempt),
         {:ok, census_a_bytes} <- plan114_file(root, paths.census_a),
         {:ok, census_b_bytes} <- plan114_file(root, paths.census_b),
         {:ok, census_a} <- plan114_decode_json(census_a_bytes, paths.census_a),
         {:ok, census_b} <- plan114_decode_json(census_b_bytes, paths.census_b),
         {:ok, census} <- plan114_json(root, paths.census),
         {:ok, _review} <- plan114_file(root, paths.review),
         {:ok, _security} <- plan114_file(root, paths.security),
         {:ok, inventory} <- plan114_json(root, paths.inventory),
         {:ok, _validation} <- plan114_file(root, paths.validation),
         {:ok, authority} <- plan114_json(root, paths.p121_authority),
         source when is_map(source) <- preflight["source"],
         source <- Map.take(source, ["sha", "tree"]),
         true <- valid_hex?(source["sha"], 40) and valid_hex?(source["tree"], 40),
         :ok <- plan114_record_credit(preflight),
         :ok <- plan114_record_credit(authorization),
         :ok <- plan114_record_credit(supply),
         true <- preflight["plan"] == "133-126" and preflight["schema_version"] == 1,
         true <- authorization["plan"] == "133-126" and authorization["schema_version"] == 1,
         true <- supply["plan"] == "133-126" and supply["schema_version"] == 2,
         true <- Map.take(supply["source"], ["sha", "tree"]) == source,
         true <- supply["status"] == "available",
         true <- Map.take(authorization["source"], ["sha", "tree"]) == source,
         true <- attempt["plan"] == "133-126" and attempt["attempts"] == 1,
         true <-
           attempt["source"] == supply["source"] and
             attempt["supply_sha256"] == supply["report_sha256"],
         :ok <- plan114_record_credit(attempt),
         {:ok, preflight_bytes} <- plan114_file(root, paths.p126_preflight),
         true <- authorization["preflight_sha256"] == sha256(preflight_bytes),
         true <- authorization["answer"] == "authorize",
         true <- authorization["attempt"] == 1 and authorization["remote_action_count"] == 1,
         true <- preflight["status"] == "needs_authorization",
         true <- authorization["operation"] == preflight["operation"],
         true <-
           get_in(authorization, ["operation", "url"]) == "https://github.com/lexbor/lexbor.git",
         true <-
           get_in(authorization, ["operation", "commit"]) ==
             "244b84956a6dc7eec293781d051354f351274c46",
         true <-
           get_in(authorization, ["operation", "destination"]) ==
             get_in(supply, ["native", "lexbor", "path"]),
         :ok <- plan121_local_gates(local_gates, source),
         :ok <- plan126_source(root, source),
         :ok <- plan126_supply_and_gates(root, paths),
         :ok <-
           plan121_authority_digests(
             root,
             paths,
             authority,
             requirement_state == :complete
           ),
         :ok <-
           plan121_census_pair(census_a_bytes, census_b_bytes, census_a, census_b, census, source),
         true <- inventory["source"] == source,
         true <-
           Map.get(authority, "plan") == "133-121" and Map.get(authority, "schema_version") == 1,
         true <- Map.get(authority, "status") == "authority_complete",
         true <- Map.get(authority, "source") == source,
         true <- Map.get(authority, "flagged_edge_rows") == @plan114_edge_rows,
         true <-
           Map.get(authority, "remote_ref") ==
             "refs/heads/phase-133-evidence-" <> String.slice(source["sha"], 0, 12),
         true <- Map.get(authority, "remote_lookup") == %{"exit_code" => 0, "output" => ""},
         true <- Map.get(authority, "remote_commands") == 0,
         :ok <- plan114_record_credit(authority),
         :ok <- plan114_requirements_state(root, requirement_state) do
      {:ok, "Plan 121 authority valid; zero requirement credit"}
    else
      {:error, message} when is_binary(message) ->
        {:error, message}

      false ->
        {:error,
         "Plan 126 source, supply, local gates, census, upstream digest, or requirement state differs"}

      _ ->
        {:error, "Plan 121 authority or Plan 126 evidence is missing or malformed"}
    end
  rescue
    _ -> {:error, "Plan 121 authority or Plan 126 evidence is missing or malformed"}
  end

  defp validate_plan121_current_authority(root, paths, requirement_state) do
    defaults = plan121_paths()
    paths = Map.merge(defaults, Map.take(paths, Map.keys(defaults)))

    with {:ok, preflight} <- plan114_json(root, paths.p174_preflight),
         source when is_map(source) <- preflight["source"],
         source <- Map.take(source, ["sha", "tree"]),
         true <- valid_hex?(source["sha"], 40) and valid_hex?(source["tree"], 40),
         :ok <- plan114_record_credit(preflight),
         true <- preflight["plan"] == "133-174" and preflight["schema_version"] == 1,
         :ok <- plan174_supply_and_gates(root, paths, source),
         {:ok, census_a_bytes} <- plan114_file(root, paths.census_a),
         {:ok, census_b_bytes} <- plan114_file(root, paths.census_b),
         {:ok, census_a} <- plan114_decode_json(census_a_bytes, paths.census_a),
         {:ok, census_b} <- plan114_decode_json(census_b_bytes, paths.census_b),
         {:ok, census} <- plan114_json(root, paths.census),
         {:ok, _review} <- plan114_file(root, paths.review),
         {:ok, _security} <- plan114_file(root, paths.security),
         {:ok, inventory} <- plan114_json(root, paths.inventory),
         {:ok, _validation} <- plan114_file(root, paths.validation),
         {:ok, authority} <- plan114_json(root, paths.p121_authority),
         :ok <-
           plan121_authority_digests(
             root,
             paths,
             authority,
             requirement_state == :complete
           ),
         :ok <-
           plan121_census_pair(census_a_bytes, census_b_bytes, census_a, census_b, census, source),
         true <- inventory["source"] == source,
         true <-
           Map.get(authority, "plan") == "133-121" and Map.get(authority, "schema_version") == 1,
         true <- Map.get(authority, "status") == "authority_complete",
         true <- Map.get(authority, "source") == source,
         true <- Map.get(authority, "flagged_edge_rows") == @plan114_edge_rows,
         true <-
           Map.get(authority, "remote_ref") ==
             "refs/heads/phase-133-evidence-" <> String.slice(source["sha"], 0, 12),
         true <- Map.get(authority, "remote_lookup") == %{"exit_code" => 0, "output" => ""},
         true <- Map.get(authority, "remote_commands") == 0,
         :ok <- plan114_record_credit(authority),
         :ok <- plan114_requirements_state(root, requirement_state) do
      {:ok, "Plan 121 authority valid; zero requirement credit"}
    else
      {:error, message} when is_binary(message) ->
        {:error, message}

      false ->
        {:error,
         "Plan 174 source, supply, local gates, census, upstream digest, or requirement state differs"}

      _ ->
        {:error, "Plan 121 authority or Plan 174 evidence is missing or malformed"}
    end
  rescue
    _ -> {:error, "Plan 121 authority or Plan 174 evidence is missing or malformed"}
  end

  defp plan174_supply_and_gates(root, paths, source) do
    with {:ok, p155_supply} <- plan114_json(root, paths.p155_supply),
         {:ok, p155_route} <- plan114_json(root, paths.p155_route),
         {:ok, preflight} <- plan114_json(root, paths.p174_preflight),
         {:ok, supply} <- plan114_json(root, paths.p174_supply),
         {:ok, retrieval} <- plan114_json(root, paths.p174_retrieval),
         {:ok, authorization} <- plan114_json(root, paths.p174_qualification_authorization),
         {:ok, attempt} <- plan114_json(root, paths.p174_qualification_attempt),
         {:ok, local_gates} <- plan114_json(root, paths.p174_local_gates),
         true <- p155_supply["plan"] == "133-155" and p155_supply["status"] == "available",
         true <-
           p155_supply["report_sha256"] ==
             "ff8e87783333dc672d3ef5cfda803deccd320fbed6772db109b983d8e11f21f5",
         true <-
           p155_route["plan"] == "133-155" and
             p155_route["report_sha256"] ==
               "a616ed0320334a0d7f4030ea1fc7fd96d52fa22ff4f49173d1828762951556cf",
         true <- get_in(p155_supply, ["coverage", "required"]) == 96,
         true <- get_in(p155_supply, ["coverage", "authenticated"]) == 96,
         true <- get_in(p155_supply, ["coverage", "status"]) == "complete",
         true <- get_in(p155_supply, ["coverage", "missing"]) == [],
         true <- length(p155_supply["required_names"] || []) == 96,
         true <- p155_supply["missing_names"] == [],
         receipts <- [preflight, retrieval, authorization, attempt],
         true <- supply["plan"] == "133-174" and supply["schema_version"] == 2,
         true <- Enum.all?(receipts, &(&1["plan"] == "133-174" and &1["schema_version"] == 1)),
         true <-
           Enum.all?(
             [supply | receipts],
             &(Map.take(&1["source"] || %{}, ["sha", "tree"]) == source)
           ),
         true <-
           Enum.all?(
             [supply | receipts],
             &(&1["qualification_credit"] == 0 and &1["requirements_completed"] == [])
           ),
         true <- local_gates["plan"] == "133-174" and local_gates["schema_version"] == 1,
         true <-
           local_gates["subject_sha"] == source["sha"] and
             local_gates["subject_tree"] == source["tree"],
         :ok <- plan114_record_credit(local_gates),
         true <- preflight["status"] == "ready",
         staging when is_map(staging) <- preflight["staging_proof"],
         true <- staging["status"] == "complete",
         true <- staging["registry_names"] == 96 and staging["archive_outputs"] == 67,
         true <- valid_hex?(staging["contents_sha256"], 64),
         stage_root when is_binary(stage_root) <- staging["root"],
         true <- Path.type(stage_root) == :absolute and stage_root == Path.expand(stage_root),
         true <- stage_root != Path.expand(root),
         true <- preflight["supply_sha256"] == supply["report_sha256"],
         true <- supply["status"] == "available",
         true <- preflight["plan155_supply_sha256"] == p155_supply["report_sha256"],
         true <-
           get_in(supply, ["registry_supply", "report_sha256"]) == p155_supply["report_sha256"],
         true <- preflight["plan155_route_sha256"] == p155_route["report_sha256"],
         true <-
           get_in(supply, ["registry_supply", "route_sha256"]) == p155_route["report_sha256"],
         true <- get_in(supply, ["registry_supply", "required_names_count"]) == 96,
         true <-
           retrieval["status"] == "not_required" and retrieval["network_request_count"] == 0,
         true <- authorization["decision"] == "authorize",
         true <-
           valid_hex?(preflight["report_sha256"], 64) and valid_hex?(supply["report_sha256"], 64),
         true <- authorization["preflight_sha256"] == preflight["report_sha256"],
         true <- authorization["supply_sha256"] == supply["report_sha256"],
         true <-
           authorization["literal_answer"] ==
             "Authorize Plan 174 qualification once: #{preflight["report_sha256"]}",
         true <- attempt["attempts"] == 1,
         true <- attempt["preflight_sha256"] == preflight["report_sha256"],
         true <- attempt["supply_sha256"] == supply["report_sha256"],
         true <- attempt["authorization_sha256"] == authorization["report_sha256"],
         true <- get_in(local_gates, ["terminal", "status"]) == "locally_qualified",
         true <- get_in(local_gates, ["terminal", "first_red"]) == nil,
         true <- get_in(local_gates, ["cleanup", "status"]) == "passed",
         true <- get_in(local_gates, ["cleanup", "transient_state_absent"]) == true,
         {:ok, node} <- authenticate_plan174_node(preflight, supply, authorization, local_gates),
         :ok <- invoke_plan174_qualification_verifier(root, node) do
      :ok
    else
      {:error, message} when is_binary(message) ->
        {:error, message}

      _ ->
        {:error,
         "Plan 174 receipts, complete Plan 155 supply, or exact-source terminal proof differs"}
    end
  rescue
    _ ->
      {:error,
       "Plan 174 receipts, complete Plan 155 supply, or exact-source terminal proof is malformed"}
  end

  # Receipts are untrusted until their executable agrees with the installed
  # version. Never execute a receipt path or rewrite the inherited PATH to find it.
  defp authenticate_plan174_node(preflight, supply, authorization, gates) do
    with {installation, 0} <-
           System.cmd("asdf", ["where", "nodejs", "22.14.0"], stderr_to_stdout: true),
         installation <- String.trim(installation),
         true <- Path.type(installation) == :absolute,
         node <- Path.join(installation, "bin/node"),
         true <- node == Path.expand(node) and regular_absolute_node?(node),
         {:ok, bytes} <- File.read(node),
         identity <- %{"realpath" => node, "sha256" => sha256(bytes), "version" => "v22.14.0"},
         true <-
           Enum.all?(
             [preflight, supply, authorization, gates],
             &(&1["node_executable"] == identity)
           ),
         true <- get_in(supply, ["network_guard", "executable"]) == node,
         true <- get_in(supply, ["network_guard", "host_context", "node_executable"]) == node,
         true <- get_in(gates, ["guard", "executable"]) == node,
         true <- get_in(gates, ["guard", "host_context", "node_executable"]) == node,
         path when is_binary(path) <- System.get_env("PATH"),
         true <- get_in(supply, ["runtime", "env", "PATH"]) == path,
         true <-
           Enum.all?(
             [preflight, supply, authorization, gates],
             &(&1["path_sha256"] == sha256(path))
           ),
         {"v22.14.0\n", 0} <- System.cmd(node, ["--version"], stderr_to_stdout: true),
         {:ok, ^bytes} <- File.read(node),
         true <- regular_absolute_node?(node) do
      {:ok, node}
    else
      _ -> {:error, "Plan 174 authenticated Node 22.14.0 executable or inherited PATH differs"}
    end
  rescue
    _ ->
      {:error, "Plan 174 authenticated Node 22.14.0 executable or inherited PATH is unavailable"}
  end

  defp regular_absolute_node?(node) do
    components = Path.split(node) |> Enum.scan(&Path.join(&2, &1))

    Enum.all?(components, fn component ->
      case File.lstat(component) do
        {:ok, %{type: :directory}} ->
          component != node

        {:ok, %{type: :regular, mode: mode}} ->
          component == node and Bitwise.band(mode, 0o111) != 0

        _ ->
          false
      end
    end)
  end

  defp invoke_plan174_qualification_verifier(root, node) do
    script = Path.join(Path.expand(root), "scripts/maintainer/phase_133_qualification_174.mjs")

    case System.cmd(
           node,
           [script, "verify-qualification", "--plan", "133-174", "--root", Path.expand(root)],
           cd: Path.expand(root),
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        :ok

      {output, _status} ->
        {:error,
         "Plan 174 independent qualification verifier failed: #{String.slice(output, 0, 1200)}"}
    end
  end

  def validate_plan122(root, mode, checkpoint \\ %{}, requirement_state \\ :pending)
      when mode in [:preflight, :decision, :candidate] do
    paths = plan122_paths()

    with {:ok, _authority} <- validate_plan121_authority(root, %{}, requirement_state),
         {:ok, upstream_authority} <- plan114_json(root, plan121_paths().p121_authority),
         {:ok, preflight} <- plan114_json(root, paths.p122_preflight),
         :ok <- plan114_record_credit(preflight),
         true <- preflight["plan"] == "133-122" and preflight["schema_version"] == 1,
         source when is_map(source) <- preflight["source"],
         true <- valid_hex?(source["sha"], 40) and valid_hex?(source["tree"], 40),
         true <- upstream_authority["source"] == source,
         expected_ref <- "refs/heads/phase-133-evidence-" <> String.slice(source["sha"], 0, 12),
         true <- preflight["remote_ref"] == expected_ref,
         true <- preflight["remote_lookup"] == %{"exit_code" => 0, "output" => ""},
         true <- preflight["remote_commands"] == 0,
         :ok <- plan122_authorities_match(root, preflight, requirement_state),
         :ok <- plan122_branch(root, mode, paths, preflight, checkpoint) do
      {:ok, "Plan 122 #{mode} evidence valid; zero requirement credit"}
    else
      {:error, message} when is_binary(message) ->
        {:error, message}

      false ->
        {:error,
         "Plan 122 source, ref, authority digests, remote lookup, or zero-credit state differs"}

      _ ->
        {:error, "Plan 122 evidence is missing or malformed"}
    end
  rescue
    _ -> {:error, "Plan 122 evidence is missing or malformed"}
  end

  def validate_plan123(root, mode) when mode in [:preterminal, :terminal] do
    transaction_path = plan123_paths().p123_transaction

    with {:ok, transaction} <- plan114_optional_json(root, transaction_path),
         :ok <- plan123_ordinary_journal_gate(mode, transaction),
         {:ok, _candidate} <-
           validate_plan122(
             root,
             :candidate,
             %{},
             if(mode == :terminal, do: :complete, else: :pending)
           ),
         :ok <- plan123_state(root, mode) do
      result =
        if mode == :preterminal,
          do: "Plan 123 preterminal authority valid; zero requirement credit",
          else: "Plan 123 terminal proof valid"

      {:ok, result}
    else
      {:error, message} when is_binary(message) -> {:error, message}
      false -> {:error, "Plan 123 candidate, terminal proof, or requirement binding differs"}
      _ -> {:error, "Plan 123 evidence is missing or malformed"}
    end
  rescue
    _ -> {:error, "Plan 123 evidence is missing or malformed"}
  end

  defp plan122_paths do
    phase = @phase_dir

    %{
      p122_preflight: Path.join(phase, "133-122-PREFLIGHT.json"),
      p122_decision: Path.join(phase, "133-122-DECISION.json"),
      p122_candidate: Path.join(phase, "133-122-CANDIDATE.json"),
      p122_private_candidate: Path.join(phase, "133-122-PRIVATE-CANDIDATE.json")
    }
  end

  defp plan123_paths do
    phase = @phase_dir

    %{
      p123_transaction: Path.join(phase, "133-123-TRANSACTION.json"),
      p123_summary: Path.join(phase, "133-123-SUMMARY.md"),
      canonical_receipt: Path.join(phase, "133-NIGHTLY-EVIDENCE.json"),
      p122_private_candidate: Path.join(phase, "133-122-PRIVATE-CANDIDATE.json")
    }
  end

  defp plan122_authority_map(root) do
    paths = plan121_paths()

    case plan121_authority_map(root, paths) do
      authorities when is_map(authorities) ->
        case plan114_artifact_hash(root, paths.p121_authority) do
          {:ok, digest} -> Map.put(authorities, "p121_authority_sha256", digest)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp plan122_authorities_match(root, preflight, :pending) do
    case plan123_validation_append_matches(
           root,
           preflight["authorities"],
           plan122_authority_map(root),
           false
         ) do
      :ok ->
        :ok

      _ ->
        {:error,
         "Plan 122 source, ref, authority digests, remote lookup, or zero-credit state differs"}
    end
  end

  defp plan122_authorities_match(root, preflight, :complete) do
    case plan123_validation_append_matches(
           root,
           preflight["authorities"],
           plan122_authority_map(root),
           true
         ) do
      :ok ->
        :ok

      _ ->
        {:error,
         "Plan 122 upstream authority digest differs outside the exact Plan 123 validation append"}
    end
  end

  defp plan123_validation_append_matches(_root, expected, current, _allow_append?)
       when is_map(expected) and is_map(current) and expected == current,
       do: :ok

  defp plan123_validation_append_matches(_root, _expected, _current, false), do: :mismatch

  defp plan123_validation_append_matches(root, expected, current, true) do
    validation_key = "validation_sha256"
    validation_path = Path.join(@phase_dir, "133-VALIDATION.md")
    summary_path = Path.join(@phase_dir, "133-123-SUMMARY.md")

    with true <- is_map(expected) and is_map(current),
         expected_validation when is_binary(expected_validation) <- expected[validation_key],
         true <- Map.delete(expected, validation_key) == Map.delete(current, validation_key),
         {:ok, validation} <- plan114_file(root, validation_path),
         {:ok, summary_bytes} <- plan114_file(root, summary_path),
         {:ok, summary} <- summary_document(summary_bytes),
         proof_digest when is_binary(proof_digest) <- summary.metadata["terminal_proof_sha256"],
         true <- valid_hex?(proof_digest, 64),
         suffix <-
           "Plan 123 copied-tree terminal proof: #{proof_digest}; five IDs completed by automated transaction.\n",
         true <- String.ends_with?(validation, suffix),
         prefix_size <- byte_size(validation) - byte_size(suffix),
         prefix <- binary_part(validation, 0, prefix_size),
         true <- sha256(prefix) == expected_validation do
      :ok
    else
      _ -> :mismatch
    end
  end

  defp plan122_branch(_root, :preflight, _paths, _preflight, _checkpoint), do: :ok

  defp plan122_branch(root, :decision, paths, preflight, checkpoint) do
    with {:ok, decision} <- plan114_json(root, paths.p122_decision),
         {:ok, preflight_bytes} <- plan114_file(root, paths.p122_preflight),
         :ok <- plan114_record_credit(decision),
         true <- decision["plan"] == "133-122" and decision["schema_version"] == 1,
         true <- decision["answer"] in ["authorize", "stop"],
         true <- decision["preflight_sha256"] == sha256(preflight_bytes),
         true <- decision["source"] == preflight["source"],
         true <- decision["remote_ref"] == preflight["remote_ref"],
         true <- decision["authorities"] == preflight["authorities"],
         true <-
           decision["remote_action_count"] ==
             if(decision["answer"] == "authorize", do: 2, else: 0),
         true <- checkpoint == %{} or plan122_checkpoint_matches?(checkpoint, decision) do
      if decision["answer"] == "stop",
        do: {:error, "Plan 122 decision stopped; no remote permission"},
        else: :ok
    else
      {:error, message} when is_binary(message) -> {:error, message}
      false -> {:error, "Plan 122 decision answer, checkpoint, or preflight binding differs"}
      _ -> {:error, "Plan 122 decision is missing or malformed"}
    end
  end

  defp plan122_branch(root, :candidate, paths, preflight, _checkpoint) do
    with :ok <- plan122_branch(root, :decision, paths, preflight, %{}),
         {:ok, decision} <- plan114_json(root, paths.p122_decision),
         {:ok, candidate} <- plan114_json(root, paths.p122_candidate),
         {:ok, candidate_bytes} <- plan114_file(root, paths.p122_private_candidate),
         {:ok, private_candidate} <-
           plan114_decode_json(candidate_bytes, paths.p122_private_candidate),
         :ok <- plan114_record_credit(candidate),
         true <- decision["answer"] == "authorize",
         true <- candidate["plan"] == "133-122" and candidate["schema_version"] == 1,
         true <- candidate["status"] == "private_candidate",
         true <- candidate["source"] == preflight["source"],
         true <- candidate["remote_ref"] == preflight["remote_ref"],
         true <- candidate["preflight_sha256"] == decision["preflight_sha256"],
         true <- candidate["decision_sha256"] == plan122_digest(root, paths.p122_decision),
         true <- candidate["authorities"] == preflight["authorities"],
         true <- private_candidate["plan"] == "133-122",
         true <- private_candidate["status"] == "private_candidate",
         true <- private_candidate["source"] == candidate["source"],
         true <- private_candidate["authorities"] == candidate["authorities"],
         true <-
           Process.get(:phase133_history126, false) or
             private_candidate["verification"] == candidate["verification"],
         true <- Map.get(private_candidate, "qualification_credit", 0) == 0,
         true <- Map.get(private_candidate, "requirements_completed", []) == [],
         true <- candidate["candidate_sha256"] == sha256(candidate_bytes),
         true <- candidate["remote_action_count"] == 2,
         true <-
           plan122_verified_run?(
             candidate["verification"],
             preflight["source"],
             preflight["remote_ref"]
           ) do
      :ok
    else
      {:error, message} when is_binary(message) ->
        {:error, message}

      false ->
        {:error, "Plan 122 candidate, private receipt, authorization, or exact run differs"}

      _ ->
        {:error, "Plan 122 candidate is missing or malformed"}
    end
  end

  defp plan122_digest(root, relative) do
    case plan114_artifact_hash(root, relative) do
      {:ok, digest} -> digest
      _ -> nil
    end
  end

  defp plan122_verified_run?(
         %{"verified" => true, "event" => "workflow_dispatch", "conclusion" => "success"} =
           receipt,
         source,
         remote_ref
       ) do
    is_integer(receipt["run_id"]) and receipt["run_id"] > 0 and
      is_integer(receipt["run_attempt"]) and receipt["run_attempt"] > 0 and
      receipt["sha"] == source["sha"] and receipt["ref"] == remote_ref
  end

  defp plan122_verified_run?(_, _, _), do: false

  defp plan122_checkpoint_matches?(checkpoint, decision) do
    Map.get(checkpoint, :answer) == decision["answer"] and
      Map.get(checkpoint, :preflight_sha256) == decision["preflight_sha256"]
  end

  defp plan123_ordinary_journal_gate(_mode, nil), do: :ok

  defp plan123_ordinary_journal_gate(_mode, %{"plan" => "133-123", "status" => "pending"}),
    do: {:error, "Plan 123 ordinary terminal validation rejects a pending transaction journal"}

  defp plan123_ordinary_journal_gate(_mode, _transaction),
    do: {:error, "Plan 123 transaction journal is present but not cleared"}

  defp plan123_state(root, :preterminal), do: plan114_requirements_state(root, :pending)

  defp plan123_state(root, :terminal) do
    paths = plan123_paths()

    with :ok <- plan114_requirements_state(root, :complete),
         {:ok, candidate} <- plan114_json(root, plan122_paths().p122_candidate),
         {:ok, candidate_bytes} <- plan114_file(root, paths.p122_private_candidate),
         {:ok, canonical_bytes} <- plan114_file(root, paths.canonical_receipt),
         {:ok, summary_bytes} <- plan114_file(root, paths.p123_summary),
         {:ok, summary} <- summary_document(summary_bytes),
         true <- summary.status == "complete",
         true <- Map.get(summary.metadata, "requirements-completed") == @plan114_requirements,
         true <- Map.get(summary.metadata, "source_sha") == candidate["source"]["sha"],
         true <- Map.get(summary.metadata, "source_tree") == candidate["source"]["tree"],
         true <- Map.get(summary.metadata, "candidate_sha256") == sha256(candidate_bytes),
         true <- Map.get(summary.metadata, "canonical_receipt_sha256") == sha256(canonical_bytes),
         true <-
           Map.get(summary.metadata, "candidate_sha256") ==
             Map.get(summary.metadata, "canonical_receipt_sha256"),
         true <- Map.get(summary.metadata, "transaction_status") == "cleared",
         true <- Map.get(summary.metadata, "final_consistency") == "pass",
         proof <- %{
           "status" => "green",
           "source_sha" => candidate["source"]["sha"],
           "source_tree" => candidate["source"]["tree"],
           "candidate_sha256" => sha256(candidate_bytes),
           "authority_sha256" =>
             sha256(Jason.encode!(candidate["authorities"], pretty: true) <> "\n"),
           "automated" => true
         },
         true <-
           Map.get(summary.metadata, "terminal_proof_sha256") ==
             sha256(Jason.encode!(proof, pretty: true) <> "\n") do
      :ok
    else
      {:error, message} when is_binary(message) ->
        {:error, message}

      _ ->
        {:error,
         "Plan 123 terminal proof, canonical receipt, or exactly five requirement statuses differ"}
    end
  end

  defp run_plan122(argv) do
    switches = [
      root: :string,
      checkpoint_answer: :string,
      checkpoint_preflight_sha256: :string,
      expect_plan122_preflight: :boolean,
      expect_plan122_decision: :boolean,
      expect_plan122_candidate: :boolean
    ]

    with {opts, [], []} <- OptionParser.parse(argv, strict: switches),
         true <- length(opts) == length(Enum.uniq_by(opts, &elem(&1, 0))),
         [mode] <-
           Enum.filter(
             [:preflight, :decision, :candidate],
             &Keyword.get(opts, String.to_atom("expect_plan122_#{&1}"))
           ),
         {:ok, root} <- resolve_root(Keyword.get(opts, :root)),
         checkpoint <- %{
           answer: Keyword.get(opts, :checkpoint_answer),
           preflight_sha256: Keyword.get(opts, :checkpoint_preflight_sha256)
         },
         {:ok, result} <- validate_plan122(root, mode, checkpoint) do
      IO.puts(result)
      :ok
    else
      {:error, _} = error -> error
      _ -> {:error, "Plan 122 requires exactly one evidence mode and a valid root"}
    end
  end

  defp run_plan123(argv) do
    switches = [
      root: :string,
      expect_plan123_preterminal: :boolean,
      expect_plan123_terminal: :boolean
    ]

    with {opts, [], []} <- OptionParser.parse(argv, strict: switches),
         true <- length(opts) == length(Enum.uniq_by(opts, &elem(&1, 0))),
         [mode] <-
           Enum.filter(
             [:preterminal, :terminal],
             &Keyword.get(opts, String.to_atom("expect_plan123_#{&1}"))
           ),
         {:ok, root} <- resolve_root(Keyword.get(opts, :root)),
         {:ok, result} <- validate_plan123(root, mode) do
      IO.puts(result)
      :ok
    else
      {:error, _} = error -> error
      _ -> {:error, "Plan 123 requires exactly one evidence mode and a valid root"}
    end
  end

  defp run_plan121(argv) do
    switches = [root: :string, expect_plan121_authority: :boolean]

    with {opts, [], []} <- OptionParser.parse(argv, strict: switches),
         true <- length(opts) == length(Enum.uniq_by(opts, &elem(&1, 0))),
         true <- Keyword.get(opts, :expect_plan121_authority) == true,
         {:ok, root} <- resolve_root(Keyword.get(opts, :root)),
         {:ok, result} <- validate_plan121_authority(root) do
      IO.puts(result)
      :ok
    else
      {:error, _} = error -> error
      _ -> {:error, "Plan 121 requires exactly --expect-plan121-authority and a valid root"}
    end
  end

  defp plan121_legacy_paths do
    phase = @phase_dir

    %{
      p126_preflight: Path.join(phase, "133-126-PREFLIGHT.json"),
      p126_authorization: Path.join(phase, "133-126-AUTHORIZATION.json"),
      p126_supply: Path.join(phase, "133-126-SUPPLY.json"),
      p126_local_gates: Path.join(phase, "133-126-LOCAL-GATES.json"),
      p126_qualification_attempt: Path.join(phase, "133-126-QUALIFICATION-ATTEMPT.json"),
      census_a: Path.join(phase, "133-121-CENSUS-A.json"),
      census_b: Path.join(phase, "133-121-CENSUS-B.json"),
      census: Path.join(phase, "133-EVIDENCE-CENSUS.json"),
      review: Path.join(phase, "133-REVIEW.md"),
      security: Path.join(phase, "133-SECURITY.md"),
      inventory: Path.join(phase, "133-SECURITY-INVENTORY.json"),
      validation: Path.join(phase, "133-VALIDATION.md"),
      p121_authority: Path.join(phase, "133-121-AUTHORITY.json")
    }
  end

  defp plan121_paths do
    if Process.get(:phase133_history126, false) do
      plan121_legacy_paths()
    else
      plan121_legacy_paths()
      |> Map.drop([
        :p126_preflight,
        :p126_authorization,
        :p126_supply,
        :p126_local_gates,
        :p126_qualification_attempt
      ])
      |> Map.merge(%{
        p155_supply: Path.join(@phase_dir, "133-155-SUPPLY.json"),
        p155_route: Path.join(@phase_dir, "133-155-ROUTE.json"),
        p174_preflight: Path.join(@phase_dir, "133-174-PREFLIGHT.json"),
        p174_supply: Path.join(@phase_dir, "133-174-SUPPLY.json"),
        p174_retrieval: Path.join(@phase_dir, "133-174-RETRIEVAL.json"),
        p174_qualification_authorization:
          Path.join(@phase_dir, "133-174-QUALIFICATION-AUTHORIZATION.json"),
        p174_qualification_attempt: Path.join(@phase_dir, "133-174-QUALIFICATION-ATTEMPT.json"),
        p174_local_gates: Path.join(@phase_dir, "133-174-LOCAL-GATES.json")
      })
    end
  end

  defp plan121_local_gates(report, source) do
    with true <- report["plan"] == "133-126" and report["schema_version"] == 1,
         :ok <- plan114_record_credit(report),
         true <-
           report["subject_sha"] == source["sha"] and report["subject_tree"] == source["tree"],
         {:ok, _green} <- local_gate_authority(report) do
      :ok
    else
      _ -> {:error, "Plan 126 local-gates authority differs"}
    end
  end

  # The qualification checkout is gone by this stage. Recheck durable inputs and
  # recorded guard/stage proof without launching a native build or another Mix run.
  defp plan126_supply_and_gates(root, paths) do
    script = ~S"""
    import fs from 'node:fs';
    import path from 'node:path';
    import {execFileSync} from 'node:child_process';
    import {pathToFileURL} from 'node:url';
    const [root, helper, preflightPath, supplyPath, gatesPath] = process.argv.slice(1);
    const api = await import(pathToFileURL(helper));
    const read = file => fs.readFileSync(api.safe(file));
    const json = file => JSON.parse(read(path.join(root, file)));
    const preflight = json(preflightPath), supply = json(supplyPath), gates = json(gatesPath);
    const check = (ok, message) => { if (!ok) throw new Error(message); };
    check(preflight.runtime?.erlang === '27.3.4.15' && preflight.runtime?.elixir === '1.17.3-otp-27' &&
      supply.runtime?.elixir === '1.17.3' && supply.runtime?.otp === '27' && supply.runtime?.otp_patch === '27.3.4.15',
      'supported runtime');
    check(supply.report_sha256 === api.digest(supply), 'supply report digest');
    const lock = execFileSync('git', ['show', `${supply.source.sha}:mix.lock`], {cwd: root});
    check(api.sha(lock) === preflight.source.lock_sha256, 'locked source digest');
    check(supply.source.blobs && Object.keys(supply.source.blobs).length > 0, 'source blob identities');
    for (const [file, blob] of Object.entries(supply.source.blobs)) {
      check(api.sha(execFileSync('git', ['show', `${supply.source.sha}:${file}`], {cwd:root})) === blob.sha256 &&
        execFileSync('git', ['rev-parse', `${supply.source.sha}:${file}`], {cwd:root,encoding:'utf8'}).trim() === blob.oid,
        'source blob binding');
    }
    const packages = api.parseLock(lock.toString());
    check(packages.length === 67 && supply.packages.length === 67, 'locked package count');
    const contents = new Map();
    for (const [index, pkg] of packages.entries()) {
      const recorded = supply.packages[index];
      check(recorded.status === 'available' && Object.keys(pkg).every(key => recorded[key] === pkg[key]), 'locked package identity');
      contents.set(pkg.name, api.authenticate(read(path.join(supply.locations.cache, pkg.relative)), pkg));
    }
    const vix = supply.native.vix, lexbor = supply.native.lexbor;
    check(vix.status === 'available' && api.sha(read(vix.path)) === vix.sha256 &&
      preflight.inputs.vix.sha256 === vix.sha256, 'locked Vix asset');
    const checksums = contents.get('vix').get('checksum.exs').bytes.toString();
    check([...checksums.matchAll(/"([^"]+)"\s*=>\s*"sha256:([a-f0-9]{64})"/g)]
      .filter(match => match[1] === path.basename(vix.path) && match[2] === vix.sha256).length === 1, 'Vix checksum metadata');
    const lazy = contents.get('lazy_html').get('mix.exs').bytes.toString();
    check(lexbor.status === 'available' && lexbor.pin === '244b84956a6dc7eec293781d051354f351274c46' &&
      lazy.match(/@lexbor_git_sha "([a-f0-9]{40})"/)?.[1] === lexbor.pin, 'locked Lexbor pin');
    const nativeGit = args => execFileSync('git', args, {cwd:api.safe(lexbor.path),encoding:'utf8'}).trim();
    check(nativeGit(['rev-parse','HEAD']) === lexbor.pin && nativeGit(['rev-parse','HEAD^{tree}']) === lexbor.tree &&
      nativeGit(['status','--porcelain','--untracked-files=all']) === '', 'durable Lexbor source');
    const names = nativeGit(['ls-files']).split('\n');
    check(names.includes('CMakeLists.txt') && names.some(name=>name.startsWith('source/')) &&
      api.sha(Buffer.from(JSON.stringify(names.map(name=>[name,api.sha(read(api.safe(path.join(lexbor.path,name),lexbor.path)))])))) === lexbor.files_sha256,
      'durable Lexbor bytes');
    api.verifyGuardProof(gates.guard);
    api.verifyGates(root, supply, gates);
    """

    case System.cmd(
           "node",
           [
             "--input-type=module",
             "-e",
             script,
             Path.expand(root),
             Path.join(__DIR__, "phase_133_local_supply.mjs"),
             paths.p126_preflight,
             paths.p126_supply,
             paths.p126_local_gates
           ],
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        :ok

      {output, _} ->
        {:error,
         "Plan 126 durable supply or qualification proof differs: #{String.slice(output, 0, 1200)}"}
    end
  end

  defp plan126_source(root, source) do
    phase = @phase_dir

    allowed =
      Map.values(plan121_paths()) ++
        Map.values(plan122_paths()) ++
        Map.values(plan123_paths()) ++
        Enum.map(
          ~w(133-126-FETCH-ATTEMPT.json 133-126-CLONE-STARTED.json 133-126-CHECKOUT-STARTED.json
                  133-126-QUALIFICATION-ATTEMPT.json 133-126-SUMMARY.md 133-121-SUMMARY.md
                  133-122-SUMMARY.md 133-123-CANDIDATE-STAGED.json),
          &Path.join(phase, &1)
        ) ++
        [".planning/REQUIREMENTS.md", ".planning/ROADMAP.md", ".planning/STATE.md"]

    with true <- source["sha"] != "87572a019636ba1367c0c7245ae5cb89d0ea1909",
         :ok <-
           validate_committed_source(root, source["sha"], source["tree"], [
             "mix.lock",
             "coveralls.json"
           ]),
         {:ok, _} <- git(root, ["merge-base", "--is-ancestor", source["sha"], "HEAD"]),
         {:ok, commits} <- git(root, ["rev-list", "--first-parent", "#{source["sha"]}..HEAD"]),
         {:ok, dirty} <- git(root, ["diff", "--name-only", "--no-renames", "HEAD"]),
         {:ok, untracked} <- git(root, ["ls-files", "--others", "--exclude-standard"]),
         true <-
           Enum.all?(String.split(dirty <> "\n" <> untracked, "\n", trim: true), &(&1 in allowed)),
         true <-
           Enum.all?(String.split(commits, "\n", trim: true), fn commit ->
             case git(root, [
                    "diff-tree",
                    "--no-commit-id",
                    "--name-only",
                    "--no-renames",
                    "-r",
                    "#{commit}^1",
                    commit
                  ]) do
               {:ok, paths} -> Enum.all?(String.split(paths, "\n", trim: true), &(&1 in allowed))
               _ -> false
             end
           end),
         true <-
           Enum.all?(["133-115", "133-120"], fn plan ->
             case plan114_optional_json(root, Path.join(phase, "#{plan}-PREFLIGHT.json")) do
               {:ok, nil} -> true
               {:ok, old} -> get_in(old, ["source", "sha"]) != source["sha"]
               _ -> false
             end
           end) do
      :ok
    else
      _ -> {:error, "Plan 126 frozen source differs or reuses historical authority"}
    end
  end

  defp plan121_authority_map(root, paths) do
    hashes =
      paths
      |> Enum.reject(fn {key, _path} -> key == :p121_authority end)
      |> Map.new(fn {key, path} -> {"#{key}_sha256", plan114_artifact_hash(root, path)} end)

    if Enum.all?(Map.values(hashes), &match?({:ok, _}, &1)) do
      hashes = Map.new(hashes, fn {key, {:ok, digest}} -> {key, digest} end)

      if Map.has_key?(paths, :p155_supply) and Map.has_key?(paths, :p155_route) do
        with {:ok, p155_supply} <- plan114_json(root, paths.p155_supply),
             {:ok, p155_supply_bytes} <- plan114_file(root, paths.p155_supply),
             {:ok, p155_route} <- plan114_json(root, paths.p155_route),
             {:ok, p155_route_bytes} <- plan114_file(root, paths.p155_route),
             true <- valid_hex?(p155_supply["report_sha256"], 64),
             true <- valid_hex?(p155_route["report_sha256"], 64),
             {:ok, preflight} <- plan114_json(root, paths.p174_preflight),
             staging_digest <- get_in(preflight, ["staging_proof", "contents_sha256"]),
             node_digest <- get_in(preflight, ["node_executable", "sha256"]),
             path_digest <- preflight["path_sha256"],
             true <- Enum.all?([staging_digest, node_digest, path_digest], &valid_hex?(&1, 64)) do
          hashes
          |> Map.put("p155_supply_sha256", p155_supply["report_sha256"])
          |> Map.put("p155_supply_artifact_sha256", sha256(p155_supply_bytes))
          |> Map.put("p155_route_sha256", p155_route["report_sha256"])
          |> Map.put("p155_route_artifact_sha256", sha256(p155_route_bytes))
          |> Map.put("p174_staging_sha256", staging_digest)
          |> Map.put("p174_node_sha256", node_digest)
          |> Map.put("p174_path_sha256", path_digest)
        else
          _ -> nil
        end
      else
        hashes
      end
    else
      nil
    end
  end

  defp plan121_authority_digests(root, paths, authority, allow_plan123_append?) do
    case plan123_validation_append_matches(
           root,
           Map.get(authority, "authorities"),
           plan121_authority_map(root, paths),
           allow_plan123_append?
         ) do
      :ok -> :ok
      _ -> {:error, "Plan 121 upstream authority digest differs"}
    end
  end

  defp plan114_decode_json(bytes, label) do
    case Jason.decode(bytes) do
      {:ok, value} when is_map(value) -> {:ok, value}
      _ -> {:error, "Plan 121 census receipt is malformed: #{label}"}
    end
  end

  defp plan121_census_pair(a_bytes, b_bytes, a, b, ledger, source) do
    with true <- a_bytes == b_bytes,
         :ok <- plan121_census_identity(a, source),
         :ok <- plan121_census_identity(b, source),
         :ok <- plan121_census_identity(ledger, source),
         :ok <- plan121_census_taxonomy(a),
         :ok <- plan121_census_taxonomy(b),
         :ok <- plan121_census_taxonomy(ledger),
         :ok <- plan121_census_dispositions(a),
         :ok <- plan121_census_dispositions(b),
         :ok <- plan121_census_dispositions(ledger),
         true <- Map.get(ledger, "frozen") == true do
      :ok
    else
      {:error, message} ->
        {:error, message}

      _ ->
        {:error,
         "Plan 121 census receipts must be identical and bind a frozen exact-source ledger"}
    end
  end

  defp plan121_census_identity(%{"source" => source}, expected),
    do: plan121_source_equal(source, expected)

  defp plan121_census_identity(%{"subject_sha" => sha, "subject_tree" => tree}, expected),
    do: plan121_source_equal(%{"sha" => sha, "tree" => tree}, expected)

  defp plan121_census_identity(%{"source_sha" => sha, "source_tree" => tree}, expected),
    do: plan121_source_equal(%{"sha" => sha, "tree" => tree}, expected)

  defp plan121_census_identity(_, _), do: {:error, "Plan 121 census source identity is missing"}

  defp plan121_source_equal(source, expected) do
    if is_map(source) and source["sha"] == expected["sha"] and source["tree"] == expected["tree"],
      do: :ok,
      else: {:error, "Plan 121 census source differs from Plan 126"}
  end

  defp plan121_census_taxonomy(%{"dimensions" => entries}), do: plan121_dimension_ids(entries)
  defp plan121_census_taxonomy(%{"taxonomy" => entries}), do: plan121_dimension_ids(entries)

  defp plan121_census_taxonomy(_),
    do: {:error, "Plan 121 census must record all twelve taxonomy dimensions"}

  defp plan121_dimension_ids(entries) when is_list(entries) do
    ids = Enum.map(entries, fn entry -> if is_map(entry), do: entry["id"], else: entry end)

    if Enum.sort(ids) == Enum.sort(@plan121_dimensions) and length(ids) == length(Enum.uniq(ids)),
      do: :ok,
      else: {:error, "Plan 121 census must contain exactly twelve unique taxonomy dimensions"}
  end

  defp plan121_dimension_ids(_), do: {:error, "Plan 121 census taxonomy must be an array"}

  defp plan121_census_dispositions(%{"dispositions" => rows}), do: plan121_disposition_rows(rows)
  defp plan121_census_dispositions(%{"candidates" => rows}), do: plan121_disposition_rows(rows)

  defp plan121_census_dispositions(_),
    do: {:error, "Plan 121 census candidate dispositions are missing"}

  defp plan121_disposition_rows(rows) when is_list(rows) and rows != [] do
    ids =
      Enum.map(rows, fn row -> if is_map(row), do: row["id"] || row["candidate_id"], else: nil end)

    valid? =
      Enum.all?(rows, fn
        row when is_map(row) ->
          disposition = row["disposition"]

          valid_id =
            is_binary(row["id"] || row["candidate_id"]) and
              (row["id"] || row["candidate_id"]) != ""

          disposition in ["fix", "retain", "defer"] and valid_id and
            (disposition != "defer" or (is_map(row["trigger"]) and row["trigger"] != %{}))

        _ ->
          false
      end)

    if valid? and length(ids) == length(Enum.uniq(ids)),
      do: :ok,
      else:
        {:error,
         "Plan 121 census candidate identities and dispositions must be unique and complete"}
  end

  defp plan121_disposition_rows(_),
    do: {:error, "Plan 121 census candidate dispositions are malformed"}

  defp run_plan116(argv) do
    switches = [root: :string, expect_plan116_authority: :boolean]

    with {opts, [], []} <- OptionParser.parse(argv, strict: switches),
         true <- Keyword.get(opts, :expect_plan116_authority) == true,
         {:ok, root} <- resolve_root(Keyword.get(opts, :root)),
         {:ok, result} <- validate_plan116_authority(root) do
      IO.puts("#{result}")
      :ok
    else
      {:error, _} = error -> error
      _ -> {:error, "Plan 116 requires exactly --expect-plan116-authority and a valid root"}
    end
  end

  defp run_plan117(argv) do
    switches = [
      root: :string,
      checkpoint_answer: :string,
      checkpoint_preflight_sha256: :string,
      expect_plan117_preflight: :boolean,
      expect_plan117_decision: :boolean,
      expect_plan117_candidate: :boolean
    ]

    with {opts, [], []} <- OptionParser.parse(argv, strict: switches),
         [mode] <-
           Enum.filter([:preflight, :decision, :candidate], fn key ->
             Keyword.get(opts, String.to_atom("expect_plan117_#{key}")) == true
           end),
         {:ok, root} <- resolve_root(Keyword.get(opts, :root)),
         checkpoint <- %{
           answer: Keyword.get(opts, :checkpoint_answer),
           preflight_sha256: Keyword.get(opts, :checkpoint_preflight_sha256)
         },
         {:ok, result} <- validate_plan117(root, mode, %{}, checkpoint) do
      IO.puts("#{result}")
      :ok
    else
      {:error, _} = error -> error
      _ -> {:error, "Plan 117 requires exactly one decision mode and a valid root"}
    end
  end

  defp run_plan118(argv) do
    switches = [
      root: :string,
      expect_plan118_preterminal: :boolean,
      expect_plan118_provisional: :boolean,
      expect_plan118_restored: :boolean,
      expect_plan118_terminal: :boolean
    ]

    with {opts, [], []} <- OptionParser.parse(argv, strict: switches),
         [mode] <-
           Enum.filter([:preterminal, :provisional, :restored, :terminal], fn key ->
             Keyword.get(opts, String.to_atom("expect_plan118_#{key}")) == true
           end),
         {:ok, root} <- resolve_root(Keyword.get(opts, :root)),
         {:ok, result} <- validate_plan118(root, mode) do
      IO.puts("#{result}")
      :ok
    else
      {:error, _} = error -> error
      _ -> {:error, "Plan 118 requires exactly one state mode and a valid root"}
    end
  end

  defp plan114_paths do
    phase = @phase_dir

    %{
      p115_preflight: Path.join(phase, "133-115-PREFLIGHT.json"),
      p115_supply: Path.join(phase, "133-115-SUPPLY.json"),
      p115_local_gates: Path.join(phase, "133-115-LOCAL-GATES.json"),
      census_a: Path.join(phase, "133-116-CENSUS-A.json"),
      census_b: Path.join(phase, "133-116-CENSUS-B.json"),
      census: Path.join(phase, "133-EVIDENCE-CENSUS.json"),
      review: Path.join(phase, "133-REVIEW.md"),
      security: Path.join(phase, "133-SECURITY.md"),
      inventory: Path.join(phase, "133-SECURITY-INVENTORY.json"),
      validation: Path.join(phase, "133-VALIDATION.md"),
      p116_authority: Path.join(phase, "133-116-AUTHORITY.json"),
      p117_preflight: Path.join(phase, "133-117-PREFLIGHT.json"),
      p117_decision: Path.join(phase, "133-117-DECISION.json"),
      p117_candidate: Path.join(phase, "133-117-CANDIDATE.json"),
      p117_candidate_receipt: Path.join(phase, "133-117-PRIVATE-CANDIDATE.json"),
      p118_transaction: Path.join(phase, "133-118-TRANSACTION.json"),
      p118_summary: Path.join(phase, "133-118-SUMMARY.md"),
      canonical_receipt: Path.join(phase, "133-NIGHTLY-EVIDENCE.json")
    }
  end

  defp plan114_upstream_paths(paths) do
    Map.take(paths, [
      :p115_preflight,
      :p115_supply,
      :p115_local_gates,
      :census_a,
      :census_b,
      :census,
      :review,
      :security,
      :inventory,
      :validation,
      :p116_authority,
      :p117_preflight,
      :p117_decision,
      :p117_candidate,
      :p117_candidate_receipt,
      :p118_transaction,
      :p118_summary,
      :canonical_receipt
    ])
  end

  defp plan114_file(root, relative) do
    target = Path.expand(relative, root)
    root = Path.expand(root)
    parts = Path.split(Path.relative_to(target, root))

    ancestors = Enum.scan(parts, root, &Path.join(&2, &1))

    with true <- plan114_inside?(target, root),
         true <-
           Enum.all?(ancestors, fn path ->
             case File.lstat(path) do
               {:ok, %{type: type}} -> type in [:regular, :directory]
               _ -> false
             end
           end) or {:error, "Plan 114 input is missing or has unsafe ancestry"},
         {:ok, %{type: :regular, size: size}} <- File.stat(target),
         true <- size <= 16_777_216,
         {:ok, bytes} <- File.read(target) do
      {:ok, bytes}
    else
      {:error, message} when is_binary(message) -> {:error, message}
      _ -> {:error, "Plan 114 input is missing or has unsafe ancestry"}
    end
  end

  defp plan114_json(root, relative) do
    with {:ok, bytes} <- plan114_file(root, relative),
         {:ok, value} <- Jason.decode(bytes),
         true <- is_map(value) do
      {:ok, value}
    else
      {:error, message} when is_binary(message) -> {:error, message}
      _ -> {:error, "Plan 114 JSON is missing or malformed: #{relative}"}
    end
  end

  defp plan114_optional_json(root, relative) do
    target = Path.expand(relative, root)
    root = Path.expand(root)
    parts = Path.split(Path.relative_to(target, root))
    ancestors = Enum.scan(Enum.drop(parts, -1), root, &Path.join(&2, &1))

    with true <- plan114_inside?(target, root) and target != root,
         true <-
           Enum.all?(ancestors, fn path ->
             case File.lstat(path) do
               {:ok, %{type: :directory}} -> true
               _ -> false
             end
           end) do
      case File.lstat(target) do
        {:error, :enoent} -> {:ok, nil}
        {:ok, %{type: :regular}} -> plan114_json(root, relative)
        _ -> {:error, "Plan 114 JSON is unsafe: #{relative}"}
      end
    else
      _ -> {:error, "Plan 114 JSON ancestry is unsafe: #{relative}"}
    end
  end

  defp plan114_inside?(target, root) do
    relative = Path.relative_to(target, root)

    relative == "." or
      (relative != target and relative != ".." and not String.starts_with?(relative, "../"))
  end

  defp plan114_record_credit(record) do
    if record["qualification_credit"] == 0 and record["requirements_completed"] == [],
      do: :ok,
      else: {:error, "Plan 114 authority must preserve zero qualification credit"}
  end

  defp plan114_requirements_state(root, :pending), do: validate_requirements(root, false)
  defp plan114_requirements_state(root, :complete), do: validate_requirements(root, true)

  defp plan114_requirements_state(root, :either) do
    case validate_requirements(root, false) do
      :ok -> :ok
      {:error, _} -> validate_requirements(root, true)
    end
  end

  defp plan114_artifact_hash(root, relative) do
    with {:ok, bytes} <- plan114_file(root, relative), do: {:ok, sha256(bytes)}
  end

  defp plan114_authority_map(root, paths, include_plan116? \\ true) do
    files =
      [
        {"p115_preflight_sha256", paths.p115_preflight},
        {"p115_supply_sha256", paths.p115_supply},
        {"p115_local_gates_sha256", paths.p115_local_gates},
        {"census_a_sha256", paths.census_a},
        {"census_b_sha256", paths.census_b},
        {"census_ledger_sha256", paths.census},
        {"review_sha256", paths.review},
        {"security_sha256", paths.security},
        {"inventory_sha256", paths.inventory},
        {"validation_sha256", paths.validation}
      ] ++ if(include_plan116?, do: [{"p116_authority_sha256", paths.p116_authority}], else: [])

    Enum.reduce_while(files, {:ok, %{}}, fn {name, path}, {:ok, acc} ->
      case plan114_artifact_hash(root, path) do
        {:ok, digest} -> {:cont, {:ok, Map.put(acc, name, digest)}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, map} -> map
      {:error, _} -> nil
    end
  end

  defp plan114_authority_digests(root, paths, authority) do
    if authority["authorities"] == plan114_authority_map(root, paths, false),
      do: :ok,
      else: {:error, "Plan 116 upstream authority digest differs"}
  end

  defp plan114_census_pair(a, b, ledger, source) do
    source_of = fn value ->
      value["source"] || %{"sha" => value["subject_sha"], "tree" => value["subject_tree"]}
    end

    if source_of.(a) == source_of.(b) and source_of.(a)["sha"] == source["sha"] and
         source_of.(a)["tree"] == source["tree"] and a["dimensions"] == b["dimensions"] and
         a["dispositions"] == b["dispositions"] and a["dimensions"] == ledger["dimensions"] and
         a["dispositions"] == ledger["dispositions"] do
      :ok
    else
      {:error, "Plan 116 census pair or ledger differs"}
    end
  end

  defp plan114_plan117_branch(_root, :preflight, _paths, _preflight, _checkpoint), do: :ok

  defp plan114_plan117_branch(root, :decision, paths, preflight, checkpoint) do
    with {:ok, decision} <- plan114_json(root, paths.p117_decision),
         {:ok, preflight_bytes} <- plan114_file(root, paths.p117_preflight),
         :ok <- plan114_record_credit(decision),
         true <- decision["plan"] == "133-117" and decision["schema_version"] == 1,
         true <- decision["answer"] in ["authorize", "stop"],
         true <- decision["preflight_sha256"] == sha256(preflight_bytes),
         true <-
           decision["source"] == preflight["source"] and
             decision["remote_ref"] == preflight["remote_ref"],
         true <- decision["authorities"] == preflight["authorities"],
         true <-
           decision["remote_action_count"] ==
             if(decision["answer"] == "authorize", do: 2, else: 0),
         true <-
           is_nil(Map.get(checkpoint, :answer)) or
             (Map.get(checkpoint, :answer) == decision["answer"] and
                Map.get(checkpoint, :preflight_sha256) == decision["preflight_sha256"]) do
      :ok
    else
      {:error, message} when is_binary(message) -> {:error, message}
      false -> {:error, "Plan 117 decision answer, checkpoint, or preflight binding differs"}
      _ -> {:error, "Plan 117 decision is missing or malformed"}
    end
  end

  defp plan114_plan117_branch(root, :candidate, paths, preflight, checkpoint) do
    with :ok <- plan114_plan117_branch(root, :decision, paths, preflight, checkpoint),
         {:ok, decision} <- plan114_json(root, paths.p117_decision),
         {:ok, candidate} <- plan114_json(root, paths.p117_candidate),
         {:ok, candidate_receipt} <- plan114_file(root, paths.p117_candidate_receipt),
         :ok <- plan114_record_credit(candidate),
         true <- decision["answer"] == "authorize",
         true <- candidate["plan"] == "133-117" and candidate["schema_version"] == 1,
         true <- candidate["status"] == "private_candidate",
         true <-
           candidate["source"] == preflight["source"] and
             candidate["remote_ref"] == preflight["remote_ref"],
         true <- candidate["preflight_sha256"] == decision["preflight_sha256"],
         true <- candidate["authorities"] == preflight["authorities"],
         true <- candidate["candidate_sha256"] == sha256(candidate_receipt),
         true <- candidate["remote_action_count"] == 2 do
      :ok
    else
      {:error, message} when is_binary(message) -> {:error, message}
      false -> {:error, "Plan 117 candidate, private receipt, authorization, or source differs"}
      _ -> {:error, "Plan 117 candidate is missing or malformed"}
    end
  end

  defp plan114_plan118_state(root, :preterminal, paths, nil) do
    with :ok <- plan114_requirements_state(root, :pending),
         {:ok, candidate} <- plan114_json(root, paths.p117_candidate),
         true <- candidate["status"] == "private_candidate" do
      :ok
    else
      {:error, message} when is_binary(message) -> {:error, message}
      _ -> {:error, "Plan 118 preterminal requires a private candidate and five pending IDs"}
    end
  end

  defp plan114_plan118_state(_root, :preterminal, _paths, _transaction),
    do: {:error, "Plan 118 preterminal must be read-only before the transaction journal exists"}

  defp plan114_plan118_state(_root, mode, _paths, nil) when mode in [:provisional, :restored],
    do: {:error, "Plan 118 pending transaction journal is missing"}

  defp plan114_plan118_state(_root, :provisional, _paths, transaction) do
    if transaction["plan"] == "133-118" and transaction["status"] == "pending" and
         transaction["phase"] == "provisional" and transaction["qualification_credit"] == 0 and
         transaction["requirements_completed"] == @plan114_requirements and
         valid_hex?(transaction["old_receipt_sha256"], 64),
       do: :ok,
       else:
         {:error, "Plan 118 provisional state must remain behind a zero-credit pending journal"}
  end

  defp plan114_plan118_state(root, :restored, paths, transaction) do
    with true <- transaction["plan"] == "133-118" and transaction["status"] == "restored",
         true <- transaction["old_receipt_sha256"] == @plan80_prior_receipt_sha256,
         true <- transaction["requirements_completed"] == [],
         :ok <- plan114_requirements_state(root, :pending),
         {:ok, receipt} <- plan114_file(root, paths.canonical_receipt),
         true <- sha256(receipt) == transaction["old_receipt_sha256"] do
      :ok
    else
      {:error, message} when is_binary(message) -> {:error, message}
      _ -> {:error, "Plan 118 restored state must preserve the old receipt and five pending IDs"}
    end
  end

  defp plan114_plan118_state(root, :terminal, paths, nil) do
    with {:ok, summary} <- plan114_file(root, paths.p118_summary),
         {:ok, receipt} <- plan114_file(root, paths.canonical_receipt),
         {:ok, parsed} <- summary_document(summary),
         true <- parsed.status == "complete",
         true <- Map.get(parsed.metadata, "requirements-completed") == @plan114_requirements,
         true <- Map.get(parsed.metadata, "terminal_proof_sha256") |> valid_hex?(64),
         true <- Map.get(parsed.metadata, "canonical_receipt_sha256") == sha256(receipt),
         {:ok, candidate_receipt} <- plan114_file(root, paths.p117_candidate_receipt),
         true <- sha256(candidate_receipt) == sha256(receipt),
         :ok <- plan114_requirements_state(root, :complete) do
      :ok
    else
      {:error, message} when is_binary(message) ->
        {:error, message}

      _ ->
        {:error,
         "Plan 118 terminal proof, canonical receipt, or exactly five requirement statuses differ"}
    end
  end

  defp plan114_plan118_state(_root, :terminal, _paths, _transaction),
    do: {:error, "Plan 118 ordinary terminal validation rejects a pending transaction journal"}

  defp run_plan112_preterminal(argv) do
    switches = [root: :string, expect_plan112_preterminal: :boolean]

    with {opts, [], []} <- OptionParser.parse(argv, strict: switches),
         true <- length(opts) == length(Enum.uniq_by(opts, &elem(&1, 0))),
         true <- Keyword.get(opts, :expect_plan112_preterminal) == true,
         {:ok, root} <- resolve_root(Keyword.get(opts, :root)),
         {:ok, result} <- validate_plan112_preterminal(root) do
      IO.puts("phase 133 Plan 112 preterminal valid: #{result}; zero requirement credit")
      :ok
    else
      {:error, _} = error -> error
      _ -> {:error, "Plan 112 requires exactly --expect-plan112-preterminal and a valid root"}
    end
  end

  def validate_plan112_preterminal(root, check \\ &plan111_check/3) do
    with {:ok, bytes} <- plan111_read(root, "133-112-PRETERMINAL.json"),
         {:ok, report} <- Jason.decode(bytes),
         :ok <- plan112_preterminal_record(root, report, check) do
      {:ok, "#{report["status"]} Plan 112 evidence"}
    else
      {:error, "Plan 111 input is missing or has unsafe ancestry"} ->
        {:error, "Plan 112 preterminal record is missing or unsafe"}

      {:error, %Jason.DecodeError{}} ->
        {:error, "Plan 112 preterminal record is malformed"}

      {:error, :enoent} ->
        {:error, "Plan 112 preterminal record is missing"}

      {:error, reason} when is_atom(reason) ->
        {:error, "Plan 112 preterminal record is missing or unsafe"}

      {:error, message} when is_binary(message) ->
        {:error, message}

      _ ->
        {:error, "Plan 112 preterminal record is missing or malformed"}
    end
  rescue
    _ -> {:error, "Plan 112 preterminal record is missing or malformed"}
  end

  defp plan112_preterminal_record(root, report, check) do
    with true <- report["plan"] == "133-112" and report["schema_version"] == 1,
         :ok <- plan112_zero_credit(root, report),
         :ok <- plan112_first_red(report),
         :ok <- plan112_candidate(root, report, check) do
      :ok
    else
      {:error, message} when is_binary(message) -> {:error, message}
      false -> {:error, "Plan 112 source, candidate digest, or zero-credit binding differs"}
      _ -> {:error, "Plan 112 preterminal record is missing or malformed"}
    end
  end

  defp plan112_zero_credit(root, report) do
    source = report["source"]

    with true <-
           is_map(source) and valid_hex?(source["sha"], 40) and valid_hex?(source["tree"], 40),
         true <- report["requirements_completed"] == [] and report["qualification_credit"] == 0,
         :ok <- validate_requirements(root, false),
         {:ok, prior_bytes} <- plan111_read(root, "133-NIGHTLY-EVIDENCE.json"),
         true <- sha256(prior_bytes) == @plan80_prior_receipt_sha256 do
      :ok
    else
      {:error, message} when is_binary(message) -> {:error, message}
      _ -> {:error, "Plan 112 must preserve the canonical receipt and all five pending IDs"}
    end
  end

  defp plan112_candidate(_root, %{"status" => "stopped"}, _check), do: :ok

  defp plan112_candidate(root, %{"status" => "ready"} = report, check) do
    with {:ok, candidate_bytes} <- plan111_read(root, "133-111-CANDIDATE.json"),
         true <- report["candidate_sha256"] == sha256(candidate_bytes),
         {:ok, candidate} <- Jason.decode(candidate_bytes),
         true <- candidate["subject_sha"] == get_in(report, ["source", "sha"]),
         true <- candidate["remote_ref"] == report["remote_ref"],
         {:ok, summary_bytes} <- plan111_read(root, "133-111-SUMMARY.md"),
         {:ok, summary} <- summary_document(summary_bytes),
         true <- summary.metadata["subject_tree"] == get_in(report, ["source", "tree"]),
         {:ok, preflight_bytes} <- plan111_read(root, "133-111-PREFLIGHT.json"),
         {:ok, preflight} <- Jason.decode(preflight_bytes),
         {:ok, decision_bytes} <- plan111_read(root, "133-111-DECISION.json"),
         {:ok, decision} <- Jason.decode(decision_bytes),
         true <- report["authorities"] == preflight["authorities"],
         true <- report["source"] == preflight["source"],
         {:ok, _} <-
           validate_plan111(
             root,
             :candidate,
             %{answer: decision["decision"], preflight_sha256: sha256(preflight_bytes)},
             check
           ) do
      :ok
    else
      {:error, message} when is_binary(message) -> {:error, message}
      _ -> {:error, "Plan 112 candidate, source, or upstream authorities differ"}
    end
  end

  defp plan112_candidate(_root, _report, _check),
    do: {:error, "Plan 112 status must be ready or stopped"}

  defp plan112_first_red(%{"status" => "ready", "first_red" => nil}), do: :ok

  defp plan112_first_red(%{"status" => "stopped", "first_red" => red})
       when is_map(red) and map_size(red) > 0,
       do: :ok

  defp plan112_first_red(_),
    do: {:error, "Plan 112 ready/stopped status and first-red evidence differ"}

  defp run_plan113(argv) do
    switches = [
      root: :string,
      expect_plan113_provisional: :boolean,
      expect_plan113_restored: :boolean,
      expect_plan113_terminal: :boolean
    ]

    with {opts, [], []} <- OptionParser.parse(argv, strict: switches),
         true <- length(opts) == length(Enum.uniq_by(opts, &elem(&1, 0))),
         [{flag, true}] <-
           Enum.filter(opts, fn {key, value} ->
             String.starts_with?(Atom.to_string(key), "expect_plan113_") and value
           end),
         {:ok, root} <- resolve_root(Keyword.get(opts, :root)),
         mode <-
           %{
             expect_plan113_provisional: :provisional,
             expect_plan113_restored: :restored,
             expect_plan113_terminal: :terminal
           }[flag],
         {:ok, result} <- validate_plan113_state(root, mode) do
      IO.puts("phase 133 Plan 113 #{mode} valid: #{result}")
      :ok
    else
      {:error, _} = error -> error
      _ -> {:error, "Plan 113 requires exactly one state mode and a valid root"}
    end
  end

  def validate_plan113_state(root, mode) when mode in [:provisional, :restored, :terminal] do
    with {:ok, provisional_bytes} <- plan111_read(root, "133-113-PROVISIONAL.json"),
         {:ok, provisional} <- Jason.decode(provisional_bytes),
         :ok <- validate_requirements(root, provisional["status"] == "provisional"),
         {:ok, canonical} <- plan111_read(root, "133-NIGHTLY-EVIDENCE.json"),
         {:ok, candidate} <- plan111_read(root, "133-111-CANDIDATE.json"),
         {:ok, preterminal_bytes} <- plan111_read(root, "133-112-PRETERMINAL.json"),
         {:ok, preterminal} <- Jason.decode(preterminal_bytes),
         :ok <- plan113_source_and_snapshots(provisional, preterminal, preterminal_bytes),
         :ok <- plan113_state_branch(root, mode, provisional, canonical, candidate) do
      {:ok, "#{mode} state verified; no mutation performed"}
    else
      {:error, message} when is_binary(message) -> {:error, message}
      _ -> {:error, "Plan 113 state evidence is missing or malformed"}
    end
  rescue
    _ -> {:error, "Plan 113 state evidence is missing or malformed"}
  end

  def validate_plan113_state(_root, _mode), do: {:error, "unknown Plan 113 state mode"}

  defp plan113_source_and_snapshots(p, preterminal, preterminal_bytes) do
    with true <- p["plan"] == "133-113" and p["schema_version"] == 1,
         true <- p["source"] == preterminal["source"],
         true <- p["preterminal_sha256"] == sha256(preterminal_bytes),
         true <- valid_hex?(p["old_receipt_sha256"], 64),
         true <- valid_hex?(p["requirements_snapshot_sha256"], 64),
         true <- valid_hex?(p["roadmap_snapshot_sha256"], 64),
         true <- valid_hex?(p["state_snapshot_sha256"], 64),
         true <- p["candidate_sha256"] == preterminal["candidate_sha256"],
         true <- p["subject_sha"] == get_in(p, ["source", "sha"]),
         true <- p["remote_ref"] == preterminal["remote_ref"] do
      :ok
    else
      _ -> {:error, "Plan 113 source, snapshot, or preterminal binding differs"}
    end
  end

  defp plan113_state_branch(root, :provisional, p, canonical, candidate) do
    terminal_summary = Path.join([root, @phase_dir, "133-113-SUMMARY.md"])

    with true <- p["status"] == "provisional" and p["first_red"] == nil,
         true <- p["terminal_summary_published"] == false,
         true <- p["candidate_sha256"] == sha256(candidate),
         true <- canonical == candidate,
         true <- not File.exists?(terminal_summary),
         true <- p["requirements_completed"] == @phase_requirements do
      :ok
    else
      _ ->
        {:error,
         "Plan 113 provisional state must bind the exact candidate and five temporary IDs"}
    end
  end

  defp plan113_state_branch(_root, :restored, p, canonical, _candidate) do
    with true <- p["status"] == "restored" and is_map(p["first_red"]),
         true <- p["requirements_completed"] == [],
         true <- sha256(canonical) == @plan80_prior_receipt_sha256,
         true <- p["old_receipt_sha256"] == @plan80_prior_receipt_sha256 do
      :ok
    else
      _ ->
        {:error,
         "Plan 113 restored state must preserve the original receipt and five pending IDs"}
    end
  end

  defp plan113_state_branch(root, :terminal, p, canonical, candidate) do
    summary_path = Path.join([root, @phase_dir, "133-113-SUMMARY.md"])

    with {:ok, summary_bytes} <- File.read(summary_path),
         {:ok, summary} <- summary_document(summary_bytes),
         true <- summary.metadata["subject_sha"] == p["subject_sha"],
         true <- summary.metadata["subject_tree"] == get_in(p, ["source", "tree"]),
         true <- summary.metadata["remote_ref"] == p["remote_ref"],
         true <- summary.metadata["candidate_sha256"] == p["candidate_sha256"],
         true <- summary.metadata["requirements-completed"] == p["requirements_completed"],
         :ok <- plan113_terminal_branch(summary.status, p, canonical, candidate) do
      :ok
    else
      _ -> {:error, "Plan 113 terminal summary differs from the reconciled state"}
    end
  end

  defp plan113_terminal_branch("complete", p, canonical, candidate) do
    with true <- p["status"] == "provisional",
         true <- canonical == candidate,
         true <- p["requirements_completed"] == @phase_requirements do
      :ok
    else
      _ -> {:error, "Plan 113 terminal success lacks the exact provisional receipt and IDs"}
    end
  end

  defp plan113_terminal_branch("halted", p, canonical, _candidate) do
    with true <- p["status"] == "restored" and is_map(p["first_red"]),
         true <- sha256(canonical) == @plan80_prior_receipt_sha256,
         true <- p["requirements_completed"] == [] do
      :ok
    else
      _ -> {:error, "Plan 113 terminal halt must remain restored and zero-credit"}
    end
  end

  defp plan113_terminal_branch(_, _p, _canonical, _candidate),
    do: {:error, "Plan 113 terminal summary must be complete or halted"}

  defp run_legacy(argv) do
    with {:ok, options} <- parse_options(argv),
         {:ok, root} <- resolve_root(options.root) do
      report_root = Path.expand(options.fixture_report_root || root)

      cond do
        options.expect_plan64_repair ->
          validate_plan64_mode(report_root, root, :repair)

        options.expect_plan64_halted ->
          validate_plan64_mode(report_root, root, :halted)

        options.fixture_expect_plan64_repair ->
          validate_plan64_mode(report_root, root, :repair, :fixture)

        options.fixture_expect_plan64_halted ->
          validate_plan64_mode(report_root, root, :halted, :fixture)

        options.expect_plan65_source ->
          validate_plan65_mode(report_root, root, :production)

        options.fixture_expect_plan65_source ->
          validate_plan65_mode(report_root, root, :fixture)

        options.expect_plan66_qualified ->
          validate_plan66_mode(report_root, root, :qualified, :production)

        options.expect_plan66_halted ->
          validate_plan66_mode(report_root, root, :halted, :production)

        options.fixture_expect_plan66_qualified ->
          validate_plan66_mode(report_root, root, :qualified, :fixture)

        options.fixture_expect_plan66_halted ->
          validate_plan66_mode(report_root, root, :halted, :fixture)

        options.expect_plan69_qualified ->
          validate_plan69_mode(report_root, root, :qualified, :production)

        options.expect_plan69_halted ->
          validate_plan69_mode(report_root, root, :halted, :production)

        options.fixture_expect_plan69_qualified ->
          validate_plan69_mode(report_root, root, :qualified, :fixture)

        options.fixture_expect_plan69_halted ->
          validate_plan69_mode(report_root, root, :halted, :fixture)

        options.expect_plan84_repair_complete ->
          validate_plan84_mode(report_root, root, :repair_complete, :production)

        options.fixture_expect_plan84_repair_complete ->
          validate_plan84_mode(report_root, root, :repair_complete, :fixture)

        options.expect_plan85_halted ->
          validate_plan84_mode(report_root, root, :plan85_halted, :production)

        options.fixture_expect_plan85_halted ->
          validate_plan84_mode(report_root, root, :plan85_halted, :fixture)

        options.expect_plan85_qualified ->
          validate_plan84_mode(report_root, root, :plan85_qualified, :production)

        options.fixture_expect_plan85_qualified ->
          validate_plan84_mode(report_root, root, :plan85_qualified, :fixture)

        options.expect_plan91_local_result ->
          validate_plan91_mode(report_root, root, :production)

        options.fixture_expect_plan91_local_result ->
          validate_plan91_mode(report_root, root, :fixture)

        options.expect_plan80_qualified ->
          validate_plan79_branch_mode(report_root, root, 80, :qualified, :production)

        options.expect_plan80_halted ->
          validate_plan79_branch_mode(report_root, root, 80, :halted, :production)

        options.fixture_expect_plan80_qualified ->
          validate_plan79_branch_mode(report_root, root, 80, :qualified, :fixture)

        options.fixture_expect_plan80_halted ->
          validate_plan79_branch_mode(report_root, root, 80, :halted, :fixture)

        options.expect_plan81_authority_complete ->
          validate_plan79_branch_mode(report_root, root, 81, :qualified, :production)

        options.expect_plan81_halted ->
          validate_plan79_branch_mode(report_root, root, 81, :halted, :production)

        options.fixture_expect_plan81_authority_complete ->
          validate_plan79_branch_mode(report_root, root, 81, :qualified, :fixture)

        options.fixture_expect_plan81_halted ->
          validate_plan79_branch_mode(report_root, root, 81, :halted, :fixture)

        options.expect_plan82_owned_candidate ->
          validate_plan79_branch_mode(report_root, root, 82, :qualified, :production)

        options.expect_plan82_halted ->
          validate_plan79_branch_mode(report_root, root, 82, :halted, :production)

        options.fixture_expect_plan82_owned_candidate ->
          validate_plan79_branch_mode(report_root, root, 82, :qualified, :fixture)

        options.fixture_expect_plan82_halted ->
          validate_plan79_branch_mode(report_root, root, 82, :halted, :fixture)

        options.expect_plan83_execution_complete ->
          validate_plan79_branch_mode(report_root, root, 83, :qualified, :production)

        options.expect_plan83_halted ->
          validate_plan79_branch_mode(report_root, root, 83, :halted, :production)

        options.fixture_expect_plan83_execution_complete ->
          validate_plan79_branch_mode(report_root, root, 83, :qualified, :fixture)

        options.fixture_expect_plan83_halted ->
          validate_plan79_branch_mode(report_root, root, 83, :halted, :fixture)

        options.expect_plan62_qualified ->
          validate_plan62_mode(report_root, :qualified)

        options.expect_plan62_halted ->
          validate_plan62_mode(report_root, :halted)

        true ->
          if plan79_pre_attempt?(report_root) do
            validate_plan79_pre_attempt(report_root, root)
          else
            run_execution(options, root)
          end
      end
    end
  end

  @plan111_files %{
    "supply_sha256" => "133-108-PREFLIGHT.json",
    "local_gates_sha256" => "133-108-LOCAL-GATES.json",
    "census_sha256" => "133-EVIDENCE-CENSUS.json",
    "census_a_sha256" => "133-109-CENSUS-A.json",
    "census_b_sha256" => "133-109-CENSUS-B.json",
    "review_sha256" => "133-REVIEW.md",
    "security_sha256" => "133-SECURITY.md",
    "inventory_sha256" => "133-SECURITY-INVENTORY.json",
    "validation_sha256" => "133-VALIDATION.md",
    "authority_sha256" => "133-110-AUTHORITY.json"
  }
  @plan111_checks ~w(review security nyquist dialyzer nightly_summary incident truth)
  @plan105_summary_digest "731a7373309bdac840dab3aec7602cc17f67f5408c724bda1ba799b717c840e6"

  # checkpoint_* are supplied by the checkpoint-handling caller, NEVER read from
  # DECISION.json. They are a trusted invocation boundary, not a local signature.
  defp run_plan111(argv) do
    switches = [
      root: :string,
      checkpoint_answer: :string,
      checkpoint_preflight_sha256: :string,
      expect_plan111_decision: :boolean,
      expect_plan111_authorization: :boolean,
      expect_plan111_candidate: :boolean
    ]

    with {opts, [], []} <- OptionParser.parse(argv, strict: switches),
         true <- length(opts) == length(Enum.uniq_by(opts, &elem(&1, 0))),
         [{flag, true}] <-
           Enum.filter(opts, fn {key, value} ->
             String.starts_with?(Atom.to_string(key), "expect_plan111_") and value
           end),
         {:ok, root} <- resolve_root(Keyword.get(opts, :root)),
         mode <-
           %{
             expect_plan111_decision: :decision,
             expect_plan111_authorization: :authorization,
             expect_plan111_candidate: :candidate
           }[flag],
         checkpoint <- %{
           answer: Keyword.get(opts, :checkpoint_answer),
           preflight_sha256: Keyword.get(opts, :checkpoint_preflight_sha256)
         },
         {:ok, result} <- validate_plan111(root, mode, checkpoint) do
      IO.puts("phase 133 Plan 111 #{mode} valid: #{result}; zero requirement credit")
      :ok
    else
      {:error, _} = error ->
        error

      _ ->
        {:error, "Plan 111 requires one mode and explicit checkpoint context; invalid arguments"}
    end
  end

  # The effect seam is for copied-tree tests; the CLI exposes no bypass or fixture
  # switch. Real calls always use the repository-owned validators below.
  def validate_plan111(root, mode, checkpoint, check \\ &plan111_check/3) do
    with true <- mode in [:decision, :authorization, :candidate],
         :ok <- plan111_preserved(root),
         {:ok, preflight_bytes} <- plan111_read(root, "133-111-PREFLIGHT.json"),
         {:ok, preflight} <- Jason.decode(preflight_bytes),
         {:ok, decision_bytes} <- plan111_read(root, "133-111-DECISION.json"),
         {:ok, decision} <- Jason.decode(decision_bytes),
         :ok <- plan111_decision_binding(preflight, decision, sha256(preflight_bytes)),
         :ok <- plan111_checkpoint(preflight, decision, checkpoint, sha256(preflight_bytes)),
         {:ok, result} <- plan111_branch(root, mode, preflight, decision, check) do
      {:ok, result}
    else
      {:error, message} when is_binary(message) -> {:error, message}
      _ -> {:error, "Plan 111 evidence is missing or malformed"}
    end
  rescue
    _ -> {:error, "Plan 111 evidence is missing or malformed"}
  end

  defp plan111_preserved(root) do
    with :ok <- validate_requirements(root, false),
         {:ok, prior} <- plan111_read(root, "133-NIGHTLY-EVIDENCE.json"),
         true <-
           sha256(prior) == @plan80_prior_receipt_sha256 or {:error, "canonical receipt changed"},
         {:ok, history} <- plan111_read(root, "133-105-SUMMARY.md"),
         true <-
           sha256(history) == @plan105_summary_digest or {:error, "Plan 105 history changed"} do
      :ok
    end
  end

  defp plan111_read(root, filename) do
    target = Path.join([root, @phase_dir, filename])
    parts = Path.split(Path.relative_to(target, root))
    ancestors = Enum.scan(parts, root, &Path.join(&2, &1))

    with true <-
           Enum.all?(ancestors, fn p ->
             case File.lstat(p) do
               {:ok, %{type: type}} -> type in [:regular, :directory]
               _ -> false
             end
           end) or {:error, "Plan 111 input is missing or has unsafe ancestry"},
         {:ok, %{type: :regular, size: size}} <- File.stat(target),
         true <- size <= 16_777_216,
         {:ok, bytes} <- File.read(target) do
      {:ok, bytes}
    else
      _ -> {:error, "Plan 111 input is missing or has unsafe ancestry"}
    end
  end

  defp plan111_decision_binding(p, d, digest) do
    source = p["source"]

    valid_source =
      is_map(source) and valid_hex?(source["sha"], 40) and valid_hex?(source["tree"], 40)

    cond do
      p["plan"] != "133-111" or d["plan"] != "133-111" or
        p["schema_version"] != 1 or d["schema_version"] != 1 ->
        {:error, "Plan 111 plan/schema identity differs"}

      not valid_source or
          p["remote_ref"] != "refs/heads/phase-133-evidence-#{String.slice(source["sha"], 0, 12)}" ->
        {:error, "Plan 111 full SHA/tree or literal derived ref differs"}

      d["source"] != source or d["remote_ref"] != p["remote_ref"] or
          d["preflight_sha256"] != digest ->
        {:error, "Plan 111 decision source/ref/preflight digest differs"}

      d["authorities"] != p["authorities"] ->
        {:error, "Plan 111 decision upstream authority digests differ"}

      not Enum.all?(
        [p, d],
        &(&1["requirements_completed"] == [] and &1["qualification_credit"] == 0 and
              &1["remote_commands"] == 0)
      ) ->
        {:error,
         "Plan 111 decision/preflight must grant zero credit and record zero remote commands"}

      d["decision"] not in ["authorize", "stop"] or d["checkpoint_answer"] != d["decision"] ->
        {:error, "Plan 111 decision is not a literal authorize or stop"}

      true ->
        :ok
    end
  end

  defp plan111_checkpoint(p, d, checkpoint, digest) do
    automatic_stop =
      p["status"] == "stopped" and d["decision"] == "stop" and is_map(p["first_red"])

    if automatic_stop or
         (checkpoint[:answer] == d["decision"] and checkpoint[:preflight_sha256] == digest),
       do: :ok,
       else:
         {:error,
          "Plan 111 requires the independent checkpoint answer and displayed preflight digest"}
  end

  defp plan111_branch(root, :decision, p, %{"decision" => "stop"}, _check) do
    if ((p["status"] == "ready" and p["first_red"] == nil) or
          (p["status"] == "stopped" and is_map(p["first_red"]) and map_size(p["first_red"]) > 0)) and
         not File.exists?(Path.join([root, @phase_dir, "133-111-CANDIDATE.json"])),
       do: {:ok, "stopped; no remote permission"},
       else: {:error, "Plan 111 stop cannot carry a candidate or unknown preflight status"}
  end

  defp plan111_branch(_root, _mode, _p, %{"decision" => "stop"}, _check),
    do: {:error, "Plan 111 stop denies all remote writes and candidates"}

  defp plan111_branch(root, mode, p, d, check) do
    with :ok <- plan111_ready(root, p, check),
         :ok <- if(mode == :candidate, do: plan111_candidate(root, p, d, check), else: :ok) do
      {:ok,
       if(mode == :candidate,
         do: "authenticated private candidate",
         else: "authorized exact pair"
       )}
    end
  end

  defp plan111_ready(root, p, check) do
    expected_lookup = %{
      "argv" => ["git", "ls-remote", "--heads", "origin", p["remote_ref"]],
      "exit_code" => 0,
      "stdout" => ""
    }

    with true <-
           (p["status"] == "ready" and p["first_red"] == nil) or
             {:error, "ready preflight required"},
         true <-
           p["lookup"] == expected_lookup or {:error, "exact ref absence is not established"},
         true <-
           p["prior_receipt_sha256"] == @plan80_prior_receipt_sha256 or
             {:error, "preflight prior receipt differs"},
         {:ok, files} <- plan111_authority_files(root, p["authorities"]),
         {:ok, gates} <- Jason.decode(files["local_gates_sha256"]),
         {:ok, _} <- local_gate_authority(gates),
         true <-
           (gates["plan"] == "133-108" and gates["subject_sha"] == p["source"]["sha"] and
              gates["subject_tree"] == p["source"]["tree"]) or
             {:error, "Plan 108 green source differs"},
         {:ok, authority} <- Jason.decode(files["authority_sha256"]),
         :ok <- plan111_authority_record(authority, p, files),
         :ok <- plan111_authority_sections(authority, p, files),
         :ok <- check.(:source, root, p),
         :ok <- check.(:supply, root, p),
         :ok <- check.(:census, root, %{preflight: p, files: files}) do
      :ok
    end
  end

  defp plan111_authority_files(root, digests) do
    if is_map(digests) and Enum.sort(Map.keys(digests)) == Enum.sort(Map.keys(@plan111_files)) do
      Enum.reduce_while(@plan111_files, {:ok, %{}}, fn {key, name}, {:ok, files} ->
        case plan111_read(root, name) do
          {:ok, bytes} ->
            if valid_hex?(digests[key], 64) and sha256(bytes) == digests[key],
              do: {:cont, {:ok, Map.put(files, key, bytes)}},
              else: {:halt, {:error, "Plan 111 stale upstream authority: #{key}"}}

          error ->
            {:halt, error}
        end
      end)
    else
      {:error, "Plan 111 requires the complete upstream authority digest set"}
    end
  end

  defp plan111_authority_record(a, p, files) do
    upstream = Map.delete(p["authorities"], "authority_sha256")
    checks = a["checks"]

    with true <-
           (a["plan"] == "133-110" and a["status"] == "ready" and a["source"] == p["source"] and
              a["remote_ref"] == p["remote_ref"] and a["authorities"] == upstream) or
             {:error, "Plan 110 source or upstream binding differs"},
         true <-
           (a["requirements_completed"] == [] and a["qualification_credit"] == 0) or
             {:error, "Plan 110 must grant zero credit"},
         true <-
           (is_map(checks) and Enum.sort(Map.keys(checks)) == Enum.sort(@plan111_checks)) or
             {:error, "Plan 110 check set is incomplete"},
         true <-
           Enum.all?(@plan111_checks, fn key ->
             c = checks[key]

             is_map(c) and c["exit_code"] == 0 and c["status"] == "pass" and
               c["source"] == p["source"] and
               is_binary(c["command"]) and c["command"] != "" and
               is_integer(c["test_count"]) and c["test_count"] > 0
           end) or {:error, "Plan 110 checks are red, empty, or foreign"},
         true <-
           (a["wr_01"] == "closed_by_executable_contract" and a["blocking_findings"] == 0 and
              a["high_findings"] == 0) or {:error, "Plan 110 unresolved review/security finding"},
         true <-
           files["census_a_sha256"] == files["census_b_sha256"] or
             {:error, "Plan 109 census receipts differ"} do
      :ok
    end
  end

  defp plan111_authority_sections(a, p, files) do
    metadata =
      p["authorities"]
      |> Map.merge(
        Map.take(
          Map.get(a, "sections", %{}),
          ~w(review_section_sha256 security_section_sha256 nyquist_section_sha256)
        )
      )
      |> Map.put("subject_tree", p["source"]["tree"])

    sections = [
      {"review_sha256", "## Plan 110 Current-Source Review", :review},
      {"security_sha256", "## Plan 110 Current-Source Security", :security},
      {"validation_sha256", "## Plan 110 Current-Source Nyquist", :nyquist}
    ]

    with :ok <-
           Enum.reduce_while(sections, :ok, fn {key, heading, kind}, :ok ->
             result =
               with {:ok, section} <- unique_heading_section(files[key], heading),
                    {:ok, _fields} <- section_field_map(section),
                    do:
                      validate_plan66_authority_section(
                        files[key],
                        heading,
                        metadata,
                        p["source"]["sha"],
                        kind
                      )

             case result do
               :ok -> {:cont, :ok}
               error -> {:halt, error}
             end
           end),
         {:ok, inventory} <- Jason.decode(files["inventory_sha256"]),
         true <-
           (inventory["audited_subject"] == p["source"]["sha"] and
              inventory["binding"] ==
                Map.put(
                  Map.take(
                    metadata,
                    ~w(subject_tree local_gates_sha256 census_sha256 census_a_sha256 census_b_sha256)
                  ),
                  "subject_sha",
                  p["source"]["sha"]
                ) and
              inventory["unresolved_high_ids"] == [] and
              is_list(inventory["items"]) and inventory["items"] != []) or
             {:error, "Plan 110 security inventory is empty, foreign, or unresolved"} do
      :ok
    end
  end

  defp plan111_candidate(root, p, d, check) do
    with {:ok, bytes} <- plan111_read(root, "133-111-CANDIDATE.json"),
         {:ok, candidate} <- Jason.decode(bytes),
         {:ok, summary_bytes} <- plan111_read(root, "133-111-SUMMARY.md"),
         {:ok, summary} <- summary_document(summary_bytes),
         {:ok, decision_bytes} <- plan111_read(root, "133-111-DECISION.json"),
         m <- summary.metadata,
         true <-
           (summary.status == "complete" and m["candidate_sha256"] == sha256(bytes) and
              m["decision_sha256"] == sha256(decision_bytes) and
              m["preflight_sha256"] == d["preflight_sha256"] and
              m["subject_sha"] == p["source"]["sha"] and
              m["subject_tree"] == p["source"]["tree"] and m["remote_ref"] == p["remote_ref"] and
              m["requirements-completed"] == []) or
             {:error, "Plan 111 candidate/decision/summary binding differs"},
         true <-
           (positive_integer?(m["run_id"]) and m["run_attempt"] == 1 and
              plan82_receipt_contract?(
                candidate,
                p["source"]["sha"],
                p["remote_ref"],
                m["run_id"],
                m["run_attempt"]
              )) or
             {:error, "Plan 111 candidate identity or Nightly evidence differs"},
         true <-
           candidate["incident_snapshot_before"] == candidate["incident_snapshot_after"] or
             {:error, "diagnostic dispatch changed the incident"},
         true <-
           (get_in(candidate, ["local_authorities", "census", "subject_sha"]) ==
              p["source"]["sha"] and
              get_in(candidate, ["local_authorities", "census", "ledger_sha256"]) ==
                p["authorities"]["census_sha256"] and
              get_in(candidate, ["local_authorities", "live_truth", "subject_sha"]) ==
                p["source"]["sha"]) or
             {:error, "candidate local authority differs from authorization"},
         :ok <-
           check.(:live_receipt, root, %{
             candidate: candidate,
             path: Path.join([root, @phase_dir, "133-111-CANDIDATE.json"])
           }) do
      :ok
    end
  end

  defp plan111_check(:source, root, p) do
    subject = p["source"]["sha"]

    paths =
      ~w(scripts/maintainer/validate_phase_133_reconciliation.exs scripts/maintainer/validate_evidence_census.exs scripts/maintainer/phase_133_local_supply.mjs scripts/ci/verify_nightly_run.sh)

    with {:ok, tree} <- git(root, ["rev-parse", "#{subject}^{tree}"]),
         true <- tree == p["source"]["tree"] or {:error, "source commit tree differs"} do
      Enum.reduce_while(paths, :ok, fn name, :ok ->
        case System.cmd("git", ["show", "#{subject}:#{name}"], cd: root, stderr_to_stdout: true) do
          {bytes, 0} ->
            trusted_path = Path.expand("../../#{name}", __DIR__)

            if File.read(trusted_path) == {:ok, bytes},
              do: {:cont, :ok},
              else: {:halt, {:error, "Plan 111 verifier differs from frozen source"}}

          _ ->
            {:halt, {:error, "Plan 111 frozen source is unavailable"}}
        end
      end)
    end
  end

  defp plan111_check(:supply, root, _p) do
    args = [
      Path.join(__DIR__, "phase_133_local_supply.mjs"),
      "verify",
      "--root",
      root,
      "--plan",
      "133-108",
      "--report",
      Path.join(@phase_dir, "133-108-PREFLIGHT.json"),
      "--local-gates",
      Path.join(@phase_dir, "133-108-LOCAL-GATES.json")
    ]

    case System.cmd("node", args, cd: root, stderr_to_stdout: true) do
      {_, 0} -> :ok
      _ -> {:error, "Plan 108 production green/supply verification failed"}
    end
  end

  defp plan111_check(:census, root, %{preflight: p, files: files}) do
    with {:ok, ledger} <- Jason.decode(files["census_sha256"]) do
      Enum.reduce_while(~w(census_a_sha256 census_b_sha256), :ok, fn key, :ok ->
        with {:ok, receipt} <- Jason.decode(files[key]),
             :ok <- validate_plan66_census_contract(ledger, receipt, p["source"]["sha"], root) do
          {:cont, :ok}
        else
          _ -> {:halt, {:error, "Plan 109 production census validation failed"}}
        end
      end)
    end
  end

  defp plan111_check(:live_receipt, root, %{candidate: candidate, path: path}),
    do:
      verify_receipt_live(
        root,
        candidate,
        path,
        Path.expand("../ci/verify_nightly_run.sh", __DIR__)
      )

  defp run_execution(options, root) do
    with report_root <- Path.expand(options.fixture_report_root || root),
         mode <- validation_mode(options),
         {:ok, expected} <- expected_records(report_root, mode),
         result <- maybe_print_addendum(options, expected, mode),
         :continue <- result,
         :ok <- require_tracked_inputs(report_root, mode),
         {:ok, prefix} <- validation_prefix(report_root, options, mode),
         :ok <- validate_prefix_metadata(report_root, options, mode, prefix),
         :ok <- maybe_write_addendum(report_root, options, prefix, expected, mode),
         {:ok, addendum} <- validate_validation(report_root, prefix, mode),
         {:ok, actual} <- parse_addendum(addendum),
         :ok <- compare_records(expected, actual),
         :ok <- validate_closure_flags(addendum, mode),
         {:ok, summary_state} <- validate_summaries_and_roadmap(report_root, mode, root),
         :ok <-
           if(options.check_repair_inventory,
             do: validate_repair_inventory(report_root),
             else: :ok
           ) do
      IO.puts(
        success_message(mode, summary_state, length(expected), total_plans(report_root, mode))
      )

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
      fixture_report_root: :string,
      fixture_expect_plan64_repair: :boolean,
      fixture_expect_plan64_halted: :boolean,
      fixture_expect_plan65_source: :boolean,
      fixture_expect_plan66_qualified: :boolean,
      fixture_expect_plan66_halted: :boolean,
      fixture_expect_plan69_qualified: :boolean,
      fixture_expect_plan69_halted: :boolean,
      fixture_expect_plan84_repair_complete: :boolean,
      fixture_expect_plan85_halted: :boolean,
      fixture_expect_plan85_qualified: :boolean,
      fixture_expect_plan91_local_result: :boolean,
      fixture_expect_plan80_qualified: :boolean,
      fixture_expect_plan80_halted: :boolean,
      fixture_expect_plan81_authority_complete: :boolean,
      fixture_expect_plan81_halted: :boolean,
      fixture_expect_plan82_owned_candidate: :boolean,
      fixture_expect_plan82_halted: :boolean,
      fixture_expect_plan83_execution_complete: :boolean,
      fixture_expect_plan83_halted: :boolean,
      expect_execution_complete: :boolean,
      expect_plan65_source: :boolean,
      expect_plan66_qualified: :boolean,
      expect_plan66_halted: :boolean,
      expect_plan69_qualified: :boolean,
      expect_plan69_halted: :boolean,
      expect_plan84_repair_complete: :boolean,
      expect_plan85_halted: :boolean,
      expect_plan85_qualified: :boolean,
      expect_plan91_local_result: :boolean,
      expect_plan80_qualified: :boolean,
      expect_plan80_halted: :boolean,
      expect_plan81_authority_complete: :boolean,
      expect_plan81_halted: :boolean,
      expect_plan82_owned_candidate: :boolean,
      expect_plan82_halted: :boolean,
      expect_plan83_execution_complete: :boolean,
      expect_plan83_halted: :boolean,
      expect_plan64_repair: :boolean,
      expect_plan64_halted: :boolean,
      expect_plan62_qualified: :boolean,
      expect_plan62_halted: :boolean,
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
        fixture_report_root = values[:fixture_report_root]

        plan79_fixture_mode? =
          Enum.any?(
            [
              values[:fixture_expect_plan80_qualified],
              values[:fixture_expect_plan80_halted],
              values[:fixture_expect_plan81_authority_complete],
              values[:fixture_expect_plan81_halted],
              values[:fixture_expect_plan82_owned_candidate],
              values[:fixture_expect_plan82_halted],
              values[:fixture_expect_plan83_execution_complete],
              values[:fixture_expect_plan83_halted]
            ],
            &(&1 == true)
          )

        plan84_fixture_mode? =
          Enum.any?(
            [
              values[:fixture_expect_plan84_repair_complete],
              values[:fixture_expect_plan85_halted],
              values[:fixture_expect_plan85_qualified]
            ],
            &(&1 == true)
          )

        plan91_fixture_mode? = values[:fixture_expect_plan91_local_result] == true

        fixture_mode =
          not is_nil(fixture_ref) or not is_nil(active_ref) or not is_nil(fixture_topology) or
            values[:fixture_expect_plan69_qualified] == true or
            values[:fixture_expect_plan69_halted] == true or
            plan84_fixture_mode? or
            plan91_fixture_mode? or
            Enum.any?(
              [
                values[:fixture_expect_plan80_qualified],
                values[:fixture_expect_plan80_halted],
                values[:fixture_expect_plan81_authority_complete],
                values[:fixture_expect_plan81_halted],
                values[:fixture_expect_plan82_owned_candidate],
                values[:fixture_expect_plan82_halted],
                values[:fixture_expect_plan83_execution_complete],
                values[:fixture_expect_plan83_halted]
              ],
              & &1
            )

        cond do
          is_nil(fixture_ref) != is_nil(fixture_sha) ->
            {:error, "fixture historical ref and digest must be supplied together"}

          not is_nil(fixture_sha) and not Regex.match?(~r/\A[0-9a-f]{64}\z/, fixture_sha) ->
            {:error, "fixture historical digest must be lowercase SHA-256"}

          is_nil(active_ref) != is_nil(active_sha) ->
            {:error, "fixture active prefix ref and digest must be supplied together"}

          Enum.count(
            [
              values[:expect_plan62_qualified],
              values[:expect_plan62_halted],
              values[:expect_plan64_repair],
              values[:expect_plan64_halted],
              values[:expect_plan65_source],
              values[:expect_plan66_qualified],
              values[:expect_plan66_halted],
              values[:expect_plan69_qualified],
              values[:expect_plan69_halted],
              values[:expect_plan84_repair_complete],
              values[:expect_plan85_halted],
              values[:expect_plan85_qualified],
              values[:expect_plan91_local_result],
              values[:expect_plan80_qualified],
              values[:expect_plan80_halted],
              values[:expect_plan81_authority_complete],
              values[:expect_plan81_halted],
              values[:expect_plan82_owned_candidate],
              values[:expect_plan82_halted],
              values[:expect_plan83_execution_complete],
              values[:expect_plan83_halted],
              values[:fixture_expect_plan64_repair],
              values[:fixture_expect_plan64_halted],
              values[:fixture_expect_plan65_source],
              values[:fixture_expect_plan66_qualified],
              values[:fixture_expect_plan66_halted],
              values[:fixture_expect_plan69_qualified],
              values[:fixture_expect_plan69_halted],
              values[:fixture_expect_plan84_repair_complete],
              values[:fixture_expect_plan85_halted],
              values[:fixture_expect_plan85_qualified],
              values[:fixture_expect_plan91_local_result],
              values[:fixture_expect_plan80_qualified],
              values[:fixture_expect_plan80_halted],
              values[:fixture_expect_plan81_authority_complete],
              values[:fixture_expect_plan81_halted],
              values[:fixture_expect_plan82_owned_candidate],
              values[:fixture_expect_plan82_halted],
              values[:fixture_expect_plan83_execution_complete],
              values[:fixture_expect_plan83_halted]
            ],
            & &1
          ) > 1 ->
            {:error, "Phase 133 special modes are mutually exclusive"}

          Enum.any?(
            [
              values[:expect_plan64_repair],
              values[:expect_plan64_halted],
              values[:expect_plan65_source],
              values[:expect_plan66_qualified],
              values[:expect_plan66_halted],
              values[:expect_plan69_qualified],
              values[:expect_plan69_halted],
              values[:expect_plan84_repair_complete],
              values[:expect_plan85_halted],
              values[:expect_plan85_qualified],
              values[:expect_plan91_local_result],
              values[:expect_plan80_qualified],
              values[:expect_plan80_halted],
              values[:expect_plan81_authority_complete],
              values[:expect_plan81_halted],
              values[:expect_plan82_owned_candidate],
              values[:expect_plan82_halted],
              values[:expect_plan83_execution_complete],
              values[:expect_plan83_halted]
            ],
            &(&1 || false)
          ) and
              fixture_mode ->
            {:error, production_fixture_error(values)}

          Enum.any?(
            [
              values[:fixture_expect_plan64_repair],
              values[:fixture_expect_plan64_halted],
              values[:fixture_expect_plan65_source],
              values[:fixture_expect_plan66_qualified],
              values[:fixture_expect_plan66_halted],
              values[:fixture_expect_plan69_qualified],
              values[:fixture_expect_plan69_halted],
              values[:fixture_expect_plan84_repair_complete],
              values[:fixture_expect_plan85_halted],
              values[:fixture_expect_plan85_qualified],
              values[:fixture_expect_plan91_local_result],
              values[:fixture_expect_plan80_qualified],
              values[:fixture_expect_plan80_halted],
              values[:fixture_expect_plan81_authority_complete],
              values[:fixture_expect_plan81_halted],
              values[:fixture_expect_plan82_owned_candidate],
              values[:fixture_expect_plan82_halted],
              values[:fixture_expect_plan83_execution_complete],
              values[:fixture_expect_plan83_halted]
            ],
            &(&1 || false)
          ) and
              not fixture_mode ->
            {:error, fixture_inputs_error(values)}

          not is_nil(active_sha) and not Regex.match?(~r/\A[0-9a-f]{64}\z/, active_sha) ->
            {:error, "fixture active prefix digest must be lowercase SHA-256"}

          not is_nil(fixture_ref) and not is_nil(active_ref) ->
            {:error, "historical and active fixture modes are mutually exclusive"}

          fixture_topology not in [
            nil,
            "repair-32",
            "branch-37",
            "branch-42",
            "branch-83",
            "branch-85",
            "branch-91"
          ] ->
            {:error,
             "fixture topology must be repair-32, branch-37, branch-42, branch-83, or branch-85"}

          not is_nil(fixture_report_root) and not fixture_mode ->
            {:error, "fixture report root requires an explicit fixture mode"}

          plan79_fixture_mode? and
              (is_nil(fixture_report_root) or fixture_topology != "branch-83") ->
            {:error, "Plan 79 fixture modes require a copied report root and branch-83 topology"}

          plan84_fixture_mode? and
              (is_nil(fixture_report_root) or fixture_topology != "branch-85") ->
            {:error, "Plan 84 fixture modes require a copied report root and branch-85 topology"}

          plan91_fixture_mode? and
              (is_nil(fixture_report_root) or fixture_topology != "branch-91") ->
            {:error, "Plan 91 fixture modes require a copied report root and branch-91 topology"}

          true ->
            {:ok,
             %{
               root: values[:root],
               fixture_ref: fixture_ref,
               fixture_sha: fixture_sha,
               active_ref: active_ref,
               active_sha: active_sha,
               fixture_topology: fixture_topology,
               fixture_report_root: fixture_report_root,
               fixture_expect_plan64_repair: values[:fixture_expect_plan64_repair] || false,
               fixture_expect_plan64_halted: values[:fixture_expect_plan64_halted] || false,
               fixture_expect_plan65_source: values[:fixture_expect_plan65_source] || false,
               fixture_expect_plan66_qualified: values[:fixture_expect_plan66_qualified] || false,
               fixture_expect_plan66_halted: values[:fixture_expect_plan66_halted] || false,
               fixture_expect_plan69_qualified: values[:fixture_expect_plan69_qualified] || false,
               fixture_expect_plan69_halted: values[:fixture_expect_plan69_halted] || false,
               fixture_expect_plan84_repair_complete:
                 values[:fixture_expect_plan84_repair_complete] || false,
               fixture_expect_plan85_halted: values[:fixture_expect_plan85_halted] || false,
               fixture_expect_plan85_qualified: values[:fixture_expect_plan85_qualified] || false,
               fixture_expect_plan91_local_result:
                 values[:fixture_expect_plan91_local_result] || false,
               fixture_expect_plan80_qualified: values[:fixture_expect_plan80_qualified] || false,
               fixture_expect_plan80_halted: values[:fixture_expect_plan80_halted] || false,
               fixture_expect_plan81_authority_complete:
                 values[:fixture_expect_plan81_authority_complete] || false,
               fixture_expect_plan81_halted: values[:fixture_expect_plan81_halted] || false,
               fixture_expect_plan82_owned_candidate:
                 values[:fixture_expect_plan82_owned_candidate] || false,
               fixture_expect_plan82_halted: values[:fixture_expect_plan82_halted] || false,
               fixture_expect_plan83_execution_complete:
                 values[:fixture_expect_plan83_execution_complete] || false,
               fixture_expect_plan83_halted: values[:fixture_expect_plan83_halted] || false,
               expect_execution_complete: values[:expect_execution_complete] || false,
               expect_plan65_source: values[:expect_plan65_source] || false,
               expect_plan66_qualified: values[:expect_plan66_qualified] || false,
               expect_plan66_halted: values[:expect_plan66_halted] || false,
               expect_plan69_qualified: values[:expect_plan69_qualified] || false,
               expect_plan69_halted: values[:expect_plan69_halted] || false,
               expect_plan84_repair_complete: values[:expect_plan84_repair_complete] || false,
               expect_plan85_halted: values[:expect_plan85_halted] || false,
               expect_plan85_qualified: values[:expect_plan85_qualified] || false,
               expect_plan91_local_result: values[:expect_plan91_local_result] || false,
               expect_plan80_qualified: values[:expect_plan80_qualified] || false,
               expect_plan80_halted: values[:expect_plan80_halted] || false,
               expect_plan81_authority_complete:
                 values[:expect_plan81_authority_complete] || false,
               expect_plan81_halted: values[:expect_plan81_halted] || false,
               expect_plan82_owned_candidate: values[:expect_plan82_owned_candidate] || false,
               expect_plan82_halted: values[:expect_plan82_halted] || false,
               expect_plan83_execution_complete:
                 values[:expect_plan83_execution_complete] || false,
               expect_plan83_halted: values[:expect_plan83_halted] || false,
               expect_plan64_repair: values[:expect_plan64_repair] || false,
               expect_plan64_halted: values[:expect_plan64_halted] || false,
               expect_plan62_qualified: values[:expect_plan62_qualified] || false,
               expect_plan62_halted: values[:expect_plan62_halted] || false,
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
    completed = roadmap_completed_count(summary_state)
    halted = MapSet.size(summary_state.halted)
    summarized = MapSet.size(summary_state.completed) + halted
    pending = total - summarized

    "phase 133 reconciliation valid: #{completed} completed, #{halted} halted, " <>
      "#{pending} pending plans, #{summarized}/#{total} summarized, " <>
      "#{pair_count} validation records"
  end

  # Before the Plan 55 recovery branch, the report's "completed" figure counts
  # product completion and excludes diagnostic Plan 53. The Plan 55–57 roadmap
  # handoff explicitly counts all complete summaries, including that diagnostic.
  defp roadmap_completed_count(summary_state) do
    completed = MapSet.size(summary_state.completed)

    recovery_handoff? =
      Enum.any?([55, 57], fn plan ->
        MapSet.member?(summary_state.completed, plan) or
          MapSet.member?(summary_state.halted, plan)
      end)

    if recovery_handoff? or not MapSet.member?(summary_state.completed, 53),
      do: completed,
      else: completed - 1
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
          cond do
            Enum.any?(
              [63, 64],
              &File.regular?(Path.join(root, Path.join(@phase_dir, "133-#{&1}-PLAN.md")))
            ) ->
              28..64

            Enum.any?(
              [58, 59, 60, 61, 62],
              &File.regular?(Path.join(root, Path.join(@phase_dir, "133-#{&1}-PLAN.md")))
            ) ->
              28..62

            Enum.any?(
              [55, 56, 57],
              &File.regular?(Path.join(root, Path.join(@phase_dir, "133-#{&1}-PLAN.md")))
            ) ->
              28..57

            Enum.any?(
              [53, 54],
              &File.regular?(Path.join(root, Path.join(@phase_dir, "133-#{&1}-PLAN.md")))
            ) ->
              28..54

            File.regular?(Path.join(root, Path.join(@phase_dir, "133-50-PLAN.md"))) ->
              28..52

            File.regular?(Path.join(root, Path.join(@phase_dir, "133-43-PLAN.md"))) ->
              28..49

            true ->
              28..42
          end
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

      (Enum.any?(
         [55, 56, 57],
         &File.regular?(Path.join(root, Path.join(@phase_dir, "133-#{&1}-PLAN.md")))
       ) and
         length(:binary.matches(current, @plans_55_heading)) != 1) or
          length(:binary.matches(current, @legacy_plans_55_heading)) != 0 ->
        {:error, "Plans 55–57 validation addendum heading must appear exactly once"}

      Enum.any?(
        [53, 54],
        &File.regular?(Path.join(root, Path.join(@phase_dir, "133-#{&1}-PLAN.md")))
      ) and
          length(:binary.matches(current, @plans_53_heading)) != 1 ->
        {:error, "Plans 53–54 validation addendum heading must appear exactly once"}

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
          cond do
            Enum.any?(
              [58, 59, 60, 61, 62],
              &File.regular?(Path.join(root, Path.join(@phase_dir, "133-#{&1}-PLAN.md")))
            ) ->
              {33..62, []}

            Enum.any?(
              [55, 56, 57],
              &File.regular?(Path.join(root, Path.join(@phase_dir, "133-#{&1}-PLAN.md")))
            ) ->
              {33..57, []}

            Enum.any?(
              [53, 54],
              &File.regular?(Path.join(root, Path.join(@phase_dir, "133-#{&1}-PLAN.md")))
            ) ->
              {33..54, []}

            File.regular?(Path.join(root, Path.join(@phase_dir, "133-50-PLAN.md"))) ->
              {33..52, []}

            File.regular?(Path.join(root, Path.join(@phase_dir, "133-43-PLAN.md"))) ->
              {33..49, []}

            true ->
              {33..42, []}
          end
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

  defp parse_plan(contents, plan, _mode, root) when plan in 43..64 do
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
        parser = if plan in 50..64, do: &parse_inventory_gap_tasks/3, else: &parse_gap_tasks/3
        parser.(task_matches, plan, root)
    end
  end

  defp parse_plan(contents, plan, mode, root) do
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
        with :ok <- validate_plan_42_record_state_source(plan, root),
             {:ok, task_records} <- parse_tasks(task_matches, plan, root),
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
      verify_bodies =
        Regex.scan(~r/<verify\b[^>]*>(.*?)<\/verify>/s, body, capture: :all_but_first)

      pair_result =
        Enum.reduce_while(verify_bodies, {:ok, []}, fn [verify_body], {:ok, acc} ->
          case parse_plan_pairs(verify_body) do
            {:ok, pairs} -> {:cont, {:ok, acc ++ pairs}}
            {:error, _reason} = error -> {:halt, error}
          end
        end)

      case pair_result do
        {:ok, pairs} ->
          automated_count =
            Enum.reduce(verify_bodies, 0, fn [verify_body], count ->
              count + length(Regex.scan(~r/<automated>/, verify_body))
            end)

          failure_count =
            Enum.reduce(verify_bodies, 0, fn [verify_body], count ->
              count + length(Regex.scan(~r/<fails_when>/, verify_body))
            end)

          if pairs == [] or automated_count != length(pairs) or failure_count != length(pairs) do
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

        {:error, _reason} ->
          {:halt,
           {:error, "task #{ordinal} verification markup has invalid automated/fails_when pairs"}}
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

  defp parse_tasks(task_matches, plan, root) do
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
                |> enrich_closure_records(plan, attributes, root)
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

  defp record_state(plan, root) when plan in [59, 62] do
    # These pending command rows sit in Plan 64's authenticated validation prefix.
    # Their immutable halted outcomes are authenticated separately from summaries
    # and reports; don't rewrite those historical per-command states from a
    # plan-level halt.
    plan_id = String.pad_leading(Integer.to_string(plan), 2, "0")
    path = Path.join(root, Path.join(@phase_dir, "133-#{plan_id}-SUMMARY.md"))

    case File.read(path) do
      {:ok, summary} ->
        case summary_document(summary) do
          {:ok, %{status: "complete"}} -> @executed_state
          _ -> @pending_state
        end

      _ ->
        @pending_state
    end
  end

  defp record_state(plan, root) when plan in 43..64 do
    plan_id = String.pad_leading(Integer.to_string(plan), 2, "0")
    path = Path.join(root, Path.join(@phase_dir, "133-#{plan_id}-SUMMARY.md"))

    case File.read(path) do
      {:ok, summary} ->
        case summary_document(summary) do
          {:ok, %{status: "complete"}} ->
            @executed_state

          {:ok, %{status: "halted", metadata: metadata}} ->
            if plan == 48 and
                 (Map.get(metadata, "report-gate") == "blocked" or
                    plan_48_pending_checkpoint?(root, metadata)),
               do: @pending_state,
               else: @halted_state

          _ ->
            @pending_state
        end

      _ ->
        @pending_state
    end
  end

  defp record_state(42, root) do
    case authenticated_plan_42_halt(root) do
      {:ok, @halted_state} -> @halted_state
      _ -> @pending_state
    end
  end

  defp record_state(plan, _root), do: record_state(plan)

  defp validate_plan_42_record_state_source(42, root) do
    case authenticated_plan_42_halt(root) do
      {:ok, _state} -> :ok
      {:error, reason} -> {:error, "halted summary 133-42 #{reason}"}
    end
  end

  defp validate_plan_42_record_state_source(_plan, _root), do: :ok

  defp authenticated_plan_42_halt(root) do
    case File.read(summary_path(root, 42)) do
      {:ok, summary} ->
        case summary_document(summary) do
          {:ok, %{status: "halted"} = document} ->
            case validate_branch_halted_summary(42, document) do
              :ok -> {:ok, @halted_state}
              {:error, _reason} = error -> error
            end

          {:ok, _document} ->
            {:ok, @pending_state}

          {:error, _reason} = error ->
            error
        end

      {:error, :enoent} ->
        {:ok, @pending_state}

      {:error, _reason} ->
        {:error, "summary 133-42 is unreadable"}
    end
  end

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

  defp enrich_closure_records(records, plan, attributes, root) when plan in 38..42 do
    Enum.map(records, fn record ->
      state =
        if record.key == "133-42-01:1" do
          record_state(42, root)
        else
          record.state
        end

      credit =
        cond do
          String.contains?(attributes, "checkpoint:") -> "authorization-only"
          plan == 42 and record.key == "133-42-02:6" -> "terminal-completion"
          true -> "pending"
        end

      Map.merge(record, %{
        state: state,
        credit: credit,
        requirements: Enum.join(@phase_requirements, ","),
        validation_level: closure_validation_level(plan),
        branch_status:
          cond do
            record.key == "133-42-02:6" -> "sole-terminal-completion-path"
            plan in [38, 39] -> "passed — executed"
            state == @halted_state -> @halted_state
            true -> "pending — not executed"
          end
      })
    end)
  end

  defp enrich_closure_records(records, _plan, _attributes, _root), do: records

  defp closure_validation_level(38), do: "repair-backstop"
  defp closure_validation_level(39), do: "reconciliation-authority"
  defp closure_validation_level(40), do: "exact-subject-qualification"
  defp closure_validation_level(41), do: "authorization-only"
  defp closure_validation_level(42), do: "terminal-attempt"

  defp enrich_gap_records(records, plan, ordinal, attributes) when plan in 43..64 do
    Enum.map(records, fn record ->
      state =
        if plan == 57 and record.state == @halted_state and ordinal < 3,
          do: @executed_state,
          else: record.state

      credit =
        cond do
          String.contains?(attributes, "checkpoint:") -> "authorization-only"
          plan == 49 and ordinal == 2 -> "terminal-completion"
          true -> "pending"
        end

      Map.merge(record, %{
        state: state,
        credit: credit,
        requirements: Enum.join(@phase_requirements, ","),
        validation_level: "gap-closure",
        branch_status:
          case state do
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
              plan_context =
                case Regex.run(~r/\A133-(\d+)-/, wanted.key) do
                  [_, plan] -> " (Plan #{String.to_integer(plan)})"
                  _ -> ""
                end

              {:halt, {:error, "pending state differs for #{wanted.key}#{plan_context}"}}

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

  defp validate_summaries_and_roadmap(root, :historical_snapshot, _source_root) do
    case validate_historical_roadmap(root) do
      :ok -> {:ok, 10}
      {:error, _message} = error -> error
    end
  end

  defp validate_summaries_and_roadmap(root, mode, source_root)
       when mode in [
              :execution,
              :execution_complete,
              :branch_execution,
              :branch_execution_complete,
              :repair_execution,
              :repair_execution_complete
            ] do
    with {:ok, summary_state} <-
           summary_state(root, total_plans(root, mode), mode, source_root),
         :ok <- validate_execution_summary_state(summary_state, mode),
         :ok <- validate_branch_terminal_summaries(root, summary_state, mode, source_root),
         :ok <- validate_execution_roadmap(root, summary_state, mode),
         :ok <- validate_live_authorities(root, summary_state, mode) do
      {:ok, summary_state}
    end
  end

  defp summary_state(root, total, mode, source_root) do
    initial = %{completed: MapSet.new(), halted: MapSet.new()}

    Enum.reduce_while(1..total, {:ok, initial}, fn plan, {:ok, state} ->
      plan_id = String.pad_leading(Integer.to_string(plan), 2, "0")
      path = Path.join(root, Path.join(@phase_dir, "133-#{plan_id}-SUMMARY.md"))

      case File.read(path) do
        {:ok, summary} ->
          case summary_document(summary) do
            {:ok, %{status: "complete"}}
            when plan in [27, 49] or
                   (plan == 32 and
                      mode in [
                        :execution,
                        :execution_complete,
                        :branch_execution,
                        :branch_execution_complete
                      ]) or
                   (plan == 37 and mode in [:execution, :execution_complete]) ->
              {:halt, {:error, "Plan #{plan} must remain halted; status: complete is forbidden"}}

            {:ok, %{status: "complete"}} when plan in [55, 59] ->
              {:halt,
               {:error, "Plan #{plan} must remain halted with its immutable failed qualification"}}

            {:ok, %{status: status} = document}
            when plan == 62 and status in ["complete", "halted"] ->
              case validate_plan62_outcome(root, document) do
                :ok ->
                  key = if status == "complete", do: :completed, else: :halted
                  {:cont, {:ok, Map.update!(state, key, &MapSet.put(&1, plan))}}

                {:error, reason} ->
                  {:halt, {:error, "Plan 62 summary #{reason}"}}
              end

            {:ok, %{status: status} = document}
            when plan == 63 and status in ["complete", "halted"] ->
              result =
                if status == "complete",
                  do: validate_plan63_outcome(root, source_root, document),
                  else: validate_plan63_halted_outcome(root, document)

              case result do
                :ok ->
                  key = if status == "complete", do: :completed, else: :halted
                  {:cont, {:ok, Map.update!(state, key, &MapSet.put(&1, plan))}}

                {:error, reason} ->
                  {:halt, {:error, "Plan 63 summary #{reason}"}}
              end

            {:ok, %{status: status} = document}
            when plan == 64 and status in ["complete", "halted"] ->
              expected = if status == "complete", do: :repair, else: :halted

              case validate_plan64_outcome(root, source_root, document, expected) do
                :ok ->
                  key = if status == "complete", do: :completed, else: :halted
                  {:cont, {:ok, Map.update!(state, key, &MapSet.put(&1, plan))}}

                {:error, reason} ->
                  {:halt, {:error, "Plan 64 summary #{reason}"}}
              end

            {:ok, %{status: "complete"} = document} when plan == 65 ->
              case validate_plan65_source(root, source_root, document) do
                :ok -> {:cont, {:ok, %{state | completed: MapSet.put(state.completed, plan)}}}
                {:error, reason} -> {:halt, {:error, "Plan 65 summary #{reason}"}}
              end

            {:ok, %{status: status} = document}
            when plan == 66 and status in ["complete", "halted"] ->
              expected = if status == "complete", do: :qualified, else: :halted

              case validate_plan66_outcome(root, source_root, document, expected) do
                :ok ->
                  key = if status == "complete", do: :completed, else: :halted
                  {:cont, {:ok, Map.update!(state, key, &MapSet.put(&1, plan))}}

                {:error, reason} ->
                  {:halt, {:error, "Plan 66 summary #{reason}"}}
              end

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
              case validate_branch_halted_summary(plan, document, root) do
                :ok -> {:cont, {:ok, %{state | halted: MapSet.put(state.halted, plan)}}}
                {:error, reason} -> {:halt, {:error, "halted summary 133-#{plan} #{reason}"}}
              end

            {:ok, %{status: "halted"} = document} when plan == 55 ->
              case validate_plan55_halted_summary(document) do
                :ok -> {:cont, {:ok, %{state | halted: MapSet.put(state.halted, plan)}}}
                {:error, reason} -> {:halt, {:error, "halted summary 133-55 #{reason}"}}
              end

            {:ok, %{status: "halted"} = document} when plan == 56 ->
              case validate_plan56_terminal_outcome(root, document) do
                :ok -> {:cont, {:ok, %{state | halted: MapSet.put(state.halted, plan)}}}
                {:error, reason} -> {:halt, {:error, "halted summary 133-56 #{reason}"}}
              end

            {:ok, %{status: "halted"} = document} when plan == 57 ->
              case validate_plan57_terminal_summary(document) do
                :ok -> {:cont, {:ok, %{state | halted: MapSet.put(state.halted, plan)}}}
                {:error, reason} -> {:halt, {:error, "halted summary 133-57 #{reason}"}}
              end

            {:ok, %{status: "halted"} = document} when plan == 59 ->
              case validate_plan59_outcome(root, document) do
                :ok -> {:cont, {:ok, %{state | halted: MapSet.put(state.halted, plan)}}}
                {:error, reason} -> {:halt, {:error, "halted summary 133-59 #{reason}"}}
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
    expected = %{
      "qualification" => "failed",
      "terminal_automation" => "halted",
      "requirements-completed" => [],
      "subject_sha" => "68b1c82390b506da343116f49b943f05442692b0",
      "published_ref" => "refs/heads/phase-133-evidence-68b1c82390b5",
      "run_id" => 36_274_589_243,
      "run_attempt" => 1,
      "run_conclusion" => "failure",
      "failed_compat_jobs" => [
        "Compat Matrix (1.17, 27)",
        "Compat Matrix (1.15, 26)",
        "Compat Matrix (1.18, 27)",
        "Compat Matrix (1.16, 26)",
        "Compat Matrix (1.18, 28)"
      ],
      "failed_aggregate_job" => "Nightly Summary — Enforce strict Nightly verdict",
      "receipt_sha256" => "1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4",
      "candidate_receipt" => "absent"
    }

    halt_reason = Map.get(document.metadata, "halt_reason", "")

    if Enum.all?(expected, fn {key, value} -> Map.get(document.metadata, key) == value end) and
         is_binary(halt_reason) and String.contains?(halt_reason, "36274589243") and
         String.contains?(halt_reason, "immutable") do
      :ok
    else
      {:error,
       "must preserve the exact immutable Plan 49 failed attempt tuple and prior receipt digest"}
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

  defp validate_branch_halted_summary(48, document, root) do
    metadata = document.metadata

    cond do
      Map.get(metadata, "decision") in ["authorize", "stop"] ->
        validate_branch_halted_summary(48, document)

      Map.get(metadata, "report-gate") == "blocked" ->
        validate_branch_halted_summary(48, document)

      plan_48_pending_checkpoint?(root, metadata) ->
        :ok

      true ->
        {:error, "must bind the passed report gate to the pending exact-pair checkpoint"}
    end
  end

  defp validate_branch_halted_summary(plan, document, _root),
    do: validate_branch_halted_summary(plan, document)

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
        with :ok <- validate_gap_plan_lifecycle(summary_state),
             {:ok, lifecycle} <- closure_lifecycle(summary_state),
             {:ok, current_lifecycle} <- execution_lifecycle_from_state(lifecycle, summary_state) do
          cond do
            mode != :execution_complete ->
              :ok

            current_lifecycle == :qualified_success_42 ->
              :ok

            current_lifecycle == :qualified_success_61 ->
              :ok

            current_lifecycle == :terminal_complete_68 ->
              :ok

            true ->
              {:error, "execution-complete requires a qualified Plan 61 terminal receipt"}
          end
        else
          {:error, _message} = error -> error
        end
    end
  end

  defp execution_lifecycle_from_state(base, summary_state) do
    summarized = MapSet.union(summary_state.completed, summary_state.halted)

    has_gap_closure_plans? =
      Enum.any?(43..68, &MapSet.member?(summarized, &1))

    cond do
      not has_gap_closure_plans? -> {:ok, base}
      MapSet.member?(summary_state.completed, 68) -> {:ok, :terminal_complete_68}
      MapSet.member?(summary_state.halted, 68) -> {:ok, :terminal_halted_68}
      MapSet.member?(summary_state.completed, 67) -> {:ok, :remote_candidate_verified_67}
      MapSet.member?(summary_state.halted, 67) -> {:ok, :remote_candidate_halted_67}
      MapSet.member?(summary_state.completed, 66) -> {:ok, :qualified_local_66}
      MapSet.member?(summary_state.halted, 66) -> {:ok, :qualification_halted_66}
      MapSet.member?(summary_state.completed, 65) -> {:ok, :source_proven_65}
      MapSet.member?(summary_state.completed, 64) -> {:ok, :repair_proven_64}
      MapSet.member?(summary_state.halted, 64) -> {:ok, :repair_halted_64}
      MapSet.member?(summary_state.completed, 63) -> {:ok, :runner_repair_complete_63}
      MapSet.member?(summary_state.halted, 63) -> {:ok, :runner_repair_halted_63}
      MapSet.member?(summary_state.completed, 61) -> {:ok, :qualified_success_61}
      MapSet.member?(summary_state.halted, 61) -> {:ok, :terminal_halted_61}
      MapSet.member?(summary_state.completed, 60) -> {:ok, :remote_candidate_verified_60}
      MapSet.member?(summary_state.halted, 60) -> {:ok, :remote_candidate_halted_60}
      MapSet.member?(summary_state.completed, 62) -> {:ok, :qualified_local_62}
      MapSet.member?(summary_state.halted, 62) -> {:ok, :qualification_halted_62}
      MapSet.member?(summary_state.halted, 59) -> {:ok, :qualification_halted_59}
      MapSet.member?(summary_state.completed, 58) -> {:ok, :local_recovery_complete_58}
      MapSet.member?(summary_state.halted, 58) -> {:ok, :local_recovery_halted_58}
      MapSet.member?(summary_state.completed, 57) -> {:ok, :local_recovery_complete_57}
      MapSet.member?(summary_state.halted, 57) -> {:ok, :local_recovery_halted_57}
      MapSet.member?(summary_state.halted, 55) -> {:ok, :local_recovery_pending_57}
      MapSet.member?(summary_state.completed, 55) -> {:ok, :qualified_local_55}
      MapSet.size(summarized) >= 54 -> {:ok, :pending_plan55}
      true -> {:ok, base}
    end
  end

  defp validate_gap_plan_lifecycle(summary_state) do
    completed = summary_state.completed
    summarized = MapSet.union(completed, summary_state.halted)
    later_plans = Enum.filter(47..68, &MapSet.member?(summarized, &1))

    cond do
      MapSet.member?(summarized, 56) ->
        {:error, "Plan 56 remains blocked by immutable Plan 55 evidence and cannot be summarized"}

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

      MapSet.member?(summarized, 54) and not MapSet.member?(completed, 53) ->
        {:error, "Plan 53 must be complete before Plan 54 can be summarized"}

      MapSet.member?(summarized, 55) and not MapSet.member?(completed, 54) ->
        {:error, "Plan 54 must be complete before Plan 55 can be summarized"}

      MapSet.member?(summarized, 56) and not MapSet.member?(completed, 55) ->
        {:error, "Plan 55 must be complete before Plan 56 can be summarized"}

      MapSet.member?(summarized, 57) and not MapSet.member?(completed, 54) ->
        {:error, "Plan 54 must be complete before independent Plan 57 can be summarized"}

      MapSet.member?(summarized, 58) and not MapSet.member?(completed, 54) ->
        {:error, "Plan 54 must be complete before independent Plan 58 can be summarized"}

      MapSet.member?(summarized, 59) and not MapSet.member?(completed, 58) ->
        {:error, "Plan 58 must complete local recovery before Plan 59 can be summarized"}

      MapSet.member?(summarized, 62) and not MapSet.member?(completed, 58) ->
        {:error, "Plan 58 must complete before independent Plan 62 can be summarized"}

      MapSet.member?(summarized, 62) and not MapSet.member?(summary_state.halted, 59) ->
        {:error, "Plan 59 must remain halted before independent Plan 62 can be summarized"}

      MapSet.member?(summarized, 60) and not MapSet.member?(completed, 62) ->
        {:error, "Plan 62 must qualify a fresh subject before Plan 60 can be summarized"}

      MapSet.member?(summarized, 61) and not MapSet.member?(completed, 60) ->
        {:error, "Plan 60 must verify a private candidate before Plan 61 can be summarized"}

      MapSet.member?(summarized, 63) and
          (not MapSet.member?(completed, 58) or
             not MapSet.member?(summary_state.halted, 59) or
             not MapSet.member?(summary_state.halted, 62)) ->
        {:error, "Plan 63 requires completed Plan 58 and halted Plans 59 and 62"}

      MapSet.member?(summarized, 63) and
          (MapSet.member?(summarized, 60) or MapSet.member?(summarized, 61)) ->
        {:error, "Plans 60 and 61 remain blocked while Plan 63 repair evidence is active"}

      MapSet.member?(summarized, 64) and not MapSet.member?(completed, 63) ->
        {:error, "Plan 63 must complete before Plan 64 can be summarized"}

      MapSet.member?(summarized, 64) and
          (MapSet.member?(summarized, 60) or MapSet.member?(summarized, 61)) ->
        {:error, "Plans 60 and 61 remain blocked while Plan 64 repair evidence is active"}

      MapSet.member?(summarized, 65) and not MapSet.member?(completed, 64) ->
        {:error, "Plan 64 repair-proven evidence is required before Plan 65"}

      MapSet.member?(summarized, 66) and not MapSet.member?(completed, 65) ->
        {:error, "Plan 65 source-proven handoff is required before Plan 66"}

      MapSet.member?(summarized, 67) and not MapSet.member?(completed, 66) ->
        {:error, "only qualified Plan 66 can feed Plan 67"}

      MapSet.member?(summarized, 68) and not MapSet.member?(completed, 67) ->
        {:error, "completed Plan 67 candidate is required before Plan 68"}

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

  defp validate_branch_terminal_summaries(_root, _summary_state, mode, _source_root)
       when mode in [:repair_execution, :repair_execution_complete],
       do: :ok

  defp validate_branch_terminal_summaries(root, summary_state, mode, source_root)
       when mode in [:execution, :execution_complete] do
    with {:ok, lifecycle} <- closure_lifecycle(summary_state),
         :ok <- validate_plan_41_decision(root, lifecycle),
         :ok <- validate_plan_42_qualification(root, lifecycle),
         :ok <- validate_plan_48_authorization(root, summary_state),
         :ok <- validate_plan55_summary(root, source_root),
         :ok <- validate_plan56_summary(root),
         :ok <- validate_plan57_summary(root),
         :ok <- validate_new_chain_summaries(root, summary_state) do
      :ok
    end
  end

  defp validate_branch_terminal_summaries(root, summary_state, _mode, _source_root) do
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
             :ok <- validate_plan_48_decision(root, document, summarized_49) do
          :ok
        else
          {:error, _message} = error ->
            error

          _ ->
            {:error, "Plan 48 must record authorize, stop, or a report-gate halt before decision"}
        end
    end
  end

  defp validate_plan_48_decision(root, %{status: "halted", metadata: metadata}, summarized_49) do
    if is_nil(Map.get(metadata, "decision")) do
      cond do
        summarized_49 ->
          {:error, "Plan 48 pre-decision checkpoint cannot summarize Plan 49"}

        metadata["report-gate"] == "blocked" and
          is_binary(metadata["halt_reason"]) and
          String.contains?(metadata["halt_reason"], "report gate") and
          is_nil(metadata["authorized_ref"]) and is_nil(metadata["authorized_sha"]) ->
          :ok

        plan_48_pending_checkpoint?(root, metadata) ->
          :ok

        true ->
          {:error,
           "Plan 48 pre-decision checkpoint rejected: pending census schema, HEAD, or binding is invalid"}
      end
    else
      validate_plan_48_recorded_decision(metadata, summarized_49)
    end
  end

  defp validate_plan_48_decision(_root, %{metadata: metadata}, summarized_49) do
    validate_plan_48_recorded_decision(metadata, summarized_49)
  end

  defp plan_48_pending_checkpoint?(root, metadata) do
    subject = Map.get(metadata, "subject_sha")

    with true <- Map.get(metadata, "report-gate") == "pass",
         true <- Map.get(metadata, "checkpoint") == "blocking-human-pending",
         true <- is_nil(Map.get(metadata, "decision")),
         true <- is_nil(Map.get(metadata, "authorized_ref")),
         true <- is_nil(Map.get(metadata, "authorized_sha")),
         true <- Map.get(metadata, "requirements-completed") == [],
         true <- is_binary(subject) and Regex.match?(~r/\A[0-9a-f]{40}\z/, subject),
         true <-
           Map.get(metadata, "proposed_ref") ==
             "refs/heads/phase-133-evidence-#{String.slice(subject, 0, 12)}",
         true <- Map.get(metadata, "proposed_ref_status") == "absent-read-only-lookup",
         digest when is_binary(digest) <- Map.get(metadata, "census_sha256"),
         true <- Regex.match?(~r/\A[0-9a-f]{64}\z/, digest),
         {:ok, census_bytes} <- File.read(Path.join(root, @census_path)),
         true <- sha256(census_bytes) == digest,
         {:ok, census} <- Jason.decode(census_bytes),
         true <- Map.get(census, "subject_sha") == subject,
         :ok <- Rindle.ValidateEvidenceCensus.validate_ledger_contract(census, root) do
      true
    else
      _ -> false
    end
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

  defp validate_plan55_summary(root, _source_root) do
    case File.read(summary_path(root, 55)) do
      {:error, :enoent} ->
        if File.regular?(Path.join(root, Path.join(@phase_dir, "133-57-PLAN.md"))),
          do:
            {:error,
             "Plan 55 halted summary is required before independent Plan 57 reconciliation"},
          else: :ok

      {:ok, summary} ->
        with {:ok, document} <- summary_document(summary),
             :ok <- validate_plan55_halted_summary(document),
             :ok <- validate_plan55_artifacts(root, document.metadata) do
          validate_plan55_validation_prefix(root)
        else
          {:error, _message} = error -> error
          _ -> {:error, "Plan 55 halted qualification summary is malformed"}
        end

      {:error, _reason} ->
        {:error, "Plan 55 summary is unreadable"}
    end
  end

  defp validate_plan55_halted_summary(%{status: "halted", metadata: metadata} = document) do
    expected = %{
      "qualification" => "blocked",
      "subject_sha" => @plan55_subject,
      "remote_ref" => @plan55_ref,
      "remote_absent" => true,
      "remote_lookup_exit_code" => 0,
      "census_sha256" => @plan55_census_sha256,
      "first_census_sha256" => @plan55_receipt_sha256,
      "second_census_sha256" => @plan55_receipt_sha256,
      "prior_receipt_sha256" => @plan55_prior_receipt_sha256,
      "review_report_sha256" => Map.fetch!(@plan55_report_digests, "133-REVIEW.md"),
      "security_inventory_sha256" =>
        Map.fetch!(@plan55_report_digests, "133-SECURITY-INVENTORY.json"),
      "security_report_sha256" => Map.fetch!(@plan55_report_digests, "133-SECURITY.md"),
      "validation_report_sha256" =>
        "9ecf6e6111d95863069fc7110873caa0016bc50f59f41894e5f2556dc737e164",
      "security_verdict" => "OPEN_THREATS",
      "security_open_threats" => 1,
      "halt_reason" =>
        "mix ci baseline format check failed; the single full coverage invocation exited 2; T-133-55-03 remains open.",
      "requirements-completed" => []
    }

    mismatch = Enum.find(expected, fn {key, value} -> Map.get(metadata, key) != value end)

    cond do
      not is_nil(mismatch) ->
        {key, _value} = mismatch
        {:error, "must preserve the authentic halted Plan 55 #{key} fact"}

      not String.contains?(document.body, "T-133-55-03 remains open") ->
        {:error, "must retain the open T-133-55-03 qualification finding"}

      true ->
        :ok
    end
  end

  defp validate_plan55_halted_summary(_document),
    do: {:error, "must retain immutable halted status and zero requirement credit"}

  defp validate_plan55_artifacts(root, metadata) do
    phase_dir = Path.join(root, @phase_dir)
    first_path = Path.join(phase_dir, "133-55-CENSUS-A.json")
    second_path = Path.join(phase_dir, "133-55-CENSUS-B.json")
    ledger_path = Path.join(root, @census_path)
    prior_receipt_path = Path.join(root, @receipt_path)
    plan59_active? = File.regular?(summary_path(root, 59))

    with {:ok, first} <- File.read(first_path),
         {:ok, second} <- File.read(second_path),
         {:ok, ledger_bytes} <- File.read(ledger_path),
         {:ok, prior_receipt} <- File.read(prior_receipt_path),
         true <-
           (sha256(first) == @plan55_receipt_sha256 and
              sha256(first) == Map.get(metadata, "first_census_sha256")) or
             {:error, "Plan 55 first census receipt identity differs"},
         true <-
           (sha256(second) == @plan55_receipt_sha256 and
              sha256(second) == Map.get(metadata, "second_census_sha256")) or
             {:error, "Plan 55 second census receipt identity differs"},
         true <- first == second or {:error, "Plan 55 census receipt artifacts differ"},
         {:ok, first_receipt} <- Jason.decode(first),
         {:ok, second_receipt} <- Jason.decode(second),
         {:ok, ledger} <- Jason.decode(ledger_bytes),
         true <-
           plan59_active? or
             (sha256(ledger_bytes) == @plan55_census_sha256 and
                sha256(ledger_bytes) == Map.get(metadata, "census_sha256")) or
             {:error, "Plan 55 census ledger digest differs"},
         true <-
           plan59_active? or Map.get(ledger, "subject_sha") == @plan55_subject or
             {:error, "Plan 55 census subject differs"},
         true <-
           Enum.all?([first_receipt, second_receipt], &(&1["source_sha"] == @plan55_subject)) or
             {:error, "Plan 55 census receipt subject differs"},
         true <-
           terminal_plan61_complete?(root) or
             sha256(prior_receipt) == @plan55_prior_receipt_sha256 or
             {:error, "Plan 55 prior canonical receipt digest differs"},
         :ok <- if(plan59_active?, do: :ok, else: validate_plan55_report_digests(phase_dir)) do
      :ok
    else
      {:error, message} -> {:error, message}
      _ -> {:error, "Plan 55 census receipt evidence is malformed"}
    end
  end

  defp validate_plan55_report_digests(phase_dir) do
    Enum.reduce_while(@plan55_report_digests, :ok, fn {name, digest}, :ok ->
      case File.read(Path.join(phase_dir, name)) do
        {:ok, bytes} ->
          if sha256(bytes) == digest,
            do: {:cont, :ok},
            else: {:halt, {:error, "Plan 55 report artifact digest differs for #{name}"}}

        {:error, _reason} ->
          {:halt, {:error, "Plan 55 report artifact is missing: #{name}"}}
      end
    end)
  end

  defp validate_plan55_validation_prefix(root) do
    with {:ok, validation} <- File.read(Path.join(root, @validation_path)),
         {offset, _length} <- :binary.match(validation, @plans_55_heading),
         prefix <- binary_part(validation, 0, offset),
         true <-
           byte_size(prefix) == @plan55_validation_prefix_bytes or
             {:error, "Plan 55 historical validation prefix byte length differs"},
         true <-
           sha256(prefix) == @plan55_validation_prefix_sha256 or
             {:error, "Plan 55 historical validation prefix digest differs"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 55 historical validation prefix is missing"}
    end
  end

  defp validate_plan57_summary(root) do
    case File.read(summary_path(root, 57)) do
      {:error, :enoent} ->
        :ok

      {:ok, summary} ->
        with {:ok, document} <- summary_document(summary),
             :ok <- validate_plan57_terminal_summary(document) do
          :ok
        else
          {:error, message} -> {:error, "Plan 57 summary #{message}"}
          _ -> {:error, "Plan 57 local recovery summary is malformed"}
        end

      {:error, _reason} ->
        {:error, "Plan 57 summary is unreadable"}
    end
  end

  defp validate_plan57_terminal_summary(%{status: "complete", metadata: metadata}) do
    validate_plan57_metadata(metadata, "local-gates-passed", false)
  end

  defp validate_plan57_terminal_summary(%{status: "halted", metadata: metadata}) do
    validate_plan57_metadata(metadata, "local-gates-failed", true)
  end

  defp validate_plan57_terminal_summary(_document),
    do: {:error, "must retain a local-gates-failed halt with zero requirement credit"}

  defp validate_plan57_metadata(metadata, qualification, halted?) do
    requirements = Map.get(metadata, "requirements-completed")
    halt_reason = Map.get(metadata, "halt_reason")
    local_source_sha = Map.get(metadata, "local_source_sha")
    prior_receipt_sha256 = Map.get(metadata, "prior_receipt_sha256")

    remote_identity_keys =
      ~w(subject_sha remote_ref authorized_ref published_ref run_id run_attempt receipt_sha256)

    remote_identity = Enum.find(remote_identity_keys, &Map.has_key?(metadata, &1))

    cond do
      Map.get(metadata, "qualification") != qualification ->
        {:error, "qualification must be #{qualification}"}

      requirements != [] ->
        {:error, "must grant zero requirement credit"}

      not (is_binary(local_source_sha) and Regex.match?(~r/\A[0-9a-f]{40}\z/, local_source_sha)) ->
        {:error, "must bind the local recovery source SHA"}

      prior_receipt_sha256 != @plan55_prior_receipt_sha256 ->
        {:error, "must preserve the prior canonical receipt digest"}

      Map.get(metadata, "remote_action") != "none" ->
        {:error, "must record remote_action: none"}

      not is_nil(remote_identity) ->
        {:error, "must not carry remote identity metadata (#{remote_identity})"}

      halted? and not (is_binary(halt_reason) and halt_reason != "") ->
        {:error, "halt must record a bounded halt_reason"}

      true ->
        :ok
    end
  end

  defp validate_new_chain_summaries(root, summary_state) do
    with :ok <- validate_plan58_summary(root),
         :ok <- validate_plan59_summary(root, summary_state),
         :ok <- validate_plan62_summary(root, summary_state),
         :ok <- validate_plan60_summary(root, summary_state),
         :ok <- validate_plan61_summary(root, summary_state) do
      :ok
    end
  end

  defp validate_plan58_summary(root) do
    validate_local_repair_summary(root, 58, "local-gates-passed", "local-gates-failed")
  end

  defp validate_local_repair_summary(root, plan, success_qualification, halt_qualification) do
    case File.read(summary_path(root, plan)) do
      {:error, :enoent} ->
        :ok

      {:ok, summary} ->
        with {:ok, document} <- summary_document(summary),
             :ok <-
               validate_local_repair_document(
                 root,
                 document,
                 success_qualification,
                 halt_qualification
               ) do
          :ok
        else
          {:error, reason} -> {:error, "Plan #{plan} summary #{reason}"}
          _ -> {:error, "Plan #{plan} local recovery summary is malformed"}
        end

      {:error, _reason} ->
        {:error, "Plan #{plan} summary is unreadable"}
    end
  end

  defp validate_local_repair_document(
         root,
         %{status: "complete", metadata: metadata},
         success,
         _halt
       ) do
    validate_local_repair_metadata(root, metadata, success, false)
  end

  defp validate_local_repair_document(
         root,
         %{status: "halted", metadata: metadata},
         _success,
         halt
       ) do
    validate_local_repair_metadata(root, metadata, halt, true)
  end

  defp validate_local_repair_document(_root, _document, _success, _halt),
    do: {:error, "must record a completed local gate or immutable halt"}

  defp validate_local_repair_metadata(root, metadata, qualification, halted?) do
    local_source_sha = Map.get(metadata, "local_source_sha")
    halt_reason = Map.get(metadata, "halt_reason")

    forbidden_remote_keys =
      ~w(subject_sha remote_ref authorized_ref published_ref run_id run_attempt receipt_sha256)

    cond do
      Map.get(metadata, "qualification") != qualification ->
        {:error, "qualification must be #{qualification}"}

      Map.get(metadata, "requirements-completed") != [] ->
        {:error, "must grant zero requirement credit"}

      Map.get(metadata, "prior_receipt_sha256") != @plan55_prior_receipt_sha256 ->
        {:error, "must preserve the canonical receipt digest"}

      Map.get(metadata, "remote_action") != "none" ->
        {:error, "must record remote_action: none"}

      not (is_binary(local_source_sha) and Regex.match?(~r/\A[0-9a-f]{40}\z/, local_source_sha)) ->
        {:error, "must bind a full local source SHA"}

      Enum.any?(forbidden_remote_keys, &Map.has_key?(metadata, &1)) ->
        {:error, "must not carry remote identity metadata"}

      halted? and not (is_binary(halt_reason) and String.trim(halt_reason) != "") ->
        {:error, "halt must record a bounded halt_reason"}

      not prior_receipt_unchanged?(root) ->
        {:error, "must preserve the prior canonical receipt bytes"}

      true ->
        :ok
    end
  end

  defp validate_plan59_summary(root, summary_state) do
    path = summary_path(root, 59)

    case File.read(path) do
      {:error, :enoent} ->
        if File.regular?(summary_path(root, 60)) or File.regular?(summary_path(root, 62)),
          do: {:error, "Plan 59 immutable halted summary is required before Plan 60 or 62"},
          else: :ok

      {:ok, summary} ->
        with true <-
               MapSet.member?(summary_state.completed, 58) or
                 {:error, "requires completed Plan 58 local gates"},
             {:ok, document} <- summary_document(summary),
             true <-
               document.status == "halted" or
                 {:error, "must remain halted; a Plan 59 success is forbidden"},
             :ok <- validate_plan59_outcome(root, document) do
          :ok
        else
          {:error, reason} -> {:error, "Plan 59 summary #{reason}"}
          _ -> {:error, "Plan 59 summary is malformed"}
        end

      {:error, _reason} ->
        {:error, "Plan 59 summary is unreadable"}
    end
  end

  defp validate_plan59_outcome(root, %{status: "halted", metadata: metadata} = document) do
    report_path = Path.join([root, @phase_dir, "133-59-LOCAL-GATES.json"])

    expected = %{
      "qualification" => "local-gates-failed",
      "terminal_automation" => "halted",
      "local_source_sha" => @plan59_restricted_subject,
      "local_gate_report_sha256" => @plan59_local_gate_sha256,
      "ci_exit_code" => 1,
      "coverage_result" => "not_started",
      "coverage_invocations" => 0,
      "prior_receipt_sha256" => @plan55_prior_receipt_sha256,
      "census_receipts" => "not_run",
      "fresh_reports" => "not_run",
      "remote_action" => "none",
      "remote_ref" => nil,
      "remote_lookup" => "not_run",
      "requirements-completed" => []
    }

    mismatch = Enum.find(expected, fn {key, value} -> Map.get(metadata, key) != value end)

    with nil <- mismatch,
         true <-
           prior_receipt_unchanged?(root) or
             {:error, "must preserve the prior canonical receipt bytes"},
         {:ok, report_bytes} <- File.read(report_path),
         true <-
           sha256(report_bytes) == @plan59_local_gate_sha256 or
             {:error, "local gate report digest differs"},
         {:ok, report} <- Jason.decode(report_bytes),
         true <-
           Map.get(report, "subject_sha") == @plan59_restricted_subject or
             {:error, "local report subject differs"},
         ci when is_map(ci) <- Map.get(report, "ci"),
         coverage when is_map(coverage) <- Map.get(report, "coverage"),
         true <-
           (Map.get(ci, "exit_code") == 1 and Map.get(ci, "command") == "mix ci") or
             {:error, "local report must retain the sole failed mix ci result"},
         true <-
           (Map.get(coverage, "invocations") == 0 and Map.get(coverage, "started") == false) or
             {:error, "coverage must remain unstarted"},
         true <-
           String.contains?(document.body, @plan59_restricted_subject) or
             {:error, "halted history must retain the restricted failed source"} do
      :ok
    else
      {key, _value} -> {:error, "must preserve the authentic halted Plan 59 #{key} fact"}
      _ -> {:error, "halted source report or summary is malformed"}
    end
  end

  defp validate_plan59_outcome(_root, _document),
    do: {:error, "must retain the authentic immutable local-gates-failed halt"}

  defp validate_plan62_mode(root, expected_status) do
    summary_status = if expected_status == :qualified, do: "complete", else: "halted"

    with :ok <- validate_plan58_summary(root),
         {:ok, plan59_bytes} <- File.read(summary_path(root, 59)),
         {:ok, plan59} <- summary_document(plan59_bytes),
         :ok <- validate_plan59_outcome(root, plan59),
         {:ok, plan62_bytes} <- File.read(summary_path(root, 62)),
         {:ok, plan62} <- summary_document(plan62_bytes),
         true <-
           plan62.status == summary_status or
             {:error, "Plan 62 outcome does not match --expect-plan62-#{expected_status}"},
         true <-
           (not File.regular?(summary_path(root, 60)) and
              not File.regular?(Path.join([root, @phase_dir, "133-60-CANDIDATE.json"]))) or
             {:error, "Plan 62 special mode must run before a Plan 60 result exists"},
         :ok <- validate_plan62_outcome(root, plan62),
         :ok <- validate_requirements(root, false) do
      result = if expected_status == :qualified, do: "qualified", else: "halted"
      IO.write("phase 133 Plan 62 #{result} evidence valid; requirements remain pending\n")
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 62 special-mode evidence is missing or malformed"}
    end
  end

  defp production_fixture_error(values) do
    cond do
      values[:expect_plan69_qualified] ->
        "Plan 69 production modes cannot use fixture inputs"

      values[:expect_plan69_halted] ->
        "Plan 69 production modes cannot use fixture inputs"

      values[:expect_plan84_repair_complete] ->
        "Plan 84 production modes cannot use fixture inputs"

      values[:expect_plan85_halted] ->
        "Plan 85 production modes cannot use fixture inputs"

      values[:expect_plan85_qualified] ->
        "Plan 85 production modes cannot use fixture inputs"

      values[:expect_plan65_source] ->
        "Plan 65 production modes cannot use fixture inputs"

      values[:expect_plan66_qualified] ->
        "Plan 66 production modes cannot use fixture inputs"

      values[:expect_plan66_halted] ->
        "Plan 66 production modes cannot use fixture inputs"

      true ->
        "Plan 64 production modes cannot use fixture inputs"
    end
  end

  defp fixture_inputs_error(values) do
    cond do
      values[:fixture_expect_plan69_qualified] ->
        "Plan 69 fixture modes require explicit fixture inputs"

      values[:fixture_expect_plan69_halted] ->
        "Plan 69 fixture modes require explicit fixture inputs"

      values[:fixture_expect_plan84_repair_complete] ->
        "Plan 84 fixture modes require explicit fixture inputs"

      values[:fixture_expect_plan85_halted] ->
        "Plan 85 fixture modes require explicit fixture inputs"

      values[:fixture_expect_plan85_qualified] ->
        "Plan 85 fixture modes require explicit fixture inputs"

      values[:fixture_expect_plan65_source] ->
        "Plan 65 fixture modes require explicit fixture inputs"

      values[:fixture_expect_plan66_qualified] ->
        "Plan 66 fixture modes require explicit fixture inputs"

      values[:fixture_expect_plan66_halted] ->
        "Plan 66 fixture modes require explicit fixture inputs"

      true ->
        "Plan 64 fixture modes require explicit fixture inputs"
    end
  end

  defp validate_plan84_mode(root, source_root, mode, result_scope) do
    with :ok <- validate_plan80_immutable_halt(root),
         :ok <- validate_plan84_repair_summary(root, source_root, result_scope),
         :ok <- validate_plan85_downstream_absent(root),
         :ok <- validate_plan85_outcome(root, source_root, mode, result_scope),
         :ok <- validate_requirements(root, false) do
      message =
        case {mode, result_scope} do
          {:repair_complete, :fixture} ->
            "Plan 84 repair fixture valid; production acceptance not established"

          {:repair_complete, :production} ->
            "Plan 84 formatter repair evidence valid; requirements remain pending"

          {:plan85_halted, :fixture} ->
            "Plan 85 halted fixture valid; production acceptance not established"

          {:plan85_halted, :production} ->
            "Plan 85 halted local evidence valid; requirements remain pending"

          {:plan85_qualified, :fixture} ->
            "Plan 85 qualified fixture valid; production acceptance not established"

          {:plan85_qualified, :production} ->
            "Plan 85 local evidence valid; requirements remain pending"
        end

      IO.write(message <> "\n")
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 84/85 local branch evidence is missing or malformed"}
    end
  end

  defp validate_plan80_immutable_halt(root) do
    with {:ok, summary_bytes} <- File.read(summary_path(root, 80)),
         true <-
           sha256(summary_bytes) == @plan80_halted_summary_sha256 or
             {:error, "Plan 80 immutable summary bytes changed"},
         {:ok, summary} <- summary_document(summary_bytes),
         true <- summary.status == "halted" or {:error, "Plan 80 must remain halted"},
         true <-
           (Map.get(summary.metadata, "subject_sha") == @plan80_halted_subject and
              Map.get(summary.metadata, "subject_tree") == @plan80_halted_tree) or
             {:error, "Plan 80 immutable source identity differs"},
         true <-
           (Map.get(summary.metadata, "qualification") == "local-gates-failed" and
              Map.get(summary.metadata, "requirements-completed") == [] and
              Map.get(summary.metadata, "prior_receipt_sha256") ==
                @plan80_prior_receipt_sha256 and
              Map.get(summary.metadata, "remote_action") == "none" and
              is_nil(Map.get(summary.metadata, "remote_ref"))) or
             {:error, "Plan 80 must preserve its zero-credit local halt"},
         true <-
           Map.get(summary.metadata, "local_gates_sha256") == @plan80_halted_report_sha256 or
             {:error, "Plan 80 immutable report digest differs"},
         report_path <- Path.join([root, @phase_dir, @plan80_report_filename]),
         {:ok, report_bytes} <- File.read(report_path),
         true <-
           sha256(report_bytes) == @plan80_halted_report_sha256 or
             {:error, "Plan 80 immutable local gate report bytes changed"},
         {:ok, report} <- Jason.decode(report_bytes),
         :ok <-
           validate_plan80_report_outcome(
             report,
             @plan80_halted_subject,
             @plan80_halted_tree,
             :halted
           ),
         {:ok, receipt_bytes} <- File.read(Path.join(root, @receipt_path)),
         true <-
           sha256(receipt_bytes) == @plan80_prior_receipt_sha256 or
             {:error, "Plan 80 prior canonical receipt bytes changed"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 80 immutable halted evidence is missing or malformed"}
    end
  end

  defp validate_plan84_repair_summary(root, source_root, result_scope) do
    with {:ok, bytes} <- File.read(summary_path(root, 84)),
         {:ok, summary} <- summary_document(bytes),
         true <- summary.status == "complete" or {:error, "Plan 84 repair must be complete"},
         true <-
           Map.get(summary.metadata, "qualification") == "formatter-repaired" or
             {:error, "Plan 84 must record the formatter repair"},
         commit when is_binary(commit) <- Map.get(summary.metadata, "formatter_repair_commit"),
         tree when is_binary(tree) <- Map.get(summary.metadata, "formatter_repair_tree"),
         file when is_binary(file) <- Map.get(summary.metadata, "formatter_repair_file"),
         digest when is_binary(digest) <- Map.get(summary.metadata, "formatter_repair_sha256"),
         true <-
           (valid_hex?(commit, 40) and valid_hex?(tree, 40)) or
             {:error, "Plan 84 formatter repair must bind a full source SHA and tree"},
         true <-
           file == "test/install_smoke/phase_133_completed_validation_test.exs" or
             {:error, "Plan 84 formatter repair file differs from the identified tracked path"},
         true <- valid_hex?(digest, 64) or {:error, "Plan 84 formatter file digest is malformed"},
         true <-
           Map.get(summary.metadata, "requirements-completed") == [] or
             {:error, "Plan 84 formatter repair must grant zero requirement credit"},
         true <-
           (Map.get(summary.metadata, "prior_receipt_sha256") ==
              @plan80_prior_receipt_sha256 and
              Map.get(summary.metadata, "remote_action") == "none" and
              is_nil(Map.get(summary.metadata, "remote_ref"))) or
             {:error, "Plan 84 must preserve the receipt and authorize no remote action"},
         :ok <-
           validate_plan84_formatter_source(source_root, commit, tree, file, digest, result_scope) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 84 formatter repair summary is missing or malformed"}
    end
  end

  defp validate_plan84_formatter_source(_root, _commit, _tree, _file, _digest, :fixture),
    do: :ok

  defp validate_plan84_formatter_source(root, commit, tree, file, digest, :production) do
    with :ok <- validate_committed_source(root, commit, tree, [file]),
         {:ok, changed} <-
           git(root, ["diff-tree", "--no-commit-id", "--name-only", "-r", commit]),
         true <-
           file in String.split(changed, "\n", trim: true) or
             {:error, "Plan 84 formatter repair commit did not change the recorded file"},
         {contents, 0} <- System.cmd("git", ["show", "#{commit}:#{file}"], cd: root),
         true <-
           sha256(contents) == digest or
             {:error, "Plan 84 formatter repair file digest differs from its commit"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 84 formatter repair source commit is unavailable"}
    end
  end

  defp validate_plan91_mode(report_root, source_root, result_scope) do
    summary_file = Path.join([report_root, @phase_dir, @plan91_summary_filename])

    with :ok <- validate_plan91_prior_history(report_root),
         {:ok, summary_bytes} <- File.read(summary_file),
         {:ok, summary} <- summary_document(summary_bytes),
         result when result in [:halted, :qualified] <- plan91_result(summary),
         :ok <- validate_plan91_summary(summary, result),
         report_file <- Path.join([report_root, @phase_dir, @plan91_report_filename]),
         {:ok, report_bytes} <- File.read(report_file),
         true <-
           sha256(report_bytes) == Map.get(summary.metadata, "local_gates_sha256") or
             {:error, "Plan 91 local-gates report digest differs"},
         {:ok, report} <- Jason.decode(report_bytes),
         :ok <-
           validate_plan91_report(
             report_root,
             source_root,
             summary.metadata,
             report,
             result,
             result_scope
           ),
         :ok <- validate_plan91_attempt_record(report_root, summary.metadata, report),
         :ok <- validate_requirements(report_root, false),
         :ok <- validate_plan91_downstream_absent(report_root) do
      outcome = if(result == :qualified, do: "qualified", else: "halted")
      suffix = if(result_scope == :fixture, do: "fixture", else: "local result")
      IO.write("Plan 91 #{outcome} #{suffix} valid; requirements remain pending\n")
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 91 local result is missing or malformed"}
    end
  end

  defp plan91_result(%{status: "halted", metadata: %{"qualification" => "local-gates-failed"}}),
    do: :halted

  defp plan91_result(%{status: "complete", metadata: %{"qualification" => "passed"}}),
    do: :qualified

  defp plan91_result(_summary), do: :invalid

  defp validate_plan91_summary(summary, result) do
    metadata = summary.metadata
    subject = Map.get(metadata, "subject_sha")
    tree = Map.get(metadata, "subject_tree")
    expected_qualification = if(result == :qualified, do: "passed", else: "local-gates-failed")
    expected_status = if(result == :qualified, do: "complete", else: "halted")

    cond do
      summary.status != expected_status or
          Map.get(metadata, "qualification") != expected_qualification ->
        {:error, "Plan 91 outcome differs from its report"}

      not valid_hex?(subject, 40) or not valid_hex?(tree, 40) ->
        {:error, "Plan 91 must bind a full source SHA and tree"}

      subject == @plan87_subject or subject in @plan69_exhausted_subjects ->
        {:error, "Plan 91 subject reuses a barred or consumed source SHA"}

      Map.get(metadata, "local_gates_attempts") != 1 ->
        {:error, "Plan 91 must record exactly one local attempt"}

      Map.get(metadata, "requirements-completed") != [] ->
        {:error, "Plan 91 local result must grant zero requirement credit"}

      MapSet.new(Map.get(metadata, "requirements-pending", [])) != MapSet.new(@phase_requirements) ->
        {:error, "Plan 91 local result must leave all five requirements pending"}

      Map.get(metadata, "prior_receipt_sha256") != @plan80_prior_receipt_sha256 ->
        {:error, "Plan 91 local result must preserve the prior canonical receipt"}

      Map.get(metadata, "remote_action") != "none" or
        not is_nil(Map.get(metadata, "remote_ref")) or
        Map.get(metadata, "remote_lookup") not in ["not-run", "not_run"] or
        Map.get(metadata, "publication_count") != 0 or
        Map.get(metadata, "dispatch_count") != 0 or
          Map.get(metadata, "census") != "none" ->
        {:error, "Plan 91 local result must authorize no census or remote action"}

      result == :halted and
          (not is_binary(Map.get(metadata, "halt_reason")) or
             String.trim(Map.get(metadata, "halt_reason", "")) == "") ->
        {:error, "Plan 91 halt must preserve its first failure reason"}

      result == :qualified and String.trim(Map.get(metadata, "halt_reason", "")) != "" ->
        {:error, "Plan 91 qualified result cannot carry a halt reason"}

      true ->
        :ok
    end
  end

  defp validate_plan91_prior_history(root) do
    plan87_summary_path = summary_path(root, 87)
    plan87_report_path = Path.join([root, @phase_dir, "133-87-LOCAL-GATES.json"])
    plan85_summary_path = summary_path(root, 85)
    plan85_report_path = Path.join([root, @phase_dir, "133-85-LOCAL-GATES.json"])
    receipt_path = Path.join(root, @receipt_path)

    with {:ok, plan87_bytes} <- File.read(plan87_summary_path),
         true <-
           sha256(plan87_bytes) == @plan87_summary_sha256 or
             {:error, "Plan 87 immutable summary bytes changed"},
         {:ok, plan87} <- summary_document(plan87_bytes),
         true <-
           (plan87.status == "halted" and
              Map.get(plan87.metadata, "qualification") == "preflight-halted-zero-credit" and
              Map.get(plan87.metadata, "source_sha") == @plan87_subject and
              Map.get(plan87.metadata, "source_tree") == @plan87_tree and
              Map.get(plan87.metadata, "local_gates_report") == "absent" and
              Map.get(plan87.metadata, "local_gates_attempts") == 0 and
              Map.get(plan87.metadata, "requirements-completed") == []) or
             {:error, "Plan 87 must remain halted with no local-gates attempt"},
         true <-
           not File.regular?(plan87_report_path) or
             {:error, "Plan 87 local-gates report must remain absent"},
         {:ok, plan85_summary_bytes} <- File.read(plan85_summary_path),
         true <-
           sha256(plan85_summary_bytes) == @plan85_summary_sha256 or
             {:error, "Plan 85 immutable summary bytes changed"},
         {:ok, plan85_report_bytes} <- File.read(plan85_report_path),
         true <-
           sha256(plan85_report_bytes) == @plan85_report_sha256 or
             {:error, "Plan 85 immutable report bytes changed"},
         {:ok, receipt_bytes} <- File.read(receipt_path),
         true <-
           sha256(receipt_bytes) == @plan80_prior_receipt_sha256 or
             {:error, "prior canonical receipt bytes changed"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 91 immutable Plan 87/85 history is missing or malformed"}
    end
  end

  defp validate_plan91_report(report_root, source_root, metadata, report, result, result_scope) do
    subject = Map.get(metadata, "subject_sha")
    tree = Map.get(metadata, "subject_tree")

    with true <-
           Map.get(report, "schema_version") == 1 or {:error, "Plan 91 report schema differs"},
         true <-
           Map.get(report, "subject_sha") == subject or
             {:error, "Plan 91 report subject SHA differs"},
         true <-
           Map.get(report, "subject_tree") == tree or
             {:error, "Plan 91 report source tree differs"},
         :ok <- validate_plan91_subject_history(report_root, subject),
         :ok <- validate_plan91_source(source_root, subject, tree, result_scope),
         :ok <- validate_plan91_gate_commands(report),
         :ok <- validate_plan91_report_outcome(source_root, report, result),
         :ok <- validate_plan91_failure_reason(metadata, report, source_root, result) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 91 local-gates report is malformed"}
    end
  end

  defp validate_plan91_subject_history(root, subject) do
    current = Path.join([root, @phase_dir, @plan91_report_filename])
    report_glob = Path.join([root, @phase_dir, "133-*-LOCAL-GATES.json"])
    plan91_reports = Path.wildcard(Path.join([root, @phase_dir, "133-91-LOCAL-GATES*.json"]))

    with true <-
           plan91_reports == [current] or
             {:error, "Plan 91 must contain exactly one local-gates report"},
         {:ok, prior_subjects} <- prior_local_subjects(report_glob, current),
         true <-
           subject not in prior_subjects or
             {:error, "Plan 91 subject reuses a barred or consumed source SHA"},
         true <-
           subject != @plan87_subject or
             {:error, "Plan 91 subject reuses a barred or consumed source SHA"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 91 local-subject history is malformed"}
    end
  end

  defp prior_local_subjects(glob, current) do
    glob
    |> Path.wildcard()
    |> Enum.reject(&(&1 == current))
    |> Enum.reduce_while({:ok, []}, fn path, {:ok, subjects} ->
      with {:ok, bytes} <- File.read(path),
           {:ok, report} <- Jason.decode(bytes),
           subject when is_binary(subject) <- Map.get(report, "subject_sha"),
           true <- valid_hex?(subject, 40) do
        {:cont, {:ok, [subject | subjects]}}
      else
        _ -> {:halt, {:error, "Previously consumed local-gates report is malformed"}}
      end
    end)
  end

  defp validate_plan91_source(_root, _subject, _tree, :fixture), do: :ok

  defp validate_plan91_source(root, subject, tree, :production),
    do: validate_committed_source(root, subject, tree, @plan91_source_paths)

  defp validate_plan91_gate_commands(report) do
    dependencies = Map.get(report, "dependencies", %{})
    jose = Map.get(report, "jose_preflight", %{})
    ci = Map.get(report, "ci", %{})
    coverage = Map.get(report, "coverage", %{})

    cond do
      Map.get(dependencies, "command") != "mix deps.get --check-locked" ->
        {:error, "Plan 91 dependency stage command differs"}

      Map.get(jose, "command") != @plan91_jose_command ->
        {:error, "Plan 91 JOSE preflight command differs"}

      Map.get(ci, "command") != "mix ci" ->
        {:error, "Plan 91 CI command differs"}

      Map.get(coverage, "command") != @plan91_coverage_command ->
        {:error, "Plan 91 coverage command differs"}

      Map.get(coverage, "invocations", 0) not in [0, 1] ->
        {:error, "Plan 91 report shows more than one coverage invocation"}

      Map.get(coverage, "started") == true and Map.get(coverage, "invocations") != 1 ->
        {:error, "Plan 91 coverage invocation count differs from its start state"}

      Map.get(coverage, "started") != true and Map.get(coverage, "invocations", 0) != 0 ->
        {:error, "Plan 91 coverage invocation count differs from its start state"}

      Map.get(coverage, "started") != true and
          Enum.any?(
            ["exit_code", "test_count", "failure_count", "total_percent"],
            &(not is_nil(Map.get(coverage, &1)))
          ) ->
        {:error, "Plan 91 coverage output exists without a started invocation"}

      true ->
        :ok
    end
  end

  defp validate_plan91_report_outcome(source_root, report, :halted) do
    dependencies = Map.get(report, "dependencies", %{})
    jose = Map.get(report, "jose_preflight", %{})
    ci = Map.get(report, "ci", %{})
    coverage = Map.get(report, "coverage", %{})
    coverage_started = Map.get(coverage, "started") == true
    ci_green = plan91_ci_green?(ci, report)

    cond do
      not is_integer(Map.get(dependencies, "exit_code")) ->
        {:error, "Plan 91 dependency stage result is missing"}

      Map.get(dependencies, "exit_code") != 0 and
          (Map.get(jose, "started") == true or Map.get(ci, "started") == true or coverage_started) ->
        {:error, "Plan 91 dependency failure has downstream gate output"}

      not plan91_jose_green?(report) and
          (Map.get(ci, "started") == true or coverage_started) ->
        {:error, "Plan 91 JOSE preflight failure has downstream gate output"}

      Map.get(ci, "started") == true and not ci_green and coverage_started ->
        {:error, "Plan 91 failed mix ci started coverage"}

      Map.get(ci, "started") != true and coverage_started ->
        {:error, "Plan 91 coverage started before mix ci"}

      ci_green and plan91_coverage_green?(source_root, report) ->
        {:error, "Plan 91 passing local report cannot be called halted"}

      true ->
        :ok
    end
  end

  defp validate_plan91_report_outcome(source_root, report, :qualified) do
    ci = Map.get(report, "ci", %{})
    coverage = Map.get(report, "coverage", %{})

    with true <-
           plan91_dependencies_green?(report) or {:error, "Plan 91 report is not fully green"},
         true <- plan91_jose_green?(report) or {:error, "Plan 91 report is not fully green"},
         true <-
           plan91_ci_green?(ci, report) or
             {:error, "Plan 91 report lacks a complete green terminal CI summary"},
         true <-
           plan91_coverage_green?(source_root, report) or
             {:error, "Plan 91 report is not fully green"},
         {:ok, terminal} <- plan91_terminal_ci_summary(report),
         true <-
           Map.get(coverage, "test_count") == terminal.tests or
             {:error, "Plan 91 full CI and coverage test counts differ"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 91 report is not fully green"}
    end
  end

  defp plan91_dependencies_green?(report) do
    dependencies = Map.get(report, "dependencies", %{})

    Map.get(dependencies, "command") == "mix deps.get --check-locked" and
      Map.get(dependencies, "exit_code") == 0
  end

  defp plan91_jose_green?(report) do
    jose = Map.get(report, "jose_preflight", %{})

    Map.get(jose, "command") == @plan91_jose_command and
      Map.get(jose, "started") == true and Map.get(jose, "exit_code") == 0 and
      Map.get(jose, "stage_verified") == true
  end

  defp plan91_ci_green?(ci, report) do
    Map.get(ci, "command") == "mix ci" and Map.get(ci, "started") == true and
      Map.get(ci, "exit_code") == 0 and
      case plan91_terminal_ci_summary(report) do
        {:ok, %{tests: tests, failures: 0, invalid: 0}} when tests > 0 -> true
        _ -> false
      end
  end

  defp plan91_terminal_ci_summary(report) do
    lines = get_in(report, ["diagnostics", "command_output", "ci", "lines"])

    clean_lines =
      if is_list(lines),
        do:
          Enum.filter(lines, &is_binary/1) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")),
        else: []

    summaries =
      Enum.flat_map(clean_lines, fn line ->
        case Regex.run(
               ~r/\A(\d+) doctests?, (\d+) tests?, (\d+) failures?, (\d+) excluded, (\d+) invalid, (\d+) skipped\z/,
               line,
               capture: :all_but_first
             ) do
          [doctests, tests, failures, excluded, invalid, skipped] ->
            [
              %{
                line: line,
                doctests: String.to_integer(doctests),
                tests: String.to_integer(tests),
                failures: String.to_integer(failures),
                excluded: String.to_integer(excluded),
                invalid: String.to_integer(invalid),
                skipped: String.to_integer(skipped)
              }
            ]

          _ ->
            []
        end
      end)

    case summaries do
      [summary] ->
        if List.last(clean_lines) == summary.line,
          do: {:ok, summary},
          else: {:error, "mix ci report lacks a complete terminal suite summary"}

      _ ->
        {:error, "mix ci report lacks a complete terminal suite summary"}
    end
  end

  defp plan91_coverage_green?(source_root, report) do
    coverage = Map.get(report, "coverage", %{})
    total = Map.get(coverage, "total_percent")
    floor = Map.get(coverage, "floor_percent")

    configured_floor =
      with {:ok, bytes} <- File.read(Path.join(source_root, "coveralls.json")),
           {:ok, config} <- Jason.decode(bytes),
           options when is_map(options) <- Map.get(config, "coverage_options"),
           value when is_number(value) <- Map.get(options, "minimum_coverage") do
        value
      else
        _ -> nil
      end

    Map.get(coverage, "command") == @plan91_coverage_command and
      Map.get(coverage, "started") == true and Map.get(coverage, "invocations") == 1 and
      Map.get(coverage, "exit_code") == 0 and positive_integer?(Map.get(coverage, "test_count")) and
      Map.get(coverage, "failure_count") == 0 and is_number(total) and total >= floor and
      total <= 100 and is_number(floor) and floor == configured_floor and
      case plan91_terminal_ci_summary(report) do
        {:ok, %{tests: tests}} -> Map.get(coverage, "test_count") == tests
        _ -> false
      end
  end

  defp validate_plan91_attempt_record(root, metadata, report) do
    path = Path.join([root, @validation_path])
    heading = "## Plan 91 Fresh-Subject Local Qualification — Halted, Zero Credit"
    subject = Map.get(metadata, "subject_sha")
    tree = Map.get(metadata, "subject_tree")
    digest = Map.get(metadata, "local_gates_sha256")

    with {:ok, validation} <- File.read(path),
         true <-
           length(Regex.scan(~r/^#{Regex.escape(heading)}$/m, validation)) == 1 or
             {:error, "Plan 91 validation must record exactly one attempt"},
         [_, section] <-
           Regex.run(~r/(?ms)^#{Regex.escape(heading)}\s*\n(.*?)(?=^## |\z)/, validation),
         true <-
           String.contains?(section, "plan91_attempt_count: 1") or
             {:error, "Plan 91 validation must record exactly one attempt"},
         true <-
           String.contains?(section, "plan91_source_sha: #{subject}") or
             {:error, "Plan 91 validation source SHA differs"},
         true <-
           String.contains?(section, "plan91_source_tree: #{tree}") or
             {:error, "Plan 91 validation source tree differs"},
         true <-
           String.contains?(section, "plan91_report_sha256: #{digest}") or
             {:error, "Plan 91 validation report digest differs"},
         true <-
           String.contains?(
             section,
             "plan91_plan87_summary_sha256_before_and_after: #{@plan87_summary_sha256}"
           ) or
             {:error, "Plan 91 validation Plan 87 fingerprint differs"},
         true <-
           String.contains?(section, "plan91_plan85_summary_sha256: #{@plan85_summary_sha256}") or
             {:error, "Plan 91 validation Plan 85 summary fingerprint differs"},
         true <-
           String.contains?(section, "plan91_plan85_report_sha256: #{@plan85_report_sha256}") or
             {:error, "Plan 91 validation Plan 85 report fingerprint differs"},
         true <-
           String.contains?(
             section,
             "plan91_prior_canonical_receipt_sha256: #{@plan80_prior_receipt_sha256}"
           ) or
             {:error, "Plan 91 validation receipt fingerprint differs"},
         true <-
           (String.contains?(section, "plan91_remote_action: none") and
              String.contains?(section, "plan91_census_or_candidate: none")) or
             {:error, "Plan 91 validation must record no census or remote action"},
         true <- Map.get(report, "subject_sha") == subject do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 91 append-only validation record is missing or malformed"}
    end
  end

  defp validate_plan91_failure_reason(_metadata, _report, _source_root, :qualified), do: :ok

  defp validate_plan91_failure_reason(metadata, report, source_root, :halted) do
    reason = Map.get(metadata, "halt_reason", "")

    stage =
      cond do
        not plan91_dependencies_green?(report) -> "mix deps.get"
        not plan91_jose_green?(report) -> "JOSE"
        not plan91_ci_green?(Map.get(report, "ci", %{}), report) -> "mix ci"
        not plan91_coverage_green?(source_root, report) -> "coverage"
        true -> nil
      end

    if is_binary(stage) and String.contains?(String.downcase(reason), String.downcase(stage)) do
      :ok
    else
      {:error, "Plan 91 halt must preserve its first failed gate"}
    end
  end

  defp validate_plan91_downstream_absent(root) do
    forbidden = [
      "133-91-CENSUS.json",
      "133-91-CANDIDATE.json",
      "133-91-RUN.json"
    ]

    if Enum.any?(forbidden, &File.regular?(Path.join([root, @phase_dir, &1]))) do
      {:error, "Plan 91 result must not create census, remote, or candidate output"}
    else
      :ok
    end
  end

  defp validate_plan85_outcome(root, _source_root, :repair_complete, _result_scope) do
    if File.regular?(summary_path(root, 85)) or
         File.regular?(Path.join([root, @phase_dir, "133-85-LOCAL-GATES.json"])),
       do: {:error, "Plan 85 output requires its branch-specific production reconciliation mode"},
       else: :ok
  end

  defp validate_plan85_outcome(root, source_root, :plan85_halted, result_scope),
    do: validate_plan85(root, source_root, :halted, result_scope)

  defp validate_plan85_outcome(root, source_root, :plan85_qualified, result_scope),
    do: validate_plan85(root, source_root, :qualified, result_scope)

  defp validate_plan85(root, source_root, expected, result_scope) do
    with {:ok, bytes} <- File.read(summary_path(root, 85)),
         {:ok, summary} <- summary_document(bytes),
         expected_status <- if(expected == :qualified, do: "complete", else: "halted"),
         true <-
           summary.status == expected_status or
             {:error, "Plan 85 outcome differs from requested mode"},
         :ok <- validate_plan85_summary(summary.metadata, expected),
         :ok <- validate_plan85_report(root, source_root, summary.metadata, expected),
         :ok <- validate_plan85_source(root, source_root, summary.metadata, result_scope),
         :ok <- validate_plan85_failure_reason(root, summary.metadata, expected) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 85 local gate report or summary is missing or malformed"}
    end
  end

  defp validate_plan85_summary(metadata, expected) do
    subject = Map.get(metadata, "subject_sha")
    tree = Map.get(metadata, "subject_tree")
    qualification = Map.get(metadata, "qualification")
    expected_qualification = if(expected == :qualified, do: "passed", else: "local-gates-failed")

    cond do
      not valid_hex?(subject, 40) or not valid_hex?(tree, 40) ->
        {:error, "Plan 85 must bind a full source SHA and tree"}

      subject in @plan69_exhausted_subjects or subject == @plan62_subject_sha ->
        {:error, "Plan 85 subject reuses a consumed source SHA"}

      tree == @plan80_halted_tree ->
        {:error, "Plan 85 source tree reuses the halted Plan 80 tree"}

      qualification != expected_qualification ->
        {:error, "Plan 85 qualification differs from requested mode"}

      Map.get(metadata, "requirements-completed") != [] ->
        {:error, "Plan 85 local result must grant zero requirement credit"}

      Map.get(metadata, "prior_receipt_sha256") != @plan80_prior_receipt_sha256 ->
        {:error, "Plan 85 local result must preserve the prior canonical receipt"}

      Map.get(metadata, "remote_action") != "none" or
        not is_nil(Map.get(metadata, "remote_ref")) or
        Map.get(metadata, "remote_lookup") not in ["not-run", "not_run"] or
        Map.get(metadata, "publication_count") != 0 or
          Map.get(metadata, "dispatch_count") != 0 ->
        {:error, "Plan 85 local result must authorize no remote or downstream action"}

      expected == :halted and
          (not is_binary(Map.get(metadata, "halt_reason")) or
             String.trim(Map.get(metadata, "halt_reason", "")) == "") ->
        {:error, "Plan 85 halt must preserve its first failure reason"}

      true ->
        :ok
    end
  end

  defp validate_plan85_report(root, source_root, metadata, expected) do
    path = Path.join([root, @phase_dir, "133-85-LOCAL-GATES.json"])
    subject = Map.get(metadata, "subject_sha")
    tree = Map.get(metadata, "subject_tree")

    with {:ok, bytes} <- File.read(path),
         true <-
           sha256(bytes) == Map.get(metadata, "local_gates_sha256") or
             {:error, "Plan 85 local gate report digest differs"},
         {:ok, report} <- Jason.decode(bytes),
         true <-
           Map.get(report, "subject_sha") == subject or
             {:error, "Plan 85 report subject SHA differs"},
         true <-
           Map.get(report, "subject_tree") == tree or
             {:error, "Plan 85 report source tree differs"},
         :ok <- validate_plan85_report_outcome(report, subject, tree, expected),
         :ok <- validate_plan85_configured_floor(source_root, report, expected),
         :ok <- validate_plan85_runner_contract(source_root) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 85 local gate report is malformed"}
    end
  end

  defp validate_plan85_report_outcome(report, subject, tree, :qualified) do
    ci = Map.get(report, "ci", %{})

    if Map.get(ci, "exit_code") != 0 do
      {:error, "Plan 85 report is not fully green"}
    else
      with :ok <-
             validate_plan66_local_report(report, subject, tree, "mix deps.get --check-locked"),
           ci <- Map.get(report, "ci", %{}),
           coverage <- Map.get(report, "coverage", %{}),
           true <-
             Map.get(ci, "test_count") == Map.get(coverage, "test_count") or
               {:error, "Plan 85 full CI and coverage test counts differ"} do
        :ok
      else
        {:error, _message} = error -> error
        _ -> {:error, "Plan 85 report is not fully green"}
      end
    end
  end

  defp validate_plan85_report_outcome(report, subject, tree, :halted) do
    dependencies = Map.get(report, "dependencies", %{})
    jose = Map.get(report, "jose_preflight", %{})
    ci = Map.get(report, "ci", %{})
    coverage = Map.get(report, "coverage", %{})

    cond do
      Map.get(report, "schema_version") != 1 or Map.get(report, "subject_sha") != subject or
          not valid_hex?(tree, 40) ->
        {:error, "Plan 85 halted report source identity differs"}

      Map.get(dependencies, "command") != "mix deps.get --check-locked" ->
        {:error, "Plan 85 dependency stage command differs"}

      Map.get(dependencies, "exit_code") != 0 and
          (Map.get(jose, "started") == true or Map.get(ci, "started") == true or
             Map.get(coverage, "started") == true) ->
        {:error, "Plan 85 dependency failure has downstream gate output"}

      Map.get(dependencies, "exit_code") == 0 and
          Map.get(jose, "command") !=
            "mix run --no-start --no-deps-check --no-compile -e <focused JOSE structure and Elixir compile>" ->
        {:error, "Plan 85 JOSE preflight command differs"}

      Map.get(jose, "exit_code") not in [nil, 0] and
          (Map.get(ci, "started") == true or Map.get(coverage, "started") == true) ->
        {:error, "Plan 85 JOSE preflight failure has downstream gate output"}

      Map.get(ci, "started") == true and Map.get(ci, "command") != "mix ci" ->
        {:error, "Plan 85 CI command differs"}

      Map.get(ci, "exit_code") not in [nil, 0] and Map.get(coverage, "started") == true ->
        {:error, "Plan 85 failed mix ci started coverage"}

      Map.get(coverage, "invocations", 0) not in [0, 1] ->
        {:error, "Plan 85 halt report shows more than one coverage invocation"}

      Map.get(coverage, "started") != true and Map.get(coverage, "invocations", 0) != 0 ->
        {:error, "Plan 85 coverage invocation count differs from its start state"}

      Map.get(coverage, "started") == true and Map.get(coverage, "invocations") != 1 ->
        {:error, "Plan 85 coverage must run exactly once after green CI"}

      Map.get(coverage, "started") == true and not plan85_ci_green?(ci) ->
        {:error, "Plan 85 coverage started before complete green CI"}

      Map.get(coverage, "started") == true and
          Map.get(coverage, "command") != "mix coveralls.multiple --type local --type json" ->
        {:error, "Plan 85 coverage command differs"}

      Map.get(coverage, "started") == true and plan85_coverage_green?(coverage) and
          Map.get(ci, "test_count") == Map.get(coverage, "test_count") ->
        {:error, "Plan 85 passing local report cannot be called halted"}

      Map.get(coverage, "started") != true and plan85_ci_green?(ci) ->
        {:error, "Plan 85 green CI halt must preserve its first failed gate"}

      true ->
        :ok
    end
  end

  defp validate_plan85_configured_floor(source_root, report, :halted) do
    coverage = Map.get(report, "coverage", %{})

    if Map.get(coverage, "started") == true do
      validate_plan85_configured_floor(source_root, report, :qualified, allow_below_floor: true)
    else
      :ok
    end
  end

  defp validate_plan85_configured_floor(source_root, report, :qualified),
    do: validate_plan85_configured_floor(source_root, report, :qualified, [])

  defp validate_plan85_configured_floor(source_root, report, :qualified, validation_options) do
    path = Path.join(source_root, "coveralls.json")

    with {:ok, bytes} <- File.read(path),
         {:ok, config} <- Jason.decode(bytes),
         coverage_options when is_map(coverage_options) <- Map.get(config, "coverage_options"),
         floor when is_number(floor) <- Map.get(coverage_options, "minimum_coverage"),
         coverage <- Map.get(report, "coverage", %{}),
         true <-
           Map.get(coverage, "floor_percent") == floor or
             {:error, "Plan 85 coverage floor differs from repository configuration"},
         true <-
           Keyword.get(validation_options, :allow_below_floor, false) or
             Map.get(coverage, "total_percent", 0) >= floor or
             {:error, "Plan 85 coverage is below the configured floor"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 85 configured coverage floor is unavailable"}
    end
  end

  defp validate_plan85_failure_reason(_root, _metadata, :qualified), do: :ok

  defp validate_plan85_failure_reason(root, metadata, :halted) do
    report_path = Path.join([root, @phase_dir, "133-85-LOCAL-GATES.json"])

    with {:ok, bytes} <- File.read(report_path),
         {:ok, report} <- Jason.decode(bytes),
         reason when is_binary(reason) <- Map.get(metadata, "halt_reason"),
         stage when is_binary(stage) <- plan85_first_failed_stage(report),
         true <-
           String.contains?(String.downcase(reason), String.downcase(stage)) or
             {:error, "Plan 85 halt reason does not preserve the first failed #{stage} gate"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 85 halt must preserve its first red gate"}
    end
  end

  defp plan85_first_failed_stage(report) do
    dependencies = Map.get(report, "dependencies", %{})
    jose = Map.get(report, "jose_preflight", %{})
    ci = Map.get(report, "ci", %{})
    coverage = Map.get(report, "coverage", %{})

    cond do
      Map.get(dependencies, "exit_code") != 0 ->
        "mix deps.get"

      Map.get(jose, "started") != true or Map.get(jose, "exit_code") != 0 or
          Map.get(jose, "stage_verified") != true ->
        "JOSE"

      not plan85_ci_green?(ci) ->
        "mix ci"

      Map.get(coverage, "started") != true or not plan85_coverage_green?(coverage) or
          Map.get(ci, "test_count") != Map.get(coverage, "test_count") ->
        "coverage"

      true ->
        ""
    end
  end

  defp plan85_ci_green?(ci) do
    Map.get(ci, "command") == "mix ci" and Map.get(ci, "started") == true and
      Map.get(ci, "exit_code") == 0 and positive_integer?(Map.get(ci, "test_count")) and
      Map.get(ci, "failure_count") == 0
  end

  defp plan85_coverage_green?(coverage) do
    total = Map.get(coverage, "total_percent")
    floor = Map.get(coverage, "floor_percent")

    Map.get(coverage, "command") == "mix coveralls.multiple --type local --type json" and
      Map.get(coverage, "started") == true and Map.get(coverage, "invocations") == 1 and
      Map.get(coverage, "exit_code") == 0 and positive_integer?(Map.get(coverage, "test_count")) and
      Map.get(coverage, "failure_count") == 0 and Map.get(coverage, "test_count") != nil and
      is_number(total) and is_number(floor) and floor >= 0 and total >= floor and total <= 100
  end

  defp validate_plan85_runner_contract(root) do
    path = Path.join(root, "scripts/maintainer/phase_133_local_gates.sh")

    with {:ok, script} <- File.read(path),
         true <-
           String.contains?(script, @plan80_halted_subject) or
             {:error, "Plan 85 runner must reject the exhausted Plan 80 subject"},
         true <-
           String.contains?(script, "output already exists; prior evidence is never overwritten") or
             {:error, "Plan 85 runner must preserve no-clobber report creation"},
         true <-
           String.contains?(script, "mix deps.get --check-locked") or
             {:error, "Plan 85 runner must use locked dependencies"},
         true <-
           (String.contains?(script, "ASDF_ERLANG_VERSION=27.3.4.15") and
              String.contains?(script, "ASDF_ELIXIR_VERSION=1.17.3-otp-27")) or
             {:error, "Plan 85 runner must pin the supported toolchain"},
         true <-
           String.contains?(
             script,
             "preflight_command=\"mix run --no-start --no-deps-check --no-compile -e <focused JOSE structure and Elixir compile>\""
           ) or
             {:error, "Plan 85 runner must execute the active JOSE preflight"},
         true <-
           (String.contains?(script, "ci_command=\"mix ci\"") and
              String.contains?(
                script,
                "coverage_command=\"mix coveralls.multiple --type local --type json\""
              )) or
             {:error, "Plan 85 runner must preserve canonical CI and coverage gates"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 85 runner contract is missing or malformed"}
    end
  end

  defp validate_plan85_source(_report_root, _source_root, _metadata, :fixture), do: :ok

  defp validate_plan85_source(report_root, source_root, metadata, :production) do
    subject = Map.get(metadata, "subject_sha")
    tree = Map.get(metadata, "subject_tree")

    with {:ok, repair_bytes} <- File.read(summary_path(report_root, 84)),
         {:ok, repair_summary} <- summary_document(repair_bytes),
         repair <- Map.get(repair_summary.metadata, "formatter_repair_commit"),
         true <- valid_hex?(repair, 40) or {:error, "Plan 85 repair source SHA is malformed"},
         :ok <- validate_committed_source(source_root, subject, tree, @plan79_source_paths),
         {output, 0} <-
           System.cmd("git", ["merge-base", "--is-ancestor", repair, subject],
             cd: source_root,
             stderr_to_stdout: true
           ),
         true <- output == "" or {:error, "Plan 85 ancestry check returned unexpected output"} do
      :ok
    else
      {:error, _message} = error ->
        error

      {_output, _status} ->
        {:error, "Plan 85 source must descend from the Plan 84 formatter repair"}

      _ ->
        {:error, "Plan 85 committed source or tree is unavailable"}
    end
  end

  defp validate_plan85_downstream_absent(root) do
    phase_path = Path.join(root, @phase_dir)

    forbidden = [
      "133-81-SUMMARY.md",
      "133-82-SUMMARY.md",
      "133-83-SUMMARY.md",
      "133-82-CANDIDATE.json",
      "133-85-CANDIDATE.json",
      "133-85-CENSUS-A.json",
      "133-85-CENSUS-B.json",
      "133-85-EVIDENCE-CENSUS.json",
      "133-85-RUN.json"
    ]

    if Enum.any?(forbidden, &File.regular?(Path.join(phase_path, &1))),
      do: {:error, "Plan 85 red result must not create downstream census or candidate output"},
      else: :ok
  end

  defp validate_plan79_branch_mode(root, source_root, plan, expected_status, result_scope) do
    allow_terminal_promotion? = plan == 83 and expected_status == :qualified
    plan80_expected = if plan == 80, do: expected_status, else: :qualified
    plan81_expected = if plan == 81, do: expected_status, else: :qualified
    plan82_expected = if plan == 82, do: expected_status, else: :qualified
    plan83_expected = if plan == 83, do: expected_status, else: :qualified

    with :ok <-
           validate_plan79_prerequisites(
             root,
             source_root,
             result_scope,
             allow_terminal_promotion?
           ),
         :ok <- validate_plan80(root, source_root, plan80_expected, result_scope),
         :ok <- validate_plan79_downstream_absent(root, 80, plan80_expected),
         :ok <-
           validate_plan81(
             root,
             source_root,
             plan81_expected,
             plan >= 81,
             result_scope,
             allow_terminal_promotion?
           ),
         :ok <- validate_plan79_downstream_absent(root, 81, plan81_expected),
         :ok <- validate_plan82(root, source_root, plan82_expected, plan >= 82, result_scope),
         :ok <- validate_plan79_downstream_absent(root, 82, plan82_expected),
         :ok <- validate_plan83(root, source_root, plan83_expected, plan == 83, result_scope),
         :ok <- validate_requirements(root, plan == 83 and expected_status == :qualified) do
      outcome = if expected_status == :qualified, do: "qualified", else: "halted"

      message =
        if result_scope == :fixture do
          if plan == 83 and expected_status == :qualified,
            do: "Plan 83 terminal fixture valid; production acceptance not established",
            else: "Plan #{plan} #{outcome} fixture valid; production acceptance not established"
        else
          if plan == 83 and expected_status == :qualified,
            do: "Plan 83 terminal evidence valid",
            else: "Plan #{plan} #{outcome} evidence valid; requirements remain pending"
        end

      IO.write(message <> "\n")
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan #{plan} branch evidence is missing or malformed"}
    end
  end

  defp plan79_pre_attempt?(root) do
    File.regular?(summary_path(root, 79)) and
      Enum.all?(80..83, &(not File.regular?(summary_path(root, &1))))
  end

  defp validate_plan79_pre_attempt(root, source_root) do
    with :ok <- validate_plan79_prerequisites(root, source_root, :production, false),
         :ok <- validate_plan79_pre_attempt_outputs(root),
         :ok <- validate_requirements(root, false) do
      IO.write("phase 133 Plan 79 pre-attempt state valid; requirements remain pending\n")
      :ok
    end
  end

  defp validate_plan79_pre_attempt_outputs(root) do
    phase_path = Path.join(root, @phase_dir)

    with {:ok, entries} <- File.ls(phase_path) do
      unexpected =
        Enum.filter(entries, fn entry ->
          Regex.match?(~r/^133-(?:80|81|82|83)-/, entry) and
            not String.ends_with?(entry, "-PLAN.md")
        end)

      if unexpected == [],
        do: :ok,
        else: {:error, "Plan 79 pre-attempt state contains downstream output"}
    else
      _ -> {:error, "Plan 79 phase directory is unreadable"}
    end
  end

  defp validate_plan79_prerequisites(root, source_root, result_scope, allow_terminal_promotion?) do
    validator_path =
      Path.join(source_root, "scripts/maintainer/validate_phase_133_reconciliation.exs")

    with {:ok, plan78_bytes} <- File.read(summary_path(root, 78)),
         {:ok, plan78} <- summary_document(plan78_bytes),
         true <- plan78.status == "complete" or {:error, "Plan 78 must remain complete"},
         true <-
           Map.get(plan78.metadata, "requirements-completed") == [] or
             {:error, "Plan 78 must retain zero requirement credit"},
         true <-
           (String.contains?(plan78_bytes, "phase_133_reconciliation_test.exs") and
              String.contains?(plan78_bytes, "92 tests, 0 failures")) or
             {:error, "Plan 78 passing focused reconciliation evidence is missing"},
         {:ok, plan79_bytes} <- File.read(summary_path(root, 79)),
         {:ok, plan79} <- summary_document(plan79_bytes),
         true <- plan79.status == "complete" or {:error, "Plan 79 reconciler must be complete"},
         true <-
           Map.get(plan79.metadata, "requirements-completed") == [] or
             {:error, "Plan 79 must retain zero requirement credit"},
         {:ok, validator_bytes} <- File.read(validator_path),
         true <-
           sha256(validator_bytes) == Map.get(plan79.metadata, "final_validator_sha256") or
             {:error, "Plan 79 final validator SHA differs from the summary"},
         true <-
           (valid_hex?(Map.get(plan79.metadata, "final_source_sha"), 40) and
              valid_hex?(Map.get(plan79.metadata, "final_source_tree"), 40)) or
             {:error, "Plan 79 final validator source SHA/tree is malformed"},
         :ok <- validate_plan79_final_source(source_root, plan79.metadata, result_scope),
         :ok <- validate_plan79_plan64_review(root),
         :ok <-
           if(allow_terminal_promotion? or prior_receipt_unchanged?(root),
             do: :ok,
             else: {:error, "prior canonical receipt changed before Plan 80"}
           ) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 79 requires completed zero-credit Plan 78 and its authorities"}
    end
  end

  defp validate_plan79_final_source(_source_root, _metadata, :fixture), do: :ok

  defp validate_plan79_final_source(source_root, metadata, :production) do
    validate_committed_source(
      source_root,
      Map.get(metadata, "final_source_sha"),
      Map.get(metadata, "final_source_tree"),
      @plan79_source_paths
    )
  end

  defp validate_plan79_plan64_review(root) do
    review_path = Path.join([root, @phase_dir, "133-REVIEW.md"])
    plan64_path = summary_path(root, 64)

    with {:ok, review} <- File.read(review_path),
         {:ok, plan64_bytes} <- File.read(plan64_path),
         {:ok, plan64} <- summary_document(plan64_bytes),
         true <- plan64.status == "complete" or {:error, "Plan 64 repair must remain complete"},
         {:ok, section} <-
           unique_heading_section(review, "## Plan 64 Independent Code Review — Qualified Source"),
         true <-
           sha256(section) == Map.get(plan64.metadata, "review_section_sha256") or
             {:error, "Plan 64 review section digest differs"},
         true <-
           sha256(
             binary_part(
               review,
               0,
               elem(
                 :binary.match(review, "## Plan 64 Independent Code Review — Qualified Source"),
                 0
               )
             )
             |> trim_appended_separator()
           ) ==
             @plan64_review_prefix_sha256 or
             {:error, "Plan 64 authenticated review prefix changed"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "restored Plan 64 review authority is missing or malformed"}
    end
  end

  defp validate_plan80(root, source_root, expected, result_scope) do
    with {:ok, summary_bytes} <- File.read(summary_path(root, 80)),
         {:ok, summary} <- summary_document(summary_bytes),
         expected_status <- if(expected == :qualified, do: "complete", else: "halted"),
         true <-
           summary.status == expected_status or
             {:error, "Plan 80 outcome differs from requested mode"},
         :ok <- validate_plan80_summary(root, summary, expected),
         :ok <-
           validate_plan80_report(root, source_root, summary.metadata, expected, result_scope) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 80 local gate report or summary is missing or malformed"}
    end
  end

  defp validate_plan80_summary(_root, %{metadata: metadata}, :qualified) do
    subject = Map.get(metadata, "subject_sha")
    tree = Map.get(metadata, "subject_tree")

    cond do
      Map.get(metadata, "qualification") not in ["passed", "local-qualified"] ->
        {:error, "Plan 80 qualification must record a passing local result"}

      not valid_hex?(subject, 40) or not valid_hex?(tree, 40) ->
        {:error, "Plan 80 must bind a full source SHA and tree"}

      subject in @plan69_exhausted_subjects or subject == @plan62_subject_sha ->
        {:error, "Plan 80 must use a fresh, non-exhausted source SHA"}

      Map.get(metadata, "requirements-completed") != [] ->
        {:error, "Plan 80 local qualification must grant zero requirement credit"}

      Map.get(metadata, "prior_receipt_sha256") != @plan80_prior_receipt_sha256 ->
        {:error, "Plan 80 must preserve the old canonical receipt digest"}

      Map.get(metadata, "remote_action") != "none" or
          not is_nil(Map.get(metadata, "remote_ref")) ->
        {:error, "Plan 80 local result must not authorize remote actions"}

      true ->
        :ok
    end
  end

  defp validate_plan80_summary(root, %{metadata: metadata}, :halted) do
    subject = Map.get(metadata, "subject_sha")
    tree = Map.get(metadata, "subject_tree")
    report_path = Path.join([root, @phase_dir, @plan80_report_filename])

    cond do
      Map.get(metadata, "qualification") not in ["local-gates-failed", "halted"] ->
        {:error, "Plan 80 halt must retain a failed local-gate qualification"}

      not valid_hex?(subject, 40) or not valid_hex?(tree, 40) ->
        {:error, "Plan 80 halt must bind its exact source SHA and tree"}

      not is_binary(Map.get(metadata, "halt_reason")) or
          String.trim(Map.get(metadata, "halt_reason", "")) == "" ->
        {:error, "Plan 80 halt must retain a bounded halt reason"}

      Map.get(metadata, "requirements-completed") != [] or
          Map.get(metadata, "prior_receipt_sha256") != @plan80_prior_receipt_sha256 ->
        {:error, "Plan 80 halt must retain zero credit and the old receipt"}

      Map.get(metadata, "remote_action") != "none" or not is_nil(Map.get(metadata, "remote_ref")) ->
        {:error, "Plan 80 halt must have no remote action"}

      not File.regular?(report_path) ->
        {:error, "Plan 80 halt must retain its local gate report"}

      true ->
        :ok
    end
  end

  defp validate_plan80_report(root, source_root, metadata, expected, result_scope) do
    path = Path.join([root, @phase_dir, @plan80_report_filename])

    with {:ok, report_bytes} <- File.read(path),
         true <-
           sha256(report_bytes) == Map.get(metadata, "local_gates_sha256") or
             {:error, "Plan 80 local gate report digest differs"},
         {:ok, report} <- Jason.decode(report_bytes),
         subject <- Map.get(metadata, "subject_sha"),
         tree <- Map.get(metadata, "subject_tree"),
         :ok <- validate_plan80_report_outcome(report, subject, tree, expected),
         :ok <- validate_plan80_source(root, source_root, subject, tree, result_scope) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 80 local gate report is malformed"}
    end
  end

  defp validate_plan80_report_outcome(report, subject, tree, :qualified) do
    with true <-
           Map.get(report, "subject_sha") == subject or
             {:error, "Plan 80 report subject SHA differs"},
         :ok <- validate_plan66_local_report(report, subject, tree) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 80 supported local gate report is missing"}
    end
  end

  defp validate_plan80_report_outcome(report, subject, tree, :halted) do
    dependencies = Map.get(report, "dependencies", %{})
    jose = Map.get(report, "jose_preflight", %{})
    ci = Map.get(report, "ci", %{})
    coverage = Map.get(report, "coverage", %{})

    cond do
      Map.get(report, "schema_version") != 1 or Map.get(report, "subject_sha") != subject or
          not valid_hex?(tree, 40) ->
        {:error, "Plan 80 halted report source identity differs"}

      Map.get(dependencies, "exit_code") != 0 and
          (Map.get(jose, "started") == true or Map.get(ci, "started") == true or
             Map.get(coverage, "started") == true) ->
        {:error, "Plan 80 dependency failure has downstream gate output"}

      Map.get(jose, "exit_code") not in [nil, 0] and
          (Map.get(ci, "started") == true or Map.get(coverage, "started") == true) ->
        {:error, "Plan 80 JOSE preflight failure has downstream gate output"}

      Map.get(ci, "exit_code") not in [nil, 0] and Map.get(coverage, "started") == true ->
        {:error, "Plan 80 failed mix ci started coverage"}

      Map.get(coverage, "invocations", 0) not in [0, 1] ->
        {:error, "Plan 80 halt report shows more than one coverage invocation"}

      plan80_report_green?(report) ->
        {:error, "Plan 80 passing local report cannot be called halted"}

      true ->
        :ok
    end
  end

  defp validate_plan80_source(_report_root, source_root, _subject, _tree, :fixture),
    do: validate_plan80_runner_contract(source_root)

  defp validate_plan80_source(report_root, source_root, subject, tree, :production) do
    with :ok <- validate_committed_source(source_root, subject, tree, @plan79_source_paths),
         :ok <- validate_plan80_descends_from_plan79(report_root, source_root, subject),
         {:ok, changed} <-
           git(source_root, ["diff", "--name-only", subject, "--"] ++ @plan79_source_paths),
         {:ok, staged} <-
           git(
             source_root,
             ["diff", "--cached", "--name-only", subject, "--"] ++ @plan79_source_paths
           ),
         true <-
           (changed == "" and staged == "") or
             {:error, "Plan 80 source files changed after the qualified commit"},
         :ok <- validate_plan80_runner_contract(source_root) do
      :ok
    end
  end

  defp validate_plan80_descends_from_plan79(report_root, source_root, subject) do
    with {:ok, plan79_bytes} <- File.read(summary_path(report_root, 79)),
         {:ok, plan79} <- summary_document(plan79_bytes),
         parent when is_binary(parent) <- Map.get(plan79.metadata, "final_source_sha"),
         {output, 0} <-
           System.cmd("git", ["merge-base", "--is-ancestor", parent, subject],
             cd: source_root,
             stderr_to_stdout: true
           ) do
      if output == "" do
        :ok
      else
        {:error, "Plan 80 subject ancestry check returned unexpected output"}
      end
    else
      {_output, _status} -> {:error, "Plan 80 subject does not descend from Plan 79 source"}
      _ -> {:error, "Plan 80 subject ancestry from Plan 79 cannot be established"}
    end
  end

  defp validate_plan80_runner_contract(root) do
    path = Path.join(root, "scripts/maintainer/phase_133_local_gates.sh")

    with {:ok, script} <- File.read(path),
         true <-
           (String.contains?(script, "ASDF_ERLANG_VERSION=27.3.4.15") and
              String.contains?(script, "ASDF_ELIXIR_VERSION=1.17.3-otp-27")) or
             {:error, "Plan 80 runner no longer pins the supported toolchain"},
         true <-
           String.contains?(
             script,
             "runtime does not match the supported Elixir 1.17.3 / OTP 27 toolchain"
           ) or
             {:error, "Plan 80 runner does not verify the supported runtime"},
         true <-
           String.contains?(script, "${worktree}/mix.lock") or
             String.contains?(script, "mix deps.get") or
             {:error, "Plan 80 runner does not use the locked Mix dependency path"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 80 runner contract is missing or malformed"}
    end
  end

  defp plan80_report_green?(report) do
    ci = Map.get(report, "ci", %{})
    coverage = Map.get(report, "coverage", %{})

    Map.get(Map.get(report, "dependencies", %{}), "exit_code") == 0 and
      Map.get(Map.get(report, "jose_preflight", %{}), "exit_code") == 0 and
      Map.get(Map.get(report, "jose_preflight", %{}), "stage_verified") == true and
      Map.get(ci, "exit_code") == 0 and positive_integer?(Map.get(ci, "test_count")) and
      Map.get(ci, "failure_count") == 0 and Map.get(coverage, "started") == true and
      Map.get(coverage, "invocations") == 1 and Map.get(coverage, "exit_code") == 0 and
      positive_integer?(Map.get(coverage, "test_count")) and
      Map.get(coverage, "failure_count") == 0 and
      is_number(Map.get(coverage, "total_percent")) and
      is_number(Map.get(coverage, "floor_percent")) and
      Map.get(coverage, "total_percent") >= Map.get(coverage, "floor_percent")
  end

  defp validate_plan81(
         root,
         _source_root,
         expected,
         required?,
         result_scope,
         allow_terminal_promotion?
       ) do
    if required? do
      with {:ok, plan80_bytes} <- File.read(summary_path(root, 80)),
           {:ok, plan80} <- summary_document(plan80_bytes),
           true <- plan80.status == "complete" or {:error, "Plan 81 requires qualified Plan 80"},
           {:ok, summary_bytes} <- File.read(summary_path(root, 81)),
           {:ok, summary} <- summary_document(summary_bytes),
           expected_status <- if(expected == :qualified, do: "complete", else: "halted"),
           true <-
             summary.status == expected_status or
               {:error, "Plan 81 outcome differs from requested mode"},
           :ok <- validate_plan81_summary(root, plan80.metadata, summary, expected),
           :ok <-
             validate_plan81_authorities(
               root,
               plan80.metadata,
               summary.metadata,
               expected,
               result_scope,
               allow_terminal_promotion?
             ) do
        :ok
      else
        {:error, _message} = error -> error
        _ -> {:error, "Plan 81 census or authority evidence is missing or malformed"}
      end
    else
      absent_summary(root, 81)
    end
  end

  defp validate_plan81_summary(_root, plan80, %{metadata: metadata}, :qualified) do
    subject = Map.get(plan80, "subject_sha")
    tree = Map.get(plan80, "subject_tree")
    expected_ref = "refs/heads/phase-133-evidence-" <> String.slice(subject, 0, 12)

    cond do
      Map.get(metadata, "qualification") not in ["passed", "authority-complete"] ->
        {:error, "Plan 81 qualification must record complete independent authority"}

      Map.get(metadata, "subject_sha") != subject or Map.get(metadata, "subject_tree") != tree ->
        {:error, "Plan 81 source SHA or tree differs from Plan 80"}

      Map.get(metadata, "local_gates_sha256") != Map.get(plan80, "local_gates_sha256") ->
        {:error, "Plan 81 local gate report digest differs from Plan 80"}

      Map.get(metadata, "remote_ref") != expected_ref or
          Map.get(metadata, "remote_lookup_ref") != expected_ref ->
        {:error, "Plan 81 exact full ref differs from the Plan 80 subject"}

      Map.get(metadata, "remote_lookup_command") !=
          "git ls-remote --heads origin #{expected_ref}" ->
        {:error, "Plan 81 exact-ref lookup command differs"}

      Map.get(metadata, "remote_lookup_exit_code") != 0 or
        Map.get(metadata, "remote_lookup_stdout") not in ["", nil] or
          Map.get(metadata, "remote_ref_status") != "absent-read-only-lookup" ->
        {:error, "Plan 81 requires a successful empty exact-ref lookup"}

      Map.get(metadata, "remote_action") != "none" or
          Map.get(metadata, "requirements-completed") != [] ->
        {:error, "Plan 81 authority completion must have zero remote action and zero credit"}

      Map.get(metadata, "prior_receipt_sha256") != @plan80_prior_receipt_sha256 ->
        {:error, "Plan 81 must preserve the old canonical receipt digest"}

      true ->
        :ok
    end
  end

  defp validate_plan81_summary(_root, _plan80, %{metadata: metadata}, :halted) do
    cond do
      Map.get(metadata, "qualification") not in ["authority-failed", "halted"] ->
        {:error, "Plan 81 halt must retain an authority failure"}

      Map.get(metadata, "requirements-completed") != [] or
          Map.get(metadata, "prior_receipt_sha256") != @plan80_prior_receipt_sha256 ->
        {:error, "Plan 81 halt must preserve zero credit and the prior receipt"}

      not is_binary(Map.get(metadata, "halt_reason")) or
          String.trim(Map.get(metadata, "halt_reason", "")) == "" ->
        {:error, "Plan 81 halt must retain a bounded halt reason"}

      Map.get(metadata, "remote_action") != "none" ->
        {:error, "Plan 81 halt cannot authorize a remote action"}

      true ->
        :ok
    end
  end

  defp validate_plan81_authorities(_root, _plan80, _summary, :halted, _scope, _terminal),
    do: :ok

  defp validate_plan81_authorities(
         root,
         plan80,
         summary,
         :qualified,
         result_scope,
         allow_terminal_promotion?
       ) do
    phase = Path.join(root, @phase_dir)

    filenames = %{
      "census_sha256" => "133-EVIDENCE-CENSUS.json",
      "census_a_sha256" => "133-81-CENSUS-A.json",
      "census_b_sha256" => "133-81-CENSUS-B.json",
      "review_report_sha256" => "133-REVIEW.md",
      "security_inventory_sha256" => "133-SECURITY-INVENTORY.json",
      "security_report_sha256" => "133-SECURITY.md"
    }

    subject = Map.get(plan80, "subject_sha")

    with {:ok, files} <- read_and_check_digest_files(phase, filenames, summary),
         census_a when is_binary(census_a) <- Map.get(files, "census_a_sha256"),
         census_b when is_binary(census_b) <- Map.get(files, "census_b_sha256"),
         true <-
           census_a == census_b or
             {:error, "independent Plan 81 census receipts are not byte-identical"},
         {:ok, ledger} <- Jason.decode(Map.fetch!(files, "census_sha256")),
         {:ok, receipt_a} <- Jason.decode(census_a),
         {:ok, receipt_b} <- Jason.decode(census_b),
         true <-
           (evidence_subject(ledger) == subject and evidence_subject(receipt_a) == subject and
              evidence_subject(receipt_b) == subject) or
             {:error, "Plan 81 ledger or census receipt subject differs"},
         :ok <- validate_plan81_census_contract(root, ledger, receipt_a, subject, result_scope),
         :ok <- validate_plan81_authority_documents(root, summary, files, subject),
         :ok <-
           if(allow_terminal_promotion? or prior_receipt_unchanged?(root),
             do: :ok,
             else: {:error, "prior canonical receipt changed before Plan 82"}
           ) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 81 census or authority artifacts are incomplete"}
    end
  end

  defp validate_plan81_census_contract(_root, _ledger, _receipt, _subject, :fixture), do: :ok

  defp validate_plan81_census_contract(root, ledger, receipt, subject, :production) do
    case validate_plan66_census_contract(ledger, receipt, subject, root) do
      :ok -> :ok
      {:error, message} -> {:error, "Plan 81 census contract #{message}"}
    end
  end

  defp validate_plan81_authority_documents(_root, metadata, files, subject) do
    review = Map.fetch!(files, "review_report_sha256")
    inventory = Map.fetch!(files, "security_inventory_sha256")
    security = Map.fetch!(files, "security_report_sha256")

    census_digests =
      Enum.map(~w(census_sha256 census_a_sha256 census_b_sha256), &Map.get(metadata, &1))

    review_heading = "## Plan 81 Independent Code Review — Qualified Source"
    security_heading = "## Plan 81 ASVS L1 Security — Qualified Source"
    nyquist_heading = "## Plan 81 Nyquist Validation — Qualified Source"

    with true <-
           (Enum.all?(census_digests, &valid_hex?(&1, 64)) and
              valid_hex?(Map.get(metadata, "local_gates_sha256"), 64)) or
             {:error, "Plan 81 local-gate or census digests are malformed"},
         true <-
           reports_bind_to?(review, subject, [
             Map.get(metadata, "local_gates_sha256") | census_digests
           ]) or
             {:error, "Plan 81 review is not bound to source and census"},
         true <-
           reports_bind_to?(inventory, subject, [
             Map.get(metadata, "local_gates_sha256") | census_digests
           ]) or
             {:error, "Plan 81 security inventory is not bound to source and census"},
         true <-
           reports_bind_to?(security, subject, [
             Map.get(metadata, "local_gates_sha256") | census_digests
           ]) or
             {:error, "Plan 81 security report is not bound to source and census"},
         :ok <-
           validate_plan66_authority_section(review, review_heading, metadata, subject, :review),
         :ok <-
           validate_plan66_authority_section(
             security,
             security_heading,
             metadata,
             subject,
             :security
           ),
         :ok <-
           validate_plan66_authority_section(review, nyquist_heading, metadata, subject, :nyquist),
         {:ok, inventory_document} <- Jason.decode(inventory),
         true <-
           Map.get(
             inventory_document,
             "audited_subject",
             Map.get(inventory_document, "subject_sha")
           ) == subject or
             {:error, "Plan 81 security inventory subject differs"},
         true <-
           Map.get(metadata, "review_section_sha256") ==
             plan66_section_digest(review, review_heading) or
             {:error, "Plan 81 review section digest is stale"},
         true <-
           Map.get(metadata, "security_section_sha256") ==
             plan66_section_digest(security, security_heading) or
             {:error, "Plan 81 security section digest is stale"},
         true <-
           Map.get(metadata, "nyquist_section_sha256") ==
             plan66_section_digest(review, nyquist_heading) or
             {:error, "Plan 81 Nyquist section digest is stale"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 81 independent review, security, or Nyquist evidence is incomplete"}
    end
  end

  defp validate_plan82(root, source_root, expected, required?, result_scope) do
    if required? do
      with {:ok, plan81_bytes} <- File.read(summary_path(root, 81)),
           {:ok, plan81} <- summary_document(plan81_bytes),
           true <-
             plan81.status == "complete" or
               {:error, "Plan 82 requires completed Plan 81 authority"},
           {:ok, summary_bytes} <- File.read(summary_path(root, 82)),
           {:ok, summary} <- summary_document(summary_bytes),
           expected_status <- if(expected == :qualified, do: "complete", else: "halted"),
           true <-
             summary.status == expected_status or
               {:error, "Plan 82 outcome differs from requested mode"},
           :ok <- validate_plan82_summary(root, plan81.metadata, summary, expected),
           :ok <-
             validate_plan82_candidate(
               root,
               source_root,
               plan81.metadata,
               summary.metadata,
               expected,
               result_scope
             ) do
        :ok
      else
        {:error, _message} = error -> error
        _ -> {:error, "Plan 82 authorization or candidate evidence is missing or malformed"}
      end
    else
      absent_summary(root, 82)
    end
  end

  defp validate_plan82_summary(_root, plan81, %{metadata: metadata}, :qualified) do
    subject = Map.get(plan81, "subject_sha")
    ref = Map.get(plan81, "remote_ref")
    run_id = Map.get(metadata, "run_id")
    prior_runs = Map.get(metadata, "pre_dispatch_run_ids")

    cond do
      Map.get(metadata, "qualification") not in ["remote-candidate-verified", "owned-candidate"] ->
        {:error, "Plan 82 qualification must describe one verified owned candidate"}

      Map.get(metadata, "decision") != "authorize" or
        Map.get(metadata, "authorized_sha") != subject or
          Map.get(metadata, "authorized_ref") != ref ->
        {:error, "Plan 82 one-shot decision is not bound to Plan 81's literal SHA/ref"}

      Map.get(metadata, "remote_ref") != ref or Map.get(metadata, "published_ref") != ref ->
        {:error, "Plan 82 publication differs from the authorized full ref"}

      Map.get(metadata, "publication_count") != 1 or Map.get(metadata, "dispatch_count") != 1 ->
        {:error, "Plan 82 must record exactly one publication and one dispatch"}

      not positive_integer?(run_id) or not positive_integer?(Map.get(metadata, "run_attempt")) ->
        {:error, "Plan 82 owned run ID and attempt are malformed"}

      not is_list(prior_runs) or run_id in prior_runs ->
        {:error, "Plan 82 run is not newly owned by the one-shot dispatch"}

      Map.get(metadata, "incident_state") != "unchanged" or
        not valid_hex?(Map.get(metadata, "incident_before_sha256"), 64) or
          Map.get(metadata, "incident_before_sha256") !=
            Map.get(metadata, "incident_after_sha256") ->
        {:error, "Plan 82 diagnostic run changed the scheduled incident state"}

      Map.get(metadata, "requirements-completed") != [] or
          Map.get(metadata, "prior_receipt_sha256") != @plan80_prior_receipt_sha256 ->
        {:error, "Plan 82 candidate must preserve zero credit and the old canonical receipt"}

      true ->
        :ok
    end
  end

  defp validate_plan82_summary(_root, _plan81, %{metadata: metadata}, :halted) do
    cond do
      Map.get(metadata, "qualification") not in [
        "remote-attempt-failed",
        "authorization-stopped",
        "halted"
      ] ->
        {:error, "Plan 82 halt must retain a stopped or failed one-shot outcome"}

      Map.get(metadata, "requirements-completed") != [] or
          Map.get(metadata, "prior_receipt_sha256") != @plan80_prior_receipt_sha256 ->
        {:error, "Plan 82 halt must preserve zero credit and the old receipt"}

      Map.get(metadata, "decision") not in ["authorize", "stop"] ->
        {:error, "Plan 82 halt must record the separate decision"}

      Map.get(metadata, "decision") == "stop" and
          (Map.get(metadata, "publication_count", 0) != 0 or
             Map.get(metadata, "dispatch_count", 0) != 0) ->
        {:error, "Plan 82 stop decision cannot publish or dispatch"}

      not is_binary(Map.get(metadata, "halt_reason")) or
          String.trim(Map.get(metadata, "halt_reason", "")) == "" ->
        {:error, "Plan 82 halt must retain a bounded halt reason"}

      true ->
        :ok
    end
  end

  defp validate_plan82_candidate(root, _source_root, _plan81, _metadata, :halted, _scope) do
    candidate = Path.join([root, @phase_dir, "133-82-CANDIDATE.json"])

    if File.regular?(candidate),
      do: {:error, "Plan 82 halted outcome must not retain an unqualified candidate"},
      else:
        if(File.regular?(summary_path(root, 83)),
          do: {:error, "Plan 83 must remain absent after a halted Plan 82"},
          else: :ok
        )
  end

  defp validate_plan82_candidate(root, source_root, plan81, metadata, :qualified, result_scope) do
    path = Path.join([root, @phase_dir, "133-82-CANDIDATE.json"])

    with {:ok, bytes} <- File.read(path),
         true <-
           sha256(bytes) == Map.get(metadata, "candidate_sha256") or
             {:error, "Plan 82 candidate digest differs"},
         {:ok, candidate} <- Jason.decode(bytes),
         true <-
           Map.get(candidate, "subject_sha") == Map.get(plan81, "subject_sha") or
             {:error, "Plan 82 candidate subject differs from Plan 81"},
         true <-
           compatible_receipt_ref?(
             Map.get(plan81, "remote_ref"),
             Map.get(candidate, "remote_ref")
           ) or
             {:error, "Plan 82 candidate ref differs from Plan 81"},
         true <-
           (to_string(Map.get(candidate, "run_id")) == to_string(Map.get(metadata, "run_id")) and
              to_string(Map.get(candidate, "run_attempt")) ==
                to_string(Map.get(metadata, "run_attempt"))) or
             {:error, "Plan 82 candidate run ID or attempt differs"},
         true <-
           plan82_strict_verdict_passed?(candidate) or
             {:error, "Plan 82 candidate lacks a strict passing verdict"},
         true <-
           plan82_receipt_contract?(
             candidate,
             Map.get(plan81, "subject_sha"),
             Map.get(plan81, "remote_ref"),
             Map.get(metadata, "run_id"),
             Map.get(metadata, "run_attempt")
           ) or
             {:error, "Plan 82 candidate jobs, supported PLT, preflight, or run identity differs"},
         true <-
           Map.get(candidate, "incident_snapshot_before") ==
             Map.get(candidate, "incident_snapshot_after") or
             {:error, "Plan 82 candidate records a changed incident"},
         :ok <- verify_plan82_receipt_live(source_root, candidate, path, result_scope) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 82 candidate is missing or does not match its owned run"}
    end
  end

  defp verify_plan82_receipt_live(_source_root, _candidate, _path, :fixture), do: :ok

  defp verify_plan82_receipt_live(source_root, candidate, path, :production) do
    verify_receipt_live(source_root, candidate, path)
  end

  defp validate_plan83(root, source_root, expected, required?, result_scope) do
    if required? do
      with {:ok, plan82_bytes} <- File.read(summary_path(root, 82)),
           {:ok, plan82} <- summary_document(plan82_bytes),
           true <-
             plan82.status == "complete" or
               {:error, "Plan 83 requires one completed Plan 82 candidate"},
           {:ok, summary_bytes} <- File.read(summary_path(root, 83)),
           {:ok, summary} <- summary_document(summary_bytes),
           expected_status <- if(expected == :qualified, do: "complete", else: "halted"),
           true <-
             summary.status == expected_status or
               {:error, "Plan 83 outcome differs from requested mode"},
           :ok <- validate_plan83_summary(root, plan82.metadata, summary, expected),
           :ok <-
             validate_plan83_receipt(
               root,
               source_root,
               plan82.metadata,
               summary.metadata,
               expected,
               result_scope
             ) do
        :ok
      else
        {:error, _message} = error -> error
        _ -> {:error, "Plan 83 terminal receipt or summary is missing or malformed"}
      end
    else
      absent_summary(root, 83)
    end
  end

  defp validate_plan83_summary(_root, plan82, %{metadata: metadata}, :qualified) do
    terminal_ids = Enum.sort(@plan83_requirement_ids)
    completed = Map.get(metadata, "requirements-completed")

    cond do
      Map.get(metadata, "qualification") != "verified" or
          Map.get(metadata, "terminal_automation") != "passed" ->
        {:error, "Plan 83 terminal automation must be verified and passed"}

      Map.get(metadata, "subject_sha") != Map.get(plan82, "authorized_sha") or
        Map.get(metadata, "remote_ref") != Map.get(plan82, "remote_ref") or
        to_string(Map.get(metadata, "run_id")) != to_string(Map.get(plan82, "run_id")) or
          to_string(Map.get(metadata, "run_attempt")) != to_string(Map.get(plan82, "run_attempt")) ->
        {:error, "Plan 83 terminal tuple differs from its owned Plan 82 candidate"}

      not is_list(completed) or Enum.sort(completed) != terminal_ids ->
        {:error, "Plan 83 terminal summary must complete exactly the five Phase 133 requirements"}

      true ->
        :ok
    end
  end

  defp validate_plan83_summary(_root, _plan82, %{metadata: metadata}, :halted) do
    cond do
      Map.get(metadata, "requirements-completed") != [] or
          Map.get(metadata, "prior_receipt_sha256") != @plan80_prior_receipt_sha256 ->
        {:error, "Plan 83 halt must restore the prior receipt and zero requirement credit"}

      Map.get(metadata, "terminal_automation") not in ["halted", "failed"] ->
        {:error, "Plan 83 halt must retain its terminal automation result"}

      true ->
        :ok
    end
  end

  defp validate_plan83_receipt(root, _source_root, _plan82, _metadata, :halted, _scope) do
    candidate_path = Path.join([root, @phase_dir, "133-82-CANDIDATE.json"])
    canonical_path = Path.join([root, @phase_dir, "133-NIGHTLY-EVIDENCE.json"])

    cond do
      not prior_receipt_unchanged?(root) ->
        {:error, "Plan 83 halt changed the canonical receipt"}

      File.regular?(candidate_path) and File.regular?(canonical_path) ->
        :ok

      true ->
        {:error, "Plan 83 halt must preserve Plan 82 candidate without changing prior receipt"}
    end
  end

  defp validate_plan83_receipt(root, source_root, plan82, metadata, :qualified, result_scope) do
    candidate_path = Path.join([root, @phase_dir, "133-82-CANDIDATE.json"])
    canonical_path = Path.join([root, @phase_dir, "133-NIGHTLY-EVIDENCE.json"])

    with {:ok, candidate} <- File.read(candidate_path),
         {:ok, canonical} <- File.read(canonical_path),
         true <-
           candidate == canonical or
             {:error, "Plan 83 canonical receipt is not byte-identical to the candidate"},
         true <-
           sha256(canonical) == Map.get(metadata, "receipt_sha256") or
             {:error, "Plan 83 canonical receipt digest differs"},
         true <-
           sha256(canonical) == Map.get(metadata, "candidate_sha256") or
             {:error, "Plan 83 promoted receipt differs from the Plan 82 candidate digest"},
         {:ok, receipt} <- Jason.decode(canonical),
         true <-
           canonical_receipt_shape?(receipt) or
             {:error, "Plan 83 promoted receipt schema is incomplete"},
         true <-
           Map.get(receipt, "subject_sha") == Map.get(plan82, "authorized_sha") or
             {:error, "Plan 83 receipt subject differs from Plan 82 authorization"},
         true <-
           compatible_receipt_ref?(Map.get(plan82, "remote_ref"), Map.get(receipt, "remote_ref")) or
             {:error, "Plan 83 receipt ref differs from Plan 82 authorization"},
         true <-
           (to_string(Map.get(receipt, "run_id")) == to_string(Map.get(plan82, "run_id")) and
              to_string(Map.get(receipt, "run_attempt")) ==
                to_string(Map.get(plan82, "run_attempt"))) or
             {:error, "Plan 83 receipt run tuple differs from the owned Plan 82 run"},
         true <-
           plan82_receipt_contract?(
             receipt,
             Map.get(plan82, "authorized_sha"),
             Map.get(plan82, "remote_ref"),
             Map.get(plan82, "run_id"),
             Map.get(plan82, "run_attempt")
           ) or
             {:error, "Plan 83 promoted receipt jobs, supported PLT, or preflight differs"},
         :ok <- verify_plan82_receipt_live(source_root, receipt, canonical_path, result_scope) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 83 promoted receipt is missing or malformed"}
    end
  end

  defp validate_plan79_downstream_absent(root, 80, :halted) do
    if Enum.any?([81, 82, 83], &File.regular?(summary_path(root, &1))) or
         File.regular?(Path.join([root, @phase_dir, "133-82-CANDIDATE.json"])) do
      {:error, "Plan 80 halt must not create downstream census, candidate, or terminal outputs"}
    else
      :ok
    end
  end

  defp validate_plan79_downstream_absent(root, 81, :halted) do
    if Enum.any?([82, 83], &File.regular?(summary_path(root, &1))) or
         File.regular?(Path.join([root, @phase_dir, "133-82-CANDIDATE.json"])) do
      {:error, "Plan 81 halt must not create an owned run, candidate, or terminal output"}
    else
      :ok
    end
  end

  defp validate_plan79_downstream_absent(root, 82, :halted) do
    if File.regular?(summary_path(root, 83)),
      do: {:error, "Plan 82 halt must block Plan 83"},
      else: :ok
  end

  defp validate_plan79_downstream_absent(_root, _plan, _expected), do: :ok

  defp absent_summary(root, plan) do
    if File.regular?(summary_path(root, plan)),
      do: {:error, "Plan #{plan} must remain absent before the prior lifecycle stage completes"},
      else: :ok
  end

  defp verify_receipt_live(root, candidate, path, script \\ "scripts/ci/verify_nightly_run.sh") do
    args = [
      script,
      "verify-receipt",
      "--repo",
      "szTheory/rindle",
      "--workflow",
      "nightly.yml",
      "--ref",
      Map.get(candidate, "remote_ref", ""),
      "--expected-sha",
      Map.get(candidate, "subject_sha", ""),
      "--receipt",
      path
    ]

    case System.cmd("bash", args, cd: root, stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {_output, _status} -> {:error, "live read-only verify-receipt failed"}
    end
  end

  defp plan82_strict_verdict_passed?(candidate) do
    verdict = Map.get(candidate, "strict_verdict")

    is_map(verdict) and Map.get(verdict, "summary_job") == "Nightly Summary" and
      Map.get(verdict, "verdict") == "green"
  end

  defp plan82_receipt_contract?(receipt, subject, authorized_ref, run_id, run_attempt) do
    jobs = Map.get(receipt, "jobs", [])
    job_names = MapSet.new(Enum.map(jobs, &Map.get(&1, "name")))

    required_jobs = [
      "Compat Matrix (1.17, 27)",
      "Dialyzer",
      "GCS Soak (real bucket)",
      "Nightly Summary"
    ]

    package_job? =
      Enum.any?(job_names, &(is_binary(&1) and String.starts_with?(&1, "Package Consumer")))

    dialyzer = Map.get(receipt, "dialyzer", %{})
    fresh = Map.get(dialyzer, "fresh", %{})
    restored = Map.get(dialyzer, "restored", %{})
    preflight = Map.get(receipt, "preflight", %{})

    jobs_pass? =
      Enum.all?(jobs, fn job ->
        Map.get(job, "status") == "completed" and
          Map.get(job, "conclusion") in ["success", "skipped"]
      end) and
        Enum.all?(required_jobs, &MapSet.member?(job_names, &1)) and package_job? and
        Enum.all?(
          required_jobs ++
            Enum.filter(MapSet.to_list(job_names), fn name ->
              is_binary(name) and String.starts_with?(name, "Package Consumer")
            end),
          fn name ->
            Enum.any?(jobs, fn job ->
              Map.get(job, "name") == name and Map.get(job, "conclusion") == "success"
            end)
          end
        )

    canonical_receipt_shape?(receipt) and Map.get(receipt, "conclusion") == "success" and
      Map.get(receipt, "event") == "workflow_dispatch" and
      Map.get(receipt, "repository") == "szTheory/rindle" and
      Map.get(receipt, "workflow") == "nightly.yml" and
      Map.get(receipt, "subject_sha") == subject and
      compatible_receipt_ref?(authorized_ref, Map.get(receipt, "remote_ref")) and
      to_string(Map.get(receipt, "run_id")) == to_string(run_id) and
      to_string(Map.get(receipt, "run_attempt")) == to_string(run_attempt) and
      plan82_strict_verdict_passed?(receipt) and jobs_pass? and
      Map.get(fresh, "status") == "pass" and positive_integer?(Map.get(fresh, "builds")) and
      Map.get(restored, "status") == "pass" and positive_integer?(Map.get(restored, "analyses")) and
      Map.get(preflight, "status") == "pass" and Map.get(preflight, "subject_sha") == subject and
      compatible_receipt_ref?(authorized_ref, Map.get(preflight, "remote_ref")) and
      is_list(Map.get(receipt, "incident_snapshot_before")) and
      is_list(Map.get(receipt, "incident_snapshot_after"))
  rescue
    _ -> false
  end

  defp compatible_receipt_ref?(authorized_ref, receipt_ref)
       when is_binary(authorized_ref) and is_binary(receipt_ref) do
    authorized_ref == receipt_ref or authorized_ref == "refs/heads/" <> receipt_ref
  end

  defp compatible_receipt_ref?(_authorized_ref, _receipt_ref), do: false

  defp validate_plan69_mode(root, source_root, expected_status, result_scope) do
    expected_summary_status = if expected_status == :qualified, do: "complete", else: "halted"

    with :ok <- validate_plan69_prerequisite(root, source_root, result_scope),
         {:ok, summary_bytes} <- File.read(summary_path(root, 69)),
         {:ok, summary} <- summary_document(summary_bytes),
         true <-
           summary.status == expected_summary_status or
             {:error, "outcome does not match --expect-plan69-#{expected_status}"},
         :ok <-
           validate_plan69_outcome(root, source_root, summary, expected_status, result_scope),
         :ok <- validate_plan69_blocked_plans(root),
         :ok <- validate_requirements(root, false) do
      outcome = if expected_status == :qualified, do: "qualified", else: "halted"

      message =
        if result_scope == :fixture,
          do: "Plan 69 #{outcome} fixture valid; production acceptance not established",
          else: "Plan 69 #{outcome} evidence valid; requirements remain pending"

      IO.write(message <> "\n")
      :ok
    else
      {:error, message} ->
        if String.starts_with?(message, "Plan "),
          do: {:error, message},
          else: {:error, "Plan 69 #{message}"}

      _ ->
        {:error, "Plan 69 special-mode evidence is missing or malformed"}
    end
  end

  defp validate_plan69_prerequisite(_root, _source_root, :fixture), do: :ok

  defp validate_plan69_prerequisite(root, source_root, :production) do
    with :ok <- validate_plan65_receipt(root),
         :ok <- validate_plan69_plan66_halt(root),
         true <-
           Path.expand(root) == Path.expand(source_root) or
             {:error, "production report root must be the source checkout"} do
      :ok
    end
  end

  defp validate_plan69_plan66_halt(root) do
    path = summary_path(root, 66)
    report_path = Path.join([root, @phase_dir, @plan66_report_filename])
    tracked_paths = [Path.relative_to(path, root), Path.relative_to(report_path, root)]

    with :ok <- validate_plan69_committed_history(root, tracked_paths),
         {:ok, summary_bytes} <- File.read(path),
         {:ok, summary} <- summary_document(summary_bytes),
         true <- summary.status == "halted" or {:error, "Plan 66 must remain halted"},
         true <-
           Map.get(summary.metadata, "qualification") == "local-gates-failed" or
             {:error, "Plan 66 must preserve its original local-gates failure"},
         true <-
           Map.get(summary.metadata, "subject_sha") == @plan69_exhausted_subject or
             {:error, "Plan 66 historical subject differs"},
         true <-
           Map.get(summary.metadata, "requirements-completed") == [] or
             {:error, "Plan 66 must retain zero requirement credit"},
         true <-
           Map.get(summary.metadata, "remote_action") == "none" or
             {:error, "Plan 66 must retain remote_action: none"},
         true <-
           Map.get(summary.metadata, "prior_receipt_sha256") == @plan55_prior_receipt_sha256 or
             {:error, "Plan 66 prior receipt digest differs"},
         {:ok, report_bytes} <- File.read(report_path),
         true <-
           digest_matches?(summary.metadata, "local_gates_sha256", report_bytes) or
             {:error, "Plan 66 local gate report digest is stale"},
         {:ok, report} <- Jason.decode(report_bytes),
         :ok <- validate_plan69_plan66_report(report, summary.metadata) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 66 immutable halt evidence is malformed"}
    end
  end

  defp validate_plan69_committed_history(root, paths) do
    with {:ok, _} <- git(root, ["diff", "--quiet", "HEAD", "--"] ++ paths),
         {:ok, _} <- git(root, ["diff", "--cached", "--quiet", "HEAD", "--"] ++ paths) do
      :ok
    else
      _ -> {:error, "Plan 66 committed summary or local gate report has changed"}
    end
  end

  defp validate_plan69_plan66_report(report, metadata) do
    diagnostics = Map.get(report, "diagnostics", %{})
    source = Map.get(diagnostics, "source_header", %{})
    staged = Map.get(diagnostics, "staged_header", %{})
    jose = Map.get(report, "jose_preflight", %{})
    ci = Map.get(report, "ci", %{})

    with :ok <- validate_plan66_red_report(report, metadata),
         true <-
           (Map.get(jose, "exit_code") == 0 and Map.get(jose, "stage_verified") == true) or
             {:error, "Plan 66 JOSE preflight must remain passing"},
         true <-
           (Map.get(ci, "started") == true and Map.get(ci, "exit_code") != 0) or
             {:error, "Plan 66 must preserve its original CI failure"},
         true <-
           Map.get(source, "status") == "present" or
             {:error, "Plan 66 source JOSE header must remain present"},
         true <-
           Map.get(staged, "status") in ["absent", "dangling"] or
             {:error, "Plan 66 must retain its missing staged JOSE header"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 66 original JOSE staging failure differs"}
    end
  end

  defp validate_plan69_blocked_plans(root) do
    phase = Path.join(root, @phase_dir)

    forbidden = [
      summary_path(root, 67),
      summary_path(root, 68),
      Path.join(phase, "133-67-CANDIDATE.json")
    ]

    cond do
      Enum.any?(forbidden, &File.regular?/1) ->
        {:error, "Plans 67 and 68 must remain blocked without summaries or a candidate"}

      not plan69_dependency?(Path.join(phase, "133-67-PLAN.md"), 69) ->
        {:error, "Plan 67 must remain blocked on Plan 69"}

      not plan69_dependency?(Path.join(phase, "133-68-PLAN.md"), 67) ->
        {:error, "Plan 68 must remain blocked on Plan 67"}

      true ->
        :ok
    end
  end

  defp plan69_dependency?(path, dependency) do
    case File.read(path) do
      {:ok, bytes} ->
        Regex.match?(
          ~r/^depends_on:\s*\[133-#{dependency}\]$/m,
          bytes
        )

      _ ->
        false
    end
  end

  defp validate_plan69_outcome(root, source_root, %{status: "halted"} = document, :halted, scope),
    do: validate_plan69_halted(root, source_root, document, scope)

  defp validate_plan69_outcome(
         root,
         source_root,
         %{status: "complete"} = document,
         :qualified,
         scope
       ),
       do: validate_plan69_qualified(root, source_root, document, scope)

  defp validate_plan69_outcome(_root, _source_root, _document, _expected, _scope),
    do: {:error, "status and qualification do not match the requested Plan 69 outcome"}

  defp validate_plan69_halted(root, source_root, %{metadata: metadata} = document, scope) do
    case Map.get(metadata, "qualification") do
      "local-gates-failed" ->
        validate_plan69_local_gate_halt(root, source_root, document, scope)

      "local-authority-failed" ->
        validate_plan69_authority_halt(root, source_root, document, scope)

      _ ->
        {:error, "halt qualification must identify a local gate or authority failure"}
    end
  end

  defp validate_plan69_local_gate_halt(
         root,
         source_root,
         %{metadata: metadata, body: body},
         scope
       ) do
    report_path = Path.join([root, @phase_dir, @plan69_report_filename])
    reason = Map.get(metadata, "halt_reason")
    subject = Map.get(metadata, "subject_sha")
    tree = Map.get(metadata, "subject_tree")

    with true <-
           Map.get(metadata, "qualification") == "local-gates-failed" or
             {:error, "halt qualification must record a local-gates failure"},
         true <-
           Map.get(metadata, "requirements-completed") == [] or
             {:error, "must grant zero requirement credit"},
         true <-
           Map.get(metadata, "prior_receipt_sha256") == @plan55_prior_receipt_sha256 or
             {:error, "canonical prior receipt digest differs"},
         true <-
           prior_receipt_unchanged?(root) or {:error, "canonical prior receipt bytes differ"},
         true <-
           Map.get(metadata, "remote_action") == "none" or
             {:error, "must record remote_action: none"},
         true <-
           Map.get(metadata, "census") == "not_run" or
             {:error, "halt must leave census not_run"},
         true <-
           Map.get(metadata, "remote_lookup") in [nil, "not_run"] or
             {:error, "halt must not perform remote lookup"},
         true <-
           Map.get(metadata, "remote_ref") in [nil, "none"] or
             {:error, "halt must not expose a qualified ref handoff"},
         true <-
           Enum.all?(
             ~w(authorized_ref published_ref candidate_sha256),
             &(not Map.has_key?(metadata, &1))
           ) or
             {:error, "halt must not expose authorization or candidate metadata"},
         true <-
           (is_binary(reason) and String.trim(reason) != "" and byte_size(reason) <= 512) or
             {:error, "halt requires a bounded halt_reason"},
         true <-
           String.contains?(body, reason) or
             {:error, "halt body must retain the exact halt_reason"},
         :ok <- validate_plan69_source_binding(source_root, subject, tree, scope),
         {:ok, report_bytes} <- File.read(report_path),
         true <-
           digest_matches?(metadata, "local_gates_sha256", report_bytes) or
             {:error, "halted local gate report digest is missing or stale"},
         {:ok, report} <- Jason.decode(report_bytes),
         :ok <- validate_plan69_red_report(report, metadata),
         true <-
           Map.get(metadata, "halt_stage") == "local-gates" or
             {:error, "halt must record halt_stage: local-gates"},
         true <-
           Map.get(metadata, "halt_gate") == plan69_red_gate(report) or
             {:error, "halt_gate differs from the first failed local gate"},
         true <-
           not File.regular?(Path.join([root, @phase_dir, "133-69-CENSUS-A.json"])) or
             {:error, "halted Plan 69 must stop before census"},
         true <-
           not File.regular?(Path.join([root, @phase_dir, "133-69-CENSUS-B.json"])) or
             {:error, "halted Plan 69 must stop before census"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "halted Plan 69 evidence is malformed"}
    end
  end

  defp validate_plan69_authority_halt(
         root,
         source_root,
         %{metadata: metadata, body: body},
         scope
       ) do
    report_path = Path.join([root, @phase_dir, @plan69_report_filename])
    reason = Map.get(metadata, "halt_reason")
    diagnostic = Map.get(metadata, "halt_diagnostic")
    subject = Map.get(metadata, "subject_sha")
    tree = Map.get(metadata, "subject_tree")
    authority = Map.get(metadata, "halt_authority")

    with true <-
           Map.get(metadata, "qualification") == "local-authority-failed" or
             {:error, "halt qualification must record a local authority failure"},
         true <-
           Map.get(metadata, "requirements-completed") == [] or
             {:error, "must grant zero requirement credit"},
         true <-
           Map.get(metadata, "prior_receipt_sha256") == @plan55_prior_receipt_sha256 or
             {:error, "canonical prior receipt digest differs"},
         true <-
           prior_receipt_unchanged?(root) or {:error, "canonical prior receipt bytes differ"},
         true <-
           Map.get(metadata, "remote_action") == "none" or
             {:error, "must record remote_action: none"},
         true <-
           Map.get(metadata, "remote_ref") in [nil, "none"] or
             {:error, "authority halt must not expose a qualified ref handoff"},
         true <-
           Enum.all?(
             ~w(authorized_ref published_ref candidate_sha256),
             &(not Map.has_key?(metadata, &1))
           ) or
             {:error, "authority halt must not expose authorization or candidate metadata"},
         true <-
           Map.get(metadata, "halt_stage") == "local-authority" or
             {:error, "authority halt must record halt_stage: local-authority"},
         true <-
           authority in ["census", "review", "security", "nyquist", "live-truth", "remote-lookup"] or
             {:error, "authority halt must name the failed authority"},
         true <-
           is_integer(Map.get(metadata, "authority_exit_code")) or
             {:error, "authority halt must record its exit code"},
         true <-
           (is_binary(diagnostic) and byte_size(diagnostic) in 1..512) or
             {:error, "authority halt requires a bounded diagnostic"},
         true <-
           (is_binary(reason) and byte_size(reason) in 1..512 and
              String.contains?(reason, diagnostic)) or
             {:error, "halt reason must retain its authority diagnostic"},
         true <-
           String.contains?(body, reason) or
             {:error, "halt body must retain the exact halt_reason"},
         :ok <- validate_plan69_source_binding(source_root, subject, tree, scope),
         {:ok, report_bytes} <- File.read(report_path),
         true <-
           digest_matches?(metadata, "local_gates_sha256", report_bytes) or
             {:error, "halted local gate report digest is missing or stale"},
         {:ok, report} <- Jason.decode(report_bytes),
         :ok <- validate_plan69_green_report(report, subject, tree),
         :ok <- validate_plan69_authority_failure(root, metadata, authority, subject, scope) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "halted Plan 69 authority evidence is malformed"}
    end
  end

  defp validate_plan69_authority_failure(root, metadata, "remote-lookup", subject, scope) do
    expected_ref = "refs/heads/phase-133-evidence-#{String.slice(subject, 0, 12)}"
    exit_code = Map.get(metadata, "remote_lookup_exit_code")
    stdout = Map.get(metadata, "remote_lookup_stdout")
    status = Map.get(metadata, "remote_ref_status")

    with true <-
           Map.get(metadata, "remote_lookup_ref") == expected_ref or
             {:error, "authority halt lookup ref differs from the exact subject ref"},
         true <-
           Map.get(metadata, "remote_lookup_command") ==
             "git ls-remote --heads origin #{expected_ref}" or
             {:error, "authority halt lookup command differs"},
         true <-
           Map.get(metadata, "authority_exit_code") == exit_code or
             {:error, "authority exit differs from the read-only lookup result"},
         true <-
           (is_binary(stdout) and byte_size(stdout) <= 1024) or
             {:error, "authority halt lookup output is missing or unbounded"},
         true <-
           (exit_code != 0 and status == "lookup-failed" and stdout == "") or
             (exit_code == 0 and status == "present-read-only-lookup" and
                String.contains?(stdout, expected_ref)) or
             {:error, "read-only lookup did not prove an absent ref or a safe halt"},
         :ok <- validate_plan69_bound_artifacts(root, metadata, subject, scope) do
      :ok
    end
  end

  defp validate_plan69_authority_failure(_root, metadata, _authority, _subject, _scope) do
    with true <-
           Map.get(metadata, "authority_exit_code") != 0 or
             {:error, "failed authority must have a nonzero exit code"},
         true <-
           Map.get(metadata, "remote_lookup") in [nil, "not_run"] or
             {:error, "remote lookup must not run before local authorities pass"},
         true <-
           Map.get(metadata, "remote_lookup_ref") in [nil, "none"] or
             {:error, "remote lookup ref must remain unset before local authorities pass"} do
      :ok
    end
  end

  defp validate_plan69_red_report(report, metadata) do
    dependencies = Map.get(report, "dependencies", %{})
    jose = Map.get(report, "jose_preflight", %{})
    ci = Map.get(report, "ci", %{})
    coverage = Map.get(report, "coverage", %{})
    gate = plan69_red_gate(report)

    with true <-
           Map.get(report, "schema_version") == 1 or {:error, "local gate report schema differs"},
         true <-
           Map.get(report, "subject_sha") == Map.get(metadata, "subject_sha") or
             {:error, "halted local report subject differs"},
         true <-
           Map.get(dependencies, "command") == "mix deps.get" or
             {:error, "local dependency command differs"},
         true <-
           Map.get(jose, "command") ==
             "mix run --no-start --no-deps-check --no-compile -e <focused JOSE structure and Elixir compile>" or
             {:error, "local JOSE preflight command differs"},
         true <- Map.get(ci, "command") == "mix ci" or {:error, "local CI command differs"},
         true <-
           Map.get(coverage, "command") == "mix coveralls.multiple --type local --type json" or
             {:error, "local coverage command differs"},
         true <-
           gate in ["dependencies", "jose-preflight", "ci", "coverage"] or
             {:error, "halted report does not contain a failing local gate"},
         :ok <- validate_plan69_red_order(report, gate),
         :ok <- validate_plan69_failure_diagnostics(report) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "halted Plan 69 local gate report is malformed"}
    end
  end

  defp plan69_red_gate(report) do
    dependencies = Map.get(report, "dependencies", %{})
    jose = Map.get(report, "jose_preflight", %{})
    ci = Map.get(report, "ci", %{})
    coverage = Map.get(report, "coverage", %{})

    cond do
      Map.get(dependencies, "exit_code") != 0 ->
        "dependencies"

      Map.get(jose, "started") != true or Map.get(jose, "exit_code") != 0 or
          Map.get(jose, "stage_verified") != true ->
        "jose-preflight"

      Map.get(ci, "started") != true or Map.get(ci, "exit_code") != 0 or
        not positive_integer?(Map.get(ci, "test_count")) or Map.get(ci, "failure_count") != 0 ->
        "ci"

      plan66_coverage_failed?(coverage) ->
        "coverage"

      true ->
        nil
    end
  end

  defp validate_plan69_red_order(report, "dependencies") do
    jose = Map.get(report, "jose_preflight", %{})
    ci = Map.get(report, "ci", %{})
    coverage = Map.get(report, "coverage", %{})

    if Map.get(jose, "started") != true and Map.get(ci, "started") != true and
         Map.get(coverage, "started") != true and Map.get(coverage, "invocations") == 0,
       do: :ok,
       else: {:error, "halted Plan 69 must stop after failed dependency retrieval"}
  end

  defp validate_plan69_red_order(report, "jose-preflight") do
    ci = Map.get(report, "ci", %{})
    coverage = Map.get(report, "coverage", %{})

    if Map.get(ci, "started") != true and Map.get(coverage, "started") != true and
         Map.get(coverage, "invocations") == 0,
       do: :ok,
       else: {:error, "halted Plan 69 must stop after failed JOSE preflight"}
  end

  defp validate_plan69_red_order(report, "ci") do
    coverage = Map.get(report, "coverage", %{})

    if Map.get(coverage, "started") != true and Map.get(coverage, "invocations") == 0,
      do: :ok,
      else: {:error, "halted Plan 69 must not start coverage after failed CI"}
  end

  defp validate_plan69_red_order(report, "coverage") do
    coverage = Map.get(report, "coverage", %{})

    if Map.get(coverage, "started") == true and Map.get(coverage, "invocations") == 1,
      do: :ok,
      else: {:error, "halted Plan 69 must retain exactly one failed coverage attempt"}
  end

  defp validate_plan69_failure_diagnostics(report) do
    ci = Map.get(report, "ci", %{})

    if Map.get(ci, "started") != true do
      :ok
    else
      diagnostics = Map.get(report, "diagnostics", %{})
      transitions = Map.get(diagnostics, "transitions", %{})
      after_ci = Map.get(transitions, "after_ci", %{})
      source = Map.get(after_ci, "source_header", %{})
      staged = Map.get(after_ci, "staged_header", %{})
      include = Map.get(after_ci, "staged_include", %{})
      app = Map.get(after_ci, "app_lookup_path", %{})

      with true <-
             plan69_observation_valid?(source, "deps/jose/include/jose_jwt.hrl") or
               {:error, "source path snapshot is malformed or unsafe"},
           true <-
             plan69_observation_valid?(staged, "_build/test/lib/jose/include/jose_jwt.hrl") or
               {:error, "staged path snapshot is malformed or unsafe"},
           true <-
             plan69_observation_valid?(include, "_build/test/lib/jose/include") or
               {:error, "staged include snapshot is malformed or unsafe"},
           true <-
             plan69_app_observation_valid?(app) or
               {:error, "JOSE app lookup snapshot is malformed or unsafe"} do
        :ok
      else
        {:error, _message} = error -> error
        _ -> {:error, "failure-point path diagnostics are missing or unsafe"}
      end
    end
  end

  defp plan69_observation_valid?(snapshot, repo_path) do
    statuses = [
      "present",
      "absent",
      "dangling",
      "unreadable",
      "outside_worktree",
      "not_attempted"
    ]

    errors = [nil, "ENOENT", "EACCES", "ELOOP", "ENOTDIR", "OTHER"]
    directory_statuses = ["not_checked", "present", "not_directory", "missing", "unreadable"]
    resolved_path = Map.get(snapshot, "resolved_path")
    lexical_path = Map.get(snapshot, "lexical_target_path")
    symlink_text = Map.get(snapshot, "symlink_text")
    digest = Map.get(snapshot, "sha256")
    lexical_inside = Map.get(snapshot, "lexical_target_inside_worktree")

    Map.get(snapshot, "repo_relative_path") == repo_path and
      Map.get(snapshot, "status") in statuses and
      is_boolean(Map.get(snapshot, "target_inside_worktree")) and
      is_boolean(Map.get(snapshot, "target_exists")) and
      lexical_inside in [nil, true, false] and
      Map.get(snapshot, "target_error_code") in errors and
      Map.get(snapshot, "target_directory_status") in directory_statuses and
      plan69_snapshot_state_valid?(snapshot) and
      plan69_safe_path_value?(resolved_path) and plan69_safe_path_value?(lexical_path) and
      plan69_safe_symlink_text?(symlink_text, lexical_inside) and
      (is_nil(digest) or valid_hex?(digest, 64))
  end

  defp plan69_snapshot_state_valid?(snapshot) do
    status = Map.get(snapshot, "status")

    case status do
      "present" ->
        Map.get(snapshot, "target_exists") == true and
          Map.get(snapshot, "target_inside_worktree") == true

      "outside_worktree" ->
        Map.get(snapshot, "target_exists") == true and
          Map.get(snapshot, "target_inside_worktree") == false and
          Map.get(snapshot, "resolved_path") == "<external-path-redacted>"

      "dangling" ->
        Map.get(snapshot, "file_type") == "symlink" and
          Map.get(snapshot, "target_exists") == false

      "absent" ->
        Map.get(snapshot, "target_exists") == false

      _ ->
        true
    end
  end

  defp plan69_app_observation_valid?(snapshot) do
    Map.get(snapshot, "status") in [
      "present",
      "absent",
      "unreadable",
      "outside_worktree",
      "not_attempted",
      "unresolved"
    ] and
      Map.get(snapshot, "repo_relative_path") in ["_build/test/lib/jose", nil] and
      is_boolean(Map.get(snapshot, "target_inside_worktree")) and
      is_boolean(Map.get(snapshot, "target_exists")) and
      plan69_snapshot_state_valid?(snapshot) and
      Map.get(snapshot, "target_error_code") in [
        nil,
        "ENOENT",
        "EACCES",
        "ELOOP",
        "ENOTDIR",
        "OTHER"
      ] and
      Map.get(snapshot, "target_directory_status") in [
        "not_checked",
        "present",
        "not_directory",
        "missing",
        "unreadable"
      ] and
      plan69_safe_path_value?(Map.get(snapshot, "resolved_path")) and
      plan69_safe_path_value?(Map.get(snapshot, "lexical_target_path")) and
      plan69_safe_symlink_text?(
        Map.get(snapshot, "symlink_text"),
        Map.get(snapshot, "lexical_target_inside_worktree")
      )
  end

  defp plan69_safe_path_value?(nil), do: true
  defp plan69_safe_path_value?("<external-path-redacted>"), do: true

  defp plan69_safe_path_value?("<worktree>" <> relative) do
    ".." not in String.split(relative, "/")
  end

  defp plan69_safe_path_value?(_), do: false

  defp plan69_safe_symlink_text?(nil, _lexical_inside), do: true
  defp plan69_safe_symlink_text?("<absolute-target-redacted>", false), do: true
  defp plan69_safe_symlink_text?("<external-target-redacted>", false), do: true

  defp plan69_safe_symlink_text?(text, true) when is_binary(text) do
    byte_size(text) <= 512 and
      Regex.match?(~r/\A[A-Za-z0-9._\/-]+\z/, text) and Path.type(text) == :relative
  end

  defp plan69_safe_symlink_text?(_text, _lexical_inside), do: false

  defp validate_plan69_qualified(root, source_root, %{metadata: metadata, body: body}, scope) do
    subject = Map.get(metadata, "subject_sha")
    tree = Map.get(metadata, "subject_tree")
    expected_ref = "refs/heads/phase-133-evidence-#{String.slice(to_string(subject), 0, 12)}"
    report_path = Path.join([root, @phase_dir, @plan69_report_filename])

    with true <-
           Map.get(metadata, "qualification") == "passed" or
             {:error, "qualification must be passed"},
         true <-
           Map.get(metadata, "remote_ref") == expected_ref or
             {:error, "full ref is not derived from the qualified subject"},
         true <-
           Map.get(metadata, "remote_lookup_ref") == expected_ref or
             {:error, "saved read-only lookup ref differs"},
         true <-
           Map.get(metadata, "remote_lookup_command") ==
             "git ls-remote --heads origin #{expected_ref}" or
             {:error, "saved read-only lookup command differs"},
         true <-
           Map.get(metadata, "remote_lookup_exit_code") == 0 or
             {:error, "saved read-only lookup exit code is not zero"},
         true <-
           Map.get(metadata, "remote_lookup_stdout") == "" or
             {:error, "saved read-only lookup stdout is not empty"},
         true <-
           Map.get(metadata, "remote_ref_status") == "absent-read-only-lookup" or
             {:error, "must record the successful absent-ref lookup"},
         true <-
           Map.get(metadata, "remote_action") == "none" or
             {:error, "must record remote_action: none"},
         true <-
           Map.get(metadata, "requirements-completed") == [] or
             {:error, "must grant zero requirement credit"},
         true <-
           Map.get(metadata, "census") == "passed" or
             {:error, "exact-subject census must pass"},
         true <-
           (Map.get(metadata, "prior_receipt_sha256") == @plan55_prior_receipt_sha256 and
              prior_receipt_unchanged?(root)) or
             {:error, "must preserve the prior canonical receipt"},
         :ok <- validate_plan69_source_binding(source_root, subject, tree, scope),
         {:ok, report_bytes} <- File.read(report_path),
         true <-
           digest_matches?(metadata, "local_gates_sha256", report_bytes) or
             {:error, "local gate report digest is missing or stale"},
         {:ok, report} <- Jason.decode(report_bytes),
         :ok <- validate_plan69_green_report(report, subject, tree),
         :ok <- validate_plan69_bound_artifacts(root, metadata, subject, scope),
         true <-
           String.contains?(body, "zero requirement credit") or
             {:error, "qualified summary must explicitly preserve zero requirement credit"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "qualified Plan 69 metadata or bound artifacts are malformed"}
    end
  end

  defp validate_plan69_green_report(report, subject, tree) do
    with :ok <- validate_plan66_local_report(report, subject, tree),
         diagnostics <- Map.get(report, "diagnostics", %{}),
         transitions <- Map.get(diagnostics, "transitions", %{}),
         preflight <- Map.get(transitions, "after_preflight", %{}),
         after_ci <- Map.get(transitions, "after_ci", %{}),
         source <- Map.get(after_ci, "source_header", %{}),
         staged <- Map.get(after_ci, "staged_header", %{}),
         include <- Map.get(after_ci, "staged_include", %{}),
         app <- Map.get(after_ci, "app_lookup_path", %{}),
         true <-
           valid_plan66_header?(source, "deps/jose/include/jose_jwt.hrl") or
             {:error, "failure-point source JOSE header is not valid"},
         true <-
           valid_plan66_header?(staged, "_build/test/lib/jose/include/jose_jwt.hrl") or
             {:error, "failure-point staged JOSE header is not valid"},
         true <-
           Map.get(source, "sha256") == Map.get(staged, "sha256") or
             {:error, "failure-point JOSE header hashes differ"},
         true <-
           plan69_include_valid?(include) or
             {:error, "failure-point JOSE include link is outside or unresolved"},
         true <-
           plan69_app_lookup_valid?(app) or
             {:error, "failure-point JOSE app lookup is outside or unresolved"},
         true <-
           plan69_app_lookup_valid?(Map.get(diagnostics, "app_lookup_path", %{})) or
             {:error, "top-level JOSE app lookup differs from the failure-point lookup"},
         true <-
           plan69_transition_headers_valid?(preflight) or
             {:error, "JOSE preflight source and stage snapshots differ"},
         true <-
           Map.get(diagnostics, "diagnosis_branch") ==
             "resolved-record-extract-path-or-permissions" or
             {:error, "successful report diagnosis does not resolve the compiled JOSE path"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "qualified Plan 69 report lacks failure-point JOSE diagnostics"}
    end
  end

  defp plan69_transition_headers_valid?(transition) do
    source = Map.get(transition, "source_header", %{})
    staged = Map.get(transition, "staged_header", %{})
    include = Map.get(transition, "staged_include", %{})

    valid_plan66_header?(source, "deps/jose/include/jose_jwt.hrl") and
      valid_plan66_header?(staged, "_build/test/lib/jose/include/jose_jwt.hrl") and
      Map.get(source, "sha256") == Map.get(staged, "sha256") and
      plan69_include_valid?(include)
  end

  defp plan69_include_valid?(include) do
    Map.get(include, "status") == "present" and Map.get(include, "file_type") == "symlink" and
      Map.get(include, "target_inside_worktree") == true and
      Map.get(include, "resolved_path") == "<worktree>/deps/jose/include" and
      Map.get(include, "target_directory_status") == "present" and
      Map.get(include, "target_error_code") == nil and Map.get(include, "target_exists") == true and
      Map.get(include, "symlink_text") == "../../../../deps/jose/include"
  end

  defp plan69_app_lookup_valid?(app) do
    Map.get(app, "status") == "present" and Map.get(app, "target_inside_worktree") == true and
      Map.get(app, "resolved_path") == "<worktree>/_build/test/lib/jose" and
      Map.get(app, "target_directory_status") == "present"
  end

  defp validate_plan69_source_binding(_source_root, subject, _tree, :fixture)
       when subject == @plan69_exhausted_subject,
       do: {:error, "subject reuses the consumed Plan 133-66 SHA"}

  defp validate_plan69_source_binding(_source_root, subject, tree, :fixture) do
    if valid_hex?(subject, 40) and valid_hex?(tree, 40) and
         subject not in @plan69_exhausted_subjects do
      :ok
    else
      {:error, "subject SHA or tree is malformed or exhausted"}
    end
  end

  defp validate_plan69_source_binding(source_root, subject, tree, :production) do
    with true <-
           (valid_hex?(subject, 40) and valid_hex?(tree, 40)) or
             {:error, "subject SHA or tree is malformed"},
         true <-
           subject not in @plan69_exhausted_subjects or
             {:error, "subject reuses an exhausted or diagnostic-only Plan 133 SHA"},
         :ok <- validate_committed_source(source_root, subject, tree, @plan69_source_paths),
         {:ok, repair_ancestor} <-
           git(source_root, [
             "merge-base",
             "--is-ancestor",
             "e63d2c1222763732df57fdc74757720776659a44",
             subject
           ]),
         true <-
           repair_ancestor == "" or {:error, "qualification subject omits the JOSE path repair"},
         {:ok, head} <- git(source_root, ["rev-parse", "HEAD"]),
         {:ok, ancestor} <- git(source_root, ["merge-base", "--is-ancestor", subject, head]),
         true <- ancestor == "" or {:error, "qualified subject is not on the active history"},
         :ok <- validate_plan69_clean_source(source_root, subject) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 69 subject or committed source binding is malformed"}
    end
  end

  defp validate_plan69_clean_source(root, subject) do
    paths = @plan69_source_paths

    with {:ok, _} <- git(root, ["diff", "--quiet", subject, "--"] ++ paths),
         {:ok, _} <- git(root, ["diff", "--cached", "--quiet", subject, "--"] ++ paths) do
      :ok
    else
      _ -> {:error, "Plan 69 source files changed after the qualification commit"}
    end
  end

  defp validate_plan69_bound_artifacts(root, metadata, subject, :fixture) do
    phase = Path.join(root, @phase_dir)

    filenames = %{
      "census_sha256" => "133-EVIDENCE-CENSUS.json",
      "census_a_sha256" => "133-69-CENSUS-A.json",
      "census_b_sha256" => "133-69-CENSUS-B.json",
      "review_report_sha256" => "133-REVIEW.md",
      "security_inventory_sha256" => "133-SECURITY-INVENTORY.json",
      "security_report_sha256" => "133-SECURITY.md"
    }

    with {:ok, files} <- read_and_check_digest_files(phase, filenames, metadata),
         census_a when is_binary(census_a) <- Map.get(files, "census_a_sha256"),
         census_b when is_binary(census_b) <- Map.get(files, "census_b_sha256"),
         true <- census_a == census_b or {:error, "independent Plan 69 census receipts differ"},
         {:ok, ledger} <- Jason.decode(Map.fetch!(files, "census_sha256")),
         {:ok, receipt_a} <- Jason.decode(census_a),
         {:ok, receipt_b} <- Jason.decode(census_b),
         true <-
           (evidence_subject(ledger) == subject and evidence_subject(receipt_a) == subject and
              evidence_subject(receipt_b) == subject) or
             {:error, "Plan 69 fixture census subject differs"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 69 fixture census or authority artifacts are missing or malformed"}
    end
  end

  defp validate_plan69_bound_artifacts(root, metadata, subject, :production) do
    phase = Path.join(root, @phase_dir)

    filenames = %{
      "census_sha256" => "133-EVIDENCE-CENSUS.json",
      "census_a_sha256" => "133-69-CENSUS-A.json",
      "census_b_sha256" => "133-69-CENSUS-B.json",
      "review_report_sha256" => "133-REVIEW.md",
      "security_inventory_sha256" => "133-SECURITY-INVENTORY.json",
      "security_report_sha256" => "133-SECURITY.md"
    }

    with {:ok, files} <- read_and_check_digest_files(phase, filenames, metadata),
         census_a when is_binary(census_a) <- Map.get(files, "census_a_sha256"),
         census_b when is_binary(census_b) <- Map.get(files, "census_b_sha256"),
         true <- census_a == census_b or {:error, "independent Plan 69 census receipts differ"},
         {:ok, ledger} <- Jason.decode(Map.fetch!(files, "census_sha256")),
         true <-
           evidence_subject(ledger) == subject or
             {:error, "Plan 69 evidence census subject differs"},
         {:ok, receipt_a} <- Jason.decode(census_a),
         {:ok, receipt_b} <- Jason.decode(census_b),
         true <-
           (evidence_subject(receipt_a) == subject and evidence_subject(receipt_b) == subject) or
             {:error, "Plan 69 independent census receipt subject differs"},
         :ok <- validate_plan66_census_contract(ledger, receipt_a, subject, root),
         :ok <- validate_plan69_authorities(root, metadata, files, subject),
         true <- prior_receipt_unchanged?(root) or {:error, "prior canonical receipt changed"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 69 census or source authority files are missing or malformed"}
    end
  end

  defp validate_plan69_authorities(root, metadata, files, subject) do
    review = Map.fetch!(files, "review_report_sha256")
    inventory = Map.fetch!(files, "security_inventory_sha256")
    security = Map.fetch!(files, "security_report_sha256")

    census_digests =
      Enum.map(["census_sha256", "census_a_sha256", "census_b_sha256"], &Map.get(metadata, &1))

    review_heading = "## Plan 69 Independent Code Review — Qualified Source"
    security_heading = "## Plan 69 ASVS L1 Security — Qualified Source"
    nyquist_heading = "## Plan 69 Nyquist Validation — Qualified Source"

    with true <-
           Enum.all?(census_digests, &valid_hex?(&1, 64)) or
             {:error, "Plan 69 census digest bindings are malformed"},
         true <-
           valid_hex?(Map.get(metadata, "local_gates_sha256"), 64) or
             {:error, "Plan 69 local gate digest is malformed"},
         true <-
           reports_bind_to?(review, subject, [
             Map.get(metadata, "local_gates_sha256") | census_digests
           ]) or
             {:error, "Plan 69 code review is not bound to subject and census"},
         true <-
           reports_bind_to?(inventory, subject, [
             Map.get(metadata, "local_gates_sha256") | census_digests
           ]) or
             {:error, "Plan 69 security inventory is not bound to subject and census"},
         true <-
           reports_bind_to?(security, subject, [
             Map.get(metadata, "local_gates_sha256") | census_digests
           ]) or
             {:error, "Plan 69 security signoff is not bound to subject and census"},
         :ok <-
           validate_plan66_authority_section(review, review_heading, metadata, subject, :review),
         :ok <-
           validate_plan66_authority_section(
             security,
             security_heading,
             metadata,
             subject,
             :security
           ),
         :ok <-
           validate_plan66_authority_section(review, nyquist_heading, metadata, subject, :nyquist),
         {:ok, inventory_document} <- Jason.decode(inventory),
         true <-
           Map.get(
             inventory_document,
             "audited_subject",
             Map.get(inventory_document, "subject_sha")
           ) == subject or
             {:error, "Plan 69 security inventory subject differs"},
         {:ok, security_frontmatter, _} <- bounded_frontmatter(security),
         {:ok, security_metadata} <- decode_frontmatter(security_frontmatter),
         true <-
           (Map.get(security_metadata, "verdict") == "SECURED" and
              Map.get(security_metadata, "threats_open") == 0) or
             {:error, "Plan 69 security authority has open threats or lacks SECURED verdict"},
         true <-
           Map.get(metadata, "review_section_sha256") ==
             plan66_section_digest(review, review_heading) or
             {:error, "Plan 69 review section digest is stale"},
         true <-
           Map.get(metadata, "security_section_sha256") ==
             plan66_section_digest(security, security_heading) or
             {:error, "Plan 69 security section digest is stale"},
         true <-
           Map.get(metadata, "nyquist_section_sha256") ==
             plan66_section_digest(review, nyquist_heading) or
             {:error, "Plan 69 Nyquist section digest is stale"},
         true <- prior_receipt_unchanged?(root) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 69 independent review, security, or Nyquist evidence is incomplete"}
    end
  end

  defp validate_plan65_mode(root, source_root, result_scope) do
    fixture? = result_scope == :fixture

    with :ok <- validate_plan65_receipt(root),
         :ok <- validate_plan65_prerequisite(root, source_root, result_scope),
         {:ok, summary_bytes} <- File.read(summary_path(root, 65)),
         {:ok, summary} <- summary_document(summary_bytes),
         :ok <- validate_plan65_source(root, source_root, summary),
         :ok <- validate_plan65_pending_boundary(root),
         :ok <- validate_requirements(root, false) do
      message =
        if fixture?,
          do: "Plan 65 source fixture valid; production acceptance not established",
          else: "Plan 65 committed source evidence valid; requirements remain pending"

      IO.write(message <> "\n")
      :ok
    else
      {:error, message} ->
        if String.starts_with?(message, "Plan "),
          do: {:error, message},
          else: {:error, "Plan 65 #{message}"}

      _ ->
        {:error, "Plan 65 source handoff is missing or malformed"}
    end
  end

  defp validate_plan65_prerequisite(root, source_root, result_scope) do
    validate_plan64_mode(root, source_root, :repair, result_scope)
  end

  defp validate_plan65_receipt(root) do
    if prior_receipt_unchanged?(root),
      do: :ok,
      else: {:error, "canonical prior receipt bytes differ"}
  end

  defp validate_plan65_source(
         root,
         source_root,
         %{status: "complete", metadata: metadata} = document
       ) do
    source_sha = Map.get(metadata, "source_sha")
    source_tree = Map.get(metadata, "source_tree")

    with true <-
           Map.get(metadata, "qualification") == "source-proven" or
             {:error, "qualification must be source-proven"},
         true <-
           valid_hex?(source_sha, 40) or {:error, "source SHA is not full lowercase hex"},
         true <- source_sha not in @plan66_source_reused or {:error, "source SHA must be fresh"},
         true <-
           Map.get(metadata, "requirements-completed") == [] or
             {:error, "must grant zero requirement credit"},
         true <-
           Map.get(metadata, "focused_tests_exit_code") == 0 or
             {:error, "focused tests did not pass"},
         true <-
           Map.get(metadata, "remote_action") == "none" or
             {:error, "must record remote_action: none"},
         true <-
           Map.get(metadata, "local_gates") == "not_run" or
             {:error, "must leave local gates not_run"},
         true <-
           Map.get(metadata, "census") == "not_run" or {:error, "must leave census not_run"},
         true <-
           Map.get(metadata, "prior_receipt_sha256") == @plan55_prior_receipt_sha256 or
             {:error, "canonical prior receipt digest differs"},
         true <-
           prior_receipt_unchanged?(root) or {:error, "canonical prior receipt bytes differ"},
         {:ok, plan64_bytes} <- File.read(summary_path(root, 64)),
         {:ok, plan64} <- summary_document(plan64_bytes),
         true <-
           Map.get(metadata, "plan64_source_sha") ==
             Map.get(plan64.metadata, "final_source_sha") or
             {:error, "Plan 64 repair source binding differs"},
         true <-
           Map.get(plan64.metadata, "final_source_sha") ==
             "321fc8409c825101bf6080348a7205f680cc7ffe" or
             {:error, "Plan 64 repair source differs from its immutable qualification"},
         :ok <-
           validate_committed_source(source_root, source_sha, source_tree, @plan65_source_paths),
         {:ok, ancestor_check} <-
           git(source_root, [
             "merge-base",
             "--is-ancestor",
             Map.get(plan64.metadata, "final_source_sha"),
             source_sha
           ]),
         true <- ancestor_check == "" or {:error, "Plan 64 repair source is not an ancestor"},
         {:ok, head} <- git(source_root, ["rev-parse", "HEAD"]),
         {:ok, source_is_current_ancestor} <-
           git(source_root, ["merge-base", "--is-ancestor", source_sha, head]),
         true <-
           source_is_current_ancestor == "" or {:error, "source SHA is not on the active history"},
         :ok <-
           validate_plan65_source_range(
             root,
             source_root,
             Map.get(plan64.metadata, "final_source_sha"),
             source_sha
           ),
         :ok <- validate_plan65_clean_source(root, source_root),
         true <-
           not String.contains?(document.body, "requirements-completed") or
             {:error, "source handoff body must not add requirement credit"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "status, source identity, or source-only boundary differs"}
    end
  end

  defp validate_plan65_source(_root, _source_root, _document),
    do: {:error, "must record a complete source-proven handoff"}

  defp validate_plan65_clean_source(report_root, source_root) do
    if Path.expand(report_root) != Path.expand(source_root) do
      :ok
    else
      with {:ok, _} <-
             git(source_root, ["diff", "--quiet", "HEAD", "--"] ++ @plan65_source_paths),
           {:ok, _} <-
             git(
               source_root,
               ["diff", "--cached", "--quiet", "HEAD", "--"] ++ @plan65_source_paths
             ) do
        :ok
      else
        _ -> {:error, "source reconciler or focused suites changed after commit"}
      end
    end
  end

  defp validate_plan65_source_range(report_root, source_root, plan64_sha, source_sha) do
    if Path.expand(report_root) != Path.expand(source_root) do
      :ok
    else
      with {:ok, changed_bytes} <-
             git(source_root, ["diff", "--name-only", "#{plan64_sha}..#{source_sha}"]),
           changed <- String.split(changed_bytes, "\n", trim: true),
           missing <- Enum.reject(@plan65_source_paths, &(&1 in changed)),
           true <-
             missing == [] or
               {:error, "Plan 65 source commit omits declared files since Plan 64"} do
        :ok
      else
        {:error, _message} = error -> error
        _ -> {:error, "Plan 65 source commit range is malformed"}
      end
    end
  end

  defp validate_plan65_pending_boundary(root) do
    later = [66, 67, 68]

    case Enum.find(later, &File.regular?(summary_path(root, &1))) do
      nil ->
        candidate = Path.join([root, @phase_dir, "133-67-CANDIDATE.json"])

        if File.regular?(candidate),
          do: {:error, "Plan 65 source mode cannot accept a Plan 67 candidate"},
          else: :ok

      plan ->
        {:error, "Plan 65 source mode cannot accept a Plan #{plan} outcome"}
    end
  end

  defp validate_plan66_mode(root, source_root, expected_status, result_scope) do
    expected_summary_status = if expected_status == :qualified, do: "complete", else: "halted"

    with :ok <- validate_plan65_receipt(root),
         :ok <- validate_plan65_prerequisite(root, source_root, result_scope),
         {:ok, summary_bytes} <- File.read(summary_path(root, 66)),
         {:ok, summary} <- summary_document(summary_bytes),
         true <-
           summary.status == expected_summary_status or
             {:error, "outcome does not match --expect-plan66-#{expected_status}"},
         :ok <- validate_plan66_outcome(root, source_root, summary, expected_status),
         :ok <- validate_plan66_blocked_plans(root),
         :ok <- validate_requirements(root, false) do
      outcome = if expected_status == :qualified, do: "qualified", else: "halted"

      message =
        if result_scope == :fixture,
          do: "Plan 66 #{outcome} fixture valid; production acceptance not established",
          else: "Plan 66 #{outcome} evidence valid; requirements remain pending"

      IO.write(message <> "\n")
      :ok
    else
      {:error, message} ->
        if String.starts_with?(message, "Plan "),
          do: {:error, message},
          else: {:error, "Plan 66 #{message}"}

      _ ->
        {:error, "Plan 66 special-mode evidence is missing or malformed"}
    end
  end

  defp validate_plan66_blocked_plans(root) do
    blocked = [56, 60, 61, 67, 68]

    case Enum.find(blocked, &File.regular?(summary_path(root, &1))) do
      nil ->
        if File.regular?(Path.join([root, @phase_dir, "133-67-CANDIDATE.json"])),
          do: {:error, "Plan 67 candidate is forbidden before local qualification"},
          else: :ok

      67 ->
        {:error, "Plan 67 cannot be summarized before explicit authorization"}

      68 ->
        {:error, "Plan 68 cannot be summarized before Plan 67"}

      plan ->
        {:error, "Plan #{plan} remains blocked and cannot be handed off"}
    end
  end

  defp validate_plan66_outcome(root, source_root, %{status: "complete"} = document, :qualified),
    do: validate_plan66_qualified(root, source_root, document)

  defp validate_plan66_outcome(root, source_root, %{status: "halted"} = document, :halted),
    do: validate_plan66_halted(root, source_root, document)

  defp validate_plan66_outcome(_root, _source_root, _document, _expected),
    do: {:error, "status and qualification do not match the requested Plan 66 outcome"}

  defp validate_plan66_halted(root, source_root, %{metadata: metadata, body: body}) do
    report_path = Path.join([root, @phase_dir, @plan66_report_filename])
    reason = Map.get(metadata, "halt_reason")

    with :ok <- validate_plan66_source_binding(root, source_root, metadata),
         true <-
           Map.get(metadata, "qualification") in ["local-gates-failed", "local-authority-failed"] or
             {:error,
              "halt qualification must record an original local gate or authority failure"},
         true <-
           Map.get(metadata, "requirements-completed") == [] or
             {:error, "must grant zero requirement credit"},
         true <-
           Map.get(metadata, "prior_receipt_sha256") == @plan55_prior_receipt_sha256 or
             {:error, "canonical prior receipt digest differs"},
         true <-
           prior_receipt_unchanged?(root) or {:error, "canonical prior receipt bytes differ"},
         true <-
           Map.get(metadata, "remote_action") == "none" or
             {:error, "must record remote_action: none"},
         true <-
           Map.get(metadata, "remote_ref") in [nil, "none"] or
             {:error, "halt must not expose a qualified ref handoff"},
         true <-
           Enum.all?(
             ~w(authorized_ref authorized_subject_sha published_ref candidate_sha256),
             &(not Map.has_key?(metadata, &1))
           ) or
             {:error, "halt must not expose authorization or candidate metadata"},
         true <-
           (is_binary(reason) and String.trim(reason) != "" and byte_size(reason) <= 512) or
             {:error, "halt requires a bounded halt_reason"},
         true <-
           String.contains?(body, reason) or
             {:error, "halt body must retain the exact halt_reason"},
         {:ok, report_bytes} <- File.read(report_path),
         true <-
           digest_matches?(metadata, "local_gates_sha256", report_bytes) or
             {:error, "halted local gate report digest is missing or stale"},
         {:ok, report} <- Jason.decode(report_bytes),
         :ok <- validate_plan66_halt_cause(root, report, metadata),
         true <-
           not File.regular?(Path.join([root, @phase_dir, "133-67-CANDIDATE.json"])) or
             {:error, "Plan 67 candidate is forbidden after a halted Plan 66"},
         true <-
           Map.get(metadata, "remote_lookup") in [nil, "not_run"] or
             {:error, "halted Plan 66 must not perform remote lookup"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "halted Plan 66 evidence is malformed"}
    end
  end

  defp validate_plan66_halt_cause(root, report, metadata) do
    case Map.get(metadata, "qualification") do
      "local-gates-failed" ->
        with :ok <- validate_plan66_red_report(report, metadata),
             true <-
               Map.get(metadata, "halt_stage") == "local-gates" or
                 {:error, "halt must record halt_stage: local-gates"},
             true <-
               Map.get(metadata, "halt_gate") == plan66_red_gate(report) or
                 {:error, "halt_gate differs from the first failed local gate"},
             true <-
               Map.get(metadata, "census") == "not_run" or
                 {:error, "halted Plan 66 red gate must leave census not_run"},
             true <-
               not File.regular?(Path.join([root, @phase_dir, "133-66-CENSUS-A.json"])) or
                 {:error, "halted Plan 66 red gate must not start census"},
             true <-
               not File.regular?(Path.join([root, @phase_dir, "133-66-CENSUS-B.json"])) or
                 {:error, "halted Plan 66 red gate must not start census"} do
          :ok
        else
          {:error, _message} = error -> error
          _ -> {:error, "halted Plan 66 red gate evidence is malformed"}
        end

      "local-authority-failed" ->
        subject = Map.get(metadata, "subject_sha")
        tree = Map.get(metadata, "subject_tree")

        with :ok <- validate_plan66_local_report(report, subject, tree),
             authority when authority in ["census", "review", "security", "nyquist", "live-truth"] <-
               Map.get(metadata, "halt_authority"),
             diagnostic when is_binary(diagnostic) and byte_size(diagnostic) in 1..512 <-
               Map.get(metadata, "halt_diagnostic"),
             true <-
               String.contains?(to_string(Map.get(metadata, "halt_reason")), diagnostic) or
                 {:error, "halt reason must preserve the authority failure diagnostic"},
             true <-
               (is_integer(Map.get(metadata, "authority_exit_code")) and
                  Map.get(metadata, "authority_exit_code") != 0) or
                 {:error, "halt must record the failed authority exit"} do
          :ok
        else
          {:error, _message} = error -> error
          _ -> {:error, "halted Plan 66 authority failure is not documented"}
        end

      _ ->
        {:error, "halt qualification must name a local gate or authority failure"}
    end
  end

  defp validate_plan66_red_report(report, metadata) do
    dependencies = Map.get(report, "dependencies", %{})
    jose = Map.get(report, "jose_preflight", %{})
    ci = Map.get(report, "ci", %{})
    coverage = Map.get(report, "coverage", %{})
    dependency_failed? = Map.get(dependencies, "exit_code") != 0
    jose_failed? = Map.get(jose, "exit_code") != 0 or Map.get(jose, "stage_verified") != true

    ci_failed? =
      Map.get(ci, "exit_code") != 0 or not positive_integer?(Map.get(ci, "test_count")) or
        Map.get(ci, "failure_count") not in [0, nil]

    coverage_failed? = plan66_coverage_failed?(coverage)

    cond do
      Map.get(report, "schema_version") != 1 or
          Map.get(dependencies, "command") != "mix deps.get" ->
        {:error, "halted local gate report schema differs"}

      Map.get(report, "subject_sha") != Map.get(metadata, "subject_sha") ->
        {:error, "halted local report subject differs"}

      Map.get(jose, "command") !=
          "mix run --no-start --no-deps-check --no-compile -e <focused JOSE structure and Elixir compile>" ->
        {:error, "halted local report JOSE command differs"}

      Map.get(ci, "command") != "mix ci" or
          Map.get(coverage, "command") !=
            "mix coveralls.multiple --type local --type json" ->
        {:error, "halted local report gate commands differ"}

      not (dependency_failed? or jose_failed? or ci_failed? or coverage_failed?) ->
        {:error, "halted Plan 66 must retain an original red local gate"}

      ci_failed? and
          (Map.get(coverage, "invocations") != 0 or Map.get(coverage, "started") == true) ->
        {:error, "halted Plan 66 must not start coverage after failed CI"}

      dependency_failed? and
          (Map.get(jose, "started") == true or Map.get(ci, "started") == true or
             Map.get(coverage, "invocations") != 0) ->
        {:error, "halted Plan 66 must stop after failed dependency retrieval"}

      jose_failed? and
          (Map.get(ci, "started") == true or Map.get(coverage, "invocations") != 0) ->
        {:error, "halted Plan 66 must stop after failed JOSE preflight"}

      (dependency_failed? or jose_failed?) and
          (Map.get(coverage, "invocations") != 0 or Map.get(coverage, "started") == true) ->
        {:error,
         "halted Plan 66 must not start coverage after failed dependency or JOSE preflight"}

      true ->
        :ok
    end
  end

  defp plan66_red_gate(report) do
    cond do
      Map.get(Map.get(report, "dependencies", %{}), "exit_code") != 0 ->
        "dependencies"

      Map.get(Map.get(report, "jose_preflight", %{}), "exit_code") != 0 or
          Map.get(Map.get(report, "jose_preflight", %{}), "stage_verified") != true ->
        "jose-preflight"

      Map.get(Map.get(report, "ci", %{}), "exit_code") != 0 or
        not positive_integer?(Map.get(Map.get(report, "ci", %{}), "test_count")) or
          Map.get(Map.get(report, "ci", %{}), "failure_count") not in [0, nil] ->
        "ci"

      true ->
        "coverage"
    end
  end

  defp plan66_coverage_failed?(coverage) do
    invocations = Map.get(coverage, "invocations")
    total = Map.get(coverage, "total_percent")
    floor = Map.get(coverage, "floor_percent")

    Map.get(coverage, "exit_code") != 0 or Map.get(coverage, "failure_count") not in [0, nil] or
      invocations != 1 or
      not positive_integer?(Map.get(coverage, "test_count")) or not is_number(total) or
      not is_number(floor) or total < floor
  end

  defp validate_plan66_qualified(root, source_root, %{metadata: metadata} = document) do
    subject = Map.get(metadata, "subject_sha")

    expected_ref =
      if valid_hex?(subject, 40),
        do: "refs/heads/phase-133-evidence-#{String.slice(subject, 0, 12)}"

    report_path = Path.join([root, @phase_dir, @plan66_report_filename])

    with :ok <- validate_plan66_source_binding(root, source_root, metadata),
         true <-
           Map.get(metadata, "qualification") == "passed" or
             {:error, "qualification must be passed"},
         true <-
           Map.get(metadata, "remote_ref") == expected_ref or
             {:error, "full ref is not derived from the qualified subject"},
         true <-
           Map.get(metadata, "remote_lookup_ref") == expected_ref or
             {:error, "saved read-only lookup ref differs"},
         true <-
           Map.get(metadata, "remote_lookup_command") ==
             "git ls-remote --heads origin #{expected_ref}" or
             {:error, "saved read-only lookup command differs"},
         true <-
           Map.get(metadata, "remote_lookup_exit_code") == 0 or
             {:error, "saved read-only lookup exit code is not zero"},
         true <-
           Map.get(metadata, "remote_lookup_stdout") == "" or
             {:error, "saved read-only lookup stdout is not empty"},
         true <-
           Map.get(metadata, "remote_ref_status") == "absent-read-only-lookup" or
             {:error, "must record the successful absent-ref lookup"},
         true <-
           Map.get(metadata, "remote_action") == "none" or
             {:error, "must record remote_action: none"},
         true <-
           Map.get(metadata, "requirements-completed") == [] or
             {:error, "must grant zero requirement credit"},
         true <-
           (Map.get(metadata, "prior_receipt_sha256") == @plan55_prior_receipt_sha256 and
              prior_receipt_unchanged?(root)) or
             {:error, "must preserve the prior canonical receipt"},
         {:ok, report_bytes} <- File.read(report_path),
         true <-
           digest_matches?(metadata, "local_gates_sha256", report_bytes) or
             {:error, "local gate report digest is missing or stale"},
         {:ok, report} <- Jason.decode(report_bytes),
         :ok <- validate_plan66_local_report(report, subject, Map.get(metadata, "subject_tree")),
         :ok <- validate_plan66_bound_artifacts(root, metadata, subject),
         true <-
           (Map.get(metadata, "remote_lookup_stdout") == "" and
              not String.contains?(document.body, "requirements-completed")) or
             {:error, "qualified local summary must keep zero credit and an empty-ref proof"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "qualified Plan 66 metadata or bound artifacts are malformed"}
    end
  end

  defp validate_plan66_source_binding(root, source_root, metadata) do
    with {:ok, plan65_bytes} <- File.read(summary_path(root, 65)),
         {:ok, plan65} <- summary_document(plan65_bytes),
         subject when is_binary(subject) <- Map.get(metadata, "subject_sha"),
         true <-
           subject == Map.get(plan65.metadata, "source_sha") or
             {:error, "subject differs from Plan 65 source SHA"},
         true <-
           Map.get(metadata, "subject_tree") == Map.get(plan65.metadata, "source_tree") or
             {:error, "subject tree differs from Plan 65 source"},
         true <-
           Map.get(metadata, "plan65_source_sha") == subject or
             {:error, "Plan 65 source binding differs"},
         true <-
           subject not in @plan66_source_reused or
             {:error, "subject reuses an exhausted source SHA"},
         :ok <-
           validate_committed_source(
             source_root,
             subject,
             Map.get(metadata, "subject_tree"),
             @plan65_source_paths
           ),
         :ok <- validate_plan65_clean_source(root, source_root) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 66 subject or committed source binding is malformed"}
    end
  end

  defp validate_plan66_local_report(report, subject, tree),
    do: validate_plan66_local_report(report, subject, tree, "mix deps.get")

  defp validate_plan66_local_report(report, subject, tree, dependencies_command) do
    dependencies = Map.get(report, "dependencies", %{})
    jose = Map.get(report, "jose_preflight", %{})
    ci = Map.get(report, "ci", %{})
    coverage = Map.get(report, "coverage", %{})
    diagnostics = Map.get(report, "diagnostics", %{})
    source = Map.get(diagnostics, "source_header", %{})
    staged = Map.get(diagnostics, "staged_header", %{})
    total = Map.get(coverage, "total_percent")
    floor = Map.get(coverage, "floor_percent")

    cond do
      Map.get(report, "schema_version") != 1 or Map.get(report, "subject_sha") != subject or
          not valid_hex?(tree, 40) ->
        {:error, "local gate report source identity differs"}

      Map.get(dependencies, "command") != dependencies_command or
          Map.get(dependencies, "exit_code") != 0 ->
        {:error, "local dependency retrieval did not pass"}

      Map.get(jose, "exit_code") != 0 or Map.get(jose, "stage_verified") != true ->
        {:error, "JOSE preflight did not verify the compiled application"}

      Map.get(jose, "command") !=
        "mix run --no-start --no-deps-check --no-compile -e <focused JOSE structure and Elixir compile>" or
          Map.get(jose, "started") != true ->
        {:error, "focused JOSE preflight command did not run"}

      Map.get(ci, "command") != "mix ci" or Map.get(ci, "started") != true or
        Map.get(ci, "exit_code") != 0 or not positive_integer?(Map.get(ci, "test_count")) ->
        {:error, "local CI did not pass nonvacuously exactly once"}

      Map.get(ci, "failure_count") != 0 ->
        {:error, "local CI summary contains failures"}

      Map.get(coverage, "command") != "mix coveralls.multiple --type local --type json" or
        Map.get(coverage, "started") != true or Map.get(coverage, "invocations") != 1 or
        Map.get(coverage, "exit_code") != 0 or
        not positive_integer?(Map.get(coverage, "test_count")) or
        Map.get(coverage, "failure_count") != 0 or
        not is_number(total) or not is_number(floor) or floor < 0 or floor > total or total > 100 ->
        {:error, "canonical local coverage did not pass nonvacuously once"}

      not valid_plan66_header?(source, "deps/jose/include/jose_jwt.hrl") or
        not valid_plan66_header?(staged, "_build/test/lib/jose/include/jose_jwt.hrl") or
          Map.get(source, "sha256") != Map.get(staged, "sha256") ->
        {:error, "qualified local report lacks matching regular contained JOSE header snapshots"}

      true ->
        :ok
    end
  end

  defp valid_plan66_header?(header, path) do
    Map.get(header, "status") == "present" and Map.get(header, "file_type") == "file" and
      Map.get(header, "repo_relative_path") == path and
      Map.get(header, "process_readable") == true and Map.get(header, "target_exists") == true and
      is_nil(Map.get(header, "symlink_text")) and
      valid_hex?(Map.get(header, "sha256"), 64)
  end

  defp validate_plan66_bound_artifacts(root, metadata, subject) do
    phase = Path.join(root, @phase_dir)

    filenames = %{
      "census_sha256" => "133-EVIDENCE-CENSUS.json",
      "census_a_sha256" => "133-66-CENSUS-A.json",
      "census_b_sha256" => "133-66-CENSUS-B.json",
      "review_report_sha256" => "133-REVIEW.md",
      "security_inventory_sha256" => "133-SECURITY-INVENTORY.json",
      "security_report_sha256" => "133-SECURITY.md"
    }

    with {:ok, files} <- read_and_check_digest_files(phase, filenames, metadata),
         census_a when is_binary(census_a) <- Map.get(files, "census_a_sha256"),
         census_b when is_binary(census_b) <- Map.get(files, "census_b_sha256"),
         true <- census_a == census_b or {:error, "independent census receipt bytes differ"},
         {:ok, ledger} <- Jason.decode(Map.fetch!(files, "census_sha256")),
         true <-
           evidence_subject(ledger) == subject or {:error, "active census ledger subject differs"},
         {:ok, receipt_a} <- Jason.decode(census_a),
         {:ok, receipt_b} <- Jason.decode(census_b),
         true <-
           (evidence_subject(receipt_a) == subject and evidence_subject(receipt_b) == subject) or
             {:error, "independent census receipt subject differs"},
         :ok <- validate_plan66_census_contract(ledger, receipt_a, subject, root),
         :ok <- validate_plan66_authorities(root, metadata, files, subject),
         true <- prior_receipt_unchanged?(root) or {:error, "prior canonical receipt changed"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 66 census or source authority files are missing or malformed"}
    end
  end

  defp validate_plan66_census_contract(ledger, receipt, subject, root) do
    with :ok <- Rindle.ValidateEvidenceCensus.validate_ledger_content(ledger, root),
         :ok <-
           Rindle.ValidateEvidenceCensus.validate_receipt_contract(ledger, receipt, root, subject) do
      :ok
    else
      {:error, reason} -> {:error, "Plan 66 census contract #{reason}"}
    end
  end

  defp validate_plan66_authorities(root, metadata, files, subject) do
    review = Map.fetch!(files, "review_report_sha256")
    inventory = Map.fetch!(files, "security_inventory_sha256")
    security = Map.fetch!(files, "security_report_sha256")

    census_digests =
      Enum.map(["census_sha256", "census_a_sha256", "census_b_sha256"], &Map.get(metadata, &1))

    review_heading = "## Plan 66 Independent Code Review — Qualified Source"
    security_heading = "## Plan 66 ASVS L1 Security — Qualified Source"
    nyquist_heading = "## Plan 66 Nyquist Validation — Qualified Source"

    with true <-
           Enum.all?(census_digests, &valid_hex?(&1, 64)) or
             {:error, "census digest bindings are malformed"},
         true <-
           valid_hex?(Map.get(metadata, "local_gates_sha256"), 64) or
             {:error, "local gate report digest is malformed"},
         true <-
           reports_bind_to?(review, subject, [
             Map.get(metadata, "local_gates_sha256") | census_digests
           ]) or
             {:error, "fresh independent review is not bound to subject and census"},
         true <-
           reports_bind_to?(inventory, subject, [
             Map.get(metadata, "local_gates_sha256") | census_digests
           ]) or
             {:error, "security inventory is not bound to subject and census"},
         true <-
           reports_bind_to?(security, subject, [
             Map.get(metadata, "local_gates_sha256") | census_digests
           ]) or
             {:error, "security signoff is not bound to subject and census"},
         :ok <-
           validate_plan66_authority_section(review, review_heading, metadata, subject, :review),
         :ok <-
           validate_plan66_authority_section(
             security,
             security_heading,
             metadata,
             subject,
             :security
           ),
         :ok <-
           validate_plan66_authority_section(review, nyquist_heading, metadata, subject, :nyquist),
         {:ok, inventory_document} <- Jason.decode(inventory),
         true <-
           Map.get(
             inventory_document,
             "audited_subject",
             Map.get(inventory_document, "subject_sha")
           ) == subject or
             {:error, "security inventory subject differs"},
         {:ok, security_frontmatter, _} <- bounded_frontmatter(security),
         {:ok, security_metadata} <- decode_frontmatter(security_frontmatter),
         true <-
           (Map.get(security_metadata, "verdict") == "SECURED" and
              Map.get(security_metadata, "threats_open") == 0) or
             {:error, "fresh security authority has an open threat or no SECURED verdict"},
         true <-
           Map.get(metadata, "review_section_sha256") ==
             plan66_section_digest(review, review_heading) or
             {:error, "Plan 66 review section digest is missing or stale"},
         true <-
           Map.get(metadata, "security_section_sha256") ==
             plan66_section_digest(security, security_heading) or
             {:error, "Plan 66 security section digest is missing or stale"},
         true <-
           Map.get(metadata, "nyquist_section_sha256") ==
             plan66_section_digest(review, nyquist_heading) or
             {:error, "Plan 66 Nyquist section digest is missing or stale"},
         true <- prior_receipt_unchanged?(root) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 66 independent review, security, or Nyquist evidence is incomplete"}
    end
  end

  defp validate_plan66_authority_section(bytes, heading, metadata, subject, authority) do
    digest_key =
      case authority do
        :review -> "review_section_sha256"
        :security -> "security_section_sha256"
        :nyquist -> "nyquist_section_sha256"
      end

    with {:ok, section} <- unique_heading_section(bytes, heading),
         true <-
           String.contains?(section, "source_sha: #{subject}") or
             {:error, "#{heading} source SHA differs"},
         true <-
           String.contains?(section, "source_tree: #{Map.get(metadata, "subject_tree")}") or
             {:error, "#{heading} source tree differs"},
         true <-
           String.contains?(
             section,
             "local_gates_sha256: #{Map.get(metadata, "local_gates_sha256")}"
           ) or
             {:error, "#{heading} local gate digest differs"},
         true <-
           Enum.all?(["census_sha256", "census_a_sha256", "census_b_sha256"], fn key ->
             String.contains?(section, "#{key}: #{Map.get(metadata, key)}")
           end) or {:error, "#{heading} census digest bindings differ"},
         true <-
           Regex.match?(~r/^exit_code: 0$/m, section) or
             {:error, "#{heading} command did not pass"},
         true <-
           Map.get(metadata, digest_key) == sha256(section) or
             {:error, "#{heading} digest differs"},
         true <-
           plan66_authority_verdict?(section, authority) or
             {:error, "#{heading} verdict is not passing"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "#{heading} is missing or malformed"}
    end
  end

  defp plan66_authority_verdict?(section, :review),
    do:
      Regex.match?(~r/^verdict: clean$/m, section) and
        Regex.match?(~r/^blocking_findings: 0$/m, section)

  defp plan66_authority_verdict?(section, :security),
    do:
      Regex.match?(~r/^verdict: SECURED$/m, section) and
        Regex.match?(~r/^high_findings: 0$/m, section)

  defp plan66_authority_verdict?(section, :nyquist),
    do: Regex.match?(~r/^verdict: PASS$/m, section) and Regex.match?(~r/^gaps: 0$/m, section)

  defp plan66_section_digest(bytes, heading) do
    case unique_heading_section(bytes, heading) do
      {:ok, section} -> sha256(section)
      _ -> nil
    end
  end

  defp unique_heading_section(bytes, heading) do
    pattern = Regex.compile!("(?ms)^#{Regex.escape(heading)}\\n.*?(?=^## |\\z)")

    case Regex.scan(pattern, bytes) do
      [section] -> {:ok, hd(section)}
      _ -> {:error, "authority heading must appear exactly once"}
    end
  end

  defp validate_plan64_mode(root, source_root, expected_status, result_scope \\ :production) do
    expected_summary_status = if expected_status == :repair, do: "complete", else: "halted"

    with :ok <- validate_plan58_summary(root),
         {:ok, plan59_bytes} <- File.read(summary_path(root, 59)),
         {:ok, plan59} <- summary_document(plan59_bytes),
         :ok <- validate_plan59_outcome(root, plan59),
         :ok <- validate_plan62_for_plan64(root),
         {:ok, plan63_bytes} <- File.read(summary_path(root, 63)),
         {:ok, plan63} <- summary_document(plan63_bytes),
         true <- plan63.status == "complete" or {:error, "Plan 63 must remain complete"},
         :ok <- validate_plan63_outcome(root, source_root, plan63),
         :ok <- validate_plan64_blocked_plans(root),
         {:ok, plan64_bytes} <- File.read(summary_path(root, 64)),
         {:ok, plan64} <- summary_document(plan64_bytes),
         true <-
           plan64.status == expected_summary_status or
             {:error, "outcome does not match --expect-plan64-#{expected_status}"},
         :ok <- validate_plan64_outcome(root, source_root, plan64, expected_status),
         :ok <- validate_requirements(root, false) do
      result = if expected_status == :repair, do: "repair", else: "halted"

      message =
        if result_scope == :fixture do
          "phase 133 Plan 64 #{result} fixture valid; production acceptance not established"
        else
          "phase 133 Plan 64 #{result} evidence valid; requirements remain pending"
        end

      IO.write(message <> "\n")
      :ok
    else
      {:error, message} ->
        if String.starts_with?(message, "Plan "),
          do: {:error, message},
          else: {:error, "Plan 64 #{message}"}

      _ ->
        {:error, "Plan 64 special-mode evidence is missing or malformed"}
    end
  end

  defp validate_plan62_for_plan64(root) do
    with {:ok, summary_bytes} <- File.read(summary_path(root, 62)),
         true <-
           sha256(summary_bytes) == @plan62_summary_sha256 or
             {:error, "Plan 62 immutable summary bytes differ"},
         {:ok, plan62} <- summary_document(summary_bytes),
         true <- plan62.status == "halted" or {:error, "Plan 62 must remain halted"},
         true <-
           (Map.get(plan62.metadata, "subject_sha") == @plan62_subject_sha and
              Map.get(plan62.metadata, "local_gates_sha256") == @plan62_report_sha256) or
             {:error, "Plan 62 subject or report digest differs"},
         {:ok, report_bytes} <-
           File.read(Path.join([root, @phase_dir, "133-62-LOCAL-GATES.json"])),
         true <-
           sha256(report_bytes) == @plan62_report_sha256 or
             {:error, "Plan 62 report bytes differ"},
         :ok <- validate_plan62_outcome(root, plan62),
         true <-
           prior_receipt_unchanged?(root) or {:error, "canonical prior receipt bytes differ"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 62 immutable subject, report, or receipt is malformed"}
    end
  end

  defp validate_plan63_outcome(root, source_root, %{status: "complete", metadata: metadata}) do
    runner_sha = Map.get(metadata, "runner_source_sha")
    runner_tree = Map.get(metadata, "runner_source_tree")

    with {:ok, summary_bytes} <- File.read(summary_path(root, 63)),
         true <-
           sha256(summary_bytes) == @plan63_summary_sha256 or
             {:error, "summary bytes differ from the committed runner-repair result"},
         true <-
           Map.get(metadata, "qualification") == "runner-repair-proven" or
             {:error, "qualification is not runner-repair-proven"},
         true <-
           (runner_sha == @plan63_runner_sha and runner_tree == @plan63_runner_tree and
              Map.get(metadata, "probe_source_sha") == @plan63_runner_sha and
              Map.get(metadata, "probe_source_tree") == @plan63_runner_tree) or
             {:error, "runner and probe source identity differs from the committed repair"},
         true <-
           Map.get(metadata, "focused_probe_exit_code") == 0 or
             {:error, "focused real JOSE probe did not pass"},
         true <-
           Map.get(metadata, "focused_probe_verify_report_exit_code") == 0 or
             {:error, "focused real JOSE replay did not pass"},
         true <-
           Map.get(metadata, "fake_harness_exit_code") == 0 or
             {:error, "fake harness regression did not pass"},
         true <-
           Map.get(metadata, "requirements-completed") == [] or
             {:error, "must grant zero requirement credit"},
         true <-
           Map.get(metadata, "remote_action") == "none" or
             {:error, "must record remote_action: none"},
         true <-
           Map.get(metadata, "new_local_gate_report") == "none" or
             {:error, "must not create a local-gate report"},
         true <-
           Map.get(metadata, "census") == "not_run" or
             {:error, "must not start the census"},
         true <-
           (Map.get(metadata, "plan62_subject_sha") == @plan62_subject_sha and
              Map.get(metadata, "plan62_report_sha256") == @plan62_report_sha256 and
              Map.get(metadata, "prior_receipt_sha256") == @plan55_prior_receipt_sha256 and
              Map.get(metadata, "canonical_nightly_receipt_sha256") ==
                @plan55_prior_receipt_sha256) or
             {:error, "Plan 62 or canonical receipt identity differs"},
         :ok <-
           validate_committed_source(source_root, runner_sha, runner_tree, [
             "scripts/maintainer/phase_133_local_gates.sh",
             "scripts/maintainer/test_phase_133_local_gates.sh",
             "scripts/maintainer/test_phase_133_jose_structure.sh"
           ]) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "authentic zero-credit runner repair prerequisite is malformed"}
    end
  end

  defp validate_plan63_outcome(_root, _source_root, _document),
    do: {:error, "must be status complete with runner-repair-proven qualification"}

  defp validate_plan63_halted_outcome(_root, %{status: "halted", metadata: metadata} = document) do
    reason = Map.get(metadata, "halt_reason")

    if Map.get(metadata, "qualification") == "halted-inconclusive" and
         Map.get(metadata, "requirements-completed") == [] and
         Map.get(metadata, "remote_action") == "none" and is_binary(reason) and
         String.trim(reason) != "" and String.contains?(document.body, reason) do
      :ok
    else
      {:error, "halted Plan 63 must remain an inconclusive zero-credit result"}
    end
  end

  defp validate_plan64_blocked_plans(root) do
    blocked = [
      {56, nil},
      {60, "133-60-CANDIDATE.json"},
      {61, nil}
    ]

    case Enum.find(blocked, fn {plan, artifact} ->
           File.regular?(summary_path(root, plan)) or
             (artifact && File.regular?(Path.join([root, @phase_dir, artifact])))
         end) do
      nil -> :ok
      {plan, _artifact} -> {:error, "Plan #{plan} remains blocked and cannot be handed off"}
    end
  end

  defp validate_plan64_outcome(
         root,
         source_root,
         %{status: "complete", metadata: metadata},
         :repair
       ) do
    with :ok <- validate_plan64_common(root, source_root, metadata),
         true <-
           Map.get(metadata, "qualification") == "repair-proven" or
             {:error, "qualification must be repair-proven"},
         true <-
           Map.get(metadata, "probe_exit_code") == 0 or
             {:error, "fresh real JOSE probe did not pass"},
         true <-
           Map.get(metadata, "replay_exit_code") == 0 or
             {:error, "fresh real JOSE replay did not pass"},
         true <-
           Map.get(metadata, "census") == "not_run" or
             {:error, "census must remain not_run"},
         true <-
           Map.get(metadata, "local_gates") == "not_run" or
             {:error, "local gates must remain not_run"},
         true <-
           Map.get(metadata, "coverage") == "not_started" or
             {:error, "coverage must remain not_started"},
         {:ok, _report_bytes, report_digest} <- validate_plan64_report(root, metadata, :repair),
         :ok <-
           validate_plan64_authorities(
             root,
             metadata,
             metadata["final_source_sha"],
             metadata["final_source_tree"],
             report_digest
           ) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "repair-proven evidence or independent authority is incomplete"}
    end
  end

  defp validate_plan64_outcome(
         root,
         source_root,
         %{status: "halted", metadata: metadata, body: body},
         :halted
       ) do
    reason = Map.get(metadata, "halt_reason")
    probe_exit = Map.get(metadata, "probe_exit_code")
    replay_exit = Map.get(metadata, "replay_exit_code")

    with :ok <- validate_plan64_common(root, source_root, metadata),
         true <-
           Map.get(metadata, "qualification") == "halted-inconclusive" or
             {:error, "halt qualification must be halted-inconclusive"},
         true <-
           (is_binary(reason) and String.trim(reason) != "" and byte_size(reason) <= 512) or
             {:error, "halt requires a bounded halt_reason"},
         true <-
           String.contains?(body, reason) or
             {:error, "halt body must retain the exact halt_reason"},
         true <-
           is_integer(probe_exit) or is_nil(probe_exit) or
             {:error, "probe exit code must be an integer or null"},
         true <-
           is_integer(replay_exit) or is_nil(replay_exit) or
             {:error, "replay exit code must be an integer or null"},
         true <-
           nonzero_exit?(probe_exit) or nonzero_exit?(replay_exit) or
             {:error, "halt must record a failing probe or replay exit"},
         true <-
           Map.get(metadata, "census", "not_run") == "not_run" or
             {:error, "halt must leave census not_run"},
         true <-
           Map.get(metadata, "local_gates", "not_run") == "not_run" or
             {:error, "halt must leave local gates not_run"},
         true <-
           Map.get(metadata, "coverage", "not_started") == "not_started" or
             {:error, "halt must leave coverage not_started"},
         {:ok, _report_bytes, _report_digest} <- validate_plan64_report(root, metadata, :halted) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "halted-inconclusive evidence is malformed"}
    end
  end

  defp validate_plan64_outcome(_root, _source_root, _document, _expected),
    do: {:error, "status and qualification do not match a repair or inconclusive halt"}

  defp validate_plan64_common(root, source_root, metadata) do
    final_sha = Map.get(metadata, "final_source_sha")
    final_tree = Map.get(metadata, "final_source_tree")
    forbidden_handoff = ~w(authorized_ref authorized_subject_sha published_ref candidate_sha256)
    source_changes_required = Enum.drop(@plan64_source_paths, 3)

    with :ok <- validate_plan63_binding(metadata),
         true <-
           (Map.get(metadata, "plan62_subject_sha") == @plan62_subject_sha and
              Map.get(metadata, "plan62_report_sha256") == @plan62_report_sha256 and
              Map.get(metadata, "prior_receipt_sha256") == @plan55_prior_receipt_sha256) or
             {:error, "Plan 62 subject, report, or canonical receipt digest differs"},
         true <-
           Map.get(metadata, "remote_action") == "none" or
             {:error, "must record remote_action: none"},
         true <-
           Map.get(metadata, "requirements-completed") == [] or
             {:error, "must grant zero requirement credit"},
         true <-
           Enum.all?(forbidden_handoff, &(not Map.has_key?(metadata, &1))) or
             {:error, "must not expose a remote or candidate handoff"},
         true <-
           Map.get(metadata, "remote_ref") in [nil, "none"] or
             {:error, "must not expose a remote ref"},
         true <-
           Map.get(metadata, "remote_lookup_ref") in [nil, "none"] or
             {:error, "must not perform a remote lookup"},
         true <-
           (not File.regular?(Path.join([root, @phase_dir, "133-64-LOCAL-GATES.json"])) and
              not File.regular?(Path.join([root, @phase_dir, "133-64-EVIDENCE-CENSUS.json"]))) or
             {:error, "must not create Plan 64 local-gate or census output"},
         true <-
           prior_receipt_unchanged?(root) or
             {:error, "must preserve the prior canonical receipt"},
         true <-
           final_sha != @plan63_runner_sha or
             {:error, "final combined source must differ from the Plan 63 runner source"},
         :ok <-
           validate_committed_source(source_root, final_sha, final_tree, @plan64_source_paths),
         {:ok, ancestor_check} <-
           git(source_root, ["merge-base", "--is-ancestor", @plan63_runner_sha, final_sha]),
         true <-
           ancestor_check == "" or {:error, "Plan 63 source is not an ancestor of final source"},
         :ok <- validate_plan64_source_history(root, source_root, final_sha),
         {:ok, changed_paths} <-
           git(source_root, ["diff", "--name-only", "#{@plan63_runner_sha}..#{final_sha}"]),
         changed <- String.split(changed_paths, "\n", trim: true),
         :ok <- validate_plan64_source_range(root, source_root, changed, source_changes_required),
         :ok <- validate_plan64_source_worktree(root, source_root, final_sha) do
      :ok
    else
      {:error, _message} = error ->
        error

      _ ->
        {:error, "final combined source, zero-credit metadata, or blocked-plan boundary differs"}
    end
  end

  defp validate_plan64_source_history(report_root, source_root, final_sha) do
    with {:ok, head} <- git(source_root, ["rev-parse", "HEAD"]),
         {:ok, ancestor} <- git(source_root, ["merge-base", "--is-ancestor", final_sha, head]),
         true <- ancestor == "" or {:error, "Plan 64 final source is not on active history"} do
      if head == final_sha and Path.expand(report_root) == Path.expand(source_root),
        do: validate_plan64_source_worktree(report_root, source_root, final_sha),
        else: :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 64 final source is not on active history"}
    end
  end

  defp validate_plan64_source_range(report_root, source_root, changed, required_paths) do
    if Path.expand(report_root) != Path.expand(source_root) or
         Enum.all?(required_paths, &(&1 in changed)) do
      :ok
    else
      {:error, "final source commit range omits the reconciler or focused suites"}
    end
  end

  defp validate_plan64_source_worktree(report_root, source_root, final_sha) do
    if Path.expand(report_root) != Path.expand(source_root) do
      :ok
    else
      with {:ok, head} <- git(source_root, ["rev-parse", "HEAD"]) do
        if head != final_sha do
          :ok
        else
          with {:ok, _} <-
                 git(source_root, ["diff", "--quiet", final_sha, "--"] ++ @plan64_source_paths),
               {:ok, _} <-
                 git(
                   source_root,
                   ["diff", "--cached", "--quiet", final_sha, "--"] ++ @plan64_source_paths
                 ) do
            :ok
          else
            _ ->
              {:error,
               "runner, probe, reconciler, or focused suite source changed after final commit"}
          end
        end
      else
        _ -> {:error, "cannot identify Plan 64 source HEAD"}
      end
    end
  end

  defp validate_plan63_binding(metadata) do
    if Map.get(metadata, "plan63_runner_sha") == @plan63_runner_sha and
         Map.get(metadata, "plan63_runner_tree") == @plan63_runner_tree do
      :ok
    else
      {:error, "Plan 63 runner source binding differs"}
    end
  end

  defp validate_plan64_report(root, metadata, expected_outcome) do
    path = Path.join([root, @phase_dir, @plan64_report_filename])

    case File.read(path) do
      {:ok, bytes} ->
        digest = sha256(bytes)

        with true <-
               digest_matches?(metadata, "jose_regression_sha256", bytes) or
                 {:error, "fresh JOSE regression report digest is missing or stale"},
             {:ok, report} <- Jason.decode(bytes),
             :ok <-
               validate_plan64_report_identity(
                 report,
                 Map.get(metadata, "final_source_sha"),
                 Map.get(metadata, "final_source_tree")
               ),
             :ok <-
               if(expected_outcome == :repair,
                 do: validate_plan64_report_controls(report),
                 else: :ok
               ) do
          {:ok, bytes, digest}
        else
          {:error, _message} = error -> error
          _ -> {:error, "fresh JOSE regression report is malformed"}
        end

      {:error, :enoent} when expected_outcome == :halted ->
        if is_nil(Map.get(metadata, "jose_regression_sha256")) and
             nonzero_exit?(Map.get(metadata, "probe_exit_code")) do
          {:ok, nil, nil}
        else
          {:error, "halt without a report requires a nonzero probe exit and null report digest"}
        end

      {:error, _reason} ->
        {:error, "fresh JOSE regression report is unreadable or absent"}
    end
  end

  defp validate_plan64_report_identity(report, final_sha, final_tree) do
    if is_map(report) and Map.get(report, "schema_version") == 1 and
         Map.get(report, "kind") == "focused-regression" and
         Map.get(report, "subject_sha") == final_sha and
         Map.get(report, "subject_tree") == final_tree and
         Map.get(report, "remote_action") == "none" do
      :ok
    else
      {:error, "JOSE regression report source identity or remote_action differs"}
    end
  end

  defp validate_plan64_report_controls(report) do
    controls = Map.get(report, "controls", %{})
    negative = Map.get(controls, "negative", %{})
    repaired = Map.get(controls, "repaired", %{})
    negative_source = Map.get(negative, "source_header", %{})
    negative_staged = Map.get(negative, "staged_header", %{})
    repaired_source = Map.get(repaired, "source_header", %{})
    repaired_staged = Map.get(repaired, "staged_header", %{})
    diagnostics = Map.get(negative, "diagnostic_lines")
    diagnostic_text = if is_list(diagnostics), do: Enum.join(diagnostics, "\n"), else: ""

    cond do
      Map.get(negative, "deps_get_exit") != 0 or
          Map.get(negative, "record_extract_exit") in [nil, 0] ->
        {:error, "negative JOSE control did not reproduce the compiled-app include failure"}

      Map.get(negative_source, "repo_relative_path") != @plan64_source_header_path or
        Map.get(repaired_source, "repo_relative_path") != @plan64_source_header_path or
        Map.get(negative_staged, "repo_relative_path") != @plan64_staged_header_path or
          Map.get(repaired_staged, "repo_relative_path") != @plan64_staged_header_path ->
        {:error, "JOSE header paths differ from the expected worktree locations"}

      not valid_plan64_present_header?(negative_source) or
          not valid_hex?(Map.get(negative_source, "sha256"), 64) ->
        {:error, "negative JOSE control source header is absent or unreadable"}

      Map.get(negative_staged, "status") != "absent" or
        Map.get(negative_staged, "file_type") != nil or
        Map.get(negative_staged, "readable") != false or
          Map.get(negative_staged, "target_inside_worktree") != false ->
        {:error, "negative JOSE control did not start without the compiled-app header"}

      not String.contains?(diagnostic_text, "jose_jwt.hrl") or
          not Regex.match?(~r/enoent|no such file|could not be found/i, diagnostic_text) ->
        {:error, "negative JOSE diagnostic does not identify the expected missing include"}

      Enum.any?(
        ["deps_get_exit", "mix_structure_exit", "record_extract_exit", "jose_compile_exit"],
        &(Map.get(repaired, &1) != 0)
      ) ->
        {:error, "repaired JOSE control did not pass structure, compile, and Record.extract"}

      not valid_plan64_present_header?(repaired_source) or
          not valid_plan64_present_header?(repaired_staged) ->
        {:error, "JOSE source/staged headers must be regular readable files inside the worktree"}

      not valid_hex?(Map.get(repaired_source, "sha256"), 64) or
          Map.get(repaired_source, "sha256") != Map.get(repaired_staged, "sha256") ->
        {:error, "repaired JOSE source and staged header SHA-256 differ"}

      Map.get(negative_source, "sha256") != Map.get(repaired_source, "sha256") ->
        {:error, "negative and repaired controls do not use the same pinned JOSE source header"}

      true ->
        :ok
    end
  end

  defp valid_plan64_present_header?(header) do
    Map.get(header, "status") == "present" and Map.get(header, "file_type") == "file" and
      Map.get(header, "readable") == true and
      Map.get(header, "target_inside_worktree") == true
  end

  defp validate_plan64_authorities(root, metadata, source_sha, source_tree, report_digest) do
    authorities = [
      {
        "133-REVIEW.md",
        "## Plan 64 Independent Code Review — Qualified Source",
        "review_section_sha256",
        @plan64_review_prefix_sha256,
        "clean",
        "blocking_findings"
      },
      {
        "133-SECURITY.md",
        "## Plan 64 ASVS L1 Security — Qualified Source",
        "security_section_sha256",
        @plan64_security_prefix_sha256,
        "SECURED",
        "high_findings"
      },
      {
        "133-VALIDATION.md",
        "## Plan 64 Nyquist Validation — Qualified Source",
        "nyquist_section_sha256",
        @plan64_validation_prefix_sha256,
        "PASS",
        "gaps"
      }
    ]

    Enum.reduce_while(authorities, :ok, fn
      {filename, heading, digest_key, prefix_digest, verdict, zero_key}, :ok ->
        case validate_plan64_authority(
               root,
               filename,
               heading,
               digest_key,
               prefix_digest,
               verdict,
               zero_key,
               metadata,
               source_sha,
               source_tree,
               report_digest
             ) do
          :ok -> {:cont, :ok}
          {:error, message} -> {:halt, {:error, message}}
        end
    end)
  end

  defp validate_plan64_authority(
         root,
         filename,
         heading,
         digest_key,
         prefix_digest,
         verdict,
         zero_key,
         metadata,
         source_sha,
         source_tree,
         report_digest
       ) do
    path = Path.join([root, @phase_dir, filename])
    section_regex = Regex.compile!("(?ms)^#{Regex.escape(heading)}\\n.*?(?=^## |\\z)")

    with {:ok, bytes} <- File.read(path),
         true <-
           length(Regex.scan(Regex.compile!("^#{Regex.escape(heading)}$", "m"), bytes)) == 1 or
             {:error, "Plan 64 authority section #{heading} is missing or duplicated"},
         [section] <- Regex.run(section_regex, bytes),
         {offset, _length} <- :binary.match(bytes, heading),
         prefix <- binary_part(bytes, 0, offset) |> trim_appended_separator(),
         true <-
           sha256(prefix) == prefix_digest or
             {:error, "Plan 64 #{filename} historical prefix bytes differ"},
         true <-
           digest_matches?(metadata, digest_key, section) or
             {:error, "#{authority_label(filename)} section digest is missing or stale"},
         {:ok, fields} <- section_field_map(section),
         true <-
           Map.get(fields, "source_sha") == source_sha or
             {:error, "Plan 64 #{filename} source SHA differs"},
         true <-
           Map.get(fields, "source_tree") == source_tree or
             {:error, "Plan 64 #{filename} source tree differs"},
         true <-
           Map.get(fields, "report_sha256") == report_digest or
             {:error, "Plan 64 #{filename} report digest differs"},
         true <-
           Map.get(fields, "exit_code") == "0" or
             {:error, "Plan 64 #{filename} authority command did not pass"},
         true <-
           (is_binary(Map.get(fields, "command")) and Map.get(fields, "command") != "") or
             {:error, "Plan 64 #{filename} command is missing"},
         true <-
           (is_binary(Map.get(fields, "scope")) and Map.get(fields, "scope") != "") or
             {:error, "Plan 64 #{filename} scope is missing"},
         true <-
           Map.get(fields, "verdict") == verdict or
             {:error, "Plan 64 #{filename} verdict is not #{verdict}"},
         true <-
           Map.get(fields, zero_key) == "0" or
             {:error, "Plan 64 #{filename} must record #{zero_key}: 0"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 64 authority section #{heading} is malformed"}
    end
  end

  defp authority_label("133-REVIEW.md"), do: "review"
  defp authority_label("133-SECURITY.md"), do: "security"
  defp authority_label("133-VALIDATION.md"), do: "Nyquist"
  defp authority_label(filename), do: filename

  defp section_field_map(section) do
    pairs =
      Regex.scan(~r/^([a-z][a-z0-9_]*):\s*(.*?)\s*$/m, section, capture: :all_but_first)

    fields = Map.new(pairs, fn [key, value] -> {key, value} end)

    if map_size(fields) == length(pairs) do
      {:ok, fields}
    else
      {:error, "Plan 64 authority section contains duplicate authority fields"}
    end
  end

  defp trim_appended_separator(prefix) do
    if String.ends_with?(prefix, "\n\n"),
      do: binary_part(prefix, 0, byte_size(prefix) - 1),
      else: prefix
  end

  defp nonzero_exit?(value), do: is_integer(value) and value != 0

  defp validate_committed_source(root, sha, tree, paths) do
    with true <- valid_hex?(sha, 40) or {:error, "source SHA is not full lowercase hex"},
         true <- valid_hex?(tree, 40) or {:error, "source tree is not full lowercase hex"},
         {:ok, actual_tree} <- git(root, ["rev-parse", "#{sha}^{tree}"]),
         true <- actual_tree == tree or {:error, "source tree differs from committed SHA"},
         :ok <- require_commit_paths(root, sha, paths) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "source commit or tree is unavailable"}
    end
  end

  defp require_commit_paths(root, sha, paths) do
    Enum.reduce_while(paths, :ok, fn path, :ok ->
      case git(root, ["cat-file", "-e", "#{sha}:#{path}"]) do
        {:ok, _} -> {:cont, :ok}
        _ -> {:halt, {:error, "source commit omits #{path}"}}
      end
    end)
  end

  defp validate_plan62_outcome(root, %{status: "complete", metadata: metadata} = document) do
    subject = Map.get(metadata, "subject_sha")

    expected_ref =
      if valid_hex?(subject, 40),
        do: "refs/heads/phase-133-evidence-#{String.slice(subject, 0, 12)}"

    report_path = Path.join([root, @phase_dir, "133-62-LOCAL-GATES.json"])

    with true <-
           Map.get(metadata, "qualification") == "passed" or
             {:error, "qualification must be passed"},
         true <-
           (valid_hex?(subject, 40) and subject != @plan59_restricted_subject) or
             {:error, "must bind a fresh unrestricted source SHA"},
         true <-
           Map.get(metadata, "remote_ref") == expected_ref or
             {:error, "full ref is not derived from the qualified subject"},
         true <-
           Map.get(metadata, "remote_lookup_ref") == expected_ref or
             {:error, "saved read-only lookup ref differs"},
         true <-
           Map.get(metadata, "remote_lookup_command") ==
             "git ls-remote --heads origin #{expected_ref}" or
             {:error, "saved read-only lookup command differs"},
         true <-
           Map.get(metadata, "remote_lookup_exit_code") == 0 or
             {:error, "saved read-only lookup exit code is not zero"},
         true <-
           Map.get(metadata, "remote_lookup_stdout") == "" or
             {:error, "saved read-only lookup stdout is not empty"},
         true <-
           Map.get(metadata, "remote_ref_status") == "absent-read-only-lookup" or
             {:error, "must record the successful absent-ref lookup"},
         true <-
           Map.get(metadata, "remote_action") == "none" or
             {:error, "must record remote_action: none"},
         true <-
           Map.get(metadata, "requirements-completed") == [] or
             {:error, "must grant zero requirement credit"},
         true <-
           (Map.get(metadata, "prior_receipt_sha256") == @plan55_prior_receipt_sha256 and
              prior_receipt_unchanged?(root)) or
             {:error, "must preserve the prior canonical receipt"},
         {:ok, report_bytes} <- File.read(report_path),
         true <-
           digest_matches?(metadata, "local_gates_sha256", report_bytes) or
             {:error, "local gate report digest is missing or stale"},
         {:ok, report} <- Jason.decode(report_bytes),
         :ok <- validate_plan62_local_report(report, subject),
         diagnosis <- Map.get(Map.get(report, "diagnostics", %{}), "diagnosis_branch"),
         true <-
           (Map.get(metadata, "jose_diagnosis") == diagnosis and
              String.contains?(document.body, to_string(diagnosis))) or
             {:error, "summary must preserve the observed JOSE diagnosis"},
         :ok <- validate_plan62_bound_artifacts(root, metadata, subject) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "qualified Plan 62 metadata or bound artifacts are malformed"}
    end
  end

  defp validate_plan62_outcome(root, %{status: "halted", metadata: metadata} = document) do
    subject = Map.get(metadata, "subject_sha")
    report_path = Path.join([root, @phase_dir, "133-62-LOCAL-GATES.json"])
    forbidden_handoff = ~w(authorized_ref authorized_subject_sha published_ref candidate_sha256)

    with true <-
           Map.get(metadata, "qualification") == "local-authority-failed" or
             {:error, "halt qualification must be local-authority-failed"},
         true <-
           (valid_hex?(subject, 40) and subject != @plan59_restricted_subject) or
             {:error, "halt must retain a fresh unrestricted source SHA"},
         true <-
           is_nil(Map.get(metadata, "remote_ref")) or
             {:error, "halt must not expose a qualified ref handoff"},
         true <-
           Enum.all?(forbidden_handoff, &(not Map.has_key?(metadata, &1))) or
             {:error, "halt must not expose Plan 60 authorization or candidate metadata"},
         true <-
           Map.get(metadata, "remote_action") == "none" or
             {:error, "halt must record remote_action: none"},
         true <-
           Map.get(metadata, "requirements-completed") == [] or
             {:error, "halt must grant zero requirement credit"},
         true <-
           (Map.get(metadata, "prior_receipt_sha256") == @plan55_prior_receipt_sha256 and
              prior_receipt_unchanged?(root)) or
             {:error, "halt must preserve the prior canonical receipt"},
         reason when is_binary(reason) and byte_size(reason) > 0 <-
           Map.get(metadata, "halt_reason"),
         {:ok, report_bytes} <- File.read(report_path),
         true <-
           digest_matches?(metadata, "local_gates_sha256", report_bytes) or
             {:error, "halted local gate report digest is missing or stale"},
         {:ok, report} <- Jason.decode(report_bytes),
         true <-
           Map.get(report, "subject_sha") == subject or
             {:error, "halted local report subject differs"},
         true <-
           (is_map(Map.get(report, "diagnostics")) and
              is_binary(Map.get(Map.get(report, "diagnostics"), "diagnosis_branch"))) or
             {:error, "halted report must preserve its JOSE diagnosis"},
         diagnosis <- Map.get(Map.get(report, "diagnostics", %{}), "diagnosis_branch"),
         true <-
           (Map.get(metadata, "jose_diagnosis") == diagnosis and
              String.contains?(document.body, to_string(diagnosis))) or
             {:error, "halted summary must preserve the observed JOSE diagnosis"},
         true <-
           (not File.regular?(summary_path(root, 60)) and
              not File.regular?(Path.join([root, @phase_dir, "133-60-CANDIDATE.json"]))) or
             {:error, "halted Plan 62 must not leave a Plan 60 result"},
         true <-
           String.contains?(document.body, reason) or
             {:error, "halt body must retain the exact halt reason"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "halted Plan 62 metadata or report is malformed"}
    end
  end

  defp validate_plan62_outcome(_root, _document),
    do: {:error, "must record a qualified success or zero-credit terminal halt"}

  defp validate_plan62_local_report(report, subject) do
    dependencies = Map.get(report, "dependencies", %{})
    ci = Map.get(report, "ci", %{})
    coverage = Map.get(report, "coverage", %{})
    diagnostics = Map.get(report, "diagnostics", %{})
    source = Map.get(diagnostics, "source_header", %{})
    staged = Map.get(diagnostics, "staged_header", %{})
    floor = Map.get(coverage, "floor_percent")
    total = Map.get(coverage, "total_percent")

    cond do
      Map.get(report, "schema_version") != 1 or Map.get(report, "subject_sha") != subject ->
        {:error, "local gate report source identity differs"}

      Map.get(dependencies, "command") != "mix deps.get" or
          Map.get(dependencies, "exit_code") != 0 ->
        {:error, "local dependency retrieval did not pass"}

      Map.get(ci, "command") != "mix ci" or Map.get(ci, "started") != true or
        Map.get(ci, "exit_code") != 0 or not positive_integer?(Map.get(ci, "test_count")) ->
        {:error, "local CI did not pass nonvacuously exactly once"}

      Map.get(coverage, "command") != "mix coveralls.multiple --type local --type json" or
        Map.get(coverage, "started") != true or Map.get(coverage, "invocations") != 1 or
        Map.get(coverage, "exit_code") != 0 or
        not positive_integer?(Map.get(coverage, "test_count")) or not is_number(total) or
        not is_number(floor) or floor < 0 or floor > total or total > 100 ->
        {:error, "canonical local coverage did not pass nonvacuously once"}

      Map.get(source, "status") != "present" or Map.get(source, "process_readable") != true or
        Map.get(staged, "status") != "present" or Map.get(staged, "process_readable") != true ->
        {:error, "qualified local report lacks both readable JOSE header snapshots"}

      true ->
        :ok
    end
  end

  defp validate_plan62_bound_artifacts(root, metadata, subject) do
    phase = Path.join(root, @phase_dir)

    digest_files = %{
      "census_sha256" => "133-EVIDENCE-CENSUS.json",
      "census_a_sha256" => "133-62-CENSUS-A.json",
      "census_b_sha256" => "133-62-CENSUS-B.json",
      "review_report_sha256" => "133-REVIEW.md",
      "security_inventory_sha256" => "133-SECURITY-INVENTORY.json",
      "security_report_sha256" => "133-SECURITY.md"
    }

    with {:ok, bytes_by_key} <- read_and_check_digest_files(phase, digest_files, metadata),
         census_a when is_binary(census_a) <- Map.get(bytes_by_key, "census_a_sha256"),
         census_b when is_binary(census_b) <- Map.get(bytes_by_key, "census_b_sha256"),
         true <- census_a == census_b or {:error, "independent census receipt bytes differ"},
         {:ok, ledger} <- Jason.decode(Map.fetch!(bytes_by_key, "census_sha256")),
         true <-
           evidence_subject(ledger) == subject or {:error, "active census ledger subject differs"},
         {:ok, receipt_a} <- Jason.decode(census_a),
         {:ok, receipt_b} <- Jason.decode(census_b),
         true <-
           (evidence_subject(receipt_a) == subject and evidence_subject(receipt_b) == subject) or
             {:error, "independent census receipt subject differs"},
         :ok <- validate_plan62_reports(root, metadata, bytes_by_key, subject) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 62 local authority files are missing or malformed"}
    end
  end

  defp read_and_check_digest_files(phase, digest_files, metadata) do
    Enum.reduce_while(digest_files, {:ok, %{}}, fn {digest_key, filename}, {:ok, acc} ->
      with {:ok, bytes} <- File.read(Path.join(phase, filename)),
           true <- digest_matches?(metadata, digest_key, bytes) do
        {:cont, {:ok, Map.put(acc, digest_key, bytes)}}
      else
        _ -> {:halt, {:error, "Plan 62 #{filename} digest is missing or stale"}}
      end
    end)
  end

  defp validate_plan62_reports(root, metadata, files, subject) do
    census_digests =
      Enum.map(["census_sha256", "census_a_sha256", "census_b_sha256"], &Map.get(metadata, &1))

    review = Map.fetch!(files, "review_report_sha256")
    inventory = Map.fetch!(files, "security_inventory_sha256")
    security = Map.fetch!(files, "security_report_sha256")

    with true <-
           Enum.all?(census_digests, &valid_hex?(&1, 64)) or
             {:error, "census digest bindings are malformed"},
         true <-
           reports_bind_to?(review, subject, census_digests) or
             {:error, "fresh independent review is not bound to the subject and census"},
         true <-
           reports_bind_to?(inventory, subject, census_digests) or
             {:error, "security inventory is not bound to the subject and census"},
         true <-
           reports_bind_to?(security, subject, census_digests) or
             {:error, "security signoff is not bound to the subject and census"},
         true <-
           (String.contains?(review, "## Plan 62 Independent Review") and
              (String.contains?(review, "blocking_findings: 0") or
                 String.contains?(review, "blocking: 0")) and
              String.contains?(review, "T-133-55-03: closed")) or
             {:error, "Plan 62 review must close T-133-55-03 with zero blocking findings"},
         {:ok, nyquist} <- plan62_nyquist_section(review),
         true <-
           digest_matches?(metadata, "nyquist_evidence_sha256", nyquist) or
             {:error, "independent Nyquist section digest is missing or stale"},
         true <-
           (String.contains?(nyquist, "subject_sha: #{subject}") and
              Enum.all?(census_digests, &String.contains?(nyquist, &1)) and
              String.contains?(nyquist, "result: pass")) or
             {:error, "Plan 62 Nyquist evidence is not a passing source-bound section"},
         {:ok, inventory_document} <- Jason.decode(inventory),
         true <-
           Map.get(
             inventory_document,
             "audited_subject",
             Map.get(inventory_document, "subject_sha")
           ) == subject or
             {:error, "security inventory subject differs"},
         {:ok, security_frontmatter, _security_body} <- bounded_frontmatter(security),
         {:ok, security_metadata} <- decode_frontmatter(security_frontmatter),
         true <-
           (Map.get(security_metadata, "verdict") == "SECURED" and
              Map.get(security_metadata, "threats_open") == 0) or
             {:error, "fresh security authority has an open threat or no SECURED verdict"},
         true <- prior_receipt_unchanged?(root) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 62 independent review, security, or Nyquist evidence is incomplete"}
    end
  end

  defp plan62_nyquist_section(review) do
    case Regex.run(~r/(?ms)^## Plan 62 Nyquist Evidence\s*\n.*?(?=^## |\z)/, review) do
      [section] -> {:ok, section}
      _ -> {:error, "dedicated Plan 62 Nyquist section is missing or ambiguous"}
    end
  end

  defp reports_bind_to?(bytes, subject, digests),
    do: String.contains?(bytes, subject) and Enum.all?(digests, &String.contains?(bytes, &1))

  defp evidence_subject(document) when is_map(document),
    do: Map.get(document, "source_sha", Map.get(document, "subject_sha"))

  defp evidence_subject(_), do: nil

  defp digest_matches?(metadata, key, bytes) do
    digest = Map.get(metadata, key)
    valid_hex?(digest, 64) and sha256(bytes) == digest
  end

  defp positive_integer?(value), do: is_integer(value) and value > 0

  defp validate_plan62_summary(root, summary_state) do
    path = summary_path(root, 62)

    case File.read(path) do
      {:error, :enoent} ->
        if File.regular?(summary_path(root, 60)) or File.regular?(summary_path(root, 61)),
          do: {:error, "Plan 60 or 61 requires a Plan 62 qualification summary"},
          else: :ok

      {:ok, summary} ->
        with true <-
               MapSet.member?(summary_state.completed, 58) or
                 {:error, "requires completed Plan 58 local gates"},
             true <-
               MapSet.member?(summary_state.halted, 59) or
                 {:error, "requires immutable halted Plan 59 history"},
             {:ok, document} <- summary_document(summary),
             :ok <- validate_plan62_outcome(root, document) do
          :ok
        else
          {:error, message} -> {:error, "Plan 62 summary #{message}"}
          _ -> {:error, "Plan 62 summary is malformed"}
        end

      {:error, _reason} ->
        {:error, "Plan 62 summary is unreadable"}
    end
  end

  defp validate_plan60_summary(root, summary_state) do
    path = summary_path(root, 60)

    case File.read(path) do
      {:error, :enoent} ->
        :ok

      {:ok, summary} ->
        with true <-
               MapSet.member?(summary_state.completed, 62) or
                 {:error, "requires a completed Plan 62 qualification"},
             {:ok, plan62} <- File.read(summary_path(root, 62)),
             {:ok, plan62_document} <- summary_document(plan62),
             {:ok, document} <- summary_document(summary),
             :ok <- validate_plan60_outcome(root, document, plan62_document.metadata) do
          :ok
        else
          {:error, reason} -> {:error, "Plan 60 summary #{reason}"}
          _ -> {:error, "Plan 60 summary is malformed or lacks the Plan 62 authority"}
        end

      {:error, _reason} ->
        {:error, "Plan 60 summary is unreadable"}
    end
  end

  defp validate_plan60_outcome(root, %{status: "halted", metadata: metadata}, _plan59) do
    if Map.get(metadata, "requirements-completed") == [] and
         Map.get(metadata, "prior_receipt_sha256") == @plan55_prior_receipt_sha256 and
         prior_receipt_unchanged?(root) do
      :ok
    else
      {:error, "halt must preserve zero credit and the prior canonical receipt"}
    end
  end

  defp validate_plan60_outcome(root, %{status: "complete", metadata: metadata}, plan62) do
    authorized_subject = Map.get(metadata, "authorized_subject_sha")
    authorized_ref = Map.get(metadata, "authorized_ref")
    candidate_path = Path.join([root, @phase_dir, "133-60-CANDIDATE.json"])

    with true <-
           Map.get(metadata, "decision") == "authorize" or
             {:error, "requires literal authorization"},
         true <-
           Map.get(metadata, "qualification") == "remote-candidate-verified" or
             {:error, "candidate qualification is not verified"},
         true <-
           Map.get(metadata, "requirements-completed") == [] or
             {:error, "must grant zero requirement credit"},
         true <-
           (Map.get(metadata, "prior_receipt_sha256") == @plan55_prior_receipt_sha256 and
              prior_receipt_unchanged?(root)) or
             {:error, "prior canonical receipt digest differs"},
         true <-
           (authorized_subject == Map.get(plan62, "subject_sha") and
              authorized_ref == Map.get(plan62, "remote_ref")) or
             {:error, "authorization pair differs from Plan 62"},
         {:ok, candidate_bytes} <- File.read(candidate_path),
         candidate_digest when is_binary(candidate_digest) <-
           Map.get(metadata, "candidate_sha256"),
         true <- valid_hex?(candidate_digest, 64) and sha256(candidate_bytes) == candidate_digest,
         {:ok, candidate} <- Jason.decode(candidate_bytes),
         true <-
           (Map.get(candidate, "subject_sha") == authorized_subject and
              Map.get(candidate, "remote_ref") == authorized_ref) or
             {:error, "candidate pair differs from authorization"},
         true <-
           (is_integer(Map.get(candidate, "run_id")) and
              is_integer(Map.get(candidate, "run_attempt"))) or
             {:error, "candidate lacks an owned run tuple"} do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "candidate or authorization metadata is malformed"}
    end
  end

  defp validate_plan60_outcome(_root, _document, _plan62),
    do: {:error, "must record a verified candidate or immutable halt"}

  defp validate_plan61_summary(root, summary_state) do
    path = summary_path(root, 61)

    case File.read(path) do
      {:error, :enoent} ->
        :ok

      {:ok, summary} ->
        with true <-
               MapSet.member?(summary_state.completed, 60) or
                 {:error, "requires a completed Plan 60 candidate"},
             {:ok, candidate_bytes} <-
               File.read(Path.join([root, @phase_dir, "133-60-CANDIDATE.json"])),
             {:ok, document} <- summary_document(summary),
             :ok <- validate_plan61_outcome(root, document, candidate_bytes) do
          :ok
        else
          {:error, reason} -> {:error, "Plan 61 summary #{reason}"}
          _ -> {:error, "Plan 61 summary is malformed or lacks its candidate"}
        end

      {:error, _reason} ->
        {:error, "Plan 61 summary is unreadable"}
    end
  end

  defp validate_plan61_outcome(root, %{status: "halted", metadata: metadata}, _candidate_bytes) do
    if Map.get(metadata, "requirements-completed") == [] and
         prior_receipt_unchanged?(root) and
         Map.get(metadata, "receipt_sha256") == @plan55_prior_receipt_sha256 do
      :ok
    else
      {:error, "halt must restore the prior receipt and keep requirements pending"}
    end
  end

  defp validate_plan61_outcome(root, %{status: "complete", metadata: metadata}, candidate_bytes) do
    receipt_path = Path.join([root, @receipt_path])

    expected_terminal_command =
      "MIX_ENV=test mix run --no-start --no-deps-check --no-compile " <>
        "scripts/maintainer/validate_phase_133_reconciliation.exs --root . --expect-execution-complete"

    with true <-
           Map.get(metadata, "qualification") == "verified" or
             {:error, "qualification must be verified"},
         true <-
           Map.get(metadata, "terminal_automation") == "passed" or
             {:error, "terminal automation must pass"},
         true <-
           Map.get(metadata, "terminal_automation_command") == expected_terminal_command or
             {:error, "terminal automation command differs"},
         true <-
           Map.get(metadata, "terminal_automation_exit_code") == 0 or
             {:error, "terminal automation exit must be zero"},
         requirements when is_list(requirements) <- Map.get(metadata, "requirements-completed"),
         true <-
           MapSet.new(requirements) == MapSet.new(@phase_requirements) or
             {:error, "must list all five requirements only at terminal completion"},
         true <-
           File.read!(receipt_path) == candidate_bytes or
             {:error, "canonical receipt differs from the verified candidate"},
         true <-
           Map.get(metadata, "candidate_sha256") == sha256(candidate_bytes) or
             {:error, "candidate digest differs"},
         true <-
           Map.get(metadata, "receipt_sha256") == sha256(candidate_bytes) or
             {:error, "canonical receipt digest differs"},
         {:ok, candidate} <- Jason.decode(candidate_bytes),
         true <-
           Map.get(metadata, "subject_sha") == Map.get(candidate, "subject_sha") or
             {:error, "subject differs from the authorized candidate"},
         true <-
           Map.get(metadata, "remote_ref") == Map.get(candidate, "remote_ref") or
             {:error, "ref differs from the authorized candidate"},
         true <-
           Map.get(metadata, "run_id") == Map.get(candidate, "run_id") or
             {:error, "run ID differs from the authorized candidate"},
         true <-
           Map.get(metadata, "run_attempt") == Map.get(candidate, "run_attempt") or
             {:error, "run attempt differs from the authorized candidate"},
         true <-
           (is_integer(Map.get(candidate, "run_id")) and
              is_integer(Map.get(candidate, "run_attempt"))) or
             {:error, "candidate lacks its owned run tuple"},
         :ok <- verify_canonical_receipt(root) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "terminal receipt metadata is malformed"}
    end
  rescue
    _ -> {:error, "canonical receipt is unreadable"}
  end

  defp validate_plan61_outcome(_root, _document, _candidate_bytes),
    do: {:error, "must record terminal success or immutable halt"}

  defp prior_receipt_unchanged?(root) do
    if terminal_plan61_complete?(root) do
      true
    else
      case File.read(Path.join(root, @receipt_path)) do
        {:ok, bytes} -> sha256(bytes) == @plan55_prior_receipt_sha256
        _ -> false
      end
    end
  end

  defp terminal_plan61_complete?(root) do
    case File.read(summary_path(root, 61)) do
      {:ok, summary} ->
        case summary_document(summary) do
          {:ok, %{status: "complete"}} -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  defp valid_hex?(value, length),
    do: is_binary(value) and Regex.match?(Regex.compile!("\\A[0-9a-f]{#{length}}\\z"), value)

  defp validate_plan56_summary(root) do
    case File.read(summary_path(root, 56)) do
      {:error, :enoent} ->
        :ok

      {:ok, summary} ->
        with {:ok, document} <- summary_document(summary),
             {:ok, plan55} <- File.read(summary_path(root, 55)),
             {:ok, plan55_document} <- summary_document(plan55),
             subject <- Map.get(plan55_document.metadata, "subject_sha"),
             ref <- Map.get(plan55_document.metadata, "remote_ref"),
             true <-
               Map.get(document.metadata, "subject_sha") == subject or
                 {:error, "Plan 56 subject differs from Plan 55"},
             true <-
               Map.get(document.metadata, "published_ref") == ref or
                 {:error, "Plan 56 ref differs from the Plan 55 pair"},
             :ok <- validate_plan56_terminal_outcome(root, document) do
          :ok
        else
          {:error, _message} = error -> error
          _ -> {:error, "Plan 56 summary is malformed or lacks its Plan 55 pair"}
        end

      {:error, _reason} ->
        {:error, "Plan 56 summary is unreadable"}
    end
  end

  defp validate_plan56_terminal_outcome(_root, %{status: "halted", metadata: metadata}) do
    decision = Map.get(metadata, "decision")
    terminal = Map.get(metadata, "terminal_automation")

    requirements =
      Map.get(metadata, "requirements_completed", Map.get(metadata, "requirements-completed"))

    terminal_state? =
      (decision == "stop" and terminal in [nil, "not-run", "not attempted", "blocked"]) or
        (decision == "authorize" and terminal in ["halted", "failed"])

    if terminal_state? and requirements == [] do
      :ok
    else
      {:error, "Plan 56 halted outcome must preserve zero requirement credit and the decision"}
    end
  end

  defp validate_plan56_terminal_outcome(root, %{status: "complete", metadata: metadata}) do
    with true <-
           Map.get(metadata, "decision") == "authorize" or
             {:error, "Plan 56 completion requires explicit authorization"},
         true <-
           Map.get(metadata, "qualification") == "verified" or
             {:error, "Plan 56 qualification must be verified"},
         true <-
           Map.get(metadata, "terminal_automation") == "passed" or
             {:error, "Plan 56 terminal automation must be passed"},
         requirements when is_list(requirements) <-
           Map.get(
             metadata,
             "requirements_completed",
             Map.get(metadata, "requirements-completed")
           ),
         true <-
           MapSet.new(requirements) == MapSet.new(@phase_requirements) or
             {:error, "Plan 56 completion must qualify every Phase 133 requirement"},
         :ok <- validate_qualified_receipt(root, metadata) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "Plan 56 completion metadata is malformed"}
    end
  end

  defp validate_plan56_terminal_outcome(_root, _document),
    do: {:error, "Plan 56 summary must be complete or halted"}

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
    total = total_plans(root, mode)
    roadmap_state = roadmap_validation_state(root, summary_state, total)
    completed_count = roadmap_completed_count(roadmap_state)
    halted_count = MapSet.size(roadmap_state.halted)
    summarized_count = MapSet.size(roadmap_state.completed) + halted_count

    lifecycle =
      cond do
        mode in [:execution, :execution_complete] ->
          {:ok, base} = closure_lifecycle(roadmap_state)
          {:ok, current} = execution_lifecycle_from_state(base, roadmap_state)
          current

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
             roadmap_state.halted
           ),
         :ok <- validate_execution_checkboxes(section, roadmap_state, total),
         :ok <- validate_execution_progress_row(root, roadmap, summarized_count, total, lifecycle) do
      :ok
    else
      {:error, _message} = error -> error
      _ -> {:error, "roadmap Phase 133 section is missing or ambiguous"}
    end
  end

  defp roadmap_validation_state(root, summary_state, 61) do
    if orchestrator_plan58_pending?(root, summary_state) do
      %{summary_state | completed: MapSet.delete(summary_state.completed, 58)}
    else
      summary_state
    end
  end

  defp roadmap_validation_state(root, summary_state, 62) do
    if orchestrator_plan58_pending_from_count?(root, 57) do
      %{summary_state | completed: MapSet.delete(summary_state.completed, 58)}
    else
      summary_state
    end
  end

  defp roadmap_validation_state(_root, summary_state, _total), do: summary_state

  defp orchestrator_plan58_pending?(root, summary_state) do
    summarized = MapSet.size(summary_state.completed) + MapSet.size(summary_state.halted)

    MapSet.member?(summary_state.completed, 58) and
      orchestrator_plan58_pending_from_count?(root, summarized)
  end

  defp orchestrator_plan58_pending_from_count?(root, summarized) do
    with true <- summarized == 57,
         {:ok, roadmap} <- File.read(Path.join(root, @roadmap_path)),
         [section] <-
           Regex.run(
             ~r/### Phase 133: Evidence Charter and Live Truth(.*?)(?=\n### Phase 134:|\z)/s,
             roadmap,
             capture: :all_but_first
           ),
         [[" "]] <-
           Regex.scan(~r/^- \[([ x])\] 133-58-PLAN\.md(?:\s| |$)/m, section,
             capture: :all_but_first
           ),
         {:ok, state_contents} <- File.read(Path.join(root, @state_path)),
         {:ok, frontmatter, body} <- bounded_frontmatter(state_contents),
         {:ok, decoded} <- decode_frontmatter(frontmatter),
         %{"progress" => progress} <- decoded,
         true <- Map.get(progress, "total_plans") == 61,
         true <- Map.get(progress, "completed_plans") == 56,
         true <- Map.get(decoded, "status") == "executing",
         true <- Regex.match?(~r/^Plan:\s*58 of 61(?:\s+.*)?$/m, body) do
      true
    else
      _ -> false
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

    if mode in [:execution, :execution_complete] and
         (current_plan54_handoff_detail?(
            section,
            summarized_count,
            completed_count,
            pending_count,
            total,
            halted
          ) or
            current_plan55_handoff_detail?(
              section,
              summarized_count,
              completed_count,
              pending_count,
              total,
              halted
            ) or
            current_plan58_handoff_detail?(
              section,
              summarized_count,
              completed_count,
              pending_count,
              total,
              halted
            ) or
            current_new_chain_handoff_detail?(
              section,
              summarized_count,
              completed_count,
              pending_count,
              total,
              halted
            ) or
            current_plan62_handoff_detail?(
              section,
              summarized_count,
              completed_count,
              pending_count,
              total,
              halted
            ) or
            current_plan61_terminal_detail?(
              section,
              summarized_count,
              completed_count,
              pending_count,
              total,
              halted
            ) or
            current_plan57_handoff_detail?(
              section,
              summarized_count,
              completed_count,
              pending_count,
              total,
              halted
            )) do
      :ok
    else
      expected =
        if mode in [:execution, :execution_complete] and total > 42 do
          pre_decision_halt? = MapSet.member?(halted, 48)
          immutable_halts = if pre_decision_halt?, do: MapSet.delete(halted, 48), else: halted
          halted_text = halted_plan_text(immutable_halts)

          gate_text =
            if pre_decision_halt?, do: ", Plan 133-48 halted before a decision", else: ""

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
  end

  defp current_plan54_handoff_detail?(section, 53, 47, 1, 54, halted) do
    expected_halts = MapSet.new([27, 32, 37, 42, 49])

    expected =
      "**Plans**: 53/54 plans executed and summarized; 47 completed and Plans " <>
        "133-27, 133-32, 133-37, 133-42, and 133-49 halted with immutable attempts preserved. " <>
        "EVID-01 through EVID-04 and TRUTH-08 remain pending; a new gap plan is needed for the " <>
        "failed supported compatibility coverage matrix and Plan 42's halted-state reconciliation mismatch."

    halted == expected_halts and String.contains?(section, expected)
  end

  defp current_plan54_handoff_detail?(
         _section,
         _summarized,
         _completed,
         _pending,
         _total,
         _halted
       ),
       do: false

  defp current_plan55_handoff_detail?(section, 54, 48, 2, 56, halted) do
    expected_halts = MapSet.new([27, 32, 37, 42, 49])

    expected =
      "**Plans**: 54/56 plans executed summarized; 49 complete (including diagnostic Plan 133-53), " <>
        "Plans 133-27, 133-32, 133-37, 133-42, and 133-49 halted with immutable attempts preserved; " <>
        "Plans 133-55 and 133-56 are the two remaining gap-closure plans."

    halted == expected_halts and String.contains?(section, expected)
  end

  defp current_plan55_handoff_detail?(
         _section,
         _summarized,
         _completed,
         _pending,
         _total,
         _halted
       ),
       do: false

  defp current_plan57_handoff_detail?(section, 55, 49, 2, 57, halted) do
    expected_halts = MapSet.new([27, 32, 37, 42, 49, 55])

    expected =
      "**Plans**: 55/57 plans summarized; 49 complete (including diagnostic Plan 133-53), and " <>
        "Plans 133-27, 133-32, 133-37, 133-42, 133-49, and 133-55 halted with immutable outcomes " <>
        "preserved. Plan 133-56 remains blocked on its failed Plan 55 prerequisite; independent " <>
        "Plan 133-57 is the only runnable plan. EVID-01 through EVID-04 and TRUTH-08 remain pending."

    halted == expected_halts and String.contains?(section, expected)
  end

  defp current_plan57_handoff_detail?(section, 56, 50, 1, 57, halted) do
    expected_halts = MapSet.new([27, 32, 37, 42, 49, 55])

    expected =
      "**Plans**: 56/57 plans summarized; 50 complete (including diagnostic Plan 133-53), and " <>
        "Plans 133-27, 133-32, 133-37, 133-42, 133-49, and 133-55 halted with immutable outcomes " <>
        "preserved. Plan 133-56 remains blocked on its failed Plan 55 prerequisite; Plan 133-57 " <>
        "completed local recovery only. EVID-01 through EVID-04 and TRUTH-08 remain pending."

    halted == expected_halts and String.contains?(section, expected)
  end

  defp current_plan57_handoff_detail?(section, 56, 49, 1, 57, halted) do
    expected_halts = MapSet.new([27, 32, 37, 42, 49, 55, 57])

    expected =
      "**Plans**: 56/57 plans summarized; 49 complete (including diagnostic Plan 133-53), and " <>
        "Plans 133-27, 133-32, 133-37, 133-42, 133-49, 133-55, and 133-57 halted with immutable " <>
        "outcomes preserved. Plan 133-56 remains blocked on its failed Plan 55 prerequisite. " <>
        "EVID-01 through EVID-04 and TRUTH-08 remain pending."

    halted == expected_halts and String.contains?(section, expected)
  end

  defp current_plan57_handoff_detail?(
         _section,
         _summarized,
         _completed,
         _pending,
         _total,
         _halted
       ),
       do: false

  defp current_plan58_handoff_detail?(section, 56, 49, 5, 61, halted) do
    expected_halts = MapSet.new([27, 32, 37, 42, 49, 55, 57])

    expected =
      "**Plans**: 56/61 plans summarized; 49 complete (including diagnostic Plan 133-53), and " <>
        "Plans 133-27, 133-32, 133-37, 133-42, 133-49, 133-55, and 133-57 halted with immutable " <>
        "outcomes preserved. Plan 133-56 remains blocked on its failed Plan 55 prerequisite. " <>
        "New gap plans 133-58 through 133-61 are pending. EVID-01 through EVID-04 and TRUTH-08 remain pending."

    halted == expected_halts and String.contains?(section, expected)
  end

  defp current_plan58_handoff_detail?(section, 57, 50, 4, 61, halted) do
    expected_halts = MapSet.new([27, 32, 37, 42, 49, 55, 57])

    expected =
      "**Plans**: 57/61 plans summarized; 50 complete (including diagnostic Plan 133-53), and " <>
        "Plans 133-27, 133-32, 133-37, 133-42, 133-49, 133-55, and 133-57 halted with immutable " <>
        "outcomes preserved. Plan 133-56 remains blocked on its failed Plan 55 prerequisite; " <>
        "Plans 133-59 through 133-61 remain pending. EVID-01 through EVID-04 and TRUTH-08 remain pending."

    halted == expected_halts and String.contains?(section, expected)
  end

  defp current_plan58_handoff_detail?(
         _section,
         _summarized,
         _completed,
         _pending,
         _total,
         _halted
       ),
       do: false

  defp current_new_chain_handoff_detail?(section, 58, 51, 3, 61, halted) do
    expected_halts = MapSet.new([27, 32, 37, 42, 49, 55, 57])

    expected =
      "**Plans**: 58/61 plans summarized; 51 complete (including diagnostic Plan 133-53), and " <>
        "Plans 133-27, 133-32, 133-37, 133-42, 133-49, 133-55, and 133-57 halted with immutable " <>
        "outcomes preserved. Plan 133-56 remains blocked; Plans 133-60 and 133-61 remain pending. " <>
        "EVID-01 through EVID-04 and TRUTH-08 remain pending."

    halted == expected_halts and String.contains?(section, expected)
  end

  defp current_new_chain_handoff_detail?(section, 59, 52, 2, 61, halted) do
    expected_halts = MapSet.new([27, 32, 37, 42, 49, 55, 57])

    expected =
      "**Plans**: 59/61 plans summarized; 52 complete (including diagnostic Plan 133-53), and " <>
        "Plans 133-27, 133-32, 133-37, 133-42, 133-49, 133-55, and 133-57 halted with immutable " <>
        "outcomes preserved. Plan 133-56 remains blocked; Plan 133-61 remains pending. " <>
        "EVID-01 through EVID-04 and TRUTH-08 remain pending."

    halted == expected_halts and String.contains?(section, expected)
  end

  defp current_new_chain_handoff_detail?(
         _section,
         _summarized,
         _completed,
         _pending,
         _total,
         _halted
       ),
       do: false

  defp current_plan61_terminal_detail?(section, 60, 53, 1, 61, halted) do
    expected_halts = MapSet.new([27, 32, 37, 42, 49, 55, 57])

    expected =
      "**Plans**: 60/61 plans summarized; 53 complete (including diagnostic Plan 133-53), and " <>
        "Plans 133-27, 133-32, 133-37, 133-42, 133-49, 133-55, and 133-57 halted with immutable " <>
        "outcomes preserved. Plan 133-56 remains blocked; EVID-01 through EVID-04 and TRUTH-08 " <>
        "are complete after terminal Plan 61 automation."

    halted == expected_halts and String.contains?(section, expected)
  end

  defp current_plan61_terminal_detail?(section, 61, 53, 1, 62, halted) do
    expected_halts = MapSet.new([27, 32, 37, 42, 49, 55, 57, 59])

    expected =
      "**Plans**: 61/62 plans summarized; 53 complete (including diagnostic Plan 133-53), and " <>
        "Plans 133-27, 133-32, 133-37, 133-42, 133-49, 133-55, 133-57, and 133-59 halted with " <>
        "immutable outcomes preserved. Plan 133-56 remains blocked; EVID-01 through EVID-04 and " <>
        "TRUTH-08 are complete after terminal Plan 61 automation."

    halted == expected_halts and String.contains?(section, expected)
  end

  defp current_plan61_terminal_detail?(
         _section,
         _summarized,
         _completed,
         _pending,
         _total,
         _halted
       ),
       do: false

  defp current_plan62_handoff_detail?(section, 58, 50, 4, 62, halted) do
    expected_halts = MapSet.new([27, 32, 37, 42, 49, 55, 57, 59])

    expected =
      "**Plans**: 58/62 plans summarized; 50 complete (including diagnostic Plan 133-53), and " <>
        "Plans 133-27, 133-32, 133-37, 133-42, 133-49, 133-55, 133-57, and 133-59 halted with " <>
        "immutable outcomes preserved. Plan 133-56 remains blocked on its failed Plan 55 prerequisite. " <>
        "Plan 133-62 is the fresh local recovery; pending Plans 133-60 and 133-61 consume its qualified result. " <>
        "EVID-01 through EVID-04 and TRUTH-08 remain pending."

    halted == expected_halts and String.contains?(section, expected)
  end

  defp current_plan62_handoff_detail?(
         _section,
         _summarized,
         _completed,
         _pending,
         _total,
         _halted
       ),
       do: false

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

  defp validate_execution_checkboxes(section, summary_state, total) do
    Enum.reduce_while(1..total, :ok, fn plan, :ok ->
      id = "133-#{String.pad_leading(Integer.to_string(plan), 2, "0")}-PLAN.md"

      captures =
        Regex.scan(~r/^- \[([ x])\] #{Regex.escape(id)}(?:\s| |$)/m, section,
          capture: :all_but_first
        )

      completed_or_halted = MapSet.union(summary_state.completed, summary_state.halted)
      expected_checked = MapSet.member?(completed_or_halted, plan)

      case captures do
        [[checkbox]] when checkbox == "x" == expected_checked ->
          {:cont, :ok}

        _ ->
          if MapSet.member?(summary_state.halted, plan) do
            {:halt, {:error, "Plan #{plan} must remain checked while halted"}}
          else
            {:halt, {:error, "summary/checkbox mismatch for #{id}"}}
          end
      end
    end)
  end

  defp validate_execution_progress_row(
         root,
         roadmap,
         56,
         61,
         :local_recovery_halted_57
       ) do
    pre_wave_row =
      ~r/^\|\s*133\.\s*Evidence Charter and Live Truth\s*\|\s*56\/57\s*\|\s*In Progress\s*\|\s*\|$/m

    if orchestrator_plan58_pending_from_count?(root, 57) and
         length(Regex.scan(pre_wave_row, roadmap)) == 1 do
      :ok
    else
      {:error,
       "roadmap Progress row must retain the bounded 56/57 pre-wave state only while Plan 58 remains orchestrator-pending"}
    end
  end

  defp validate_execution_progress_row(_root, roadmap, summarized_count, total, lifecycle) do
    pattern =
      ~r/^\|\s*133\.\s*Evidence Charter and Live Truth\s*\|\s*(\d+)\/#{total}\s*\|\s*([^|]+)\|\s*([^|]*)\|$/m

    case Regex.scan(pattern, roadmap, capture: :all_but_first) do
      [[count, status, completed]] ->
        {expected_status, completion_valid?} =
          if lifecycle in [
               :qualified_success,
               :qualified_success_42,
               :qualified_success_61,
               :terminal_complete_68
             ] do
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

    {:ok, base_lifecycle} =
      if mode in [:execution, :execution_complete],
        do: closure_lifecycle(summary_state),
        else: branch_lifecycle(summary_state)

    {:ok, lifecycle} =
      if mode in [:execution, :execution_complete],
        do: execution_lifecycle_from_state(base_lifecycle, summary_state),
        else: {:ok, base_lifecycle}

    requirements_complete? =
      lifecycle in [
        :qualified_success,
        :qualified_success_42,
        :qualified_success_61,
        :terminal_complete_68
      ]

    total = total_plans(root, mode)

    with :ok <- validate_state(root, summarized_count, lifecycle, total),
         :ok <- validate_requirements(root, requirements_complete?) do
      :ok
    end
  end

  defp validate_state(root, summarized_count, lifecycle, total) do
    {expected_status, expected_plan} =
      cond do
        total == 62 and summarized_count == total - 1 and lifecycle == :qualified_success_61 ->
          {"complete", total}

        total == 61 and summarized_count == total - 1 and lifecycle == :qualified_success_61 ->
          {"complete", total}

        total == 62 and summarized_count == 58 and lifecycle == :qualification_halted_59 ->
          {"executing", 62}

        total == 61 and lifecycle == :local_recovery_complete_58 and
            orchestrator_plan58_pending_from_count?(root, summarized_count) ->
          {"executing", 58}

        total == 57 and summarized_count == 55 and
            lifecycle == :local_recovery_pending_57 ->
          {"executing", 57}

        total == 57 and summarized_count == 56 and
            lifecycle in [:local_recovery_complete_57, :local_recovery_halted_57] ->
          {"executing", 57}

        total == 56 and summarized_count == 54 and lifecycle == :pending_plan55 ->
          {"verifying", 55}

        total == 56 and summarized_count == 55 and lifecycle == :qualified_local_55 ->
          {"verifying", 56}

        total == 56 and summarized_count == 56 and lifecycle == :terminal_halted_56 ->
          {"blocked", 56}

        total > 42 and summarized_count == total and
            lifecycle in [:qualified_success, :qualified_success_42, :qualified_success_61] ->
          {"complete", total}

        total > 42 and summarized_count == total ->
          {"verifying", total}

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
      # GSD's completed_plans counter tracks terminal summaries, including
      # immutable halted outcomes. Keep it aligned with the roadmap's summary
      # count when Plan 57 completes locally or records a halt.
      expected_completed_plans =
        if total == 61 and lifecycle == :local_recovery_complete_58 and
             orchestrator_plan58_pending_from_count?(root, summarized_count),
           do: summarized_count - 1,
           else: summarized_count

      cond do
        Map.get(progress, "total_plans") != total ->
          {:error, "STATE total_plans must be #{total}"}

        Map.get(progress, "completed_plans") != expected_completed_plans ->
          {:error, "STATE completed_plans must equal #{expected_completed_plans}"}

        Map.get(decoded, "status") != expected_status ->
          {:error, "STATE status must be #{expected_status} for the #{lifecycle} branch"}

        not Regex.match?(~r/^Plan:\s*#{expected_plan} of #{total}(?:\s+.*)?$/m, body) ->
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
    existing_gap_records =
      Enum.filter(records, &String.starts_with?(&1.key, ["133-50-", "133-51-", "133-52-"]))

    new_gap_records = Enum.filter(records, &String.starts_with?(&1.key, ["133-53-", "133-54-"]))

    final_gap_records =
      Enum.filter(records, &String.starts_with?(&1.key, ["133-55-", "133-56-", "133-57-"]))

    independent_qualification_records =
      Enum.filter(
        records,
        &String.starts_with?(&1.key, ["133-58-", "133-59-", "133-60-", "133-61-", "133-62-"])
      )

    intro =
      "Plans 50–52 execute in repair-first order after the existing immutable validation history. Plan 50 precedes 51 and 52; Plans 48–49 remain pending until Plan 52 and independent authorization gates complete. These records grant no acceptance credit."

    existing_addendum =
      @plans_50_heading <>
        "\n\n" <> intro <> "\n\n" <> Enum.map_join(existing_gap_records, "\n", &render_record/1)

    prior_gap_addendum =
      case new_gap_records do
        [] ->
          existing_addendum

        records ->
          new_intro =
            "Plans 53–54 append after the existing gap-closure records. Plan 53 records its bounded diagnosis without requirement credit; Plan 54 depends on Plan 53's completed summary. These records grant no acceptance credit."

          existing_addendum <>
            "\n\n" <>
            @plans_53_heading <>
            "\n\n" <> new_intro <> "\n\n" <> Enum.map_join(records, "\n", &render_record/1)
      end

    gap_closure_addendum =
      case final_gap_records do
        [] ->
          prior_gap_addendum

        records ->
          final_intro =
            "Plans 55–57 append after the existing gap-closure records. Plan 55 preserves its immutable halted qualification facts, Plan 56 remains blocked on its literal Plan 55 prerequisite, and Plan 57 records independent local recovery only. None of these records grants Phase 133 requirement credit or remote-action authority."

          prior_gap_addendum <>
            "\n\n" <>
            @plans_55_heading <>
            "\n\n" <> final_intro <> "\n\n" <> Enum.map_join(records, "\n", &render_record/1)
      end

    case independent_qualification_records do
      [] ->
        gap_closure_addendum

      records ->
        intro =
          "Plan 59 remains immutable halted history. Independent Plan 62 binds a fresh local qualification and report authorities; Plan 60 consumes only its qualified SHA/ref pair, and Plan 61 owns terminal receipt reconciliation. Plan 56 remains blocked, and local evidence grants no requirement credit."

        gap_closure_addendum <>
          "\n\n" <>
          @plans_58_heading <>
          "\n\n" <> intro <> "\n\n" <> Enum.map_join(records, "\n", &render_record/1)
    end
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

# Library loading is only for an in-process caller. Explicit CLI verification
# must execute even if a caller accidentally inherits the test loader's flag.
unless System.get_env("RINDLE_PHASE_133_RECONCILIATION_LIBRARY_ONLY") == "1" and
         not Enum.any?(System.argv(), &(&1 == "--root" or String.starts_with?(&1, "--expect-"))) do
  case Rindle.ValidatePhase133Reconciliation.run(System.argv()) do
    :ok ->
      :ok

    {:error, message} ->
      IO.puts(:stderr, "[validate-phase-133-reconciliation] #{message}")
      System.halt(1)
  end
end
