# Exit animations (AnimatePresence)

Motion for React can animate an element out after React removes it, but only when the structure is right. Get one rule wrong and the element vanishes instantly or never leaves. This file is the checklist. Reduced motion, once for the whole file: under `reduce`, every exit drops its movement and keeps its opacity fade ([accessibility](accessibility.md)).

---

## The structure

- `exit-requires-wrapper`: the conditional element sits inside `<AnimatePresence>`, and the condition sits inside the wrapper, not around it.
- `exit-prop-required`: the element inside has an `exit` prop.
- `exit-key-required`: every child has a stable key (`item.id`), never the array index. No key, no exit.
- `exit-matches-initial`: an element leaves the way it came in.
- `exit-initial-false`: `initial={false}` on AnimatePresence skips the animation on first render, so a state swap animates only when it changes.

```tsx
import type { ReactNode } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";

function Notice({ isVisible, children }: { isVisible: boolean; children: ReactNode }) {
  const reduce = useReducedMotion();
  const y = reduce ? 0 : 20; // under reduce the fade stays and the movement goes

  return (
    <AnimatePresence initial={false}>
      {isVisible && (
        <motion.div
          initial={{ y, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y, opacity: 0 }}
        >
          {children}
        </motion.div>
      )}
    </AnimatePresence>
  );
}
```

`exit-matches-initial` covers one element coming and going. When two different elements swap places, they follow one direction instead, like a reel: the old one leaves on one side and the new one arrives from the other.

## Presence hooks

- `presence-hook-in-child`: `useIsPresent` and `usePresence` are called in the child of AnimatePresence, never in the component that renders the wrapper.
- `presence-safe-to-remove`: with `usePresence`, call `safeToRemove` once your own cleanup has finished.
- `presence-disable-interactions`: an element on its way out should ignore clicks; read `useIsPresent` and switch its handlers off.

## Choosing a mode

- `mode-wait-semantics`: `"wait"` lets the old element finish leaving before the new one starts. Use it for an icon swap, or for one rich state turning into another.
- `mode-wait-doubles-duration`: the two halves run back to back, so the swap takes about twice as long. Halve each timing.
- `mode-pop-layout-semantics`: `"popLayout"` runs both at once and lets the surrounding layout close the gap straight away. Use it for swaps inside a button, step changes and crossfades.
- `mode-pop-layout-positioned-parent`: `popLayout` takes the leaving element out of the flow with `position: absolute`, so the element that contains it needs a position other than `static`, or the leaving element jumps to some ancestor further up ([Motion AnimatePresence](https://motion.dev/docs/react-animate-presence), checked 3 October 2026).
- `mode-pop-layout-ref`: under `popLayout`, a direct child that is your own component must pass its `ref` on to its DOM element (a plain `ref` prop in React 19, `forwardRef` in React 18), as the same page warns.
- `mode-sync-layout-conflict`: the default `"sync"` overlaps entering and leaving elements in the layout; for lists, use `popLayout`.

When an exit plays but looks wrong, try another `mode` before anything else.

## Exits that depend on fresh values

- `exit-custom-to-both`: a leaving element still holds the props it last rendered with. Give the new value to AnimatePresence's `custom` as well as the element's, or a direction-aware exit uses the old direction.

```tsx
import type { ReactNode } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";

// dir: 1 forward, -1 back, 0 for a crossfade with no slide
const slideVariants = {
  enter:  (dir: number) => ({ x: dir * 40, opacity: 0 }),
  center: { x: 0, opacity: 1 },
  exit:   (dir: number) => ({ x: dir * -40, opacity: 0 }),
};

function Pager({ page, direction, children }: { page: number; direction: 1 | -1; children: ReactNode }) {
  const reduce = useReducedMotion();
  const custom = reduce ? 0 : direction; // under reduce the crossfade stays and the slide goes

  return (
    // popLayout needs a positioned parent, or the leaving page jumps
    <div style={{ position: "relative", overflow: "hidden" }}>
      <AnimatePresence custom={custom} initial={false} mode="popLayout">
        <motion.div
          key={page}
          custom={custom}
          variants={slideVariants}
          initial="enter"
          animate="center"
          exit="exit"
        >
          {children}
        </motion.div>
      </AnimatePresence>
    </div>
  );
}
```

## Nested AnimatePresence

- `nested-propagate-required`: when an outer AnimatePresence removes a section, an inner AnimatePresence inside it skips its children's exits by default. Put `propagate` on the inner one only, and those exits play ([Motion docs](https://motion.dev/docs/react-animate-presence), checked 3 October 2026).
- `nested-consistent-timing`: time the two levels together, so the children finish before their parent is gone.
