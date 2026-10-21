defmodule Rindle.Processor.AV.OutputProbeTest do
  use ExUnit.Case, async: false

  alias Rindle.Processor.AV.OutputProbe

  @tag :tmp_dir
  test "waveform output must carry the requested sample length", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "waveform.json")
    File.write!(path, Jason.encode!(%{"length" => 128, "samples" => []}))
    assert OutputProbe.verify!(path, %{}, %{output_kind: :waveform, length: 128}) == {:ok, %{}}

    assert OutputProbe.verify!(path, %{}, %{kind: :waveform, length: 256}) ==
             {:error, {:waveform_length_mismatch, %{expected: 256, actual: 128}}}
  end

  @tag :tmp_dir
  test "unreadable and malformed waveform outputs preserve their failure", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "waveform.json")
    spec = %{kind: :waveform, length: 128}
    assert OutputProbe.verify!(path, %{}, spec) == {:error, :enoent}
    File.write!(path, "not JSON")
    assert {:error, %Jason.DecodeError{}} = OutputProbe.verify!(path, %{}, spec)
    File.write!(path, Jason.encode!(%{"length" => nil}))

    assert OutputProbe.verify!(path, %{}, spec) ==
             {:error, {:waveform_length_mismatch, %{expected: 128, actual: nil}}}
  end
end
