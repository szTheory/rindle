defmodule Rindle.Processor.Ffmpeg do
  @moduledoc """
  FFmpeg processor adapter using the `Rindle.Processor` behaviour and integrating with the MuonTrap subprocess wrapper.
  """

  @behaviour Rindle.Processor

  alias Rindle.AV.Subprocess
  alias Rindle.Security.Argv

  @impl Rindle.Processor
  @spec process(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
  def process(source_path, variant_spec, destination_path) do
    case build_args(source_path, variant_spec, destination_path) do
      {:ok, args} ->
        full_args = Subprocess.build_args("ffmpeg", args, [])
        command_str = Enum.join(["ffmpeg" | full_args], " ")

        with {:ok, _} <- Argv.validate(command_str) do
          case Subprocess.run("ffmpeg", args) do
            {_output, 0} -> {:ok, destination_path}
            {output, status} -> {:error, {:ffmpeg_failed, status, output}}
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_args(source, %{capability: :video_transcode} = spec, dest) do
    base = ["-i", source]
    
    vcodec = if Map.has_key?(spec, :video_codec), do: ["-c:v", spec.video_codec], else: []
    acodec = if Map.has_key?(spec, :audio_codec), do: ["-c:a", spec.audio_codec], else: []
    
    scale = 
      case {Map.get(spec, :width), Map.get(spec, :height)} do
        {w, h} when not is_nil(w) and not is_nil(h) -> ["-vf", "scale=#{w}:#{h}"]
        _ -> []
      end
      
    {:ok, base ++ vcodec ++ acodec ++ scale ++ [dest]}
  end

  defp build_args(source, %{capability: :audio_normalize} = _spec, dest) do
    {:ok, ["-i", source, "-af", "loudnorm=I=-16:TP=-1.5:LRA=11", dest]}
  end

  defp build_args(_source, _spec, _dest) do
    {:error, :unsupported_capability}
  end
end
