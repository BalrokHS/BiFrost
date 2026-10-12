# Gesture and drag physics

How drag, swipe, flick, and sheet interactions earn the word "fluid":
1:1 tracking, velocity handoff, momentum projection, rubber-banding,
and interruption that never jumps. Springs are the substrate — see
[spring-animations](spring-animations.md) for configuration; this file
covers the physics *between* the finger and the spring.

---

## When not to use this

This file is for **touch-driven, draggable surfaces**: bottom sheets,
drawers, swipeable toasts/cards, carousels, drag-to-reorder. Skip it
entirely for:

- Desktop-pointer apps with no drag surface (dashboards, admin panels,
  forms) — there is nothing here for a click-only UI.
- Anything a component library already solves: the installed
  library's drawer (Base UI's Drawer has swipe and snap points) and
  Sonner's swipe-to-dismiss ship this physics. Reuse beats
  reimplementation; the defaults are in
  [library-selection](library-selection.md). Read this file when
  building gesture behaviour *from scratch*.
- Projects whose `VISION.md` or taste profile calls for minimal motion —
  the contract wins.

## Two phases: track, then release

Every gesture surface runs a one-question decision tree, re-asked
every frame: **is the pointer currently down?**

- **Down: track.** Position is a pure function of the pointer. No
  easing, no duration, no animation — the element is a tool in the
  hand.
- **Up: release.** Physics takes over: read the release velocity,
  project the landing point, pick a target, settle.

Most gesture bugs are one phase leaking into the other: easing applied
while tracking (input lag), or a release that ignores velocity (a dead
throw).

## 1:1 tracking (direct manipulation)

Touch and content move together. While the finger is down, the element
follows it exactly — never animate *toward* the finger.

- **Respect the grab offset.** Snapping the element's center to the
  pointer on grab breaks the illusion immediately:

```js
el.addEventListener("pointerdown", (e) => {
  el.setPointerCapture(e.pointerId); // tracking survives leaving el's bounds
  const grabOffset = e.clientY - el.getBoundingClientRect().top;
  // position = pointer − grabOffset, every move
});
```

- **Capture the pointer** with `setPointerCapture`. Without it, a fast
  finger slips off the element and the drag stops halfway.
- **`touch-action` on the drag axis:** declare which gestures the
  browser keeps, or touch devices scroll the page instead of feeding
  you `pointermove`s. A vertical drag sets `touch-action: pan-x` (the
  browser keeps horizontal panning, you own vertical); a horizontal
  swipe sets `pan-y`.
- **Multi-touch protection:** ignore additional touch points once a
  drag is active (`if (isDragging) return;` in the down handler) —
  otherwise a second finger teleports the element.
- **Hysteresis:** wait for about 10px of travel before you lock a
  direction, then track 1:1. From the first move, keep every gesture
  that could still be meant alive at once, and drop the rest as soon as
  the direction is clear. Recognisers that fire only when the gesture
  is over (a `swipeleft` event, say) are no use here: they hide the
  frame-by-frame movement your feedback runs on.
- **Track a velocity history.** Keep the last few `pointermove`
  positions + timestamps, not just the current point — release needs a
  velocity, and the final event alone is too noisy.

## Velocity handoff (where the drag becomes an animation)

On release, the spring starts at the speed the finger had when it let
go. If people can see the moment the drag stops and the animation
begins, the surface feels fine but not fluid.

- Motion for React takes absolute px/s directly:

```tsx
onDragEnd={(e, info) => {
  animate(target, { y: snapPoint }, {
    type: "spring",
    velocity: info.velocity.y, // hand off, don't restart from zero
  });
}}
```

- Some spring APIs want **relative** velocity — normalize by remaining
  distance: `relativeVelocity = gestureVelocity / (target − current)`.
  (Element at `y=50`, target `150`, finger at 50px/s gives `0.5`.)

## Momentum projection (flicks land where they are going)

Pick the snap target from where the motion would carry the element, not
from where the finger let go: project the landing point first, then take
the snap point closest to it. A flick then lands like a throw, which is
how well-made sheets and carousels behave.

```js
// Apple's exponential-decay projection (Designing Fluid Interfaces).
// decelerationRate ≈ 0.998 for scroll feel; 0.99 for snappier.
function project(initialVelocity /* px/s */, decelerationRate = 0.998) {
  return ((initialVelocity / 1000) * decelerationRate) / (1 - decelerationRate);
}

const projected = currentPosition + project(releaseVelocity);
const target = nearestSnapPoint(projected);        // choose from the projection
animateSpringTo(target, { velocity: releaseVelocity }); // then hand off velocity
```

`currentPosition`, `releaseVelocity`, `nearestSnapPoint` and
`animateSpringTo` are placeholders for your own gesture state, snap-point
lookup and spring call. With Motion the last line is
`animate(y, target, { type: "spring", velocity: releaseVelocity })`.

> Delta: the physics-textbook `v²/(2·decel)` is **not** what platforms
> ship — use the exponential-decay form above.

- **Momentum dismissal:** a fast swipe dismisses even when it is short.
  Take `velocity = Math.abs(distance) / elapsedMs` and dismiss above
  **~0.11**, however far the element moved (Sonner's production
  threshold, beside a 45px distance threshold, in the sonner 2.0.8
  source read on 3 October 2026). A quick flick should be enough:

```js
const elapsed = Date.now() - dragStartTime;
const velocity = Math.abs(swipeAmount) / elapsed;
if (Math.abs(swipeAmount) >= SWIPE_THRESHOLD || velocity > 0.11) dismiss();
```

`dragStartTime`, `swipeAmount`, `SWIPE_THRESHOLD` and `dismiss` are
placeholders for your own gesture state and dismiss handler.

- **Pair the velocity rule with a distance rule.** Crossing **40–50%**
  of the surface's dimension commits the dismissal regardless of
  speed. Velocity catches the flick, distance catches the slow
  deliberate drag — either alone feels deaf.
- **Decide reverse-vs-commit by velocity *sign* at release,** not by
  position. A sheet dragged 80% closed but moving upward should reopen.
- **Leave by the way you came.** A sheet that rose from the bottom is
  dismissed downward, a drawer from the left goes back left; swiping
  it away along another axis breaks the spatial story.

## Rubber-banding (soft boundaries)

Past an edge, the element keeps following the finger, but less and less.
A dead stop feels like the app froze; growing resistance tells people
the app heard them and there is simply no more content.

```js
// The further past the bound, the less the element follows.
function rubberband(overshoot, dimension, constant = 0.55) {
  return (overshoot * dimension * constant) /
         (dimension + constant * Math.abs(overshoot));
}
```

Use it wherever a drag can pass its limit: a sheet pulled above fully
open, a drawer pulled past its edge, a custom scroll area. Resistance,
never a wall.

## Interruption without jumps

People change their mind halfway through a gesture, so every
gesture-driven animation must stay catchable and reversible while it runs.

- **Never lock out input during a transition.** A closing sheet the
  user grabs again follows the finger — it does not finish closing
  first.
- **Start from where the element is now.** When a gesture interrupts
  an animation, take the transform currently on screen as the new
  starting point. Starting from the value the animation was heading to
  makes the element jump. Springs already work this way; CSS keyframes
  start over from their first frame, so they do not suit
  gesture-driven motion.
- **Keep the speed when the target changes.** Swapping one animation
  for another at a reversal drops the speed to zero at once, and the
  element hits an invisible wall. Use a spring library that passes the
  current speed on to the new target.
- **Give X and Y their own spring.** One spring driving the diagonal
  distance falls out of step as soon as the two axes move at different
  speeds.

## With Motion for React

Motion's `drag` prop packages the mechanics above — pointer capture,
axis lock, rubber-banding, velocity tracking — behind declarative
props:

```tsx
import { animate, motion, useMotionValue, useReducedMotion, useTransform } from "motion/react";

function Sheet({ onDismiss }: { onDismiss: () => void }) {
  const drawerHeight = 480; // or measure the sheet
  const y = useMotionValue(0);
  const backdropOpacity = useTransform(y, [0, drawerHeight], [1, 0]);
  const reduce = useReducedMotion();

  return (
    <>
      <motion.div className="backdrop" style={{ opacity: backdropOpacity }} />
      <motion.div
        className="sheet"
        drag="y"
        dragConstraints={{ top: 0, bottom: drawerHeight }}
        dragElastic={0.2}
        dragMomentum={false}
        style={{ y }}
        onDragEnd={(_, info) => {
          const past = info.offset.y > drawerHeight * 0.4; // distance: px
          const fast = info.velocity.y > 500; // instantaneous px/s
          if (past || fast) {
            onDismiss();
            return;
          }
          // Neither threshold crossed: snap back fast, handing off the release velocity.
          // Reduced motion: tracking stayed 1:1; the settle drops the velocity so it cannot overshoot.
          animate(y, 0, {
            type: "spring",
            duration: 0.3,
            bounce: 0,
            velocity: reduce ? 0 : info.velocity.y,
          });
        }}
      />
    </>
  );
}
```

- `drag="y"` locks the axis — free 2D drag is almost never what a
  sheet wants.
- `dragConstraints` takes explicit bounds or a ref to a bounding
  element (`dragConstraints={containerRef}`).
- `dragElastic={0.2}` is the rubber-band above, built in — `0` is a
  hard stop (reads frozen), `1` is no resistance.
- `dragMomentum` stays on for flings: Motion then runs its own inertia
  animation from the release velocity (tunable through
  `dragTransition`), not the exponential projection above
  ([Motion drag](https://motion.dev/docs/react-drag), checked 3 October
  2026). Use `dragMomentum={false}` for simple repositioning, and for
  snap-point surfaces like this sheet, where `onDragEnd` picks the
  target itself.
- **Constraints do not snap back.** A release inside `dragConstraints`
  stays where it was let go; the constraints only pull back what was
  dragged past them. The snap back is the explicit `animate(y, 0)` in
  `onDragEnd`. `dragSnapToOrigin` is the one-prop alternative, but it
  returns the element to the origin on every release, dismissals
  included, so it suits surfaces that never dismiss.
- `onDragEnd` reads **both** signals: `info.offset` (distance
  traveled, px) and `info.velocity` (px/s).
- **Linked values derive, never duplicate.** `useTransform(y, [0,
  drawerHeight], [1, 0])` keeps the backdrop mathematically bound to
  the sheet through every interrupted, reversed, half-finished
  gesture. Animate the backdrop separately and the pair drifts out of
  sync.

> Delta: label your velocity units. `info.velocity` is
> **instantaneous px/s** sampled from the last frames — 500 is a
> sensible dismissal threshold. The **~0.11** canonical above is
> **average px/ms** (total distance / total elapsed, ≈110 px/s
> sustained). A wrist-flick can spike past 500 px/s instantaneous
> while its gesture-long average stays under 0.11 px/ms, and a steady
> drag can do the reverse. The two bases are not interchangeable —
> pick one per surface and label the unit in code.

## Sheet release: spring or steep curve

Two sanctioned ways to settle a released sheet:

1. **Spring with velocity handoff** (above) — default bounce 0;
   configs in [spring-animations](spring-animations.md).
2. **Steep-curve fixed transition** — the drawer curve, applied to the
   transform once the drag ends:

```css
.sheet {
  /* --ease-drawer — see easing-curves.md */
  transition: transform 500ms cubic-bezier(0.32, 0.72, 0, 1);
}
.sheet--floating {
  /* smaller travel, snappier settle (--ease-out-quart) */
  transition: transform 200ms cubic-bezier(0.165, 0.84, 0.44, 1);
}
```

500ms outlives the product-UI ceiling and is still sanctioned: the
steep curve front-loads the travel, so the sheet arrives early and
spends the tail settling. A floating drawer travels less, so it
overrides down to ~200ms. Bands in
[timing-and-duration](timing-and-duration.md).

Release rules that make sheets feel engineered:

- **A button press applies no force.** Close-by-drag hands off
  velocity and may overshoot; close-by-button settles with **zero
  bounce** (the fixed curve, or a bounce-0 spring). A button-closed
  sheet that bounces is physics as decoration.
- **Failed gestures snap back fast.** A release that crosses neither
  threshold returns quickly — the system responding, not the user
  deciding.
- **Exempt interactive children.** A drag starting on a slider, input,
  or horizontally-scrolling row must not move the sheet. Vaul, where
  it is already installed, exposes `data-vaul-no-drag` for this;
  hand-rolled, check `event.target.closest("[data-no-drag]")` before
  starting the drag.

## Test on real hardware

Gesture feel does not survive simulation. Before calling a drag
surface done:

- Serve over the local network and open it on a phone: `vite --host`
  (or equivalent), then `http://<your-local-ip>:5173`.
- Trackpad simulation lies — no touch latency, no finger occlusion,
  no velocity noise from a real thumb.
- Check at both refresh rates. Roughness can show at 60Hz and hide at
  120Hz, or the other way round, so smooth on one screen proves
  nothing about the other.

## Feel checklist

| Need | Technique | Value |
| --- | --- | --- |
| 1:1 drag | Pointer Events + capture, respect grab offset | ~10px hysteresis |
| Drag to animation seam | Hand off release velocity to the spring | `info.velocity` (abs px/s) |
| Flick landing point | Exponential-decay projection | `d ≈ 0.998` |
| Flick dismissal | Velocity threshold, not distance | `> ~0.11` px/ms |
| Reverse vs commit | Velocity **sign** at release | — |
| Boundary | Rubber-band, never hard-stop | `constant ≈ 0.55` |
| Interrupt | Start from presentation value, carry velocity | springs, not keyframes |
| Feedback | On pointer-down, continuous during the gesture | never only at the end |
| Own the axis | `touch-action` set to what the browser keeps | `pan-x` for a vertical drag |
| Commit vs cancel | Distance OR velocity, units labeled | 40–50% distance; 500 px/s inst. |
| Sheet settle | Bounce-0 spring or steep fixed curve | `--ease-drawer` 500ms / ~200ms floating |
| Button close | No force applied, so zero bounce | fixed curve or bounce-0 spring |

Reduced motion: gesture *tracking* stays 1:1 (it is direct manipulation,
not decoration), but replace momentum flourishes — overshoot, bounce on
settle — with critically-damped settles. See [accessibility](accessibility.md).

Discoverability is its own problem: a drag surface needs an affordance —
a grabber, a peeking edge — before any of this physics is felt. See
[interaction-design](interaction-design.md).
