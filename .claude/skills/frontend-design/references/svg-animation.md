# SVG animation

Recipes for moving vector art (strokes that draw themselves, path morphs, shakes, slow idle motion) and the two traps that break most first attempts: where SVG puts `transform-origin`, and how Motion overrides it. Each Motion recipe has its reduced-motion branch; the policy is the last section.

Where this belongs: icons and feedback in product UI (a check that draws once, a bell that shakes on a new notification), and illustration on marketing and editorial pages. Idle scenes and attention loops are for the second group only.

---

## The viewBox is the camera

SVG has no document flow: anything you do not place sits at `(0, 0)`. The four numbers of `viewBox="minX minY width height"` set the drawing's own coordinate system and acts as a camera. The artwork scales to fit, and animation values stay valid at any size because they are in viewBox units, not screen pixels.

```html
<!-- Moving a layer 6 units looks the same whether this renders 320px or 1200px wide -->
<svg viewBox="0 0 622 319" width="100%" role="img" aria-label="Product overview illustration"></svg>
```

Pick one viewBox per asset and tune every distance against it once; resizing the display never invalidates the tuning.

## Paths and groups

- `M` moves without drawing, `L` draws a straight line, `Z` closes the shape. Capital letters are absolute, lower case relative.
- **Close shapes with `Z`.** A path that only returns to its start leaves a visible corner at the seam.
- **A shape with no size does not render**: `width="0"`, `r="0"`. There is nothing to animate, measure or click, unlike `opacity: 0`. A line whose start and end coincide is the exception when it has round or square caps: it renders as a dot.
- **Give the `<svg>` `overflow: visible`**, so a shake, a scale or an overshoot is not cut off at the viewBox edge.
- **Nest `<g>` groups to stack transforms** on one shape: the outer group drifts, the inner one swings, each with its own origin and timing.

```html
<svg viewBox="0 0 24 24" style="overflow: visible">
  <g class="drift">          <!-- slow vertical loop -->
    <g class="swing">        <!-- its own rotation -->
      <path d="M12 3 L21 19 L3 19 Z" />
    </g>
  </g>
</svg>
```

## A stroke that draws itself

Make each dash as long as the whole path, push it out of view by that length, then animate the offset back to zero. Drawing is an expressive moment; the frequency rules in [timing-and-duration](timing-and-duration.md) decide whether it should happen at all.

```html
<svg viewBox="0 0 52 52" style="overflow: visible" aria-hidden="true">
  <circle class="ring" pathLength="100" cx="26" cy="26" r="23" />
  <path class="tick" pathLength="100" d="M14 27 L23 35 L38 18" />
</svg>
```

```css
.ring, .tick {
  fill: none;
  stroke: currentColor;
  stroke-width: 3;
  stroke-linecap: round;
  stroke-dasharray: 100 110;   /* one dash the length of the path, then a slightly longer gap */
  stroke-dashoffset: 100;      /* pushed fully out of view */
  animation: trace 0.6s ease forwards;
}
.tick {
  animation: trace 0.4s ease 0.6s forwards;   /* starts once the ring is drawn */
}

@keyframes trace {
  to { stroke-dashoffset: 0; }
}
```

- **`pathLength="100"`** gives every path the same nominal length, so one set of dash numbers fits paths of different real lengths.
- **`forwards` fill is required**, or the stroke vanishes again the moment the animation ends.
- **Stagger strokes with `animation-delay`**: the tick waits for its ring.

> **Delta knowledge:** round line caps reach past the end of each dash, so a stroke that should be hidden still shows two dots. Keep the gap a little longer than the dash: `100 110` above, or a `1` dash with a `1.1` gap when `pathLength="1"`.

## Where SVG puts transform-origin

**In SVG, `transform-origin` starts at the viewBox's `(0, 0)`, and `center` means the centre of the viewBox, not of the shape.** A rotation with no fix swings the shape around the whole canvas. Two fixes:

```css
/* Usually: behave like HTML, with the origin on the shape's own box */
.badge { transform-box: fill-box; transform-origin: center; }

/* Alternatively, viewBox units turn it around a chosen point */
.minute-hand { transform-origin: 50px 50px; } /* the middle of a 100 by 100 viewBox */
```

The second form, with `transform-box: view-box`, is also how a group circles a point outside itself, such as marks orbiting the middle of a dial.

A horizontal or vertical line has a fill box with no height or no width, and percentages on that missing axis do nothing, so `transform-origin: 0% 100%` sits on one end of the line and `100% 0%` on the other: handy for swinging a line from its tip. A diagonal line has a real box, so this shortcut does not apply to it.

## Motion resets your transformOrigin

For SVG elements, Motion sets `transform-box: fill-box` and an origin of `50% 50%` itself, and that origin replaces one you set in `style`. Give the origin through `initial` instead, where Motion keeps it:

```jsx
import { motion, useReducedMotion } from "motion/react";

function CirclingDot() {
  const reduce = useReducedMotion(); // decorative: stays still under reduced motion
  return (
    <svg viewBox="0 0 140 140" style={{ overflow: "visible" }} aria-hidden="true">
      <motion.g
        style={{ transformBox: "view-box" }}
        initial={{ transformOrigin: "70px 70px" }} /* set here: an origin in style is replaced */
        animate={{ rotate: reduce ? 0 : 360 }}
        transition={{ type: "spring", damping: 25, stiffness: 250, mass: 1.2 }}
      >
        <circle cx="70" cy="18" r="6" />
      </motion.g>
    </svg>
  );
}
```

## Morphing a path

Animate a path's `d` from one shape to another. It only interpolates cleanly when both paths have the same structure: the same commands, in the same order and number.

```jsx
import { animate, motion, useMotionValue, useReducedMotion, useTransform } from "motion/react";

const open   = "M4 20 L12 6 L20 20";
const closed = "M4 15 L12 11 L20 15";

function Pinch({ label, onPress }) {
  const amount = useMotionValue(0);
  const d = useTransform(amount, [0, 1], [open, closed]);
  const reduce = useReducedMotion(); // reduced motion: the action runs, the shape stays still

  return (
    <button
      type="button"
      aria-label={label}
      onClick={(event) => {
        // Enter and Space fire a click with detail 0: keyboard presses never animate.
        if (!reduce && event.detail > 0) animate(amount, [0, 1, 0], { duration: 0.3 });
        onPress();
      }}
    >
      <svg viewBox="0 0 24 24" style={{ overflow: "visible" }} aria-hidden="true">
        <motion.path
          d={d}
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
        />
      </svg>
    </button>
  );
}
```

The pinch is feedback on a real button: `label` names the action, `onPress` performs it, and Tab, Enter and Space reach it like any button. Because a motion value drives `d`, anything can scrub the morph: a press, a drag, a scroll position.

When the two paths differ in structure, a path-interpolation library does better than forcing mismatched points together. Motion's docs point to Flubber ([Motion SVG animation](https://motion.dev/docs/react-svg-animation), checked 3 October 2026), whose last release, 0.4.2, dates from March 2018 ([npm](https://www.npmjs.com/package/flubber), checked 3 October 2026). It is an old, new dependency: check `package.json` and ask before adding it.

## Shakes with keyframe arrays

A shake, a nod or a wobble is an array of values that alternate in sign and shrink in size: a big first swing, smaller rebounds, then rest.

```jsx
import { motion, useReducedMotion } from "motion/react";

function Bell({ ringing }) {
  const reduce = useReducedMotion(); // reduced motion: the bell never shakes
  return (
    <svg viewBox="0 0 24 24" style={{ overflow: "visible" }} aria-hidden="true">
      <motion.g
        initial={{ transformOrigin: "50% 0%" }} // swing from where the bell hangs
        animate={{ rotate: ringing && !reduce ? [0, 18, -14, 11, -9, 7, -5, 3, 0] : 0 }}
        transition={{ duration: 0.8, ease: "easeInOut" }}
      >
        <path d="M12 3 C8 3 7 6 7 10 L6 16 L18 16 L17 10 C17 6 16 3 12 3 Z" />
      </motion.g>
    </svg>
  );
}
```

Rotate a wrapping `<g>`, so anything attached (a badge, a clapper) shakes with it. A steady buzz, for a hover on an illustration, is a short loop of tiny alternating offsets on `linear`, right here because it is a constant mechanical loop like a spinner:

```jsx fragment
<motion.g
  animate={{ x: ["0px", "-1.5px", "1.5px", "-1.5px", "1.5px", "0px"] }}
  transition={{ repeat: Infinity, duration: 0.25, ease: "linear" }}
/>
```

A press is not a keyframe array: it is one small scale with no overshoot, `scale(0.97)` on `ease-out` ([practical-tips](practical-tips.md), with the numbers in the interaction-feedback rule).

## Idle motion in illustrations

Barely visible loops make an illustration feel alive. The trick that keeps it organic rather than mechanical: **loops of different lengths**, so the layers never line up.

```jsx
import { motion, useReducedMotion } from "motion/react";

const bob   = { duration: 3, ease: "easeInOut", repeat: Infinity, repeatType: "reverse", delay: 2 };
const sway  = { duration: 4, ease: "easeInOut", repeat: Infinity, repeatType: "reverse", delay: 2 };

function IdleIllustration() {
  const reduce = useReducedMotion(); // decorative: the whole scene is still under reduced motion
  return (
    <svg viewBox="0 0 120 80" style={{ overflow: "visible" }} aria-hidden="true">
      <motion.g animate={reduce ? {} : { y: 1.5 }} transition={bob}>
        <motion.g animate={reduce ? {} : { rotate: 2 }} transition={sway}>
          <circle cx="60" cy="40" r="18" />
        </motion.g>
      </motion.g>
    </svg>
  );
}
```

- **3s and 4s:** lengths that do not divide into each other, so the combined movement never visibly repeats.
- **About 2s of delay** before idle and attention loops start, so people find the real controls before the scenery moves.
- **`repeatDelay` between plays** for attention loops: a wave every few seconds, not a metronome.
- **Wait for resets.** In a scripted sequence, let the stroke or path reset finish before the loop restarts, or the two fight over the same values.

## Many moving shapes

A scene with many shapes animating at once, especially filtered or blurred ones, can drop frames. Animate `transform` and `opacity`, keep filters off the moving shapes, and if one layer is needed, promote the `<svg>` element rather than the shapes inside it: CSS containment and the old `translateZ(0)` trick do nothing on shapes inside an SVG, and browsers already accelerate SVG transform animation ([Chrome, hardware-accelerated animations](https://developer.chrome.com/blog/hardware-accelerated-animations), checked 3 October 2026). The general approach is in [performance](performance.md).

## Reduced motion

One policy covers every recipe here; the general patterns are in [accessibility](accessibility.md). A decorative SVG scene is **all or nothing**: under reduced motion, drift, sway, shakes, hover and click responses all stop, so the asset is fully still. Keeping a drift while removing the click response would suggest an interaction that no longer exists. Gate with `useReducedMotion()` and give identical `initial` and `animate` values, or return early from the handlers:

```jsx
import { motion, useReducedMotion } from "motion/react";

function Scene() {
  const reduce = useReducedMotion();
  const drift = reduce
    ? {} // nothing moves
    : { y: 1.5, transition: { duration: 3, ease: "easeInOut", repeat: Infinity, repeatType: "reverse", delay: 2 } };

  return (
    <svg viewBox="0 0 120 80" aria-hidden="true">
      <motion.g animate={drift}>
        <circle cx="60" cy="40" r="18" />
      </motion.g>
    </svg>
  );
}
```

For CSS loops, stop the scene on **a frame you chose**, never the awkward first one:

```css
@media (prefers-reduced-motion: reduce) {
  .drift, .swing {
    animation-delay: -0.4s;   /* a mid-loop pose, not frame 0 */
    animation-play-state: paused;
  }
}
```

> **Delta knowledge:** for a drawn stroke, `animation: none` alone leaves the stroke invisible forever, because its resting style is the hidden one. Set the offset to zero as well, so people who prefer reduced motion see the finished drawing at once:

```css
@media (prefers-reduced-motion: reduce) {
  .ring, .tick {
    animation: none;
    stroke-dashoffset: 0;   /* show the finished stroke */
  }
}
```
