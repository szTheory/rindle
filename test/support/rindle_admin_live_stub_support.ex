defmodule Rindle.Admin.LiveStubSupport do
  @moduledoc false

  @admin_live_modules [
    Rindle.Admin.Live.HomeLive,
    Rindle.Admin.Live.AssetsLive,
    Rindle.Admin.Live.UploadSessionsLive,
    Rindle.Admin.Live.VariantsJobsLive,
    Rindle.Admin.Live.RuntimeDoctorLive,
    Rindle.Admin.Live.ActionsLive
  ]

  def ensure_placeholder_modules! do
    if Code.ensure_loaded?(Phoenix.LiveView) do
      Enum.each(@admin_live_modules, &ensure_placeholder_module!/1)
    end

    :ok
  end

  defp ensure_placeholder_module!(module) do
    :global.trans({__MODULE__, module}, fn ->
      unless Code.ensure_loaded?(module) do
        Module.create(
          module,
          quote do
            use Phoenix.LiveView
          end,
          Macro.Env.location(__ENV__)
        )
      end
    end)

    :ok
  end
end
