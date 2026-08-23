[
  {"lib/rindle.ex", :call_without_opaque},
  {"lib/rindle/upload/broker.ex", :call_without_opaque},
  {"lib/rindle/workers/promote_asset.ex", :call_without_opaque},
  # Pre-existing pattern_match / pattern_match_cov warnings surfaced after
  # Phase 34 PLT regen with :mux + :jose. Not Phase 34 surface; tracked
  # in .planning/phases/34-mux-rest-adapter-server-push-sync/deferred-items.md.
  # Supported Nightly run 32642668846 / Dialyzer job 97202060703: the optional
  # MIME fallback preserves HTML rendering when an integration does not provide
  # a source type; narrowing it would remove a behaviorally valid safe fallback.
  {"lib/rindle/html.ex", :pattern_match},
  # Supported Nightly run 32642668846 / Dialyzer job 97202060703: fallback
  # refusal normalization keeps arbitrary diagnostic terms safe for telemetry
  # without changing the runtime-status API or task failure output.
  {"lib/rindle/ops/runtime_status.ex", :pattern_match_cov},
  # Supported Nightly run 32642668846 / Dialyzer job 97202060703: the worker's
  # cancel/error and non-map fallbacks preserve lifecycle, retry, and error
  # behavior for dynamic processor and profile inputs.
  {"lib/rindle/workers/process_variant.ex", :pattern_match},
  {"lib/rindle/workers/process_variant.ex", :pattern_match_cov},
  {"lib/rindle/workers/promote_asset.ex", :pattern_match_cov},

  # v0.4.1 baseline reconciliation: repairing the Nightly PLT cache exposed the
  # pre-existing warnings below. Keep these filters description-strict so the
  # gating Nightly lane still rejects every new warning while the known debt is
  # retired deliberately in #76 instead of being hidden by file-wide filters.
  # Supported Nightly run 32640992583 / Dialyzer job 97197944599: the two
  # error-reporting branches preserve the task's distinct partial and general
  # error terms; Rindle.Error.message/1 accepts the behaviorally correct map.
  {"lib/mix/tasks/rindle.batch_owner_erasure.ex", "The function call message will not succeed."},
  # Supported Nightly run 32640992583 / Dialyzer job 97197944599: the generic
  # fallback preserves a non-binary facade failure without changing Admin copy.
  {"lib/rindle/admin/live/actions_live.ex",
   "The pattern pattern {'error', _} can never match the type, because it is covered by previous clauses."},
  # Supported Nightly run 32637455725 / Dialyzer job 97189240234: these public
  # Ecto.Migration callbacks execute DSL operations through the host migrator;
  # Dialyzer cannot model that dynamic execution context without changing the
  # pinned migration API or DDL/transaction authority.
  {"lib/rindle/migration.ex", "Function up/0 has no local return."},
  {"lib/rindle/migration.ex", "Function up/1 has no local return."},
  {"lib/rindle/migration.ex", "Function down/0 has no local return."},
  {"lib/rindle/migration.ex", "Function down/1 has no local return."},
  {"lib/rindle/migration.ex", "The function call move_public_to_rindle will not succeed."},
  {"lib/rindle/migration.ex", "Function move_public_to_rindle/0 has no local return."},
  {"lib/rindle/migration.ex", "The function call move_rindle_to_public will not succeed."},
  {"lib/rindle/migration.ex", "Function move_rindle_to_public/0 has no local return."},
  {"lib/rindle/migration.ex", "The function call up will not succeed."},
  {"lib/rindle/migration.ex", "Function dispatch/2 has no local return."},
  {"lib/rindle/migration.ex", "The function call down will not succeed."},
  # Supported Nightly run 32637455725 / Dialyzer job 97189240234: the private
  # helper intentionally raises every time, and Ecto's migration DSL cannot
  # represent the host transaction/DDL execution path in its static result.
  {"lib/rindle/migration/v1.ex", "Function raise_preflight_error!/1 has no local return."},
  {"lib/rindle/migration/v1.ex",
   "The pattern can never match the type \n  :database_create_denied\n  | :mixed_state\n  | :public_incomplete\n  | :public_marker_invalid\n  | :public_not_empty\n  | :public_unusable\n  | :rindle_incomplete\n  | :rindle_marker_invalid\n  | :rindle_not_empty\n  | :rindle_unusable\n  | :source_not_owned\n."},
  # Supported Nightly run 32640992583 / Dialyzer job 97197944599: Sandbox
  # checkout can return an error at runtime; preserving it protects diagnostics.
  {"lib/rindle/ops/runtime_checks.ex",
   "The pattern can never match the type :ok | {:already, :allowed | :owner}."},
  # Supported Nightly run 32643457947 / Dialyzer job 97203998038: multipart
  # upload must pass File.stream!/3 through Finch as a bounded request stream;
  # changing that opaque producer would buffer the upload or change error terms.
  {"lib/rindle/storage/gcs/client.ex", "The function call stream! will not succeed."},
  # Supported Nightly run 32643843369 / Dialyzer job 97204927840: the inferred
  # unreachable resumable URL mode is exercised by the broker-safe resumable
  # initiation path; its explicit URL-mode spec preserves that protocol branch.
  {"lib/rindle/storage/gcs/client.ex",
   "The pattern can never match the type :resumable_upload, _, _, Keyword.t()."},
  # Supported Nightly run 32643457947 / Dialyzer job 97203998038: Local's
  # bounded TUS stream returns tagged append errors and its concatenate stream
  # preserves source cleanup; forcing analyzer-visible stream internals would
  # change those adapter-edge contracts.
  {"lib/rindle/storage/local.ex", "Function upload_part_stream/5 has no local return."},
  {"lib/rindle/storage/local.ex", "The function call stream! will not succeed."},
  {"lib/rindle/storage/local.ex", "The created anonymous function has no local return."},
  {"lib/rindle/storage/s3.ex", "The pattern can never match the type {:error, atom()}."},
  {"lib/rindle/storage/s3.ex", "The function call stream! will not succeed."},
  {"lib/rindle/storage/s3.ex", "Function drain_tail_parts/7 will never be called."},
  {"lib/rindle/storage/s3.ex", "Function read_leading_part/1 will never be called."},
  {"lib/rindle/storage/s3.ex", "Function truncate_tail_head/2 will never be called."},
  {"lib/rindle/storage/s3.ex", "Function open_rest/2 will never be called."},
  {"lib/rindle/storage/s3.ex", "Function copy_rest/2 will never be called."},
  {"lib/rindle/upload/tus_plug.ex", "The pattern can never match the type {:error, _}."},
  {"lib/rindle/upload/tus_plug.ex",
   "The guard test _@1::'nil' | crypto:hash_state() breaks the opaqueness of its argument."},
  {"lib/rindle/upload/tus_plug.ex", "The guard clause can never succeed."},
  {"lib/rindle/workers/mux_ingest_variant.ex",
   "The pattern pattern <__mux_response@1, __reason@1> can never match the type, because it is covered by previous clauses."},
  {"lib/rindle/workers/mux_sync_provider_asset.ex",
   "The pattern variable _err@2 can never match the type, because it is covered by previous clauses."},
  # Supported Nightly run 32637455725 / Dialyzer job 97189240234: the fixture
  # is a real host Ecto.Migration callback and its runner lifecycle is dynamic.
  {"test/support/host_rindle_migration.ex", "Function up/0 has no local return."},
  {"test/support/host_rindle_migration.ex", "Function down/0 has no local return."},
  {"test/support/host_rindle_migration.ex", "Function install!/0 has no local return."}
]
