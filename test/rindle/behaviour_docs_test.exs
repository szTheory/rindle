defmodule Rindle.BehaviourDocsTest do
  @moduledoc """
  D-19 backstop: every @callback on a public behaviour module MUST have a
  visible @doc. Doctor does not analyze callback declarations
  (akoutmos/doctor module_information.ex), so this test asserts the
  convention via Code.fetch_docs/1.

  See: .planning/phases/18-documentation-and-typespec-coverage/18-CONTEXT.md (D-11, D-18, D-19).
  """

  use ExUnit.Case, async: true

  @behaviour_modules [
    Rindle.Storage,
    Rindle.Authorizer,
    Rindle.Analyzer,
    Rindle.Scanner,
    Rindle.Processor
  ]

  for module <- @behaviour_modules do
    test "every @callback in #{inspect(module)} has a non-hidden @doc" do
      module = unquote(module)
      {:docs_v1, _, _, _, _, _, docs} = fetch_docs!(module)

      callbacks =
        Enum.filter(docs, fn
          {{:callback, _name, _arity}, _, _, _, _} -> true
          _ -> false
        end)

      assert callbacks != [],
             "#{inspect(module)} should declare at least one @callback"

      for {{:callback, name, arity}, _, _, doc, _} <- callbacks do
        refute doc in [:none, :hidden],
               "#{inspect(module)}.#{name}/#{arity} callback should have a visible @doc"
      end
    end
  end

  defp fetch_docs!(module) do
    assert Code.ensure_loaded?(module),
           "#{inspect(module)} must be loadable for docs introspection"

    case Code.fetch_docs(module) do
      {:error, reason} ->
        flunk("expected compiled docs for #{inspect(module)}, got #{inspect(reason)}")

      docs ->
        docs
    end
  end
end
