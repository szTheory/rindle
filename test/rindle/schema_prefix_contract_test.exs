defmodule Rindle.SchemaPrefixContractTest do
  use ExUnit.Case, async: true

  @domain_schemas [
    Rindle.Domain.MediaAsset,
    Rindle.Domain.MediaAttachment,
    Rindle.Domain.MediaProcessingRun,
    Rindle.Domain.MediaProviderAsset,
    Rindle.Domain.MediaUploadSession,
    Rindle.Domain.MediaVariant
  ]

  test "every Rindle-owned domain schema uses the shared prefix macro" do
    for schema <- @domain_schemas do
      source = schema.module_info(:compile)[:source] |> to_string()
      {:ok, ast} = Code.string_to_quoted(File.read!(source))

      assert uses_rindle_schema?(ast), "expected #{inspect(schema)} to use Rindle.Schema"

      refute uses_ecto_schema_directly?(ast),
             "expected #{inspect(schema)} not to bypass Rindle.Schema"

      refute sets_schema_prefix_directly?(ast),
             "expected #{inspect(schema)} not to override the shared prefix"
    end
  end

  test "the shared macro is the only Rindle-owned schema prefix authority" do
    assert Rindle.Schema.prefix() == Rindle.Config.rindle_prefix()

    for schema <- @domain_schemas do
      assert schema.__schema__(:prefix) == Rindle.Schema.prefix()
      assert struct(schema).__meta__.prefix == Rindle.Schema.prefix()
    end
  end

  test "rejects a dynamic post-use schema prefix override at compile finalization" do
    module = unique_module_name("DynamicPrefixOverride")
    expected_prefix = Rindle.Schema.prefix()
    actual_prefix = opposite_prefix(expected_prefix)

    error =
      assert_raise ArgumentError, fn ->
        Code.compile_string("""
        defmodule #{inspect(module)} do
          use Rindle.Schema
          Module.put_attribute(__MODULE__, :schema_prefix, #{inspect(actual_prefix)})

          schema "dynamic_prefix_override_schemas" do
          end
        end
        """)
      end

    assert Exception.message(error) =~ inspect(module)
    assert Exception.message(error) =~ "expected #{inspect(expected_prefix)}"
    assert Exception.message(error) =~ "got #{inspect(actual_prefix)}"
  end

  defp uses_rindle_schema?(ast), do: contains?(ast, &rindle_schema_use?/1)
  defp uses_ecto_schema_directly?(ast), do: contains?(ast, &ecto_schema_use?/1)
  defp sets_schema_prefix_directly?(ast), do: contains?(ast, &schema_prefix_attribute?/1)

  defp contains?(ast, predicate) do
    {_ast, found?} =
      Macro.prewalk(ast, false, fn node, found? ->
        {node, found? or predicate.(node)}
      end)

    found?
  end

  defp rindle_schema_use?({:use, _, [{:__aliases__, _, [:Rindle, :Schema]}]}), do: true
  defp rindle_schema_use?(_), do: false

  defp ecto_schema_use?({:use, _, [{:__aliases__, _, [:Ecto, :Schema]}]}), do: true
  defp ecto_schema_use?(_), do: false

  defp schema_prefix_attribute?({:@, _, [{:schema_prefix, _, _}]}), do: true
  defp schema_prefix_attribute?(_), do: false

  defp opposite_prefix("rindle"), do: "public"
  defp opposite_prefix("public"), do: "rindle"

  defp unique_module_name(prefix) do
    Module.concat(Rindle, "#{prefix}#{System.unique_integer([:positive])}")
  end
end
