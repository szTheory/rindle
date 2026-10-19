# Live residue scanner (CRAFT-04 / CRAFT-06).
#
# Scans tracked, shipped files for planning-era identifiers and craft residue
# and compares every hit against a removal-only, area-sharded allowlist.
#
#   mix run --no-start scripts/maintainer/scan_live_residue.exs \
#     [--root DIR] [--allowlist-dir DIR] \
#     (--check | --list | --regen-baseline) [--require-no-pending AREA|all]
#
# Exit codes: 0 clean, 1 violations (one `path:line: class: text` per hit),
# 64 usage error.
#
# Scanned file content is matched with Regex only; it is never compiled or
# executed. Patterns are assembled from fragments so this file never matches
# its own rules (and it is additionally on the fixed self-exclusion list).

defmodule Rindle.Maintainer.LiveResidueScan do
  @schema "rindle-live-residue-allowlist-v1"

  @areas ~w(lib automation_generators automation_workflows install_smoke unit_tests_a
            unit_tests_b examples_docs)

  @reason_classes ~w(pending-removal policy contract immutable-receipt fixture)

  @scope_dirs ~w(lib config scripts .github examples docker brandbook/src brandbook/tokens
                 priv/static/rindle_admin test guides)

  @scope_files ~w(mix.exs .formatter.exs .credo.exs .doctor.exs .dialyzer_ignore.exs
                  coveralls.json release-please-config.json README.md RUNNING.md
                  CONTRIBUTING.md AGENTS.md SECURITY.md brandbook/README.md)

  @lib_root_files ~w(mix.exs .formatter.exs .credo.exs .doctor.exs .dialyzer_ignore.exs
                     coveralls.json release-please-config.json)

  @root_docs ~w(README.md RUNNING.md CONTRIBUTING.md AGENTS.md SECURITY.md brandbook/README.md)

  @self_files [
    "scripts/maintainer/scan_live_residue.exs",
    "test/install_smoke/live_residue_scan_test.exs"
  ]
  @self_dir "scripts/maintainer/live_residue_allowlist/"

  @binary_exts ~w(.png .jpg .jpeg .gif .webp .ico .bmp .tif .tiff .avif .heic .woff .woff2
                  .ttf .otf .eot .mp4 .mov .webm .mkv .avi .mp3 .wav .ogg .flac .aac .m4a
                  .pdf .zip .gz .tgz .tar .bz2 .xz .7z .wasm .bin .beam .so .dylib .exe
                  .dat .jar .mpg .mpeg .3gp .ivf .y4m .opus)

  @vendor_prefix "examples/adoption_demo/priv/static/assets/vendor/"

  # Classes evaluated per decoded line. Each is `{class, kind, regex}`; `:line`
  # matches any line, `:comment` matches only the text of comment lines.
  defp line_classes do
    [
      {"decision-id", :line, ~r/(?<![A-Za-z])D-\d{1,3}(?:-\d{2})?\b/},
      {"requirement-id", :line, requirement_regex()},
      {"phase-ref", :line, ~r/\bPhase[ -]?\d{1,3}\b/},
      {"spec-ref", :line, spec_regex()},
      {"planning-path", :line, planning_regex()},
      {"milestone-ref", :line, ~r/(?<![A-Za-z0-9.])v1\.\d{1,2}\b/},
      {"plan-ref", :line, ~r/\bPlan[ -]\d{1,3}(?:-\d{1,3})?\b/},
      {"mojibake", :line, mojibake_regex()}
    ]
  end

  @requirement_prefixes ~w(CRAFT HYGIENE EVID TRUTH COV EPIPE GATE ISO LOCK OBS CACHE LANE HARD
                           INBOX SEC DEPS TWIN PIPE UPLIFT COHORT VIS ADMIN SAFE META MIGRATE
                           EVAL TRUST COMPAT STREAM LIFE DX MAINT TYPE)

  defp requirement_regex do
    Regex.compile!("\\b(?:" <> Enum.join(@requirement_prefixes, "|") <> ")-\\d{2}\\b")
  end

  defp spec_regex do
    Regex.compile!(
      "UI-" <>
        "SPEC|\\b\\d{2,3}-(?:RESEARCH|CONTEXT|PLAN|SUMMARY|VALIDATION)\\.md" <>
        "|\\b(?:CR|WR|IN)-\\d{2}\\b|Assumption A\\d"
    )
  end

  # The internal planning directory token, assembled from fragments.
  defp planning_regex, do: Regex.compile!("\\." <> "planning/")

  # Tracked paths whose file name carries phase or plan numbering.
  defp path_name_regex, do: ~r/(?:^|\/)[^\/]*(?:phase|plan)[_-]\d{2,3}(?:[_.-]|$)/i

  # Decoded-text mojibake: U+FFFD, U+00C3/U+00C2 followed by U+0080..U+00BF, or
  # U+00E2 U+20AC. Assembled with escapes so the source stays pure ASCII.
  defp mojibake_regex do
    Regex.compile!(
      "\\x{FFFD}|[\\x{00C3}\\x{00C2}][\\x{0080}-\\x{00BF}]|\\x{00E2}\\x{20AC}",
      "u"
    )
  end

  def areas, do: @areas
  def reason_classes, do: @reason_classes
  def schema, do: @schema
  def self_exclusions, do: @self_files ++ [@self_dir]

  # ---------------------------------------------------------------- file set

  def files(root) do
    case System.cmd("git", ["-C", root, "ls-files", "-z", "--" | @scope_dirs ++ @scope_files],
           stderr_to_stdout: true
         ) do
      {out, 0} ->
        out
        |> String.split("\0", trim: true)
        |> Enum.reject(&excluded?/1)
        |> Enum.filter(&File.regular?(Path.join(root, &1)))
        |> Enum.uniq()
        |> Enum.sort()

      {out, _} ->
        raise ArgumentError, "git ls-files failed in #{root}: #{String.trim(out)}"
    end
  end

  defp excluded?(path) do
    path in @self_files or
      String.starts_with?(path, @self_dir) or
      String.starts_with?(path, ".planning/") or
      String.starts_with?(path, @vendor_prefix) or
      Path.basename(path) in ["CHANGELOG.md", "mix.lock", "package-lock.json"]
  end

  defp binary?(path, content) do
    String.downcase(Path.extname(path)) in @binary_exts or
      :binary.match(binary_part(content, 0, min(byte_size(content), 8192)), <<0>>) != :nomatch
  end

  # ------------------------------------------------------------------- areas

  def area_of(path) do
    cond do
      path in @lib_root_files or starts?(path, ["lib/", "config/"]) ->
        "lib"

      path in @root_docs or
          starts?(path, ["examples/", "test/adopter/", "test/brandbook/", "guides/"]) ->
        "examples_docs"

      starts?(path, [
        "scripts/ci/",
        "brandbook/src/",
        "brandbook/tokens/",
        "priv/static/rindle_admin/"
      ]) ->
        "automation_generators"

      starts?(path, [".github/", "docker/", "scripts/"]) ->
        "automation_workflows"

      starts?(path, [
        "test/install_smoke/",
        "test/fixtures/ci_timing/",
        "test/fixtures/install_smoke/"
      ]) or
          direct_test_file?(path) ->
        "install_smoke"

      starts?(path, [
        "test/rindle/admin/",
        "test/rindle/av/",
        "test/rindle/backward_compat/",
        "test/rindle/config/",
        "test/rindle/contracts/",
        "test/rindle/delivery/",
        "test/rindle/domain/"
      ]) or direct_rindle_test_file?(path) ->
        "unit_tests_a"

      String.starts_with?(path, "test/") ->
        "unit_tests_b"

      true ->
        nil
    end
  end

  defp starts?(path, prefixes), do: Enum.any?(prefixes, &String.starts_with?(path, &1))

  defp direct_test_file?("test/" <> rest),
    do: not String.contains?(rest, "/") and String.ends_with?(rest, ".exs")

  defp direct_test_file?(_), do: false

  defp direct_rindle_test_file?("test/rindle/" <> rest), do: not String.contains?(rest, "/")
  defp direct_rindle_test_file?(_), do: false

  # -------------------------------------------------------------------- hits

  @doc "Returns `{file_count, hits}`; each hit is `%{path, class, line, text}`."
  def hits(root, files) do
    hits =
      files
      |> Enum.flat_map(&scan_file(root, &1))
      |> Enum.sort_by(&{&1.path, &1.class, &1.line, &1.text})

    {length(files), hits}
  end

  defp scan_file(root, rel) do
    case File.read(Path.join(root, rel)) do
      {:ok, content} -> scan_content(rel, content)
      {:error, _} -> []
    end
  end

  defp scan_content(rel, content) do
    path_name_hits(rel) ++ scan_text(rel, content)
  end

  defp path_name_hits(rel) do
    if Regex.match?(path_name_regex(), rel),
      do: [%{path: rel, class: "path-name", line: 1, text: rel}],
      else: []
  end

  defp scan_text(rel, content) do
    cond do
      binary?(rel, content) ->
        []

      not String.valid?(content) ->
        [%{path: rel, class: "mojibake", line: 1, text: "<invalid UTF-8>"}]

      true ->
        lines = content |> String.split("\n") |> Enum.map(&String.trim_trailing(&1, "\r"))
        line_hits(rel, lines)
    end
  end

  defp line_hits(rel, lines) do
    indexed = Enum.with_index(lines, 1)
    commented = annotate_comments(rel, indexed)

    per_line =
      Enum.flat_map(commented, fn {number, line, comment} ->
        plain =
          for {class, :line, regex} <- line_classes(), Regex.match?(regex, line) do
            %{path: rel, class: class, line: number, text: normalize(line)}
          end

        prose =
          if comment do
            for {class, :comment, regex} <- comment_classes(), Regex.match?(regex, comment) do
              %{path: rel, class: class, line: number, text: normalize(line)}
            end
          else
            []
          end

        plain ++ prose
      end)

    per_line ++ duplicated_prose_hits(rel, commented)
  end

  # Comment classes evaluated on the text of comment lines only.
  defp comment_classes do
    [
      {"narration", :comment, narration_regex()},
      {"artifact-comment", :comment, artifact_regex()},
      {"artifact-comment", :comment, artifact_word_regex()}
    ]
  end

  @narration_phrases [
    "previously",
    "formerly",
    "used to (?:be|do)",
    "was changed to",
    "now we",
    "has been (?:renamed|moved|removed|replaced)",
    "for now",
    "no longer"
  ]

  defp narration_regex do
    Regex.compile!("\\b(?:" <> Enum.join(@narration_phrases, "|") <> ")\\b", "i")
  end

  @artifact_phrases [
    "generated by (?:claude|chatgpt|gpt|copilot|gemini|cursor|codex|an? ai|ai|an? llm|llm|an? agent|agent)\\b",
    "ai-generated",
    "as an ai language model",
    "gsd:write" <> "-continue"
  ]

  defp artifact_regex do
    Regex.compile!(Enum.join(@artifact_phrases, "|"), "i")
  end

  defp artifact_word_regex, do: Regex.compile!("\\b(?:TO" <> "DO|FIX" <> "ME|XXX|HA" <> "CK)\\b")

  # Tags each line with its comment text (or nil). Besides single-line comment
  # markers this follows multi-line block comments (`<%!-- --%>`, `<!-- -->`,
  # `/* */`), and, in test files, the prose heredocs of `@moduledoc` / `@doc`,
  # which are non-public narration surfaces there.
  defp annotate_comments(rel, indexed) do
    test_file? = String.ends_with?(rel, "_test.exs")

    {tagged, _state} =
      Enum.map_reduce(indexed, nil, fn {line, number}, state ->
        trimmed = String.trim(line)

        cond do
          state != nil ->
            next = if Regex.match?(state, trimmed), do: nil, else: state
            {{number, line, strip_marker(trimmed)}, next}

          test_file? and Regex.match?(~r/^@(?:moduledoc|doc) """\s*$/, trimmed) ->
            {{number, line, nil}, ~r/^"""/}

          close = block_close(rel, trimmed) ->
            single_line? = Regex.match?(close, strip_open(trimmed))
            next = if single_line?, do: nil, else: close
            {{number, line, strip_marker(trimmed)}, next}

          true ->
            {{number, line, comment_text(rel, line)}, nil}
        end
      end)

    tagged
  end

  defp block_close(rel, trimmed) do
    ext = String.downcase(Path.extname(rel))

    cond do
      ext == ".json" ->
        nil

      String.starts_with?(trimmed, "<%!--") ->
        ~r/--%>/

      String.starts_with?(trimmed, "<!--") ->
        ~r/-->/

      ext in [".js", ".mjs", ".cjs", ".ts", ".css", ".scss"] and
          String.starts_with?(trimmed, "/*") ->
        ~r/\*\//

      true ->
        nil
    end
  end

  defp strip_open(trimmed), do: String.slice(trimmed, 4..-1//1)

  defp strip_marker(trimmed) do
    Regex.replace(~r/^(?:#+|\/\/+|\/\*+|\*+|<%!--|<!--)\s*/, trimmed, "")
  end

  # Returns the comment text (marker stripped) when the whole line is a comment.
  defp comment_text(path, line) do
    trimmed = String.trim_leading(line)

    if Regex.match?(comment_marker(String.downcase(Path.extname(path))), trimmed) do
      Regex.replace(~r/^(?:#+|\/\/+|\/\*+|\*+|<%!--|<!--)\s*/, trimmed, "")
    end
  end

  defp comment_marker(".md"), do: ~r/^<!--/
  defp comment_marker(".json"), do: ~r/\A\z\A/

  defp comment_marker(ext) when ext in [".js", ".mjs", ".cjs", ".ts", ".css", ".scss"],
    do: ~r/^(?:\/\/|\/\*|\*(?:\s|\/|$))/

  defp comment_marker(_ext), do: ~r/^(?:#(?!\{)|<%!--|<!--)/

  @stopwords ~w(the and for are but not you all any can had her was one our out has him his how
                its may new now old see two way who did get let put say she too use that this
                with from have were will they them then than into over such only also each when
                what which there their these those been being would could should about)

  # Word 4-grams of alphabetic tokens (length >= 3) repeated within two adjacent
  # comment lines; code-shaped tokens break a run, so identifiers never match.
  defp duplicated_prose_hits(rel, commented) do
    commented
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn
      [{_, _, first}, {number, line, second}] when is_binary(first) and is_binary(second) ->
        if MapSet.disjoint?(grams(first), grams(second)),
          do: [],
          else: [%{path: rel, class: "duplicated-prose", line: number, text: normalize(line)}]

      _ ->
        []
    end)
  end

  defp grams(text) do
    text
    |> String.downcase()
    |> String.split(~r/\s+/u, trim: true)
    |> Enum.map(&Regex.replace(~r/\A[.,;:()"'!?]+|[.,;:()"'!?]+\z/, &1, ""))
    |> Enum.chunk_by(&Regex.match?(~r/\A[a-z]+\z/, &1))
    |> Enum.filter(fn [first | _] -> Regex.match?(~r/\A[a-z]+\z/, first) end)
    |> Enum.flat_map(fn run ->
      run
      |> Enum.filter(&(String.length(&1) >= 3))
      |> Enum.chunk_every(4, 1, :discard)
    end)
    |> Enum.filter(fn gram ->
      length(Enum.uniq(gram)) >= 4 and Enum.any?(gram, &(&1 not in @stopwords))
    end)
    |> MapSet.new()
  end

  def normalize(line), do: line |> String.trim() |> String.replace(~r/\s+/u, " ")

  # --------------------------------------------------------------- allowlist

  @doc "Loads every shard in `dir`. Returns `{entries, errors}`."
  def load_allowlist(dir) do
    if File.dir?(dir) do
      dir
      |> Path.join("*.json")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.reduce({[], []}, fn file, {entries, errors} ->
        {new, errs} = load_shard(file)
        {entries ++ new, errors ++ errs}
      end)
    else
      {[], ["allowlist directory not found: #{dir}"]}
    end
  end

  defp load_shard(file) do
    name = Path.basename(file)
    area = Path.basename(file, ".json")

    with {:ok, raw} <- File.read(file),
         {:ok, %{"schema" => @schema, "area" => ^area, "entries" => entries}}
         when is_list(entries) <- Jason.decode(raw) do
      if area in @areas do
        Enum.reduce(entries, {[], []}, fn entry, {ok, errs} ->
          case validate_entry(entry, area, name) do
            :ok -> {ok ++ [Map.put(entry, "__shard", area)], errs}
            {:error, msg} -> {ok, errs ++ [msg]}
          end
        end)
      else
        {[], ["#{name}: unknown shard area #{inspect(area)}"]}
      end
    else
      _ -> {[], ["#{name}: not a valid #{@schema} shard whose area matches its file name"]}
    end
  end

  defp validate_entry(entry, area, name) when is_map(entry) do
    path = entry["path"]
    class = entry["class"]
    text = entry["text"]
    count = entry["count"]
    label = "#{name}: entry #{inspect(path)} #{inspect(class)}"

    cond do
      not (is_binary(path) and is_binary(class) and is_binary(text)) ->
        {:error, "#{name}: entry needs string path, class and text"}

      class not in class_names() ->
        {:error, "#{label}: unknown class"}

      not (is_integer(count) and count >= 1) ->
        {:error, "#{label}: count must be a positive integer"}

      area_of(path) != area ->
        {:error, "#{label}: misfiled, path belongs to area #{inspect(area_of(path))} not #{area}"}

      true ->
        validate_reason(entry, label)
    end
  end

  defp validate_entry(_entry, _area, name), do: {:error, "#{name}: entry is not an object"}

  defp validate_reason(entry, label) do
    reason_class = entry["reason_class"]
    reason = entry["reason"]

    cond do
      reason_class not in @reason_classes ->
        {:error, "#{label}: unknown reason_class #{inspect(reason_class)}"}

      reason_class != "pending-removal" and
          not (is_binary(reason) and String.trim(reason) != "") ->
        {:error, "#{label}: #{reason_class} entry needs a non-empty reason"}

      true ->
        :ok
    end
  end

  def class_names do
    ["path-name", "duplicated-prose"] ++
      Enum.map(line_classes() ++ comment_classes(), &elem(&1, 0))
  end

  defp key(%{} = e), do: {e["path"], e["class"], e["text"]}

  @doc "Violation strings for hits not covered by exact-count allowlist entries."
  def compare(hits, entries) do
    by_key = Enum.group_by(hits, &{&1.path, &1.class, &1.text})
    seen = Enum.frequencies_by(entries, &key/1)

    dupes =
      for {k, n} <- seen,
          n > 1,
          do: "#{elem(k, 0)}: #{elem(k, 1)}: duplicate allowlist entry: #{elem(k, 2)}"

    allow = Map.new(entries, &{key(&1), &1})

    uncovered =
      for {k, group} <- by_key, not Map.has_key?(allow, k), hit <- group do
        {hit.path, hit.line, "#{hit.path}:#{hit.line}: #{hit.class}: #{hit.text}"}
      end
      |> Enum.sort()
      |> Enum.map(&elem(&1, 2))

    mismatched =
      for {k, entry} <- allow, group = Map.get(by_key, k, []), length(group) != entry["count"] do
        {path, class, text} = k

        kind =
          if group == [],
            do: "stale allowlist entry matches nothing",
            else: "allowlist count differs"

        "#{path}: #{class}: #{kind} (entry count #{entry["count"]}, live #{length(group)}): #{text}"
      end
      |> Enum.sort()

    Enum.sort(dupes) ++ uncovered ++ mismatched
  end

  def pending_violations(entries, which) do
    selected = if which == "all", do: @areas, else: [which]

    for e <- entries, e["__shard"] in selected, e["reason_class"] == "pending-removal" do
      "#{e["path"]}: #{e["class"]}: pending-removal entry remains in #{e["__shard"]}: #{e["text"]}"
    end
    |> Enum.sort()
  end

  # -------------------------------------------------------------- regen

  def regenerate(dir, hits) do
    {existing, _} = lenient_entries(dir)
    prior = Map.new(existing, &{key(&1), &1})

    grouped = Enum.group_by(hits, &{&1.path, &1.class, &1.text})

    entries =
      for {{path, class, text} = k, group} <- grouped do
        old = Map.get(prior, k, %{})

        %{
          "path" => path,
          "class" => class,
          "text" => text,
          "count" => length(group),
          "reason_class" => Map.get(old, "reason_class", "pending-removal"),
          "reason" => Map.get(old, "reason", "")
        }
      end

    File.mkdir_p!(dir)

    for area <- @areas do
      shard =
        entries
        |> Enum.filter(&(area_of(&1["path"]) == area))
        |> Enum.sort_by(&{&1["path"], &1["class"], &1["text"]})
        |> Enum.map(fn e ->
          Jason.OrderedObject.new(
            for f <- ~w(path class text count reason_class reason), do: {f, e[f]}
          )
        end)

      body =
        Jason.OrderedObject.new([{"schema", @schema}, {"area", area}, {"entries", shard}])

      File.write!(Path.join(dir, area <> ".json"), Jason.encode!(body, pretty: true) <> "\n")
    end

    length(entries)
  end

  defp lenient_entries(dir) do
    dir
    |> Path.join("*.json")
    |> Path.wildcard()
    |> Enum.flat_map(fn file ->
      with {:ok, raw} <- File.read(file),
           {:ok, %{"entries" => list}} when is_list(list) <- Jason.decode(raw) do
        Enum.filter(list, &is_map/1)
      else
        _ -> []
      end
    end)
    |> then(&{&1, []})
  end

  # --------------------------------------------------------------------- CLI

  def main(argv) do
    {opts, rest, invalid} =
      OptionParser.parse(argv,
        strict: [
          root: :string,
          allowlist_dir: :string,
          check: :boolean,
          list: :boolean,
          regen_baseline: :boolean,
          require_no_pending: :string
        ]
      )

    modes = Enum.filter([:check, :list, :regen_baseline], &Keyword.get(opts, &1))

    cond do
      rest != [] or invalid != [] or length(modes) != 1 ->
        usage("expected exactly one of --check, --list, --regen-baseline")

      (p = opts[:require_no_pending]) && p != "all" && p not in @areas ->
        usage("--require-no-pending takes an area (#{Enum.join(@areas, ", ")}) or all")

      opts[:require_no_pending] && modes != [:check] ->
        usage("--require-no-pending only applies to --check")

      true ->
        root = Path.expand(opts[:root] || Path.expand("../..", __DIR__))
        dir = Path.expand(opts[:allowlist_dir] || Path.join(root, @self_dir))
        run(hd(modes), root, dir, opts)
    end
  end

  defp usage(message) do
    IO.puts(:stderr, "usage error: #{message}")
    System.halt(64)
  end

  defp run(mode, root, dir, opts) do
    {count, hits} = hits(root, files(root))

    case mode do
      :list ->
        IO.puts(Jason.encode!(hits, pretty: true))

      :regen_baseline ->
        n = regenerate(dir, hits)
        IO.puts("live residue scan: wrote #{n} entries across #{length(@areas)} shards")

      :check ->
        {entries, load_errors} = load_allowlist(dir)

        violations =
          if load_errors != [] do
            load_errors
          else
            compare(hits, entries) ++
              if(opts[:require_no_pending],
                do: pending_violations(entries, opts[:require_no_pending]),
                else: []
              )
          end

        if violations == [] do
          IO.puts(
            "live residue scan: ok (#{count} files, #{length(hits)} hits, #{length(entries)} allowlist entries)"
          )
        else
          Enum.each(violations, &IO.puts/1)
          IO.puts("live residue scan: FAILED (#{length(violations)} violations, #{count} files)")
          System.halt(1)
        end
    end
  end
end

Rindle.Maintainer.LiveResidueScan.main(System.argv())
