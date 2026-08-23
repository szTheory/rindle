defmodule Rindle.Ops.RuntimeChecks.CoreChecks do
  @moduledoc false

  @doc false
  def schedule(profiles, probe, local_playback_route, resolved, env, checks) do
    [
      fn -> checks.delivery_support.(profiles) end,
      fn -> checks.ffmpeg_runtime.(probe) end,
      fn -> checks.local_playback.(profiles, local_playback_route) end,
      fn -> checks.profile_runtime_fit.(resolved, env) end
    ]
  end
end
