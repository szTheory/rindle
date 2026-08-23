defmodule Rindle.Ops.RuntimeChecks.OwnershipChecks do
  @moduledoc false

  @doc false
  def schedule(
        migration_statuses,
        rindle_schema_catalog,
        resumable_session_schema_catalog,
        ownership_snapshot,
        profiles,
        oban_config,
        checks
      ) do
    [
      fn -> checks.migration_pending.(migration_statuses, rindle_schema_catalog) end,
      fn -> checks.migration_unresolved.(migration_statuses, rindle_schema_catalog) end,
      fn -> checks.resumable_session_schema.(resumable_session_schema_catalog) end,
      fn -> checks.rindle_schema_ready.(ownership_snapshot.rindle) end,
      fn -> checks.oban_default_instance.(oban_config) end,
      fn -> checks.oban_jobs_ready.(ownership_snapshot.oban) end,
      fn -> checks.oban_required_queues.(profiles, oban_config) end
    ]
  end
end
