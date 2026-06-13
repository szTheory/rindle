# Phase 90: Console Ops Actions - Validation Architecture

## Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit + Phoenix.LiveViewTest |
| Config file | `test_helper.exs` |
| Quick run command | `mix test test/rindle/admin/live/` |
| Full suite command | `mix test` |

## Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ADMIN-04 | Renders owner erasure preview and enforces typed confirm | unit | `mix test test/rindle/admin/live/actions_live_test.exs` | ❌ Wave 0 |
| ADMIN-04 | Blocks execution if target changes after preview | unit | `mix test test/rindle/admin/live/actions_live_test.exs` | ❌ Wave 0 |
| ADMIN-04 | Renders partial batch erasure receipts safely | unit | `mix test test/rindle/admin/live/actions_live_test.exs` | ❌ Wave 0 |
| ADMIN-04 | Delegates to variant regeneration appropriately | unit | `mix test test/rindle/admin/live/actions_live_test.exs` | ❌ Wave 0 |

## Sampling Rate
- **Per task commit:** `mix test test/rindle/admin/live/`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

## Wave 0 Gaps
- [ ] `test/rindle/admin/live/actions_live_test.exs` — covers ADMIN-04 workflows and assertions against `data-rindle-admin-*` stable selectors.