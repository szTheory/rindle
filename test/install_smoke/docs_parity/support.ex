defmodule Rindle.InstallSmoke.DocsParity.Support do
  @moduledoc false

  import ExUnit.Assertions

  @doc false
  def load_docs!(paths) do
    Map.new(paths, fn {name, path} -> {name, File.read!(path)} end)
  end

  @doc false
  def introductory_section(doc) do
    case Regex.split(~r/^##\s+/m, doc, parts: 2) do
      [intro] -> intro
      [intro, _rest] -> intro
    end
  end

  @doc false
  def string_index(doc, snippet) do
    case :binary.match(doc, snippet) do
      {index, _} -> index
      :nomatch -> nil
    end
  end

  @doc false
  def assert_in_order!(doc, snippets) do
    normalized_doc = String.downcase(doc)

    {_last_index, _last_snippet} =
      Enum.reduce(snippets, {-1, nil}, fn snippet, {last_index, _last_snippet} ->
        index = string_index(normalized_doc, String.downcase(snippet))

        assert index,
               "expected snippet #{inspect(snippet)} to appear in order after index #{last_index}"

        assert index > last_index,
               "expected snippet #{inspect(snippet)} to appear after #{last_index}, got #{index}"

        {index, snippet}
      end)
  end

  @doc false
  def section_between!(doc, start_snippet, stop_snippet) do
    start_index =
      string_index(doc, start_snippet) ||
        flunk("expected section start #{inspect(start_snippet)}")

    tail = binary_part(doc, start_index, byte_size(doc) - start_index)

    case string_index(tail, stop_snippet) do
      nil -> tail
      stop_index -> binary_part(tail, 0, stop_index)
    end
  end

  @doc false
  def fenced_elixir_after!(section, snippet) do
    ~r/^```elixir\n(.*?)^```/ms
    |> Regex.scan(section, capture: :all_but_first)
    |> Enum.map(&hd/1)
    |> Enum.find(&String.contains?(&1, snippet))
    |> case do
      nil -> flunk("expected a closed Elixir fence containing #{inspect(snippet)}")
      contents -> contents
    end
  end

  @doc false
  def migration_call!(source) do
    source
    |> String.split("\n")
    |> Enum.find(&String.contains?(&1, "def up, do:"))
    |> case do
      nil -> flunk("expected generated migration fixture to contain a one-line up/0 call")
      call -> String.trim(call)
    end
  end

  @doc false
  def fetch_docs!(module) do
    assert Code.ensure_loaded?(module),
           "#{inspect(module)} must be loadable for docs parity checks"

    case Code.fetch_docs(module) do
      {:error, reason} ->
        flunk("expected compiled docs for #{inspect(module)}, got #{inspect(reason)}")

      docs ->
        docs
    end
  end

  @doc false
  def moduledoc!(module) do
    case fetch_docs!(module) do
      {:docs_v1, _, _, _, %{"en" => doc}, _, _} when is_binary(doc) -> doc
      {:docs_v1, _, _, _, {_, doc}, _, _} when is_binary(doc) -> doc
      {:docs_v1, _, _, _, doc, _, _} when is_binary(doc) -> doc
      other -> flunk("expected moduledoc for #{inspect(module)}, got #{inspect(other)}")
    end
  end

  @doc false
  def normalize_whitespace(text), do: text |> String.replace(~r/\s+/, " ") |> String.trim()
end
