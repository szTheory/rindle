defmodule Rindle.AV.MetadataSanitizerTest do
  use ExUnit.Case, async: true
  doctest Rindle.AV.MetadataSanitizer

  alias Rindle.AV.MetadataSanitizer

  describe "sanitize/1 (string clause)" do
    test "strips \\x00, \\x07, \\x1F control chars" do
      assert MetadataSanitizer.sanitize(<<"foo", 0x00, "bar", 0x07, "baz", 0x1F>>) ==
               "foobarbaz"
    end

    test "preserves \\t (\\x09)" do
      assert MetadataSanitizer.sanitize("col1\tcol2") == "col1\tcol2"
    end

    test "strips \\n and \\r (literal D-19; see RESEARCH.md A3)" do
      assert MetadataSanitizer.sanitize("line1\nline2\rline3") == "line1line2line3"
    end

    test "truncates to <= 1024 bytes" do
      input = String.duplicate("a", 2000)
      output = MetadataSanitizer.sanitize(input)
      assert byte_size(output) <= 1024
    end

    test "exact 1024-byte ASCII input is returned unchanged" do
      input = String.duplicate("a", 1024)
      assert MetadataSanitizer.sanitize(input) == input
    end
  end

  describe "sanitize/1 (recursive shape)" do
    test "recurses into maps" do
      input = %{"title" => <<"hi", 0x07>>, "nested" => %{"k" => "v\t1"}}

      assert MetadataSanitizer.sanitize(input) == %{
               "title" => "hi",
               "nested" => %{"k" => "v\t1"}
             }
    end

    test "recurses into lists" do
      input = ["a\x00b", %{"x" => "y\x1F"}]
      assert MetadataSanitizer.sanitize(input) == ["ab", %{"x" => "y"}]
    end

    test "passes through non-string non-collection values unchanged" do
      assert MetadataSanitizer.sanitize(42) == 42
      assert MetadataSanitizer.sanitize(:atom) == :atom
      assert MetadataSanitizer.sanitize(nil) == nil
      assert MetadataSanitizer.sanitize(true) == true
    end
  end

  describe "truncate_to_bytes/2" do
    test "returns input unchanged when byte_size <= max_bytes" do
      assert MetadataSanitizer.truncate_to_bytes("hello", 5) == "hello"
      assert MetadataSanitizer.truncate_to_bytes("hello", 100) == "hello"
    end

    test "drops the trailing partial codepoint at a multi-byte boundary" do
      # "héllo" is 6 bytes (h=1, é=2, l=1, l=1, o=1)
      assert MetadataSanitizer.truncate_to_bytes("héllo", 4) == "hél"
      assert MetadataSanitizer.truncate_to_bytes("héllo", 3) == "hé"
      assert MetadataSanitizer.truncate_to_bytes("héllo", 2) == "h"
      assert MetadataSanitizer.truncate_to_bytes("héllo", 1) == "h"
    end

    test "1023 bytes of ASCII followed by a 3-byte char with max=1024 drops the partial" do
      ascii = String.duplicate("a", 1023)
      input = ascii <> "€"
      output = MetadataSanitizer.truncate_to_bytes(input, 1024)
      assert byte_size(output) == 1023
      assert String.valid?(output)
      assert output == ascii
    end

    test "always emits valid UTF-8" do
      base = "ñé€𝄞"

      for n <- 0..15 do
        out = MetadataSanitizer.truncate_to_bytes(base, n)
        assert String.valid?(out), "invalid UTF-8 at max_bytes=#{n}: #{inspect(out)}"
      end
    end

    test "max_bytes=0 returns empty binary" do
      assert MetadataSanitizer.truncate_to_bytes("anything", 0) == <<>>
    end
  end
end
