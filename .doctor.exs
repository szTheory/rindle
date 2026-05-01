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
    Rindle.Workers.PurgeStorage
  ],
  ignore_paths: [],
  # Baseline thresholds — D-22 baseline-then-ratchet pattern. Plan 18-05 ratchets
  # these to the D-07 target values (100/100/100/95/95) once Plans 18-02..18-04
  # close the @doc/@spec gaps. The ratchet test in
  # test/rindle/doctor_thresholds_test.exs asserts the D-07 target and is
  # therefore RED in Plan 18-01 — that failure is the visible commitment.
  min_module_doc_coverage: 0,
  min_module_spec_coverage: 0,
  min_overall_doc_coverage: 50,
  min_overall_moduledoc_coverage: 100,
  min_overall_spec_coverage: 0,
  raise: false,
  reporter: Doctor.Reporters.Full,
  struct_type_spec_required: true,
  umbrella: false
}
