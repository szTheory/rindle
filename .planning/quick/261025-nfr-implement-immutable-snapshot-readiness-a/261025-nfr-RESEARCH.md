# Snapshot acceptance research

Existing ownership: acceptance binds subject and retained bytes; Closure joins local,
Actions, remote inventories and adoption; the immutable Elixir validator replays them.
Every owner currently independently requires subject == remote main. Retention also
conflates workflow producer SHA with evidence subject. Changing just one comparison
would leave either starvation or an unauthenticated candidate. No dependencies needed.

Implement an explicit snapshot mode and versioned policy, retaining legacy current-head
mode for compatibility. Admit an explicit full SHA only after authenticated protected-main
ancestry and actual push-main CI provenance, with executing policy/controller bytes equal
to that candidate. A PR ancestor alone is insufficient. Bind raw public provenance into
the immutable graph. Keep producer workflow SHA separate from candidate subject and
validate both. Candidate changes require a new immutable attempt.

Mutable inbox/security/protection and authoritative adoption/release inputs must be
read fresh from remote main, not historical candidate files. Candidate lockfiles remain
the package security subject. Refresh byte-bound mutable authority objects and preserve
all original archive/manifest bytes. Current-main readiness remains a separate refresh.

Primary references checked October25:
- https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows : schedule runs default-branch code; dispatch identity differs.
- https://docs.github.com/en/rest/commits/commits#compare-two-commits : compare validates candidate ancestry, not prior default-branch tip alone.
- https://github.com/actions/checkout : exact ref checkout; perform trusted admission before executing candidate code.

Tests must retain existing adversarial coverage plus main advance before/during/after
qualification and refresh, arbitrary PR/fork candidate, missing control-policy bytes,
latest failed attempt, wrong event/SHA/attempt, private-source denial, substituted artifact,
mutable-authority drift, cleanup failures and metadata-only main advancement.
