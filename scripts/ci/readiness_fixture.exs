Code.require_file("../maintainer/validate_exact_head_readiness.exs", __DIR__)

defmodule ReadinessFixture do
  alias Rindle.ExactHeadReadiness, as: V

  def put(root, path, value) do
    bytes = if is_binary(value), do: value, else: Jason.encode!(value)
    File.mkdir_p!(Path.dirname(Path.join(root, path)))
    File.write!(Path.join(root, path), bytes)
    %{"path" => path, "sha256" => V.sha256(bytes)}
  end

  def cleanup do
    %{
      "state" => "observed",
      "errors" => [],
      "inventories" =>
        Enum.map(
          V.resource_kinds(),
          &%{"kind" => &1, "before" => [], "after" => [], "allowed" => []}
        )
    }
  end

  def adoption do
    %{
      "class" => "maintainer_operated_synthetic",
      "independent_pilot_credit" => false,
      "pilot_01" => "open",
      "pilot_02" => "open",
      "one_point_zero_authority" => false
    }
  end

  def interval(n \\ 0) do
    %{
      "started_at" => "2026-10-22T10:#{String.pad_leading(to_string(n), 2, "0")}:00Z",
      "completed_at" => "2026-10-22T10:#{String.pad_leading(to_string(n + 1), 2, "0")}:00Z"
    }
  end

  def fixture do
    root =
      Path.join(
        System.fetch_env!("RINDLE_READINESS_TEST_ROOT"),
        "case-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(root)

    input_files =
      Map.new(
        V.input_paths(),
        &{&1,
         put(
           root,
           "inputs/#{&1}",
           if(
             &1 in V.snapshot_controls() or &1 in Rindle.ReadinessNightly.control_paths() or
               &1 in [
                 ".github/workflows/ci.yml",
                 ".github/workflows/nightly.yml",
                 ".github/workflows/release.yml",
                 "scripts/maintainer/readiness_workflow.exs",
                 "scripts/maintainer/readiness_hex_audit.exs",
                 "scripts/maintainer/land_release_train_baseline.py",
                 ".github/actions/repository-credential/action.yml",
                 "scripts/maintainer/repository_credential.py",
                 ".github/workflows/release-please-automerge.yml",
                 ".github/workflows/branch-protection-apply.yml",
                 "mix.lock",
                 "examples/adoption_demo/mix.lock"
               ],
             do: File.read!(&1),
             else: "fixture committed input #{&1}"
           )
         )}
      )

    package_files =
      Map.new(
        ~w(package_tar_sha256 package_metadata_sha256 package_tree_sha256),
        &{&1, put(root, "package/#{&1}", "fixture bytes #{&1}")}
      )

    manifest = %{
      "schema_version" => 1,
      "repository" => "szTheory/rindle",
      "subject_sha" => String.duplicate("a", 40),
      "remote_main_before" => String.duplicate("a", 40),
      "remote_main_after" => String.duplicate("a", 40),
      "policy" => V.policy(),
      "validator_sha256" =>
        V.sha256(File.read!("scripts/maintainer/validate_exact_head_readiness.exs")),
      "state" => "complete",
      "evidence_mode" => "fixture",
      "toolchain" => V.toolchain(),
      "input_identity" => Map.new(input_files, fn {p, r} -> {p, r["sha256"]} end),
      "input_files" => input_files,
      "package_identity" => Map.new(package_files, fn {p, r} -> {p, r["sha256"]} end),
      "package_files" => package_files,
      "runtime_evidence" => %{
        "elixir" => put(root, "runtime/elixir.txt", "1.17.3\n27.3.4.15\n"),
        "node" => put(root, "runtime/node.txt", "v20.18.1\n")
      },
      "observation_interval" => interval(),
      "cleanup" => cleanup(),
      "adoption" => adoption()
    }

    proofs =
      Enum.map(V.required_proofs(), fn id ->
        receipt =
          Map.take(
            manifest,
            ~w(repository subject_sha policy validator_sha256 toolchain input_identity package_identity observation_interval evidence_mode)
          )

        receipt =
          Map.merge(receipt, %{
            "schema_version" => 1,
            "id" => id,
            "state" => "complete",
            "outcome" => "passed",
            "applicability" => "required",
            "references" => []
          })

        receipt =
          if id in V.mutable_proofs() do
            n = normalized(id, manifest)

            n =
              if id == "nightly-scheduled" do
                {:ok, {_name, zip}} =
                  :zip.create(
                    ~c"incident.zip",
                    [{~c"nightly-incident-verdict.json", Jason.encode!(n["incident"])}],
                    [:memory]
                  )

                archive = put(root, "artifacts/incident.zip", zip)

                n
                |> Map.put("incident_artifact", archive)
                |> Map.put("incident_artifact_sha256", archive["sha256"])
              else
                n
              end

            n =
              if id == "remote-inventory" do
                database = put(root, "hex-database.json", %{"audits" => hex_payloads()})

                n
                |> put_in(["sources", "hex", "database"], database)
                |> put_in(["sources", "hex", "database_sha256"], database["sha256"])
                |> put_in(["sources", "hex", "count"], 2)
              else
                n
              end

            observations =
              Enum.map(["before", "after"], &put(root, "observations/#{id}-#{&1}.json", n))

            Map.merge(receipt, %{
              "references" => observations ++ extra_refs(n, id),
              "source" => %{
                "complete" => true,
                "authenticated" => true,
                "query" => "fixture/#{id}",
                "pages" => 1,
                "observation_interval" => interval(),
                "before_sha256" => hd(observations)["sha256"],
                "after_sha256" => List.last(observations)["sha256"],
                "observations" => observations,
                "policy" => V.policy(),
                "normalized" => n
              }
            })
          else
            output = put(root, "logs/#{id}.txt", "fixture command completed: #{id}\n")

            Map.merge(receipt, %{
              "references" => [output],
              "cleanup" => cleanup(),
              "tool_identity" => %{"mix" => V.sha256("fixture tool")},
              "command" => %{
                "state" => "completed",
                "exit_code" => 0,
                "duration_ms" => 1,
                "argv" => V.command_prefix(id),
                "output" => output
              }
            })
          end

        Map.put(put(root, "receipts/#{id}.json", receipt), "id", id)
      end)

    manifest = Map.put(manifest, "proofs", proofs)
    {root, manifest}
  end

  def extra_refs(n, "nightly-scheduled"), do: [n["incident_artifact"]]
  def extra_refs(n, "remote-inventory"), do: [n["sources"]["hex"]["database"]]
  def extra_refs(_n, _id), do: []

  def hex_payloads do
    Enum.map(
      [{"root", "mix.lock"}, {"examples/adoption_demo", "examples/adoption_demo/mix.lock"}],
      fn {scope, path} ->
        lock = File.read!(path)
        {:ok, packages} = Rindle.ReadinessHexAudit.lock_packages(lock)

        database =
          Enum.flat_map(packages, fn p ->
            outer =
              p["outer_checksum"]
              |> Base.decode16!(case: :lower)
              |> :erlang.term_to_binary()
              |> V.sha256()

            [
              %{
                "key" => ["outer_checksum", "hexpm", p["package"], p["version"]],
                "value_sha256" => outer
              },
              %{
                "key" => ["advisories", "hexpm", p["package"], p["version"]],
                "value_sha256" => V.sha256("fixture advisories")
              },
              %{
                "key" => ["versions", "hexpm", p["package"]],
                "value_sha256" => V.sha256("fixture versions")
              }
            ]
          end)

        %{
          "schema" => "rindle-readiness-hex-v1",
          "scope" => scope,
          "lock_sha256" => V.sha256(lock),
          "hex_version" => "2.5.1",
          "online" => true,
          "https_verified" => true,
          "registry_signature_verification" => true,
          "database" => database,
          "packages" =>
            Enum.map(
              packages,
              &(Map.take(&1, ~w(package version))
                |> Map.merge(%{"retired" => false, "advisories" => []}))
            )
        }
      end
    )
  end

  def normalized(id, manifest) do
    base = Map.take(manifest, ~w(repository subject_sha))

    specific =
      case id do
        "ci-main" ->
          run("CI", "push", "ci.yml")

        "nightly-scheduled" ->
          run("Nightly", "schedule", "nightly.yml")

        "protection" ->
          %{
            "classic_visible" => true,
            "rulesets_visible" => true,
            "organization_visible" => true,
            "enforced" => true,
            "strict" => true,
            "classic_admin_enforced" => false,
            "active_rulesets" => [],
            "bypass_actors" => [],
            "effective_checks" => [%{"context" => "CI Summary", "app_id" => 15368}]
          }

        "adoption-parity" ->
          %{
            "adoption" => adoption(),
            "adoption_policy" => "rindle-synthetic-adoption-v1",
            "authoritative_inputs" =>
              Map.take(
                manifest["input_identity"],
                ~w(.planning/REQUIREMENTS.md .planning/PROJECT.md mix.exs .release-please-manifest.json release-please-config.json)
              )
          }

        "remote-inventory" ->
          %{
            "ledger_sha256" => manifest["input_identity"][".planning/INBOX-LEDGER.json"],
            "sources" =>
              Map.new(
                ~w(issues pulls checks statuses advisories dependabot hex protection absent),
                fn source ->
                  {source,
                   %{
                     "complete" => true,
                     "authorized" => true,
                     "reconciled" => true,
                     "changed" => false,
                     "count" => 0,
                     "identity_sha256" => V.sha256("fixture inventory"),
                     "database_sha256" => V.sha256("fixture Hex database")
                   }}
                end
              )
          }
      end

    Map.merge(base, specific)
  end

  def run(name, event, workflow) do
    {:ok, topology} =
      Rindle.ReadinessWorkflow.derive(File.read!(".github/workflows/#{workflow}"), %{
        "repository" => "szTheory/rindle",
        "event" => event,
        "branch" => "main"
      })

    value = %{
      "name" => name,
      "event" => event,
      "workflow" => workflow,
      "branch" => "main",
      "run_id" => 10,
      "attempt" => 2,
      "latest_run_id" => 10,
      "rechecked_attempt" => 2,
      "state" => "completed",
      "conclusion" => "success",
      "expected_jobs" => Enum.map(topology["jobs"], & &1["name"]),
      "topology_sha256" => topology["workflow_sha256"],
      "topology_resolved" => true,
      "jobs" =>
        Enum.with_index(topology["jobs"], 100)
        |> Enum.map(fn {j, id} ->
          %{
            "id" => id,
            "name" => j["name"],
            "state" => "completed",
            "conclusion" => if(j["applicable"], do: "success", else: "skipped")
          }
        end)
    }

    if event == "schedule" do
      Map.merge(value, %{
        "incident_artifact_id" => 300,
        "incident_artifact_sha256" => V.sha256("fixture artifact"),
        "incident" => %{
          "schema" => "rindle-nightly-incident-verdict-v1",
          "repository" => "szTheory/rindle",
          "sha" => String.duplicate("a", 40),
          "workflow_name" => "Nightly",
          "workflow_ref" => "szTheory/rindle/.github/workflows/nightly.yml@refs/heads/main",
          "url" => "https://github.com/szTheory/rindle/actions/runs/10",
          "event" => "schedule",
          "ref" => "refs/heads/main",
          "run_id" => 10,
          "run_attempt" => 2,
          "verdict" => %{
            "verdict" => "green",
            "errors" => [],
            "jobs" =>
              Enum.map(~w(compat-matrix dialyzer gcs-soak package-consumer-gcs-live), fn id ->
                %{
                  "name" => id,
                  "result" => "success",
                  "applicable" => true,
                  "execution" => "passed",
                  "reason" => "",
                  "errors" => [],
                  "status" => "passed",
                  "applicability_rule" =>
                    if(id in ~w(gcs-soak package-consumer-gcs-live),
                      do: "upstream-repository-and-required-secrets",
                      else: "always"
                    )
                }
              end)
          }
        }
      })
    else
      value
    end
  end

  def context(root, manifest, envelope \\ nil) do
    files =
      Path.wildcard(Path.join(root, "**/*"), match_dot: true) |> Enum.filter(&File.regular?/1)

    %{
      objects: Map.new(files, &{Path.relative_to(&1, root), File.read!(&1)}),
      manifest_sha256: V.sha256(Jason.encode!(manifest)),
      validator_sha256: manifest["validator_sha256"],
      refresh_envelope: envelope
    }
  end

  def change(root, m, id, fun) do
    refs =
      Enum.map(m["proofs"], fn ref ->
        if ref["id"] == id do
          value = root |> Path.join(ref["path"]) |> File.read!() |> Jason.decode!() |> fun.()
          Map.put(put(root, ref["path"], value), "id", id)
        else
          ref
        end
      end)

    Map.put(m, "proofs", refs)
  end

  def change_source(root, m, id, fun) do
    change(root, m, id, fn r ->
      n = fun.(r["source"]["normalized"])
      observations = Enum.map(["before", "after"], &put(root, "mutated/#{id}-#{&1}.json", n))

      source =
        r["source"]
        |> Map.put("normalized", n)
        |> Map.put("observations", observations)
        |> Map.put("before_sha256", hd(observations)["sha256"])
        |> Map.put("after_sha256", List.last(observations)["sha256"])

      r |> Map.put("source", source) |> Map.put("references", observations ++ extra_refs(n, id))
    end)
  end

  def refresh(root, m) do
    refs =
      m["proofs"]
      |> Enum.filter(&(&1["id"] in V.mutable_proofs()))
      |> Enum.map(fn ref ->
        value =
          root
          |> Path.join(ref["path"])
          |> File.read!()
          |> Jason.decode!()
          |> Map.put("observation_interval", interval(2))

        value = put_in(value, ["source", "observation_interval"], interval(2))
        Map.put(put(root, "refresh/#{ref["id"]}.json", value), "id", ref["id"])
      end)

    Map.merge(
      Map.take(
        m,
        ~w(repository subject_sha policy validator_sha256 remote_main_before remote_main_after adoption)
      ),
      %{
        "schema_version" => 1,
        "manifest_sha256" => V.sha256(Jason.encode!(m)),
        "observation_interval" => interval(2),
        "proofs" => refs,
        "verdict" => "ready"
      }
    )
  end
end
