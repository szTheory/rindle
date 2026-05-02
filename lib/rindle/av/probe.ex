defmodule Rindle.AV.Probe do
  @moduledoc false

  @doc """
  Synchronously checks if FFmpeg is installed and is version >= 6.0.
  Raises a RuntimeError if the requirements are not met.
  """
  def check_ffmpeg!(runner \\ &System.cmd/2) do
    case runner.("ffmpeg", ["-version"]) do
      {output, 0} ->
        case Regex.run(~r/ffmpeg version (\d+\.\d+)/, output) do
          [_, version] ->
            if Version.compare(version <> ".0", "6.0.0") == :lt do
              raise "Rindle requires FFmpeg >= 6.0, found: #{version}"
            end

            :ok

          _ ->
            raise "Could not parse FFmpeg version."
        end

      _ ->
        raise "FFmpeg is not installed or not in PATH."
    end
  end
end
