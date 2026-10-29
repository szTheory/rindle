---
created: "2026-10-29"
title: Tighten Doctor resumable schema drift diagnosis
area: runtime-checks
source: Phase139 review WR-01 and WR-02
---

Doctor's resumable offset/default and expiry-index predicates date to47d1d5dc (2026-08-22). The offset check accepts10/100 because they contain0; the index check can accept an unfiltered index whose name/columns contain the expected words. These are real preexisting diagnostic gaps. Phase139's accepted shipped migrations have default0 and the proper partial index, so these findings do not invalidate its retained historical execution.

Implement a bounded local catalog check with no new dependency. Prefer structured PostgreSQL catalog facts over a general SQL parser. Test actual migrated PostgreSQL state and controlled drift: default10/100/null, allowed zero rendering/casts, missing/wrong/index-name-only predicates and correct partial index. Preserve supported prefixes/toolchains, Doctor diagnostic IDs and ordinary migration compatibility. Run Doctor/runtime-check and package-consumer regressions through normal protected PR/full CI. Do not mutate frozen readiness sources, reuse authority receipts or silently recertify the current head.
