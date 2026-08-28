defmodule Rindle.Ops.RuntimeChecks.IntegrationChecks do
  @moduledoc false

  alias Rindle.Ops.RuntimeChecks.IntegrationChecks.{GCS, Mux}
  alias Rindle.Storage.Capabilities

  @doc false
  def schedule(profile_groups, env, opts, readers) do
    Mux.schedule(profile_groups.streaming, env, opts, readers.mux_config) ++
      GCS.schedule(profile_groups.gcs, opts, readers.gcs_config) ++
      schedule_tus(profile_groups.tus)
  end

  @doc false
  def probe_gcs_bucket(bucket, finch_name, goth_name, opts \\ []),
    do: GCS.probe_gcs_bucket(bucket, finch_name, goth_name, opts)

  @doc false
  def do_probe(bucket, finch_name, goth_name, opts \\ []),
    do: GCS.do_probe(bucket, finch_name, goth_name, opts)

  defp schedule_tus([]), do: []
  defp schedule_tus(profiles), do: [fn -> check_tus_capability(profiles) end]

  defp check_tus_capability(profiles) do
    mismatches =
      Enum.reject(profiles, fn profile ->
        adapter = safely_storage_adapter(profile)
        is_atom(adapter) and Capabilities.supports?(adapter, :tus_upload)
      end)

    if mismatches == [] do
      result(
        :ok,
        "Configured tus profiles advertise :tus_upload support.",
        "Keep `config :rindle, :tus_profiles, [...]` aligned with profiles whose adapters support tus."
      )
    else
      result(
        :error,
        "Tus is configured for #{Enum.map_join(mismatches, ", ", &inspect/1)}, but the storage adapter does not advertise :tus_upload.",
        "Either mount TusPlug only for profiles backed by a :tus_upload-capable adapter, or remove the profile from `config :rindle, :tus_profiles, [...]`."
      )
    end
  end

  defp safely_storage_adapter(profile) do
    if function_exported?(profile, :storage_adapter, 0), do: profile.storage_adapter()
  rescue
    _ -> nil
  end

  defp result(status, summary, fix),
    do: {:runtime_check, status, "doctor.tus_capability", :profiles, summary, fix, %{}}
end
