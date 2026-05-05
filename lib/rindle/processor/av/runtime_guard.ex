defmodule Rindle.Processor.AV.RuntimeGuard do
  @moduledoc """
  Runtime admission checks for AV processing.
  """

  require Logger

  @default_max_output_bytes 500_000_000

  @spec check!(map(), keyword()) :: :ok | {:error, term()}
  def check!(variant_spec, opts \\ []) do
    env = Keyword.get(opts, :env, System.get_env())

    with :ok <- check_runtime(variant_spec, env),
         :ok <- check_disk(variant_spec, opts) do
      :ok
    end
  end

  @spec warn_unsupported_runtime([map()], keyword()) :: :ok
  def warn_unsupported_runtime(profiles, opts \\ []) do
    env = Keyword.get(opts, :env, System.get_env())
    logger = Keyword.get(opts, :logger, &log_warning/3)

    case unsupported_runtime(env) do
      nil ->
        :ok

      runtime ->
        affected_profiles =
          profiles
          |> Enum.filter(&profile_has_av?/1)
          |> Enum.map(&profile_name/1)
          |> Enum.sort()

        if affected_profiles == [] do
          :ok
        else
          logger.(:warning, "rindle.av.runtime_guard.unsupported_runtime", %{
            runtime: runtime,
            affected_profiles: affected_profiles
          })

          :ok
        end
    end
  end

  defp check_runtime(variant_spec, env) do
    if video_variant?(variant_spec) do
      case unsupported_runtime(env) do
        nil -> :ok
        runtime -> {:error, {:unsupported_ephemeral_runtime, runtime}}
      end
    else
      :ok
    end
  end

  defp check_disk(variant_spec, opts) do
    if av_variant?(variant_spec) do
      free_bytes =
        Keyword.get_lazy(opts, :disk_free_bytes, fn ->
          Keyword.get(opts, :path, Rindle.AV.TempRunDir.root_dir())
          |> disk_free_bytes()
        end)

      required_bytes = max_output_bytes(variant_spec) * 2

      if free_bytes < required_bytes do
        {:error, {:insufficient_disk_headroom, %{free_bytes: free_bytes, required_bytes: required_bytes}}}
      else
        :ok
      end
    else
      :ok
    end
  end

  defp max_output_bytes(variant_spec) do
    Map.get(variant_spec, :max_output_bytes, @default_max_output_bytes)
  end

  defp unsupported_runtime(env) when is_map(env) do
    cond do
      present?(env["LAMBDA_TASK_ROOT"]) or present?(env["AWS_LAMBDA_FUNCTION_NAME"]) -> :lambda
      present?(env["VERCEL"]) or present?(env["VERCEL_ENV"]) or present?(env["NOW_REGION"]) -> :vercel
      true -> nil
    end
  end

  defp disk_free_bytes(path) do
    case System.cmd("df", ["-Pk", path], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> List.last()
        |> String.split(~r/\s+/, trim: true)
        |> Enum.at(3, "0")
        |> String.to_integer()
        |> Kernel.*(1024)

      _ ->
        0
    end
  end

  defp av_variant?(%{kind: kind}) when kind in [:video, :audio, :waveform], do: true
  defp av_variant?(%{output_kind: kind}) when kind in [:video, :audio, :waveform], do: true
  defp av_variant?(_variant_spec), do: false

  defp video_variant?(%{kind: :video}), do: true
  defp video_variant?(%{output_kind: :video}), do: true
  defp video_variant?(_variant_spec), do: false

  defp profile_has_av?(%{variants: variants}) when is_list(variants) do
    Enum.any?(variants, fn
      {_name, spec} when is_map(spec) -> av_variant?(spec)
      spec when is_map(spec) -> av_variant?(spec)
      _other -> false
    end)
  end

  defp profile_has_av?(_profile), do: false

  defp profile_name(%{name: name}), do: to_string(name)
  defp profile_name(profile), do: inspect(profile)

  defp present?(value), do: is_binary(value) and value != ""

  defp log_warning(level, message, metadata) do
    Logger.log(level, message, metadata)
  end
end
