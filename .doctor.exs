%Doctor.Config{
  exception_moduledoc_required: true,
  failed: false,
  ignore_modules: [
    # Application supervisor (auto-generated, not adopter-facing)
    Rindle.Application,

    # Rindle.Internal.* namespace (regex catches future additions)
    ~r/^Rindle\.Internal\./,

    # Rindle.Security.* helpers (mime/filename validation primitives)
    ~r/^Rindle\.Security\./,

    # Rindle.Ops.* operational service modules (Mix.Tasks call into these)
    ~r/^Rindle\.Ops\./,

    # Domain finite-state machines and stale-policy (schema modules stay public)
    Rindle.Domain.AssetFSM,
    Rindle.Domain.UploadSessionFSM,
    Rindle.Domain.VariantFSM,
    Rindle.Domain.StalePolicy,

    # Profile internal helpers (Rindle.Profile itself is public)
    Rindle.Profile.Validator,
    Rindle.Profile.Digest,

    # Infrastructure helpers (configuration + repo + storage capability resolution)
    Rindle.Config,
    Rindle.Repo,
    Rindle.Storage.Capabilities,

    # Internal pipeline workers (AbortIncompleteUploads / CleanupOrphans are public)
    Rindle.Workers.PromoteAsset,
    Rindle.Workers.ProcessVariant,
    Rindle.Workers.PurgeStorage,

    # Test-support case template (@moduledoc false, not adopter-facing)
    Rindle.DataCase
  ],
  ignore_paths: [],
  # D-07 target thresholds — ratcheted in Plan 18-05 from the Plan 18-01 baseline
  # per the D-22 baseline-then-ratchet pattern. The ratchet harness at
  # test/rindle/doctor_thresholds_test.exs (D-23) asserts these exact values and
  # ships GREEN at this commit. Future doc/spec regressions on the public
  # surface fail `mix doctor --raise` in CI.
  min_module_doc_coverage: 100,
  min_module_spec_coverage: 95,
  min_overall_doc_coverage: 100,
  min_overall_moduledoc_coverage: 100,
  min_overall_spec_coverage: 95,
  raise: false,
  reporter: Doctor.Reporters.Full,
  struct_type_spec_required: true,
  umbrella: false
}
