[
  {"lib/rindle.ex", :call_without_opaque},
  {"lib/rindle/upload/broker.ex", :call_without_opaque},
  {"lib/rindle/workers/promote_asset.ex", :call_without_opaque},
  # Pre-existing pattern_match / pattern_match_cov warnings surfaced after
  # Phase 34 PLT regen with :mux + :jose. Not Phase 34 surface; tracked
  # in .planning/phases/34-mux-rest-adapter-server-push-sync/deferred-items.md.
  {"lib/rindle/html.ex", :pattern_match},
  {"lib/rindle/ops/runtime_status.ex", :pattern_match_cov},
  {"lib/rindle/workers/process_variant.ex", :pattern_match},
  {"lib/rindle/workers/process_variant.ex", :pattern_match_cov},
  {"lib/rindle/workers/promote_asset.ex", :pattern_match_cov}
]