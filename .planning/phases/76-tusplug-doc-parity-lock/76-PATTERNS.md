# Phase 76: TusPlug Doc Parity Lock - Patterns

**Mapped:** 2026-05-27

---

## Files to Modify

| File | Role | Closest Analog |
|------|------|----------------|
| `lib/rindle/upload/tus_plug.ex` | Tus protocol Plug; `@tus_extensions` + moduledoc | Self — attribute already used at line 192 for OPTIONS header |
| `test/install_smoke/docs_parity_test.exs` | Doc parity gate home | Phase 74 nine-task test (lines 260–268); `api_surface_boundary_test.exs` fetch_docs helpers |

---

## Pattern: Module Attribute → Moduledoc SSoT

**Source:** Elixir compile-time attribute interpolation

```elixir
@tus_extensions "creation,expiration,termination,checksum,creation-defer-length,concatenation"
@moduledoc """
...
`#{@tus_extensions}`.
"""
```

Attribute must precede `@moduledoc`. OPTIONS header continues:

```elixir
|> put_resp_header("tus-extension", @tus_extensions)
```

---

## Pattern: Code.fetch_docs/1 Contract Test

**Analog:** `test/rindle/api_surface_boundary_test.exs` (lines 267–292)

```elixir
defp fetch_docs!(module) do
  assert Code.ensure_loaded?(module)
  case Code.fetch_docs(module) do
    {:error, reason} -> flunk("expected compiled docs for #{inspect(module)}, got #{inspect(reason)}")
    docs -> docs
  end
end

defp moduledoc!(module) do
  case fetch_docs!(module) do
    {:docs_v1, _, _, _, %{"en" => doc}, _, _} when is_binary(doc) -> doc
    {:docs_v1, _, _, _, {_, doc}, _, _} when is_binary(doc) -> doc
    {:docs_v1, _, _, _, doc, _, _} when is_binary(doc) -> doc
    other -> flunk("expected moduledoc for #{inspect(module)}, got #{inspect(other)}")
  end
end

defp normalize_whitespace(text) do
  text |> String.replace(~r/\s+/, " ") |> String.trim()
end
```

**Usage in test:**

```elixir
moduledoc =
  Rindle.Upload.TusPlug
  |> moduledoc!()
  |> normalize_whitespace()
```

---

## Pattern: Runtime OPTIONS Truth (do NOT duplicate)

**Analog:** `test/rindle/upload/tus_plug_test.exs` lines 219–228

```elixir
test "OPTIONS advertises exactly the implemented extensions" do
  ...
  assert get_resp_header(conn, "tus-extension") == [
           "creation,expiration,termination,checksum,creation-defer-length,concatenation"
         ]
end
```

Division of labor: `tus_plug_test` = runtime; `docs_parity_test` = moduledoc advertises same scope.

---

## Pattern: Phase 74 TRUTH Parity Test Style

**Analog:** `test/install_smoke/docs_parity_test.exs` lines 260–268 (nine-task enumeration)

- Token asserts with `assert doc =~ snippet`
- Negative refutes with `refute Regex.match?(...)` 
- Module-level `@expected_*` constants for canonical strings

---

## PATTERN MAPPING COMPLETE
