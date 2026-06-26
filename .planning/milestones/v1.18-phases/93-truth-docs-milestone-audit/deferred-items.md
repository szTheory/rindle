# Deferred Items — Phase 93

## Out-of-scope pre-existing warnings (discovered during 93-01 execution)

- `lib/rindle/admin/queries.ex:224` — unused private function `action/4`
  (clause with `opts \\ []` default arg) triggers a `--warnings-as-errors`
  compile failure. Pre-existing on clean HEAD (verified by stashing the 93-01
  edit and recompiling). Not introduced by this plan; outside the four files
  93-01 edits (lib/rindle.ex + three guides). Plain `mix compile` succeeds.
  Recommend resolving in a follow-up plan (likely Phase 90 Actions ownership)
  by either using or removing the unused `action/4` clause.
