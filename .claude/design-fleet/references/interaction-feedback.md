
# Design Fleet -- Interaction feedback

Read the [Fleet policy](../../policy.md) for instruction precedence, existing authorization, interaction defaults, and evidence requirements.

> **Contract precedence:** if `VISION.md` declares timings, a components table, or error wording, those values win. Where the existing component already answers an action (its toast, its press value, its spinner), keep it. These rules apply where both are silent.

When you touch anything a person can press, submit, toggle or wait on, make it answer in the place they acted.

## Press

- `press-scale` -- Buttons, chips, cards-as-buttons and pressable rows scale to `scale(0.97)` on `:active`, over at most `150ms`, `ease-out`, transform only. Icon-only buttons scale to `scale(0.94)`.
- `press-no-delay` -- The scale decorates the press; it never gates or delays the action.
- `press-keyboard-instant` -- Enter and Space activation shows the pressed state instantly or not at all. No animation on keyboard input. Space sets `:active` too, so put `transition: none` on `:focus-visible` (or skip the scale in the key handler).
- `press-touch-gated` -- Hover styles live inside `@media (hover: hover)`. Touch gets press feedback only.
- `press-frequency` -- On actions people repeat all day (command palette, list rows, toolbar toggles) the press response is the only motion. No hover choreography, no entrance.

## Loading

- `load-in-place` -- A control that starts work shows loading in itself: the label is replaced by a spinner at the same height, the control keeps its exact width and height, nothing shifts. No full-page overlay for one control's work.
- `load-delay` -- Show the loading state only after `200ms`. Work that finishes sooner shows nothing.
- `load-busy-not-disabled` -- A loading control is `aria-busy="true"` and ignores repeat presses. It is not `disabled`: busy keeps full opacity, disabled uses the contract's disabled opacity. Announce the outcome in a polite live region; `aria-busy` alone says little to a screen reader.
- `load-skeleton` -- Content that takes longer than `1s` gets a skeleton shaped like the final layout, not a centred spinner.
- `load-optimistic` -- Reversible actions (like, star, toggle, reorder, rename) update first and reconcile after; on failure, revert and say why. Irreversible or paid actions wait for the server.
- `load-progress` -- Work longer than `5s` shows progress or a step count, and a way to cancel.

## Result

- `result-in-place` -- Success shows where the action happened: the label turns past tense (`Save changes` becomes `Saved`) for `1.5s`, then returns. A toast is only for results the person cannot see from where they are. Where the project already reports results through its toast, keep the toast.
- `result-error-actionable` -- An error says what happened and what to do, in the contract's wording when it has some. Field errors mark the field and clear on the next change to it. Inline field messages and toasts both have their place; follow the project's pattern.
- `result-undo` -- Reversible deletion gets undo in a toast for at least `5s`, not a confirm dialog. Confirm only the irreversible and the expensive.
- `result-focus` -- When an action removes or replaces the focused element, focus moves to the next item, the list or the heading. Never to `body`.

## States

- `states-reachable` -- Build the states this element can actually reach: default, hover, focus-visible and active for anything pressable; disabled only when it can be disabled; loading, error and success only when it starts work. A link has no loading state. The contract's components table, when present, says which states each family needs.
- `states-focus-visible` -- Focus is visible on keyboard and never removed without a `:focus-visible` replacement using the contract's ring token.
- `states-target` -- Pressable targets are at least `44px` square on touch and `32px` with a pointer. Grow the hit area with a pseudo-element, not the visual.

## Keyboard

- `kb-skip-link` -- A page with a repeated block before its main content (top nav, filter sidebar, toolbar) starts with a skip link to that content: the first focusable element, visible on focus, pointing at an `id` that exists. A sidebar counts as much as a nav.
- `kb-escape-closes` -- Escape closes the open overlay: dialog, drawer, popover, menu, command palette. Focus returns to the control that opened it.
- `kb-browser-keys` -- Never override the browser's own shortcuts: copy, paste, cut, new tab, close tab, reload, the address bar, save.
- `kb-scope` -- A page-level shortcut never fires while the person types: skip inputs, textareas, selects and anything `contenteditable`.
- `kb-no-motion` -- Arrow keys, Tab and Enter move and confirm instantly. Animate only moves the pointer started.

## What the machine checks

Lint checks `I2` (focus removed without `:focus-visible`), `A6` (overshoot easing) and, once `VISION.md` has a components table, `P14` (required states have a source signal in the canonical file, heuristic). Everything else here is agent review or a rendered check. A zero lint exit does not prove any of it.
