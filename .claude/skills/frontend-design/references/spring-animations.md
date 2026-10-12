# Spring animations

A spring has no fixed duration: it simulates a mass on a spring, so its motion depends on where it starts and how fast it is already going. That is why it feels physical, and why it survives interruption. This file covers when a spring is required, how to configure one, and how springs go wrong.

---

## When a spring is required

- **Gestures**: drag, flick, swipe. The release has a velocity, and only a spring can carry it.
- **Motion that can be interrupted and reversed.** A spring keeps its momentum when the target changes. A CSS transition can retarget from the current value too, but it restarts its timing curve at zero speed, so a reversal hitches; keyframes simply start over.
- Elements meant to feel alive (a Dynamic Island style pill), playful interfaces, and any deliberate overshoot-and-settle.

CSS has no true spring. `linear()` can trace a spring's curve for one fixed case, but it cannot react to velocity.

## Configuration

**Duration and bounce**, the two-parameter form Apple now uses across its own design and engineering ([Animate with springs, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10158), checked 3 October 2026). Bounce defaults to `0`; overshoot is something you choose, never a background effect:

```js
// The house default for UI state changes
{ type: "spring", duration: 0.3, bounce: 0 }

// Gestures, or motion meant to feel playful: never the default
{ type: "spring", bounce: 0.2, duration: 0.5 }
```

**Stiffness, damping and mass**, when you need finer control:

```js
// Bouncy, not the default: damping ratio = 10 / (2 * sqrt(100 * 1)) = 0.5
{ type: "spring", mass: 1, stiffness: 100, damping: 10 }
```

A damping ratio of 1 settles with no overshoot; below 1 it overshoots, more as it drops. Keep `mass: 1` for ordinary UI. Lower mass (around `0.1`) tracks faster, for cursor followers and anything stuck to the pointer.

## Spring the transforms, tween the paint

- `x`, `y`, `scale`, `rotate`: spring, so velocity carries through an interruption.
- `opacity`, `color`, `backgroundColor`: tween. There is nothing physical to overshoot, and a spring on opacity only delays the fade.

Set the transition per value and pass it as the motion element's `transition` prop:

```ts
const transition = {
  x: { type: "spring", duration: 0.3, bounce: 0 },
  scale: { type: "spring", duration: 0.3, bounce: 0 },
  opacity: { type: "tween", ease: "easeOut" },
} as const;
```

## Reason in damping and response

Apple's earlier talk describes springs with two designer-friendly numbers ([Designing Fluid Interfaces, WWDC18](https://developer.apple.com/videos/play/wwdc2018/803), checked 3 October 2026); think in these, then translate to your library:

- **Damping ratio** sets the overshoot. `1.0` is critically damped: no bounce, a smooth settle.
- **Response** is roughly how quickly the value heads for its target, in seconds. It is not a duration; the settle time falls out of the two numbers.

**House defaults:** damping `1.0` everywhere. Go down to about `0.8` only when the person's own movement put energy into the element: a fling, a toss, letting go mid-drag. Apple's own example follows the same split: the music player opened by a tap settles with no overshoot, and only closing it with a swipe gets the 80% value. A bounce after a plain fade-in looks like a glitch; a bounce after you threw something looks like physics.

Starting points that follow those defaults (the response values are common practice, not figures from the talk):

| Interaction | Damping | Response |
| --- | --- | --- |
| Move or reposition (picture in picture) | `1.0` | `0.4` |
| Rotation | `0.8` | `0.4` |
| Drawer or sheet | `0.8` | `0.3` |

In Motion's `bounce` and `duration` form, `bounce: 0` behaves like damping `1.0` and `bounce: 0.2` like damping about `0.8`.

**Repair:** a spring that feels odd usually needs more damping. Remove the wobble first; tune the speed after.

## Interruption

Springs handle interruption well only when used correctly:

- **Start from what is on screen.** A new animation begins at the element's live value, never at the old target, or it jumps.
- **Carry the velocity into the new target.** Swapping animations at a reversal without it hits like a wall.
- **Run X and Y as two springs.** One spring on the diagonal distance falls out of step when the axes move at different speeds.

Projection, rubber-banding and velocity handoff are in [gesture-and-drag](gesture-and-drag.md).

## Bounce, when you use it

- Keep it off for most UI; use it for drag-to-dismiss and genuinely playful moments.
- Keep it small, 0.1-0.3.
- Smaller things carry more: a tiny view can take `0.5`, `0.35` or `0.3` (the smallest gets the most); a panel takes `0`.
- Avoid configs that ring for ages; `stiffness: 1000, damping: 5` is far too lively.
- Hand the release velocity to the spring:

```tsx
onDragEnd={(e, info) => {
  animate(target, { x: 0 }, {
    type: "spring",
    velocity: info.velocity.x,
  });
}}
```

## Quick reference

| Moment | Curve or spring | Duration |
|--------|-----------------|----------|
| Letting go of a drag | Spring, `stiffness: 500, damping: 36` (damping ratio about 0.8, the house momentum value) | Set by the spring |
| Pressing a button | `ease-out` | 150ms |
| Opening a dialog | `ease-out` | 200ms |
| Closing a dialog | `ease-out` | 150ms |
| Moving between pages | `ease-in-out` | 250ms |
| A progress bar filling | `linear` | As long as the work takes |
| A typed character appearing | None | Instant (0ms) |

## Reduced motion

Under `prefers-reduced-motion`, spring-driven movement goes entirely; opacity fades may stay. Direct manipulation is the exception: tracking stays 1:1 and the release settles critically damped. Details in [accessibility](accessibility.md).
