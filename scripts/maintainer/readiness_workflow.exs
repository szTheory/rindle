defmodule Rindle.ReadinessWorkflow do
  @moduledoc false

  # Detailed YAML nodes preserve matrix declaration order and duplicate keys.
  def derive(yaml, context) do
    {:ok, _} = Application.ensure_all_started(:yamerl)

    [document] =
      :yamerl_constr.string(yaml,
        detailed_constr: true,
        str_node_as_binary: true,
        keep_duplicate_keys: true
      )

    workflow = yaml_node(document)
    name = get(workflow, "name")
    ensure(is_binary(name), "workflow_name")
    jobs = get(workflow, "jobs")
    ensure(mapping?(jobs) and jobs.keys != [], "jobs_missing")

    expected =
      Enum.flat_map(jobs.keys, fn id ->
        job = get(jobs, id)
        ensure(mapping?(job), "job_shape")
        condition = get(job, "if", "success()")
        applicable = condition(condition, context)

        rows =
          if applicable,
            do: matrix_rows(get(get(job, "strategy"), "matrix")),
            else: [%{pairs: [], base: %{}}]

        Enum.map(rows, fn row ->
          %{
            "job_id" => id,
            "name" => job_name(get(job, "name", id), row.pairs),
            "applicable" => applicable,
            "condition" => condition,
            "matrix" => Map.new(row.pairs),
            "matrix_order" => Enum.map(row.pairs, &elem(&1, 0))
          }
        end)
      end)

    ensure(length(expected) in 1..500, "job_inventory_limit")
    names = Enum.map(expected, & &1["name"])
    ensure(length(names) == length(Enum.uniq(names)), "ambiguous_job_names")

    {:ok,
     %{
       "name" => name,
       "jobs" => expected,
       "workflow_sha256" => :crypto.hash(:sha256, yaml) |> Base.encode16(case: :lower)
     }}
  rescue
    _error -> {:error, "unknown_topology"}
  catch
    {:topology, reason} -> {:error, "unknown_topology:" <> reason}
  end

  # Preserve the approved CI behavior while allowing the existing script-test seam to add probes.
  def guard_identity(yaml) do
    {:ok, _} = Application.ensure_all_started(:yamerl)

    [node] =
      :yamerl_constr.string(yaml,
        detailed_constr: true,
        str_node_as_binary: true,
        keep_duplicate_keys: true
      )

    workflow = yaml_node(node)
    jobs = get(workflow, "jobs")
    script_job = get(jobs, "ci-script-tests")
    ensure(mapping?(script_job), "script_seam_missing")

    script_job = %{
      script_job
      | keys: Enum.reject(script_job.keys, &(&1 == "steps")),
        values: Map.delete(script_job.values, "steps")
    }

    jobs = %{jobs | values: Map.put(jobs.values, "ci-script-tests", script_job)}
    workflow = %{workflow | values: Map.put(workflow.values, "jobs", jobs)}
    :crypto.hash(:sha256, Jason.encode!(stable(workflow))) |> Base.encode16(case: :lower)
  end

  defp stable(%{keys: keys, values: values}),
    do: Enum.map(Enum.sort(keys), &[&1, stable(values[&1])])

  defp stable(values) when is_list(values), do: Enum.map(values, &stable/1)
  defp stable(value), do: value

  def condition(value, _context) when is_boolean(value), do: value

  def condition(value, context) when is_binary(value) do
    expression =
      value
      |> String.trim()
      |> String.replace_prefix("${{", "")
      |> String.replace_suffix("}}", "")
      |> String.trim()

    {result, remaining} = expression |> tokens() |> parse_or(context)
    ensure(remaining == [], "condition_tail")
    truth(result)
  end

  def condition(_value, _context), do: fail("condition_type")

  defp yaml_node({:yamerl_doc, node}), do: yaml_node(node)

  defp yaml_node({:yamerl_map, :yamerl_node_map, _tag, _location, pairs}) do
    fields = Enum.map(pairs, fn {key, value} -> {yaml_node(key), yaml_node(value)} end)
    keys = Enum.map(fields, &elem(&1, 0))

    ensure(
      Enum.all?(keys, &is_binary/1) and length(keys) == length(Enum.uniq(keys)),
      "duplicate_yaml_key"
    )

    ensure(not Enum.any?(keys, &String.starts_with?(&1, "<<")), "yaml_merge_unsupported")
    %{keys: keys, values: Map.new(fields)}
  end

  defp yaml_node({:yamerl_seq, :yamerl_node_seq, _tag, _location, values, _count}),
    do: Enum.map(values, &yaml_node/1)

  defp yaml_node({:yamerl_null, _module, _tag, _location}), do: nil

  defp yaml_node({_kind, _module, _tag, _location, value})
       when is_binary(value) or is_boolean(value) or is_integer(value) or is_float(value),
       do: value

  defp yaml_node(_node), do: fail("yaml_node")
  defp mapping?(%{keys: keys, values: values}), do: is_list(keys) and is_map(values)
  defp mapping?(_value), do: false
  defp get(value, key, default \\ nil)
  defp get(%{values: values}, key, default), do: Map.get(values, key, default)
  defp get(nil, _key, default), do: default
  defp get(_value, _key, _default), do: fail("mapping_required")
  defp pairs(%{keys: keys, values: values}), do: Enum.map(keys, &{&1, values[&1]})
  defp pairs(_value), do: fail("matrix_mapping")

  defp matrix_rows(nil), do: [%{pairs: [], base: %{}}]

  defp matrix_rows(matrix) do
    ensure(mapping?(matrix), "dynamic_matrix")
    axes = Enum.reject(matrix.keys, &(&1 in ["include", "exclude"]))
    includes = get(matrix, "include", [])
    excludes = get(matrix, "exclude", [])
    ensure(is_list(includes) and is_list(excludes), "matrix_include_exclude")

    if axes == [] do
      ensure(includes != [] and excludes == [], "empty_matrix")

      Enum.map(includes, fn row ->
        fields = scalar_pairs(row)
        %{pairs: fields, base: nil}
      end)
    else
      base =
        Enum.reduce(axes, [%{pairs: [], base: %{}}], fn axis, rows ->
          values = get(matrix, axis)

          ensure(
            is_list(values) and values != [] and Enum.all?(values, &scalar?/1),
            "dynamic_matrix_axis"
          )

          ensure(length(rows) * length(values) <= 256, "matrix_limit")

          for row <- rows, value <- values do
            %{pairs: row.pairs ++ [{axis, value}], base: Map.put(row.base, axis, value)}
          end
        end)

      base =
        Enum.reject(base, fn row ->
          Enum.any?(excludes, &subset?(Map.new(scalar_pairs(&1)), row.base))
        end)

      Enum.reduce(includes, base, fn include, rows ->
        addition = scalar_pairs(include)

        compatible = fn row ->
          is_map(row.base) and
            Enum.all?(addition, fn {k, v} -> not Map.has_key?(row.base, k) or row.base[k] == v end)
        end

        if Enum.any?(rows, compatible) do
          Enum.map(rows, fn row ->
            if compatible.(row) do
              keys = Enum.uniq(Enum.map(row.pairs ++ addition, &elem(&1, 0)))
              merged = Map.merge(Map.new(row.pairs), Map.new(addition))
              %{row | pairs: Enum.map(keys, &{&1, merged[&1]})}
            else
              row
            end
          end)
        else
          rows ++ [%{pairs: addition, base: nil}]
        end
      end)
    end
  end

  defp scalar_pairs(value) do
    fields = pairs(value)
    ensure(fields != [] and Enum.all?(fields, fn {_key, v} -> scalar?(v) end), "matrix_value")
    fields
  end

  defp scalar?(value), do: is_binary(value) or is_boolean(value) or is_integer(value)

  defp subset?(left, right),
    do: Enum.all?(left, fn {key, value} -> Map.get(right, key, :missing) == value end)

  defp job_name(name, fields) do
    ensure(is_binary(name), "dynamic_job_name")

    if String.contains?(name, "${{") do
      rendered =
        Regex.replace(~r/\$\{\{\s*matrix\.([A-Za-z0-9_-]+)\s*\}\}/, name, fn _whole, key ->
          fields |> Map.new() |> Map.fetch!(key) |> scalar_text()
        end)

      ensure(not String.contains?(rendered, "${{"), "dynamic_job_name")
      rendered
    else
      if fields == [],
        do: name,
        else:
          name <>
            " (" <> Enum.map_join(fields, ", ", fn {_key, value} -> scalar_text(value) end) <> ")"
    end
  end

  defp scalar_text(value) when is_binary(value), do: value
  defp scalar_text(value) when is_boolean(value) or is_integer(value), do: to_string(value)
  defp scalar_text(_value), do: fail("matrix_scalar")

  defp tokens(value) do
    if String.trim(value) == "" do
      []
    else
      case Regex.run(
             ~r/\A\s*(==|!=|&&|\|\||[!(),]|'[^']*'|"[^"]*"|[A-Za-z_][A-Za-z0-9_.*-]*|[0-9]+)/,
             value
           ) do
        [whole, token] ->
          [
            token
            | tokens(binary_part(value, byte_size(whole), byte_size(value) - byte_size(whole)))
          ]

        _other ->
          fail("condition_token")
      end
    end
  end

  defp parse_or(tokens, context) do
    {left, rest} = parse_and(tokens, context)
    parse_or_tail(left, rest, context)
  end

  defp parse_or_tail(left, ["||" | rest], context) do
    {right, rest} = parse_and(rest, context)
    parse_or_tail(truth(left) or truth(right), rest, context)
  end

  defp parse_or_tail(left, rest, _context), do: {left, rest}

  defp parse_and(tokens, context) do
    {left, rest} = parse_compare(tokens, context)
    parse_and_tail(left, rest, context)
  end

  defp parse_and_tail(left, ["&&" | rest], context) do
    {right, rest} = parse_compare(rest, context)
    parse_and_tail(truth(left) and truth(right), rest, context)
  end

  defp parse_and_tail(left, rest, _context), do: {left, rest}

  defp parse_compare(tokens, context) do
    {left, rest} = primary(tokens, context)

    case rest do
      [operator | tail] when operator in ["==", "!="] ->
        {right, tail} = primary(tail, context)
        ensure(comparable?(left, right), "condition_coercion")
        {if(operator == "==", do: left == right, else: left != right), tail}

      _other ->
        {left, rest}
    end
  end

  defp primary(["!" | rest], context) do
    {value, rest} = primary(rest, context)
    {not truth(value), rest}
  end

  defp primary(["(" | rest], context) do
    {value, [")" | rest]} = parse_or(rest, context)
    {value, rest}
  end

  defp primary([name, "(" | rest], context) do
    {args, rest} = arguments(rest, context, [])
    {call(String.downcase(name), args), rest}
  end

  defp primary([token | rest], context) do
    value =
      cond do
        String.starts_with?(token, ["'", "\""]) -> binary_part(token, 1, byte_size(token) - 2)
        token == "true" -> true
        token == "false" -> false
        token == "null" -> nil
        Regex.match?(~r/\A[0-9]+\z/, token) -> String.to_integer(token)
        true -> variable(token, context)
      end

    {value, rest}
  end

  defp primary([], _context), do: fail("condition_incomplete")
  defp arguments([")" | rest], _context, args), do: {Enum.reverse(args), rest}

  defp arguments(tokens, context, args) do
    {value, rest} = parse_or(tokens, context)

    case rest do
      ["," | rest] -> arguments(rest, context, [value | args])
      [")" | rest] -> {Enum.reverse([value | args]), rest}
      _other -> fail("condition_arguments")
    end
  end

  defp call("always", []), do: true
  defp call("success", []), do: true
  defp call(name, []) when name in ["failure", "cancelled"], do: false
  defp call("contains", [values, value]) when is_list(values), do: value in values

  defp call("contains", [text, value]) when is_binary(text) and is_binary(value),
    do: String.contains?(String.downcase(text), String.downcase(value))

  defp call("startswith", [text, value]) when is_binary(text) and is_binary(value),
    do: String.starts_with?(String.downcase(text), String.downcase(value))

  defp call("endswith", [text, value]) when is_binary(text) and is_binary(value),
    do: String.ends_with?(String.downcase(text), String.downcase(value))

  defp call(_name, _args), do: fail("condition_function")
  defp variable("github.repository", c), do: Map.fetch!(c, "repository")
  defp variable("github.event_name", c), do: Map.fetch!(c, "event")
  defp variable("github.ref", c), do: "refs/heads/" <> Map.fetch!(c, "branch")
  defp variable("github.ref_name", c), do: Map.fetch!(c, "branch")
  defp variable("github.event.pull_request.labels.*.name", c), do: Map.get(c, "labels", [])
  defp variable(_name, _context), do: fail("condition_context")

  defp comparable?(a, b),
    do:
      (is_binary(a) and is_binary(b)) or (is_boolean(a) and is_boolean(b)) or
        (is_integer(a) and is_integer(b)) or a == nil or b == nil

  defp truth(value) when is_boolean(value), do: value
  defp truth(nil), do: false
  defp truth(value) when is_binary(value), do: value != ""
  defp truth(value) when is_integer(value), do: value != 0
  defp truth(_value), do: fail("condition_truthiness")
  defp ensure(true, _reason), do: :ok
  defp ensure(_false, reason), do: fail(reason)
  defp fail(reason), do: throw({:topology, reason})
end

case System.argv() do
  ["--request", path] ->
    request = path |> File.read!() |> Jason.decode!()

    result =
      case request["operation"] do
        "topology" ->
          case Rindle.ReadinessWorkflow.derive(request["yaml"], request["context"]) do
            {:ok, value} -> %{"ok" => true, "value" => value}
            {:error, reason} -> %{"ok" => false, "reason" => reason}
          end

        "hex" ->
          System.put_env("RINDLE_EXACT_HEAD_LIBRARY_ONLY", "1")
          Code.require_file("validate_exact_head_readiness.exs", __DIR__)
          Rindle.ExactHeadReadiness.validate_hex(request["payloads"], request["locks"])

        "validate" ->
          System.put_env("RINDLE_EXACT_HEAD_LIBRARY_ONLY", "1")
          Code.require_file("validate_exact_head_readiness.exs", __DIR__)

          Rindle.ExactHeadReadiness.validate_remote(
            request["id"],
            request["normalized"],
            request["inputs"]
          )
      end

    IO.puts(Jason.encode!(result))

  _ ->
    :ok
end
