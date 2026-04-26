defmodule Rindle.Adopter.CanonicalApp.Profile do
  @moduledoc """
  Canonical adopter profile fixture.

  This module is the source of truth for the snippet shown in
  `guides/getting_started.md` (DOC-01). If this file changes, that guide
  must be updated to match (D-16; CI-08 adopter lane is the parity check).

  Storage: `Rindle.Storage.S3` pointed at MinIO in CI / local dev.
  """

  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [thumb: [mode: :fit, width: 64, height: 64]],
    allow_mime: ["image/png", "image/jpeg"],
    max_bytes: 10_485_760
end
