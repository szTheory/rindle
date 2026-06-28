defmodule Rindle.AsyncSafetyGuardTest do
  @moduledoc """
  Static async-safety guard (HARD-01, D-02).

  A meta-test that globs `test/**/*_test.exs`, parses each file to an AST, and for
  every module whose `use ExUnit.Case` / `use Rindle.DataCase` header declares
  `async: true`, walks the module body asserting it uses NO concurrency-unsafe
  shared-state primitive.

  This is the inverse guard that keeps the `async: true` conversions honest: a future
  contributor who flips a module to async while adding a global-state primitive
  (`Application.put_env`, `set_mox_global`, a named process, fixed-path `File` mutation,
  named/public ETS, `:persistent_term.put`, or a `{:shared, _}` sandbox mode) gets a
  red, merge-blocking gate.

  ## Why the Ecto sandbox is NOT flagged

  `Rindle.DataCase.setup_sandbox/1` keys isolation on `tags[:async]`
  (`shared: not tags[:async]`), so a DataCase `async: true` module gets a non-shared,
  isolated connection owner by construction. The only thing that makes a module
  genuinely unsafe is a NON-Ecto shared-state primitive — those are what this guard
  detects.

  ## Escape hatch (fail-closed by default)

  A module may opt a specific primitive out of the check by declaring a module
  attribute, e.g.:

      @async_safety_allow [:application_put_env]

  Each atom names a primitive (see `@primitive_names`). This is intended for the rare
  case where a primitive is used in a process-local, async-safe way and the author has
  written a justification. The default is fail-closed: anything not allow-listed flags.

  The guard module is itself `async: true` — it only reads the filesystem and parses
  source, using no unsafe primitive, so it passes its own check.
  """
  use ExUnit.Case, async: true

  @test_root Path.expand("..", __DIR__)
  @glob Path.join(@test_root, "test/**/*_test.exs")

  # Atom names usable in @async_safety_allow [...] and reported in failure messages.
  @primitive_names [
    :application_put_env,
    :system_put_env,
    :set_mox_global,
    :named_process,
    :file_mutation,
    :public_ets,
    :persistent_term,
    :shared_sandbox,
    :global_repo_swap
  ]

  setup_all do
    files = Path.wildcard(@glob)

    assert files != [], "expected test/**/*_test.exs glob to match files, got none"

    modules =
      files
      |> Enum.flat_map(&parse_async_true_modules/1)

    # ISO-04 (D-08): the :global_repo_swap rule scans EVERY module (the
    # mutators/swappers are async: false), so it needs a separate all-modules list
    # built without the async filter; the existing per-async:true `modules` above
    # are untouched.
    all_modules =
      files
      |> Enum.flat_map(&parse_all_modules/1)

    {:ok, files: files, modules: modules, all_modules: all_modules}
  end

  test "the glob finds the test tree and at least the known async:true modules", %{
    files: files,
    modules: modules
  } do
    # This file is itself an async:true module, so the set is never empty.
    assert length(files) > 100,
           "expected the test tree to be globbed (got #{length(files)} files)"

    assert length(modules) >= 60,
           "expected >= 60 async:true modules (got #{length(modules)}); " <>
             "the guard must see every module that claims async:true"

    assert Enum.any?(modules, &(&1.module == "Rindle.AsyncSafetyGuardTest")),
           "the guard must include itself among the async:true modules it checks"
  end

  test "every async:true test module uses no concurrency-unsafe shared-state primitive", %{
    modules: modules
  } do
    offenders =
      modules
      |> Enum.flat_map(fn mod ->
        mod.body
        |> collect_offenders(mod.tmp_vars)
        |> Enum.reject(fn {primitive, _line} -> primitive in mod.allow end)
        |> Enum.map(fn {primitive, line} ->
          %{file: mod.relpath, module: mod.module, line: line, primitive: primitive}
        end)
      end)
      |> Enum.sort_by(&{&1.file, &1.line, &1.primitive})

    assert offenders == [], failure_message(offenders)
  end

  # ISO-04 (D-07/D-08/D-11): no test module — async:true OR async:false — may swap
  # the globally-read `:rindle, :repo` library config via Application.put_env/delete_env.
  # The footgun is un-reintroducible: a new global swap goes RED and points the author
  # at the sanctioned process-local `Rindle.Config.put_repo_override/1`. The 9 legitimate
  # adopter/probe-repo swappers opt out with `@async_safety_allow [:global_repo_swap]`.
  test "no test module swaps the global :rindle, :repo config (regardless of async flag)", %{
    all_modules: all_modules
  } do
    offenders =
      all_modules
      |> Enum.flat_map(fn mod ->
        mod.body
        |> collect_global_repo_swaps()
        |> Enum.reject(fn {primitive, _line} -> primitive in mod.allow end)
        |> Enum.map(fn {primitive, line} ->
          %{file: mod.relpath, module: mod.module, line: line, primitive: primitive}
        end)
      end)
      |> Enum.sort_by(&{&1.file, &1.line, &1.primitive})

    assert offenders == [], global_repo_swap_failure_message(offenders)
  end

  # ── parsing ────────────────────────────────────────────────────────────────

  # Returns a list of %{module, relpath, allow, body, tmp_vars} for each module in
  # `path` whose `use ... , async: true` header is present. `tmp_vars` is the set of
  # local variable names whose binding derives from a per-test-unique tmp source
  # (`System.tmp_dir!`/`unique_integer`/`Briefly`/`tmp_dir`), used to clear File.*
  # mutations whose path flows through such a variable.
  defp parse_async_true_modules(path) do
    relpath = Path.relative_to(path, @test_root)
    quoted = path |> File.read!() |> Code.string_to_quoted!()

    quoted
    |> collect_modules()
    |> Enum.filter(fn {_name, body} -> async_true?(body) end)
    |> Enum.map(fn {name, body} ->
      %{
        module: name,
        relpath: relpath,
        allow: collect_allowlist(body),
        tmp_vars: collect_tmp_vars(body),
        body: body
      }
    end)
  end

  # ISO-04 (D-08): mirrors `parse_async_true_modules/1` MINUS the
  # `Enum.filter(&async_true?/1)` line — returns every module in `path` (async:true
  # OR async:false) as %{module, relpath, allow, body}, honoring the same
  # `@async_safety_allow` allow-list. Used ONLY by the :global_repo_swap all-modules
  # scan; `tmp_vars` is omitted because that classifier needs no path dataflow.
  defp parse_all_modules(path) do
    relpath = Path.relative_to(path, @test_root)
    quoted = path |> File.read!() |> Code.string_to_quoted!()

    quoted
    |> collect_modules()
    |> Enum.map(fn {name, body} ->
      %{
        module: name,
        relpath: relpath,
        allow: collect_allowlist(body),
        body: body
      }
    end)
  end

  # Walk the top-level AST collecting {module_name_string, do_block_body} for every
  # `defmodule`. Handles multiple modules per file (e.g. owner_erasure_batch_opts).
  defp collect_modules(ast) do
    {_ast, mods} =
      Macro.prewalk(ast, [], fn
        {:defmodule, _, [name_ast, [{:do, body}]]} = node, acc ->
          {node, [{module_name(name_ast), body} | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(mods)
  end

  defp module_name({:__aliases__, _, parts}),
    do: parts |> Enum.map(&Atom.to_string/1) |> Enum.join(".")

  defp module_name(other), do: Macro.to_string(other)

  # True iff the module body contains a `use _, async: true` call.
  defp async_true?(body) do
    {_ast, found} =
      Macro.prewalk(body, false, fn
        {:use, _, [_template, opts]} = node, acc when is_list(opts) ->
          {node, acc or Keyword.get(opts, :async) == true}

        node, acc ->
          {node, acc}
      end)

    found
  end

  # Reads @async_safety_allow [ ... ] from the module body; returns a list of atoms.
  defp collect_allowlist(body) do
    {_ast, allow} =
      Macro.prewalk(body, [], fn
        {:@, _, [{:async_safety_allow, _, [list]}]} = node, acc when is_list(list) ->
          atoms = Enum.filter(list, &is_atom/1)
          {node, acc ++ atoms}

        node, acc ->
          {node, acc}
      end)

    allow
  end

  # Collects local variable names whose binding ultimately derives from a per-test-
  # unique tmp expression, so a later `File.write!(path, ...)` whose path flows
  # through such a variable is treated as async-safe (the path is unique per test).
  #
  # Two-stage with transitive closure: first gather every `var = <rhs>` assignment,
  # seed the tmp-var set from assignments whose rhs contains a literal tmp marker
  # (System.tmp_dir!/unique_integer/Briefly/tmp_dir), then iterate to a fixpoint,
  # promoting any assignment whose rhs references an already-known tmp var. This
  # covers `head_temp = Path.join(root, "x")` and `path = Local.path_for(k, opts)`
  # where `opts = [root: root, ...]`.
  defp collect_tmp_vars(body) do
    assignments = collect_assignments(body)

    seed =
      Enum.reduce(assignments, MapSet.new(), fn {names, rhs}, acc ->
        if tmp_marker?([rhs]), do: MapSet.union(acc, names), else: acc
      end)

    fixpoint_tmp_vars(assignments, seed)
  end

  defp fixpoint_tmp_vars(assignments, vars) do
    next =
      Enum.reduce(assignments, vars, fn {names, rhs}, acc ->
        if references_tmp_var?([rhs], acc), do: MapSet.union(acc, names), else: acc
      end)

    if MapSet.equal?(next, vars), do: vars, else: fixpoint_tmp_vars(assignments, next)
  end

  # All `lhs = rhs` assignments in the body as {bound_var_names, rhs_ast}.
  defp collect_assignments(body) do
    {_ast, pairs} =
      Macro.prewalk(body, [], fn
        {:=, _, [lhs, rhs]} = node, acc ->
          {node, [{bound_var_names(lhs), rhs} | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(pairs)
  end

  # Variable names introduced by an assignment LHS (handles plain vars and the
  # `{a, b} = ...` / `[a, b] = ...` destructuring shapes that bind a tmp root).
  defp bound_var_names(lhs) do
    {_ast, names} =
      Macro.prewalk(lhs, MapSet.new(), fn
        {name, _, ctx} = node, acc when is_atom(name) and is_atom(ctx) ->
          {node, MapSet.put(acc, name)}

        node, acc ->
          {node, acc}
      end)

    names
  end

  # ── detection ──────────────────────────────────────────────────────────────

  defp collect_offenders(body, tmp_vars) do
    {_ast, offenders} =
      Macro.prewalk(body, [], fn node, acc ->
        case classify(node, tmp_vars) do
          nil -> {node, acc}
          {primitive, line} -> {node, [{primitive, line} | acc]}
        end
      end)

    Enum.reverse(offenders)
  end

  # ISO-04 (D-07): collects every :rindle/:repo global swap in a module body. Applies
  # ONLY `classify_global_repo_swap/1` (a separate pass from `collect_offenders/2`, which
  # owns the async:true-only primitives); never touches the existing classifiers.
  defp collect_global_repo_swaps(body) do
    {_ast, swaps} =
      Macro.prewalk(body, [], fn node, acc ->
        case classify_global_repo_swap(node) do
          nil -> {node, acc}
          {primitive, line} -> {node, [{primitive, line} | acc]}
        end
      end)

    Enum.reverse(swaps)
  end

  # ISO-04 (D-07/D-11): matches `Application.put_env(:rindle, :repo, _)` /
  # `Application.delete_env(:rindle, :repo)` (research §iv locked AST shape). The
  # `[:rindle, :repo | _]` head pins the first two positional args to the app/key
  # atoms, so `:rindle, :repo_probe_owner` and `:rindle, :counting_failing_txn_repo`
  # (D-11) do NOT match.
  defp classify_global_repo_swap(
         {{:., meta, [{:__aliases__, _, [:Application]}, m]}, _, [:rindle, :repo | _]}
       )
       when m in [:put_env, :delete_env],
       do: {:global_repo_swap, line(meta)}

  defp classify_global_repo_swap(_node), do: nil

  # Returns {primitive_atom, line} when `node` matches an unsafe primitive, else nil.

  # Application.put_env / delete_env
  defp classify({{:., meta, [{:__aliases__, _, [:Application]}, m]}, _, _}, _tmp)
       when m in [:put_env, :delete_env],
       do: {:application_put_env, line(meta)}

  # System.put_env / delete_env
  defp classify({{:., meta, [{:__aliases__, _, [:System]}, m]}, _, _}, _tmp)
       when m in [:put_env, :delete_env],
       do: {:system_put_env, line(meta)}

  # Mox global mode — `set_mox_global` (bare import) or `Mox.set_mox_global`
  defp classify({:set_mox_global, meta, _}, _tmp), do: {:set_mox_global, line(meta)}

  defp classify({{:., meta, [{:__aliases__, _, [:Mox]}, :set_mox_global]}, _, _}, _tmp),
    do: {:set_mox_global, line(meta)}

  # File mutation NOT scoped to tmp_dir / unique_integer (directly or via a
  # module-local variable bound to a tmp-derived path).
  defp classify({{:., meta, [{:__aliases__, _, [:File]}, m]}, _, args}, tmp_vars)
       when m in [
              :cd,
              :cd!,
              :write,
              :write!,
              :mkdir,
              :mkdir!,
              :mkdir_p,
              :mkdir_p!,
              :rm,
              :rm!,
              :rm_rf,
              :rm_rf!,
              :cp,
              :cp!,
              :rename,
              :rename!,
              :touch,
              :touch!
            ] do
    if tmp_scoped?(args, tmp_vars), do: nil, else: {:file_mutation, line(meta)}
  end

  # :persistent_term.put
  defp classify({{:., meta, [:persistent_term, :put]}, _, _}, _tmp),
    do: {:persistent_term, line(meta)}

  # :ets.new with :named_table or :public option
  defp classify({{:., meta, [:ets, :new]}, _, args}, _tmp) do
    if ets_shared?(args), do: {:public_ets, line(meta)}, else: nil
  end

  # Ecto sandbox forced shared: Sandbox.mode(_, {:shared, _}) — match on the
  # {:shared, _} arg regardless of the alias used for the Sandbox module.
  defp classify({{:., meta, [_mod, :mode]}, _, [_repo, {:shared, _}]}, _tmp),
    do: {:shared_sandbox, line(meta)}

  # named/registered process: any *.start_link / *.start / start_supervised(ed!) /
  # GenServer.start* call whose args include a FIXED `name:` (a literal atom or a
  # bare `__MODULE__`). A name derived from `System.unique_integer` is per-test
  # unique and async-safe, so it is NOT flagged (RESEARCH: "name: __MODULE__ or a
  # fixed atom" is the unsafe shape).
  defp classify({{:., meta, [_mod, fun]}, _, args}, _tmp)
       when fun in [:start_link, :start, :start_supervised, :start_supervised!] do
    if fixed_name_kwarg?(args), do: {:named_process, line(meta)}, else: nil
  end

  defp classify({fun, meta, args}, _tmp)
       when fun in [:start_supervised, :start_supervised!] and is_list(args) do
    if fixed_name_kwarg?(args), do: {:named_process, line(meta)}, else: nil
  end

  defp classify(_node, _tmp), do: nil

  # ── helpers ────────────────────────────────────────────────────────────────

  # A File.* path arg is async-safe when it is derived from a per-test unique source:
  # directly (a tmp marker appears in the arg AST) OR via a module-local variable
  # (`tmp_vars`) bound to a tmp-derived path.
  defp tmp_scoped?(args, tmp_vars) do
    tmp_marker?(args) or references_tmp_var?(args, tmp_vars)
  end

  # True iff the AST contains a per-test-unique tmp marker: a `tmp_dir`/`@tmp_dir`
  # reference, `System.unique_integer`, `System.tmp_dir(!)`, or a `Briefly` helper.
  defp tmp_marker?(ast) do
    {_ast, safe} =
      Macro.prewalk(ast, false, fn
        {:tmp_dir, _, _} = n, _acc -> {n, true}
        {:@, _, [{:tmp_dir, _, _}]} = n, _acc -> {n, true}
        {{:., _, [{:__aliases__, _, [:System]}, :unique_integer]}, _, _} = n, _acc -> {n, true}
        {{:., _, [{:__aliases__, _, [:System]}, :tmp_dir]}, _, _} = n, _acc -> {n, true}
        {{:., _, [{:__aliases__, _, [:System]}, :tmp_dir!]}, _, _} = n, _acc -> {n, true}
        {{:., _, [{:__aliases__, _, [:Briefly]}, _]}, _, _} = n, _acc -> {n, true}
        node, acc -> {node, acc}
      end)

    safe
  end

  defp references_tmp_var?(_args, tmp_vars) when map_size(tmp_vars) == 0, do: false

  defp references_tmp_var?(args, tmp_vars) do
    {_ast, hit} =
      Macro.prewalk(args, false, fn
        {name, _, ctx} = node, acc when is_atom(name) and is_atom(ctx) ->
          {node, acc or MapSet.member?(tmp_vars, name)}

        node, acc ->
          {node, acc}
      end)

    hit
  end

  defp ets_shared?(args) do
    {_ast, shared} =
      Macro.prewalk(args, false, fn
        node, _acc when node in [:named_table, :public] -> {node, true}
        node, acc -> {node, acc}
      end)

    shared
  end

  # True iff a start_* call carries a FIXED `name:` — a literal atom or a bare
  # `__MODULE__` (an alias). A `name:` whose value is a `Module.concat(...)` /
  # interpolation containing `System.unique_integer` is per-test unique and safe.
  defp fixed_name_kwarg?(args) do
    Enum.any?(args, fn
      kw when is_list(kw) ->
        case Keyword.fetch(kw, :name) do
          {:ok, value} -> fixed_name_value?(value)
          :error -> false
        end

      _ ->
        false
    end)
  end

  # A literal atom (e.g. MyServer / :my_server) or a bare __MODULE__ is a fixed,
  # collision-prone name. Anything containing System.unique_integer is unique → safe.
  defp fixed_name_value?({:__MODULE__, _, _}), do: true
  defp fixed_name_value?({:__aliases__, _, _}), do: true
  defp fixed_name_value?(atom) when is_atom(atom), do: true
  defp fixed_name_value?(other), do: not tmp_marker?([other]) and literal_name?(other)

  # Treat only clearly-static expressions as fixed names; dynamic constructions
  # (Module.concat with interpolation, string interpolation, function calls) are
  # assumed unique-per-test and not flagged.
  defp literal_name?(value) do
    case value do
      v when is_atom(v) -> true
      {:__aliases__, _, _} -> true
      _ -> false
    end
  end

  defp line(meta), do: Keyword.get(meta, :line, 0)

  defp failure_message([]), do: "no async-safety offenders"

  defp failure_message(offenders) do
    lines =
      Enum.map_join(offenders, "\n", fn o ->
        "  - #{o.file}:#{o.line} (#{o.module}) uses #{o.primitive}"
      end)

    """
    Found #{length(offenders)} async-safety offender(s): module(s) declaring \
    `async: true` while using a concurrency-unsafe shared-state primitive.

    #{lines}

    Either (a) make the module `async: false`, (b) remove the primitive, or (c) if the \
    usage is genuinely process-local and async-safe, opt out with a justified \
    `@async_safety_allow [:#{(List.first(offenders) || %{primitive: :the_primitive}).primitive}]` \
    module attribute. Recognised primitive atoms: #{inspect(@primitive_names)}.
    """
  end

  defp global_repo_swap_failure_message([]), do: "no :global_repo_swap offenders"

  defp global_repo_swap_failure_message(offenders) do
    lines =
      Enum.map_join(offenders, "\n", fn o ->
        "  - #{o.file}:#{o.line} (#{o.module}) swaps :rindle, :repo via Application.put_env/delete_env"
      end)

    """
    Found #{length(offenders)} :global_repo_swap offender(s): test module(s) mutating the \
    globally-read `:rindle, :repo` library config with `Application.put_env`/`delete_env`. \
    This cross-pollutes any concurrent async reader of `Rindle.Config.repo/0` (ISO-04).

    #{lines}

    Use the process-local, async-safe setter `Rindle.Config.put_repo_override/1` (cleared \
    via `Rindle.Config.delete_repo_override/0`) instead — it overrides the repo only for \
    the current process and its `$callers`, never globally. If a module genuinely must swap \
    the Application env to exercise the app-env resolution path itself (e.g. config_test), \
    opt out with a justified `@async_safety_allow [:global_repo_swap]` module attribute.
    """
  end
end
