# Accessibility: reduced motion

Movement on screen can make some people dizzy or sick, pulls at the attention of others, and can hide when an interface actually changed. So every animation ships in two versions: the full one for `no-preference`, and a reduced one for `reduce`. This file says what the reduced version keeps, and gives the code for it.

---

## The four tiers

> **Delta knowledge:** `reduce` is not "turn animation off". Animation is how people see that something changed; strip it all out and the interface gets harder to follow, not easier. Take the travel away and keep the change visible: **remove the movement, keep the meaning.**

| Tier | Under `reduce` |
| --- | --- |
| **Movement**: `transform`, `translate`, `scale`, position, layout | **Removed entirely.** Never just shortened. Nothing travels. |
| **State**: `opacity`, `color`, `background-color` | **May stay.** A fade shows the change without moving anything. |
| **Decoration**: idle floats, ambient loops, parallax, marquees | **Off.** Loops pause on a chosen frame (snippet below), never frame 0. |
| **Direct manipulation**: drag, swipe, a sheet following the finger | **Still 1:1.** The person is the source of the motion; see below. |

A dialog that scaled in now fades in. A panel that slid from the edge fades in where it ends up. Steps that slid sideways crossfade. People still see each change; nothing crosses the screen.

```css
.dialog {
  animation: dialog-in 200ms ease-out;
}

@media (prefers-reduced-motion: reduce) {
  .dialog {
    animation-name: dialog-fade; /* same timing, opacity only: swapped, not deleted */
  }
}
```

Where a tier says remove, write `animation: none` or `transition: none` on that element. Never a global `* { animation: none !important }`: it also deletes the fades the reduced version should keep.

### Direct manipulation stays

An element following someone's finger is their own movement, not motion the interface imposes. Under `reduce` a dragged drawer still tracks the finger exactly and a swipe still follows the thumb; making tracking vaguer makes the product harder to use, not calmer. Only the release changes: it settles critically damped, with no bounce or overshoot ([spring-animations](spring-animations.md)).

## The setting

`prefers-reduced-motion` has two values: `no-preference`, where the full animation runs, and `reduce`, where the tiers apply. People set it once, in their operating system's accessibility settings, and expect every site to follow it. There is nothing to opt into per site and no in-app switch to build first.

## Check it by watching

Treat reduced motion as a second pass, not a constraint that shapes the first one:

1. Build the animation and get it right.
2. Apply the tiers, then switch the preference on in Chrome DevTools: open the Rendering panel and emulate `prefers-reduced-motion: reduce`.
3. Watch every animation you touched.

Reading the code is not enough. The usual miss is a reduced version that still moves: one `transform` left behind, often in a shared class or inside a spring's settings.

## Tailwind

`motion-safe:` and `motion-reduce:` map to the two values. Prefer `motion-safe:`: written that way, the calm version is what you get by default.

```html
<!-- Decoration: exists only under no-preference -->
<svg class="motion-safe:animate-bounce" viewBox="0 0 24 24"></svg>

<!-- An entrance that carries meaning: movement swapped for a fade -->
<div class="motion-safe:animate-slide-up motion-reduce:animate-fade">…</div>
```

`animate-slide-up` and `animate-fade` stand for project keyframes; Tailwind's stock set is `spin`, `ping`, `pulse` and `bounce`.

## MotionConfig: one switch for a whole app

In Motion for React, `reducedMotion="user"` follows the setting for every motion component below it. Under `reduce` it switches off transform and layout animations and keeps the others, such as `opacity` and `backgroundColor` ([Motion accessibility](https://motion.dev/docs/react-accessibility), checked 3 October 2026): the tier table, applied for you.

```jsx
import { MotionConfig } from "motion/react";

export function App({ children }) {
  return <MotionConfig reducedMotion="user">{children}</MotionConfig>;
}
```

> **Delta knowledge:** the default is `reducedMotion="never"` ([MotionConfig](https://motion.dev/docs/react-motion-config), checked 3 October 2026). Until you set it, Motion ignores the operating system setting. Set it once at the root rather than remembering it in every component.

Treat it as the floor and add `useReducedMotion` in components where fading alone loses the meaning: a hand-made reduced variant set, a loop paused on a chosen frame, video that should not start by itself.

## What a media query cannot see

Some Motion props move things without any stylesheet involved, so CSS alone never finishes the job in a Motion codebase. Check the JSX as well:

```jsx
import useMeasure from "react-use-measure";
import { motion, useReducedMotion } from "motion/react";

// A panel whose height follows its content.
export function GrowingPanel({ children }) {
  const [measureRef, size] = useMeasure();
  const reduce = useReducedMotion();

  // The height tween and the layout animation both move things, so both stop under reduce.
  return (
    <motion.div animate={reduce ? undefined : { height: size.height }} layout={!reduce} style={{ overflow: "hidden" }}>
      <div ref={measureRef}>{children}</div>
    </motion.div>
  );
}
```

## Cut between frames when the sequence is the content

Some sequences explain something, such as a diagram stepping through states, and cannot just be removed. Show every state, but cut to each one instead of moving between them:

```jsx fragment
<motion.g
  animate={diagramStates[current]}
  transition={reduce ? { duration: 0 } : { type: "spring", bounce: 0, duration: 0.3 }}
/>
```

`diagramStates` and `current` stand for your list of states and the index shown; the spring is the house default from [spring-animations](spring-animations.md).

## Smooth scrolling

Smooth scrolling is motion nobody asked for. Switch it on under `no-preference` instead of switching it off under `reduce`, so a browser that matches neither query also gets the calm version:

```css
@media (prefers-reduced-motion: no-preference) {
  :root {
    scroll-behavior: smooth;
  }
}
```

## Hover on touch screens

A tap on a touch screen fires `:hover`, so hover effects belong behind a media query for devices with a precise pointer:

```css
@media (hover: hover) and (pointer: fine) {
  .tile:hover {
    transform: scale(1.02);
  }
}
```

A hover scale is still movement: under `reduce` it goes too.

## Recipes

### Animated images

An animated GIF or AVIF plays with no way to stop it. With `<picture>`, people who prefer reduced motion get a still image, and their browser never downloads the animation:

```html
<picture>
  <source media="(prefers-reduced-motion: no-preference)" srcset="loop.avif" type="image/avif" />
  <source media="(prefers-reduced-motion: no-preference)" srcset="loop.gif" type="image/gif" />
  <!-- The still: give it real alt text if the image carries information -->
  <img src="still.png" alt="" />
</picture>
```

### Video that plays by itself

Autoplay is fine under `no-preference`. Under `reduce` the video waits, paused, behind a visible button.

```html
<figure class="clip">
  <video src="demo.mp4" muted loop playsinline controls></video>
  <button type="button" class="clip-toggle" hidden>Play video</button>
</figure>
```

```js
const allowMotion = window.matchMedia("(prefers-reduced-motion: no-preference)");

for (const clip of document.querySelectorAll(".clip")) {
  const video = clip.querySelector("video");
  const toggle = /** @type {HTMLButtonElement} */ (clip.querySelector(".clip-toggle"));

  // The label always reports what the video is really doing.
  const relabel = () => { toggle.textContent = video.paused ? "Play video" : "Pause video"; };
  video.addEventListener("play", relabel);
  video.addEventListener("pause", relabel);
  toggle.addEventListener("click", () => (video.paused ? video.play() : video.pause()));

  // Our button replaces the native controls only once this script runs.
  video.controls = false;
  toggle.hidden = false;

  // A browser that blocks autoplay leaves it paused; the button still works.
  if (allowMotion.matches) video.play().catch(() => {});
}
```

- The button starts `hidden`, so a control with nothing wired to it never flashes on screen before the script runs.
- Each figure finds its own video and button, so two clips on a page never control each other.
- `playsinline` keeps iOS from taking the video full screen.
- Autoplay starts with `play()`. The `autoplay` attribute is read only when the video first has enough data to play ([HTML standard, media ready states](https://html.spec.whatwg.org/multipage/media.html#ready-states), checked 3 October 2026), so adding it from script later starts nothing.

### Pause a loop on a frame you chose

> **Delta knowledge:** a paused loop stops on its first frame, which is usually its worst: the empty chart, the folded shape. A **negative `animation-delay` moves into the timeline**, so the pause lands on a frame you picked.

```css
.ambient {
  /* A decorative loop: its period is not an interaction duration (those bands are in timing-and-duration.md). */
  animation: drift 3s ease-in-out infinite;
}

@media (prefers-reduced-motion: reduce) {
  .ambient {
    animation-delay: -0.4s; /* holds 0.4s in; try values until the still reads well */
    animation-play-state: paused;
  }
}
```

The paused picture then reads as an illustration rather than a broken first frame.

### A reduced-motion hook without Motion

Without Motion, `useSyncExternalStore` gives a hook that is safe on the server:

```tsx
import { useSyncExternalStore } from "react";

const REDUCE = "(prefers-reduced-motion: reduce)";

function subscribe(onChange: () => void) {
  const list = window.matchMedia(REDUCE);
  list.addEventListener("change", onChange);
  return () => list.removeEventListener("change", onChange);
}

export function usePrefersReducedMotion(): boolean {
  return useSyncExternalStore(
    subscribe,
    () => window.matchMedia(REDUCE).matches, // in the browser
    () => false,                              // on the server and during hydration
  );
}
```

The first render in the browser uses the server value, `false`, so the markup matches; React then re-renders with the real setting. Use the value to choose animation values, never to decide whether something mounts, or people who prefer reduced motion see the full version flash first.

### Swap the whole variant set

A step-by-step form that slides between steps and lets its height follow the content moves things in three places: the slide, the measured height and the layout of the buttons. Each needs its own reduced branch, and swapping a complete variant set is cleaner than patching values one by one:

```jsx
import { useState } from "react";
import useMeasure from "react-use-measure";
import { AnimatePresence, MotionConfig, motion, useReducedMotion } from "motion/react";

const slide = {
  enter: (dir) => ({ x: `${dir * 110}%`, opacity: 0 }),
  shown: { x: "0%", opacity: 1 },
  leave: (dir) => ({ x: `${dir * -110}%`, opacity: 0 }),
};

// The same three states with opacity only: the step change stays readable, nothing travels.
const fade = { enter: { opacity: 0 }, shown: { opacity: 1 }, leave: { opacity: 0 } };

export function Wizard({ steps }) {
  const [index, setIndex] = useState(0);
  const [dir, setDir] = useState(1);
  const [measureRef, size] = useMeasure();
  const reduce = useReducedMotion();
  const go = (delta) => { setDir(delta); setIndex((i) => i + delta); };

  return (
    <MotionConfig transition={{ type: "spring", bounce: 0, duration: 0.3 }}>
      {/* 1. The height follows the content, except under reduce: a growing box is movement. */}
      <motion.div animate={reduce ? undefined : { height: size.height }} style={{ overflow: "hidden" }}>
        {/* popLayout takes the leaving step out of the flow, so its container is positioned. */}
        <div ref={measureRef} style={{ position: "relative" }}>
          <AnimatePresence mode="popLayout" initial={false} custom={dir}>
            {/* 2. Under reduce the whole set swaps from slide to fade. */}
            <motion.div key={index} custom={dir} variants={reduce ? fade : slide} initial="enter" animate="shown" exit="leave">
              {steps[index]}
            </motion.div>
          </AnimatePresence>
          {/* 3. The buttons reflow with a layout animation, which is movement too. */}
          <motion.div layout={!reduce} className="wizard-actions">
            <button type="button" onClick={() => go(-1)} disabled={index === 0}>Back</button>
            <button type="button" onClick={() => go(1)} disabled={index === steps.length - 1}>Next</button>
          </motion.div>
        </div>
      </motion.div>
    </MotionConfig>
  );
}
```

The habit to keep: **call `useReducedMotion()` once, then go through every property in the component that animates.** Movement hides in more than one place, and each of the three above is its own switch; miss one and the reduced version still moves.

**The blunt fallback**, when the entrance is the only animation or you cannot check every property: render it already in place.

```jsx
const reduce = useReducedMotion();

<motion.div
  initial={reduce ? false : { opacity: 0, y: 20 }}
  animate={{ opacity: 1, y: 0 }}
/>
```

`initial={false}` skips the entrance completely, the fade included, so it is the fallback, not the first choice.

### Actions revealed by hover, on a touch screen

Touch has no hover, so actions that appear on hover need another way in. The first tap shows what hover would have shown; the second tap acts.

```css
.entry .actions {
  opacity: 0;
  pointer-events: none; /* while hidden, a tap cannot land on an invisible button */
  transition: opacity 150ms ease;
}
.entry.revealed .actions,
.entry:focus-within .actions {
  opacity: 1;
  pointer-events: auto; /* keyboard focus shows them at once */
}
@media (hover: hover) and (pointer: fine) {
  .entry:hover .actions {
    opacity: 1;
    pointer-events: auto;
  }
}
```

```jsx
import { useRef, useState } from "react";

function Entry({ title, onOpen, children }) {
  const [revealed, setRevealed] = useState(false);
  const lastPointer = useRef(null);

  const handleOpen = () => {
    const touch = lastPointer.current === "touch";
    lastPointer.current = null; // a later Enter or Space starts clean
    if (touch && !revealed) {
      setRevealed(true); // first tap: show what hover shows
      return;
    }
    onOpen(); // second tap, a mouse or pen click, or Enter and Space
  };

  return (
    <div className={`entry${revealed ? " revealed" : ""}`}>
      <button
        type="button"
        className="entry-open"
        onPointerDown={(event) => { lastPointer.current = event.pointerType; }}
        onClick={handleOpen}
      >
        {title}
      </button>
      <div className="actions">{children}</div>
    </div>
  );
}
```

The open action is a real `<button>`, so it takes focus and opens with Enter or Space in one step, and focus inside the card already shows the actions. Only a touch tap, read from the pointer event, goes through the two-tap path. The actions are their own buttons next to the open button, never inside it. The fade is a tier-two opacity change, so it stays under `reduce` as it is.
