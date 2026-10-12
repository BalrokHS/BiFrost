# Performance

Good motion only reads as good when every frame arrives on time. The same curve and the same duration at a stuttering frame rate feel cheap, so performance is part of the design, not a clean-up step at the end.

---

## The budget per frame

- A 60Hz screen gives each frame about 16.7ms; a 120Hz screen about 8.3ms. Plan for the smaller number, since high refresh rates are now normal on phones.
- One forced layout on a large page can cost several frames on its own. Reading a layout value (`offsetHeight`, `getBoundingClientRect`) straight after writing a style is the usual way to trigger one.

## What each property costs

| Tier | Properties | Cost each frame |
|---|---|---|
| Composite only | `transform`, `opacity` | Cheapest; the browser can usually run it away from the main thread |
| Paint and composite | `color`, `background-color`, `box-shadow`, `border-radius`, `filter` | Repaints the element's area every frame: fine when small, heavy when large |
| Layout | `width`, `height`, `padding`, `margin`, `top`, `left`, `border-width` | Recalculates the element and everything around it: never animate these |

**Animate `transform` and `opacity` by default.** Two refinements:

- An absolutely positioned element with few children can animate a layout property without visible cost. Still, when two properties give the same picture, pick the one that cannot hurt.
- Layout properties also move the wrong things. Animate a sidebar's `margin-left` and every neighbour shifts with it; `translateX` moves only the sidebar.

## Cheaper equivalents

| Instead of | Animate |
|---|---|
| `width` / `height` | `transform: scale()` or `clip-path` |
| `top` / `left` | `transform: translate()` |
| `box-shadow` | The opacity of a pseudo-element that already carries the final shadow (first choice, see the visual rules); `filter: drop-shadow()` as a second option, tested across browsers, since its acceleration varies |
| `border-radius` | `clip-path: inset(0 round 24px)` |
| `visibility` / `display` | `opacity` |

Keep animated blur in the 2-5px band, and never above 20px; it is expensive everywhere and most of all in Safari. For elements whose size varies, translate by percentages: `translateY(100%)` hides an element of any height exactly. Some engines have declined to accelerate percentage transforms in the past; a correct result matters more than a possible speed-up.

## Acceleration is a bonus

Browsers usually move composite-only animations off the main thread, but they can decline: under memory pressure, for unusual property mixes, or by engine rules that change between versions. In 2026, `filter`, `clip-path` and `background-color` are accelerated in some engines and not others. What you control is which properties you animate; spend your effort there ([Motion performance](https://motion.dev/docs/performance), checked 3 October 2026).

## Custom properties on a parent

Animating a custom property on a parent element makes the browser recalculate styles for every child, every frame. Set `transform` on the moving element itself. The warning sign is an animation that gets worse as a list grows, visible from roughly 20 items in a drawer: it looks GPU-bound, but the cost is on the main thread.

## CSS, WAAPI or a frame loop

- **CSS transitions and animations** of composite-only properties keep running smoothly while the app is busy.
- **The Web Animations API** gives script control with the same engine: it can be accelerated, interrupted and sequenced without a library. Use it for a fixed animation that script must start or chain:

```js
element.animate(
  [{ clipPath: "inset(0 0 100% 0)" }, { clipPath: "inset(0 0 0 0)" }],
  { duration: 600, fill: "forwards", easing: "cubic-bezier(0.77, 0, 0.175, 1)" }
);
```

- **A `requestAnimationFrame` loop** runs on the main thread and stalls whenever the main thread does. A library that hands its animations to WAAPI can be accelerated; one that drives every frame itself cannot.

**Motion's `x`, `y` and `scale` values are not hardware accelerated.** Motion composes them itself on the main thread, so they stutter when the page is busy (its performance page explains the reason and the fix). Write the shorthand by default, since it reads better, and switch to a `transform` string where the motion must stay smooth during heavy work:

```jsx fragment
// Readable default
<motion.div animate={{ x: 100 }} />

// Survives navigation/hydration/load
<motion.div animate={{ transform: "translateX(100px)" }} />
```

**React:** keep animation out of the render cycle. Drive styles through refs or motion values; a state update per frame is a re-render per frame, and frames will drop.

## Motion during heavy work

Watch animations that play while the page is busy: route changes, tab switches mid-navigation, data arriving, hydration. A dashboard's shared-layout tab indicator dropped frames on every page load until it was rebuilt in CSS. Anything that must animate during load has to be composite-only and able to run off the main thread.

## `will-change` is a fix, not a setting

Add it only after you have seen a shift or dropped frames, and keep the promoted layer small. Two uses are sanctioned: a large blurred or filtered element, and the one-pixel jump fix in [practical-tips](practical-tips.md). Promoting layers by default costs GPU memory and buys nothing.

## Finding the jank

Check in this order; the earlier causes are the common ones.

1. A layout property in the animation? Use the tiers above and swap it.
2. `transition: all` hiding one? It hides the property and its cost; list the properties by name.
3. A custom property animated on a parent?
4. React state written every frame? Move it to refs or motion values.
5. Motion shorthands stalling under main-thread load? Use the `transform` string, or CSS.
6. A large paint area: a big blur, a big shadow, a full-screen repaint?
7. Only then: `will-change` on the element that still drops frames.

## Test on a real phone

Profile with the browser's performance panel, then confirm on a mid-range phone over remote debugging. CPU throttling on a desktop slows the processor but not the graphics chip or the memory, so a laptop result proves little.

## Reduced motion

Cheap motion is still motion. Under `reduce` the movement goes however little it costs; the tiers are in [accessibility](accessibility.md).
