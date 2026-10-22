defmodule Rindle.ReadinessHexAudit do
  @moduledoc false
  def lock_packages(bytes) when is_binary(bytes) and byte_size(bytes) <= 524_288 do
    {:ok, quoted} = Code.string_to_quoted(bytes, emit_warnings: false)
    true = Macro.quoted_literal?(quoted)
    {lock, []} = Code.eval_quoted(quoted, [])
    true = is_map(lock) and map_size(lock) in 1..2000

    packages =
      Enum.map(lock, fn {_app, record} ->
        true = is_tuple(record) and tuple_size(record) == 8 and elem(record, 0) == :hex
        {:hex, name, version, _inner, _builders, _deps, "hexpm", outer} = record
        true = is_atom(name) and is_binary(version) and is_binary(outer)
        true = Regex.match?(~r/\A[a-z][a-z0-9_]*\z/, Atom.to_string(name))
        true = Regex.match?(~r/\A[0-9a-f]{64}\z/, outer)
        {:ok, _} = Version.parse(version)
        %{"package" => Atom.to_string(name), "version" => version, "outer_checksum" => outer}
      end)
      |> Enum.sort_by(& &1["package"])

    true = length(Enum.uniq_by(packages, & &1["package"])) == length(packages)
    {:ok, packages}
  rescue
    _ -> {:error, "lock_inventory_unavailable"}
  end

  def lock_packages(_), do: {:error, "lock_inventory_unavailable"}

  def audit(output, extra_packages \\ []) do
    {:ok, expected} = lock_packages(File.read!("mix.lock"))
    Mix.Local.append_archives()
    true = Code.ensure_loaded?(Hex)
    Hex.start()
    registry = Hex.Registry.Server
    :ok = registry.open(check_version: false)

    true =
      is_list(extra_packages) and length(extra_packages) <= 100 and
        Enum.all?(extra_packages, &(is_binary(&1) and Regex.match?(~r/\A[a-z][a-z0-9_]*\z/, &1)))

    :ok = registry.prefetch(Enum.map(extra_packages, &{"hexpm", &1}))
    Mix.Task.run("hex.audit", [])
    lock = Mix.Dep.Lock.read()

    rows =
      Enum.flat_map(lock, fn {_app, tuple} ->
        case Hex.Utils.lock(tuple) do
          %{repo: repo, name: package, version: version} ->
            true = repo in [nil, "hexpm"]
            repo = repo || "hexpm"
            checksum = registry.outer_checksum(repo, package, version)
            true = is_binary(checksum) and byte_size(checksum) == 32

            true =
              Base.encode16(checksum, case: :lower) ==
                Enum.find(expected, &(&1["package"] == package))["outer_checksum"]

            advisories = registry.advisories(repo, package, version)
            true = is_list(advisories)
            retired = registry.retired(repo, package, version)

            [
              %{
                "package" => package,
                "version" => version,
                "retired" => retired != nil,
                "advisories" =>
                  Enum.map(advisories, fn advisory ->
                    %{"id" => advisory.id, "severity" => advisory.severity}
                  end)
              }
            ]

          nil ->
            []
        end
      end)

    latest =
      Map.new(extra_packages, fn package ->
        {:ok, versions} = registry.versions("hexpm", package)
        stable = Enum.filter(versions, &(&1.pre == []))
        true = stable != []
        {package, Enum.max(stable, Version) |> to_string()}
      end)

    :ok = registry.close()
    cache = Path.join(System.fetch_env!("HEX_HOME"), "cache.ets")
    {:ok, table} = :ets.file2tab(String.to_charlist(cache), verify: true)
    sha = fn bytes -> :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower) end

    snapshot =
      :ets.tab2list(table)
      |> Enum.reject(fn {key, _value} ->
        key == :last_update or (is_tuple(key) and elem(key, 0) == :timestamp)
      end)
      |> Enum.map(fn {key, value} ->
        key = if is_tuple(key), do: Tuple.to_list(key), else: [key]

        %{
          "key" =>
            Enum.map(key, fn item -> if is_atom(item), do: Atom.to_string(item), else: item end),
          "value_sha256" => sha.(:erlang.term_to_binary(value))
        }
      end)
      |> Enum.sort_by(& &1["key"])

    :ets.delete(table)

    payload = %{
      "schema" => "rindle-readiness-hex-v1",
      "latest_versions" => latest,
      "lock_sha256" => sha.(File.read!("mix.lock")),
      "hex_version" => Hex.version(),
      "online" => Hex.State.fetch!(:offline) == false,
      "https_verified" => Hex.State.fetch!(:unsafe_https) == false,
      "registry_signature_verification" => Hex.State.fetch!(:unsafe_registry) == false,
      "packages" => Enum.sort_by(rows, & &1["package"]),
      "database" => snapshot
    }

    File.write!(output, :json.encode(payload), [:exclusive])
  end
end

case System.argv() do
  ["--audit", output] ->
    Rindle.ReadinessHexAudit.audit(output)

  ["--audit", output, packages] ->
    Rindle.ReadinessHexAudit.audit(output, :json.decode(File.read!(packages)))

  ["--inventory", input, output] ->
    {:ok, packages} = Rindle.ReadinessHexAudit.lock_packages(File.read!(input))
    File.write!(output, :json.encode(%{"packages" => packages}), [:exclusive])

  _ ->
    :ok
end
