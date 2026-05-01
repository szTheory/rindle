defmodule Rindle.Scanner do
  @moduledoc """
  Behaviour contract for security scanning before promotion.

  Scanner implementations may inspect file contents, and any storage I/O must
  stay outside database transactions.
  """

  @doc """
  Scans the file at `path` for malware or policy violations.

  Implementations should return `:ok` for clean content or
  `{:quarantine, reason}` to mark the staged upload as quarantined. The reason
  is surfaced through telemetry and stored on the upload session for operator
  follow-up. Scanning runs before promotion, so quarantined files never reach
  the trusted asset state.
  """
  @callback scan(path :: Path.t()) :: :ok | {:quarantine, term()}
end
