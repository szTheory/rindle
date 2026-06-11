# Admin Console Motion

Rindle Admin motion is materialization, feedback, and state continuity. It is not
entertainment, marketing polish, or decoration.

Phase 86 locks motion rules only. Phase 88 and Phase 92 implement and verify the behavior.

## Token Contract

Motion must use brand token durations and the single easing token:

| Token | Duration / value | Use |
| --- | --- | --- |
| `--rindle-motion-press` | `120ms` | Press and control feedback. |
| `--rindle-motion-popover` | `160ms` | Origin-aware popovers and drawers. |
| `--rindle-motion-toast` | `200ms` | Toast materialization and dismissal. |
| `--rindle-motion-transition` | `300ms` | Page/surface transitions that preserve orientation. |
| `--rindle-motion-easing` | token value | The only easing token for console motion. |

Do not introduce raw one-off durations in console components.

## Allowed Uses

Allowed motion is tied to operational feedback:

- press feedback for buttons, toggles, and segmented controls
- origin-aware popovers and drawers
- toast materialization for completed work or recoverable failures
- state continuity for real PubSub/LiveView updates
- page/surface transitions that preserve orientation

Animations may clarify that a panel opened from a control, that a toast appeared because
work finished, or that a lifecycle state updated from real data.

## Forbidden Uses

The console forbids:

- decorative animation
- parallax
- bouncing
- infinite loops
- marketing-style hero motion
- loading animation not backed by real pending work
- large-scale transforms that pull attention from operational status

If motion would make an operator wait longer to read failure or destructive state, do not
use it.

## Reduced Motion

All console motion must respect `prefers-reduced-motion`.

When reduction is requested:

- disable non-essential transitions
- keep state changes immediate
- preserve focus visibility
- avoid opacity-only meaning

Destructive or failure states must use immediate non-animated state changes even when
normal motion is enabled.

## Live State Continuity

LiveView/PubSub updates should use motion only when there is a real event:

- variant started
- variant progress changed
- variant ready
- variant failed
- variant cancelled
- upload session state changed
- asset state changed

The animation explains continuity; the label and state value carry the meaning.

## Feedback Rules

| Interaction | Motion |
| --- | --- |
| Primary button press | `--rindle-motion-press`, immediate disabled/loading only while work is pending. |
| Drawer from row action | `--rindle-motion-popover`, origin-aware from the invoking row/control. |
| Toast after operation | `--rindle-motion-toast`, short materialization with readable dwell time. |
| Screen transition | `--rindle-motion-transition`, preserve user orientation. |
| Destructive confirmation error | No animated delay; show state immediately. |

## Downstream Constraints

- Phase 88 component CSS uses these tokens only.
- Phase 90 destructive flows keep failure/destructive state immediate.
- Phase 92 screenshot polish must not add decorative motion to make captures look richer.
