# Motion for React

Motion for React is the library once called Framer Motion: the same API under a new import, `motion/react` (it used to be `framer-motion`; `motion` 14.0.0, 2 October 2026, per [library-selection](library-selection.md)). For example, `import { motion, AnimatePresence, MotionConfig } from "motion/react"`. This file covers when to use it, the parts of the API that matter, a map for when it misbehaves, and six recipes.

---

## When it earns its place

CSS can do most of what Motion does, given time, so start with CSS. Plain enter and exit animations on primitives need no library: Radix keeps a closing component mounted while a CSS keyframe animation on its `data-state` plays ([Radix animation guide](https://www.radix-ui.com/primitives/docs/guides/animation)), and Base UI also waits for CSS transitions, since it checks `element.getAnimations()` ([Base UI animation](https://base-ui.com/react/handbook/animation)), both checked 3 October 2026. Use Motion when CSS truly cannot:

- **Springs** that keep their momentum when interrupted.
- **Layout changes** CSS cannot animate, such as `flex-direction` or `justify-content`.
- **Shared-element morphs**: one element turning into another (`layoutId`).
- **Animating out** something React has already removed (`AnimatePresence`).

When it is close, decide by what the project already ships: Motion in `package.json` makes it the readable choice, its absence makes CSS the light one. The price of Motion is opacity: a lot happens from very little code, which makes it hard to see why something goes wrong. The table under "When it misbehaves" is the way in.

## Defaults worth knowing

A `motion.div` animates from `initial` to `animate`. The values change in JavaScript, outside React's render, so an animating component does not re-render.

With no `transition` given, Motion picks one per value: a spring for physical values (`x`, `scale`), a tween for the rest (`opacity`, `color`). Spring settings are in [spring-animations](spring-animations.md). Keep repeated settings in a constant, and set one default for a subtree with `MotionConfig`, so a component moves as a single object rather than a collection of separately tuned parts:

```jsx
<MotionConfig transition={{ type: "spring", bounce: 0, duration: 0.3 }}>{children}</MotionConfig>
```

## AnimatePresence in short

The full checklist is in [exit-animations](exit-animations.md). The parts people trip on:

- **Every child needs a `key`.** Without one the old element never unmounts and its exit never runs; check the key first when an exit does nothing.
- **`mode="wait"`** finishes the exit before the entrance starts. Use it for a two-state icon swap (copy to check), and halve the timings, since the halves run back to back.
- **`mode="popLayout"`** runs both at once while the layout around them closes up. It is the usual choice for a label swap inside a button, a step change or a crossfade. It takes the leaving element out of the flow with absolute positioning, so **its container needs a position other than `static`**, or the leaving element jumps ([Motion AnimatePresence](https://motion.dev/docs/react-animate-presence), checked 3 October 2026).
- **`initial={false}`** keeps the first render still, so only later changes animate.
- When an exit plays but looks wrong, change the mode before anything else.

### Variants and direction

Variants are named sets of targets. Their useful form is a function that receives `custom`, which is how a step slides the right way:

```jsx
const reduce = useReducedMotion();
const steps = reduce
  ? { from: { opacity: 0 }, here: { opacity: 1 }, gone: { opacity: 0 } } // reduced: crossfade only
  : {
      from: (dir) => ({ x: `${dir * 110}%`, opacity: 0 }),
      here: { x: "0%", opacity: 1 },
      gone: (dir) => ({ x: `${dir * -110}%`, opacity: 0 }),
    };

<motion.div variants={steps} initial="from" animate="here" exit="gone" custom={dir} />
```

For a list that enters item by item, put the stagger on the parent's variant. In Motion 14 that is `delayChildren: stagger(0.03)`; the older `staggerChildren: 0.03` still works but is marked deprecated in the package's types ([Motion transitions](https://motion.dev/docs/react-transitions), checked 3 October 2026). 30ms sits in the product band of 30-50ms per item.

```jsx
import { motion, stagger, useReducedMotion } from "motion/react";

const reduce = useReducedMotion(); // reduced motion: rows fade in together, no rise
const list = { hidden: {}, shown: { transition: { delayChildren: stagger(0.03) } } };
const row = reduce
  ? { hidden: { opacity: 0 }, shown: { opacity: 1 } }
  : { hidden: { opacity: 0, y: 8 }, shown: { opacity: 1, y: 0 } };

<motion.ul variants={list} initial="hidden" animate="shown">
  {items.map((item) => (
    <motion.li key={item.id} variants={row}>{item.name}</motion.li>
  ))}
</motion.ul>
```

`items` stands for your data. One container, one entrance: the list does not also animate in as a whole.

Set the direction in state at the moment of the change (`1` for next, `-1` for back), and give the same value to `AnimatePresence`'s `custom` too, or the leaving step uses the old direction. Moving by `110%` instead of `100%` takes the step fully out of its container.

## Layout and layoutId

- **`layout`** animates any change in an element's box: position, size, `flex-direction`. Trigger it by changing the element's real styles (its class or inline style), not through `animate`: Motion reads the box before and after the change and travels between them.
- **Neighbours need `layout` too**, or they snap while the animated element glides.
- **`layoutId`** pairs two different elements: when a new element arrives carrying the `layoutId` of an element just removed, Motion turns the old into the new. Tab indicators, a card opening into a detail view, a button becoming a popover.
- **A shared layout animation cannot be steered directly.** For extra movement, animate a wrapping parent; the paired children ride along.
- **Set `borderRadius` and `boxShadow` through `style`**, in pixels. Motion corrects scale distortion only for values it sets itself, so a radius from a class warps during the morph ([Motion layout animations](https://motion.dev/docs/react-layout-animations), checked 3 October 2026).
- **Two components using the same `layoutId`** on one page (two tab bars, say) each need their own `<LayoutGroup id>`.

`layoutId` is for morphs within a page. A shared element across a navigation belongs to the View Transition API ([view-transitions](view-transitions.md)).

Motion animates a fixed size to `auto`, but not one `auto` size to another, which is what changing content needs. That needs measuring: the two-element split, the zero guard and `overflow: hidden` are in [container-animation](container-animation.md), and the drawer recipe below shows them with Motion.

## Motion values

A motion value changes without re-rendering React, so it can update on every frame for free. Use one for anything that changes constantly, pointer tracking above all: a cursor follower in React state re-renders on every mouse move, one built on a motion value never does.

```jsx
const pointerX = useMotionValue(0);                                  // .set() and .get()
const easedX   = useSpring(pointerX, { damping: 18 });               // follows with a spring
const grow     = useTransform(pointerX, [0, 300], [1, 1.5]);         // one range onto another
const readout  = useTransform(pointerX, (v) => `${Math.round(v)}px`); // or any function
const wipe     = useMotionTemplate`inset(0px ${pointerX}% 0px 0px)`; // a string that updates
```

Pass them through `style`, as in `<motion.div style={{ x: easedX, scale: grow }} />`; `x` and `y` become `translateX` and `translateY`.

| Hook | Use it when |
| --- | --- |
| `useMotionValue` | The value must follow an input exactly, such as scale while dragging to dismiss, where any lag would feel detached from the finger. |
| `useSpring` | Most other cases. A raw value jumps instantly and feels dead; the same interaction through a spring feels physical. |
| `useTransform` | Mapping one value's range onto another, or computing a display value such as a counter's text; it stays subscribed, so the text keeps up. |
| `useMotionTemplate` | Composing a string that must update: `clipPath`, `filter`, any combined value. |

> Delta: a motion value placed in a normal template literal is read once and never updates. Only `useMotionTemplate` builds a string that follows its values.

## Dragging

```jsx
const boundsRef = useRef(null);
const reduce = useReducedMotion(); // dragging stays 1:1; only the press scale goes

<div ref={boundsRef}>
  <motion.div
    drag
    dragConstraints={boundsRef}
    dragElastic={0.2}
    dragMomentum={false}
    whileTap={reduce ? undefined : { scale: 0.97 }}
  />
</div>
```

`drag` carries momentum after release by default, which suits a card being thrown and not a simple move (`dragMomentum={false}` switches it off). For bounds, give `dragConstraints` either a ref or a `{ top, left, right, bottom }` object; `dragElastic` sets how far the element stretches past them. Release velocity, projection and dismiss thresholds are in [gesture-and-drag](gesture-and-drag.md). A real bottom sheet is the installed library's drawer (Base UI ships one), not hand-built drag.

## In view

```jsx
const seen = useInView(ref, { once: true, margin: "-100px" });
```

With `once`, it fires a single time. The margin is negative: `"-100px"` fires when the element is 100px inside the viewport, where people see it; a positive margin fires while it is still off screen. If Motion is not already installed, use `IntersectionObserver`; this alone does not justify the dependency.

## The imperative escape hatch

`useAnimate()` returns `[scope, animate]` for selector-based control. It is powerful and hard to maintain, and rarely needed. Stay declarative unless you are coordinating many elements across several events; then target `[data-animate]` selectors, place keyframes along the duration with `times`, return `Promise.all(...)` so callers can wait, and stop running animations before starting new ones.

## Reduced motion

Every recipe here carries its own `useReducedMotion()` branch; the policy is in [accessibility](accessibility.md).

- `<MotionConfig reducedMotion="user">` covers a whole app: transform and layout animations stop, opacity and colour changes stay.
- In a component, branch the values on `useReducedMotion()`: remove movement entirely rather than shortening it, and switch layout animation off with `layout={!reduce}`.
- Dragging still follows the finger 1:1; the release settles critically damped, with no momentum flourish.
- Decorative loops pause on a chosen frame, never the first.

## When it misbehaves

| What you see | Usual cause |
| --- | --- |
| The exit never plays | No `key` on the child, so it never unmounts. Next suspect: the mode. |
| A direction-aware slide always goes one way | The leaving element still has the old direction: give `custom` to `AnimatePresence` as well as the element. |
| The outgoing element jumps during a `popLayout` swap | Its container is `position: static`; make it `relative`. |
| Corners warp during a morph | The radius came from a class or `rem`; set it in `style` in pixels. |
| A height animation freezes or jumps | The measuring ref and `animate={{ height }}` sit on the same element, or the first measurement of `0` is not falling back to `"auto"` ([container-animation](container-animation.md)). |
| Neighbours snap while one element animates its layout | Give them `layout` as well. |
| A composed string value never changes | It was built with a template literal; use `useMotionTemplate`. |
| A spring looks shaky or wild | Raise `damping`. |
| Something animates on first render that should not | Add `initial={false}` to `AnimatePresence`. |

## Recipes

Each recipe combines a few of the pieces above; read them for the technique rather than the markup.

### A button that changes its label without changing size

A submit button that moves through idle, loading and done, with the labels rolling past as if on a reel:

```jsx
const labels = {
  idle: "Send me a sign-in link",
  loading: <Spinner size={16} />,
  success: "Link sent",
};
const reduce = useReducedMotion(); // reduced motion: the labels crossfade in place

// Busy, not disabled: it keeps focus and full opacity; the submit handler ignores repeat presses.
<button type="submit" aria-busy={status === "loading"} className="relative inline-grid overflow-hidden">
  {/* The longest label, invisible, holds the button's size, so a change of state never resizes it. */}
  <span aria-hidden="true" className="invisible col-start-1 row-start-1">{labels.idle}</span>
  <AnimatePresence initial={false} mode="popLayout">
    <motion.span
      key={status}
      className="col-start-1 row-start-1 flex items-center justify-center"
      initial={{ y: reduce ? 0 : -24, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      exit={{ y: reduce ? 0 : 24, opacity: 0 }}
      transition={{ type: "spring", bounce: 0, duration: 0.3 }}
    >
      {labels[status]}
    </motion.span>
  </AnimatePresence>
</button>
```

- `status` is the form's `"idle" | "loading" | "success"` state, and `Spinner` the project's spinner, which needs its own accessible name while it stands in for the label. Loading is `aria-busy`, never `disabled` (`load-busy-not-disabled` in the interaction-feedback rule).
- **The button never changes size.** The invisible copy of the longest label shares the grid cell with the visible one, so the button is always as wide as that label, and a short "Link sent" does not shrink it. Put the widest of your labels in the sizer.
- **The button is the positioned parent** (`relative`) that `popLayout` needs, and `overflow-hidden` clips the labels as they roll in and out.
- The new label comes from above and the old one leaves below: one direction of travel, as on a reel. That does not break `exit-matches-initial` ([exit-animations](exit-animations.md)), which is about one element leaving the way it came; this is two different elements swapping.
- For a two-state icon swap (copy to check), use `mode="wait"` instead, so the check does not arrive before the copy icon has gone.

### A drawer whose height follows its content

A drawer that swaps between views while its height adjusts. The outer element animates to the measured height; inside, `AnimatePresence` crossfades the views:

```jsx
import useMeasure from "react-use-measure";

// Measure the inner element; animate the outer one.
const [measureRef, bounds] = useMeasure();
const reduce = useReducedMotion(); // reduced motion: the height snaps, views crossfade in place

// Keep the last two measured heights in state. When the measurement changes,
// record it during render; React renders again straight away with the new pair.
const [heights, setHeights] = useState({ previous: 0, current: bounds.height });
if (heights.current !== bounds.height) {
  setHeights({ previous: heights.current, current: bounds.height });
}

const FASTEST = 0.15, SLOWEST = 0.27;
const crossfadeDuration = Math.min(Math.max(Math.abs(heights.current - heights.previous) / 500, FASTEST), SLOWEST);

<motion.div
  animate={{ height: bounds.height > 0 ? bounds.height : "auto" }}
  transition={reduce ? { duration: 0 } : { duration: 0.27, ease: [0.25, 1, 0.5, 1] }}
  style={{ overflow: "hidden" }}
>
  {/* The measured element, and the positioned parent popLayout needs. */}
  <div ref={measureRef} style={{ position: "relative" }}>
    <AnimatePresence initial={false} mode="popLayout">
      <motion.div
        key={view}
        initial={{ scale: reduce ? 1 : 0.96, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        exit={{ scale: reduce ? 1 : 0.96, opacity: 0 }}
        transition={{ duration: crossfadeDuration }}
      >
        {content}
      </motion.div>
    </AnimatePresence>
  </div>
</motion.div>
```

- The measuring ref and the animated height are on **different elements**, and the inner one owns the padding; the split, the zero guard and the clipping are explained in [container-animation](container-animation.md).
- `[0.25, 1, 0.5, 1]` is `--ease-drawer-height` from [easing-curves](easing-curves.md), a strong ease-out that makes height changes feel quick.
- The crossfade lasts longer for bigger height changes, so a small swap does not linger.
- **The previous height lives in state, never in a ref written during render.** React may render and then discard the result: a transition that suspends, or a render cut short by something more urgent. A ref written in `useMemo` keeps the discarded value, so the next real render sees no change and the crossfade drops to its shortest; a state update from a discarded render is discarded with it. This is React's documented way of [storing information from previous renders](https://react.dev/reference/react/useState#storing-information-from-previous-renders), and it passes the React Compiler's [`react-hooks/refs`](https://react.dev/reference/eslint-plugin-react-hooks/lints/refs) rule, which flags reading or writing a ref during render (both checked 3 October 2026). Keep the update inside the `heights.current !== bounds.height` check, or the component renders in a loop.
- `view` and `content` stand for the active view's key and its markup.
- **One surface, one timing.** A drawer like this once opened on its library's 500ms default while its height changed in 200ms, and it read as two objects. 500ms on the steep sheet curve suits full-height travel; a floating drawer that resizes wants about 200ms, so its opening was brought down to match. Bands in [timing-and-duration](timing-and-duration.md).

### A button that turns into a popover

```jsx
const [open, setOpen] = useState(false);
const reduce = useReducedMotion();
// Reduced motion: no shared layoutId, so the button and popover swap without a morph.
const shared = (id) => (reduce ? undefined : id);

<motion.button layoutId={shared("feedback-shell")} style={{ borderRadius: 8 }} onClick={() => setOpen(true)}>
  <motion.span layoutId={shared("feedback-label")}>Feedback</motion.span>
</motion.button>

<AnimatePresence>
  {open && (
    <motion.div layoutId={shared("feedback-shell")} style={{ borderRadius: 12 }} className="popover">
      <motion.span aria-hidden layoutId={shared("feedback-label")} className="label-ghost">
        Feedback
      </motion.span>
      <textarea aria-label="Feedback" placeholder="Feedback" />
    </motion.div>
  )}
</AnimatePresence>
```

The grey word inside the open popover only looks like the textarea's placeholder. It is its own element: a span with the same `layoutId` as the button's label, so the label seems to travel into the field and become its placeholder; a real placeholder attribute cannot morph. Hide the real `placeholder` with `opacity: 0`, give the textarea its own name with `aria-label` (a placeholder is not a label), and mark the span `aria-hidden`.

Two `layoutId`s do all the morphing, with the pixel `borderRadius` set in `style` on both shapes. To swap the form for a thank-you message inside, nest an `AnimatePresence mode="popLayout"` in a positioned wrapper, with a light `filter: "blur(2px)"` on enter and exit to soften the cut. Escape closes the popover, and Cmd or Ctrl with Enter submits.

### A card that opens into a detail view

- Each pair of matching parts gets the same `layoutId`, built from the record's id: `card-${id}`, `image-${id}`, `title-${id}`, `summary-${id}`, `action-${id}`.
- The open card is `position: fixed; inset: 0`, a real style change, because layout animation moves between real layouts, not `animate` values.
- The backdrop and the card sit in separate `AnimatePresence` blocks, so the backdrop can leave almost at once: `exit={{ opacity: 0, transition: { duration: 0.05 } }}`.
- Text that exists only in the open state gets `layout`, its own fade, and a quick fade-out, so it is gone before the card shrinks.
- Pixel `borderRadius` in `style` everywhere, images included.
- Clicking outside and pressing Escape both close it.

### One widget, several rich states

A small widget that changes between a fixed set of states: a status pill that grows into a timer, a ring, a media player.

- `mode="wait"`: one state leaves completely before the next arrives.
- Animate `layout` between fixed widths and heights per state, for full control, with pixel `borderRadius` in `style`.
- Tune each pair of states separately: pass the transition through `custom` and choose `scale`, `y` and bounce per pair in variant functions. A fixed list of transitions is fine; there is a fixed list of states.
- Smaller states take more bounce to read as alive ([spring-animations](spring-animations.md)).
- A light `blur()` on enter and exit softens the cut, and `tabular-nums` keeps changing digits from shifting.

### A tab indicator that slides

One element, rendered only under the active tab. It unmounts and remounts with the same `layoutId`, and Motion slides it between tabs:

```jsx
const [activeId, setActiveId] = useState(tabs[0].id);
const [fromKeyboard, setFromKeyboard] = useState(false);
const reduce = useReducedMotion(); // reduced motion: the indicator jumps, as it does for keyboard moves
const choose = (id, keyboard) => { setFromKeyboard(keyboard); setActiveId(id); };

{tabs.map((tab) => (
  <button
    key={tab.id}
    className="relative"
    onClick={() => choose(tab.id, false)}
    onFocus={(event) => choose(tab.id, event.target.matches(":focus-visible"))}
  >
    {activeId === tab.id && (
      <motion.div
        className="absolute inset-0 bg-surface"
        layoutId="active-tab"
        style={{ borderRadius: 8 }}
        transition={fromKeyboard || reduce ? { duration: 0 } : { type: "spring", bounce: 0, duration: 0.3 }}
      />
    )}
    <span className="relative">{tab.label}</span>
  </button>
))}
```

The indicator's fill is a theme token, never a black or white tint: `bg-surface` stands for the project's own surface token, which in a shadcn project is `bg-muted` (or `bg-card` on a muted bar), and its radius is set in pixels in `style` because a class radius warps as the width changes. Each button is `relative`, so the indicator stays inside it, and the label sits in a positioned span after the indicator so it paints on top. If the tabs themselves move, give them `layout` too, and wrap each tab bar in its own `<LayoutGroup id>` when a page has more than one.

> Delta: never animate a move that keyboard focus started. An indicator gliding across the bar on every Tab press turns keyboard navigation into a slideshow; the `:focus-visible` check sends keyboard moves to `{ duration: 0 }` while pointer moves keep the spring.
