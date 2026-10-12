# Motion review

Use this when the motion itself is under review: a diff that adds or changes transitions, springs, gestures or keyframes, or a question about feel ("does this drawer feel right?", "the modal feels slow"). A single transition inside a wider UI change belongs to the [visual critique](critique.md). The [review voice](review-guidance.md) applies.

Start from no. Motion that merely runs has not earned approval: if it lands late, starts from the wrong place, or decorates something people do a hundred times a day, it gets a finding.

## What the lint already says

A3 (a reduced-motion branch in files that use Motion, a wrapping `<MotionConfig reducedMotion="user">` included) and A6 (overshooting curves outside gesture code) are source checks, and P7 compares durations with the contract's timing table when it has one. A1, A2, A4 and A5 are your judgment. Quote the lint as it reported, never wider. Then play the motion, at full speed and slowed down, to judge its timing, frequency, interruption, origin and end states. Without a running UI, say the review is source-only.

## The numbers to hold it to

The contract's timing table wins. Where it is silent, these are the house values (`content/motion.md`, `content/interaction.md`):

| Motion | House value |
| --- | --- |
| Press | `scale(0.97)` on `:active`, icon-only buttons `scale(0.94)`; at most 150ms, `ease-out`, transform only; no animation when Enter or Space activates it |
| Hover | Scale no larger than `1.02`, over 120 to 180ms, inside `@media (hover: hover)` |
| Entrance | From `scale(0.95)` with opacity; large surfaces such as sheets and big panels scale less, from `scale(0.98)`. Never from `scale(0)` |
| UI duration | Under 300ms: a modal opens in 200ms and closes in 150ms, a page change takes 250ms. A sheet or drawer moved by a gesture may settle in up to 500ms |
| Spring | For a UI state change, a spring (`type: "spring"`) with `duration: 0.3` and `bounce: 0` |
| Stagger | 30 to 50ms a step in product lists, and one entrance per container |
| Reduced motion | Movement goes, fades may stay, decorative loops stop, dragging stays 1:1. Set `<MotionConfig reducedMotion="user">` once at the app root and add `useReducedMotion()` where a fade alone would lose the meaning |

For curves, spring settings and gesture thresholds beyond these, quote the motion references in frontend-design (`easing-curves.md`, `spring-animations.md`, `timing-and-duration.md`, `accessibility.md`, `performance.md`) exactly; never round them.

## What to look for

| Question | A finding when |
| --- | --- |
| Why does it move? | The only answer is that it looks good, on something people see often. Good reasons: feedback, showing where something came from or went, marking a state change, softening a jarring cut, explaining, and delight on rare surfaces only |
| How often is it seen? | Entrance or decorative motion on a hundred-a-day action, or any movement after a keyboard action; the short press response stays allowed |
| Is the curve right? | `ease-in` on interface motion, a built-in keyword where a stronger `ease-out` curve belongs, or `transition: all` |
| Does it obey physics? | Anything that grows from `scale(0)`; a menu or popover that grows from its own centre instead of from its trigger (a centred modal is fine) |
| Is the hover restrained? | Hover scale above `1.02`, such as the familiar `scale(1.05)` swell |
| Does the entrance travel? | A bare opacity fade with no translate and no scale from `0.95` (`0.98` on a large surface); the bare fade is right only as the reduced-motion branch |
| Can it be interrupted? | Keyframes on something triggered in bursts (toasts, toggles), or a gesture that restarts from zero instead of from where it is |
| Is the timing lopsided where it should be? | Pressing and releasing, or holding and letting go, take the same time when the response should be quicker than the decision |
| Does it suit the product? | A bouncy spring in a precise dashboard; a hard crossfade where a short blur would join the two states |
| Is the stagger honest? | Everything at once where a 30 to 50ms cascade would help; the same delay for every item regardless of importance; a cascade that blocks clicks |
| Does a group enter twice? | A container animates in and its children stagger in as well |
| Does layout motion keep its corners? | A `layout` animation that stretches `border-radius` because the radius is not set inline in px for the library to correct |
| Can exits run? | Children of `AnimatePresence` with no `key`, or with the array index as their `key` |
| Does the SVG rotate or scale about its own centre? | It swings from the viewBox corner because nothing set the pivot; it needs `transform-box: fill-box` and an explicit `transform-origin` |
| Will it stay smooth when the page is busy? | Motion's `x` and `y` shorthands where the movement has to hold up while the main thread is loaded; one CSS variable on a parent animated to drive many children, which restyles them all every frame |

## Output

Two parts, in order.

**1. A Before, After, Why table.** One markdown table for every finding, never a list of "Before:" and "After:" lines. Cite `file:line` in the Before cell.

| Before | After | Why |
| --- | --- | --- |
| `Dropdown.tsx:12` scales from `center` on `ease-in` | Grows from the trigger (`transform-origin: var(--transform-origin)` in Base UI, the `--radix-*-content-transform-origin` variable in Radix), `scale(0.95)` to `1` with opacity, 200ms `ease-out` | `ease-in` holds back the first frames, which are the ones people watch, and a menu should appear to come out of its button |
| `Toast.tsx:30` slides in with `@keyframes` | A transition, or a spring at `duration: 0.3, bounce: 0`, that retargets from where it is | Toasts arrive in bursts; keyframes restart from their first frame on every new toast |

**2. The verdict.** The remaining commentary, grouped by impact in this order: motion that breaks the feel, motion that should be deleted, performance, interruption and timing, origin and fit, accessibility. End with one decision. **Recommend changes** when you found motion that breaks the feel, an entrance from `scale(0)`, `ease-in` on interface motion, movement after a keyboard action or on a hundred-a-day action, or a size or position animation that a transform would fix easily; otherwise **No observed issues**. The decision is advice unless the project defines a review gate.

## Fixes, cheapest first

Most motion findings are solved by less motion. Prefer the earliest fix that works:

1. **Delete** motion that has no job, decorates a frequent action, or moves after a keyboard action. Keep the short pointer or touch press.
2. **Shrink it**: shorter, smaller, fewer properties.
3. **Change the curve**: `ease-in` becomes a strong `ease-out` or a custom curve.
4. **Fix the origin**: grow from the trigger; `scale(0)` becomes `scale(0.95)` with opacity, or `scale(0.98)` on a large surface.
5. **Make it interruptible**: keyframes become transitions or springs.
6. **Move it to the compositor**: animate `transform` and `opacity` instead of size and position.
7. **Split the timing**: slower where the person decides, quicker where the interface answers.
8. **Polish**: blur between crossfaded states, stagger groups, match the product's character.
9. **Reduced motion and consistency**: apply the tiers above, and keep one timing family per component.

Some feel cannot be judged from code: how a spring settles, how a crossfade reads, whether a cascade looks like one wave. Say so, and suggest a screen recording of the running UI stepped through frame by frame, then a second look the next day.
