# CSS animation mechanics

How transitions, `@keyframes` and transforms really behave, then a few recipes built on them. The CSS needs no library; a few recipes use JSX only to hand each element an `--index`. Numbers live elsewhere: durations and the frequency rule in [timing-and-duration](timing-and-duration.md), named curves in [easing-curves](easing-curves.md).

The recipes come in two groups. Product recipes fit any interface. Showcase recipes (orbits, coins, letter reveals) are for marketing, editorial and illustration surfaces only, and sit in their own section at the end.

---

## CSS or a library

CSS is the right tool for a hover, an element appearing or leaving, an endless constant-speed loop (marquee, spinner), and any project counting bytes. Reach for Motion when the motion must be interrupted and keep its momentum, or when the choreography has many parts: CSS has no real spring.

Be honest about that limit. Without springs, CSS motion can feel flat next to native apps, and people judge the result, not the technology; if a library gets a better feel, use it. Where CSS wins outright is composite-only animation, which keeps running when the main thread is busy ([performance](performance.md)).

## Transition or keyframes

Ask who drives the change: the person, or the page?

| A **transition** when | **`@keyframes`** when |
| --- | --- |
| A person's action causes it: hover, press, open, a state change | It runs by itself: an intro, an attention pulse |
| It may be reversed or redirected halfway | It loops: a marquee, a spinner |
| | It has several stages: a pulse, a blink |
| | It is a one-off entrance or exit nobody interrupts |

> **Delta knowledge:** a transition starts from wherever the value is right now; a keyframe animation starts over from its first frame. That one difference decides most cases: anything that can fire again while it is still moving, like toasts arriving in a burst, must be a transition.

When a keyframe animation needs many stages, it is usually the wrong tool; a multi-step sequence is clearer in Motion.

## Writing transitions

```css
.chip {
  transition: 150ms ease;
  transition-property: background-color, border-color, color;
}
```

- **Put the transition on the resting rule**, not only inside `:hover`, or leaving the hover snaps back with no animation.
- **Name the properties; never `transition: all`.** Some unrelated property will eventually change and animate with it. When several properties share one timing, give the timing once and list the properties in `transition-property`, as above.
- **Write `ease` even though it is the default.** Many readers assume the default is `linear`, and writing it shows it was chosen.
- **Give the delay its own line.** In `transition: transform 0.2s ease 1s` the delay is easy to miss; `transition-delay: 1s` is not.
- Transitions handle entrances too, with `@starting-style` ([practical-tips](practical-tips.md)).

## Writing keyframes

```css
@keyframes appear {
  from { opacity: 0; }
}

.status-icon {
  animation: appear 200ms ease-out;
}
```

Keep the `animation` shorthand to name, duration and timing function, and write anything else as its own property.

- **A missing `from` or `to` frame is filled from the element's own computed style**, so a keyframe lists only what changes. The `appear` animation above ends wherever the icon already rests.
- **A blink needs a step.** A complete blink: `@keyframes blink { 50% { visibility: hidden; animation-timing-function: steps(1, end); } }`. The step holds `hidden` from the middle to the end of each cycle, whatever timing the element uses. Without it, `visibility` stays visible through the smooth part of each segment, so under the default `ease` the element is hidden only at the exact midpoint and never visibly blinks. `animation: blink 1s steps(1, end) infinite` on the element does the same for every segment.
- **A closing keyframe restarts, so it is not interruption-friendly.** Radix keeps a closing component mounted while a keyframe animation on `[data-state="closed"]` plays; Base UI marks the closing state with `[data-closed]` and `[data-ending-style]` and waits for transitions as well ([Base UI animation](https://base-ui.com/react/handbook/animation), checked 3 October 2026).

  ```css
  @keyframes shrink-away { to { opacity: 0; transform: scale(0.98); } }

  .menu[data-state="closed"] {
    animation: shrink-away 160ms ease-out; /* about 20% quicker than a 200ms entrance */
  }
  ```

  The missing `from` is the resting style, not the value on screen. Close a menu whose entrance is still running and it jumps to fully open before shrinking away. Anything that can close halfway through wants a transition, which starts from where it is; Base UI recommends transitions for this reason.

- **`animation-fill-mode`:** `backwards` shows the first frame while a delay runs (the cure for a delayed entrance that flashes its resting state), `forwards` holds the last frame once it ends (without it the element snaps back), and `both` combines them.
- **Loops** come from `animation-iteration-count: infinite`; a count of three or four is rarely useful.
- **`animation-direction: alternate`** runs forward then back, instead of jumping to the start each time.
- **`animation-play-state: paused`** stops an animation where it is: something a transition cannot do, and what the reduced-motion section below relies on.
- **To replay an animation in React, change the element's `key`**; the remount starts it again.

## Transforms

`transform` changes how an element is drawn without moving it in the layout: its neighbours stay where they were.

- **Translate:** positive values go right and down, negative left and up. `translateX()` and `translateY()` read more clearly than `translate(x, y)`.

  > **Delta knowledge:** a percentage in a transform is measured against the element **itself**. `translateY(100%)` moves an element of any height exactly out of its own way, which is why toast and drawer libraries move by percentages. A fixed `300px` fits one size only, so prefer percentages even when the size is fixed today.

- **Scale** multiplies, and unlike `width` and `height` it scales the content too: text, icons and corner radius come along, which is what press feedback and zoom want (press values in [practical-tips](practical-tips.md)). Never enter from `scale(0)`; nothing real grows out of nothing. UI enters from `scale(0.95)` with a fade, larger surfaces closer to 1 (a nav menu at `0.98`); an expressive marketing entrance may start lower. `scaleX` or `scaleY` alone usually looks squashed rather than resized.
- **Rotate:** a single rotation reads best with `ease-in-out`; constant rotation (spinners, coins) is `linear`.
- **Transforms apply in the order written.** Rotating before translating ends up in a different place from translating before rotating; the orbit recipe depends on it.
- **Inline elements ignore transforms.** Give a `<span>` `display: inline-block` first.
- `transform-origin` is the point everything turns or scales around, the centre by default; popovers that grow from their trigger are in [practical-tips](practical-tips.md).

## 3D in four properties

```css
.stage {
  perspective: 500px;            /* how far the viewer sits: this is what creates depth */
  transform-style: preserve-3d;  /* children live in shared 3D space instead of a flat plane */
}

.stage .face {
  backface-visibility: hidden;   /* the back of the face disappears */
  transform: rotateY(24deg) translateZ(72px);
}
```

- `rotateY` turns around the vertical axis, like a revolving door; `rotateX` around the horizontal one, like a spit roast.
- `translateZ` moves toward the viewer and does nothing visible without `perspective` on a parent; the closer the perspective, the stronger a small move looks.
- Without `preserve-3d` there is no depth: one child can never pass behind another.
- `backface-visibility: hidden` is what turns two stacked faces into one object with a front and a back.

## Hover belongs to pointers

On a touch screen, a tap sets `:hover` and it sticks. Wrap hover effects in a media query for precise pointers:

```css
@media (hover: hover) and (pointer: fine) {
  .tile:hover { background: var(--color-surface-hover); }
}
```

Tailwind v4 already wraps `hover:` in `@media (hover: hover)` ([Tailwind states](https://tailwindcss.com/docs/hover-focus-and-other-states), checked 3 October 2026). On v3, opt in:

```js
// tailwind.config.js, v3 only
module.exports = {
  future: { hoverOnlyWhenSupported: true },
};
```

When a hover reveals information rather than decoration, give keyboard users the same reveal through `:focus-visible` (which matches keyboard focus, where `:focus` also matches a click). The element must be focusable: a link, a button, or `tabindex="0"`. A move that keyboard focus starts is never animated, so that branch sets `transition-duration: 0s`.

## Product recipes

### Arrow swap on a button

One arrow slides out of the bottom as its twin slides in from the top:

```css
.export-button {
  overflow: hidden;
  display: grid;
  place-items: center;
}

.export-button svg {
  grid-area: 1 / 1; /* both arrows share one cell */
  transition: transform 150ms cubic-bezier(0.645, 0.045, 0.355, 1); /* ease-in-out-cubic */
}

.export-button svg:first-child { transform: translateY(-150%); } /* waiting above */

@media (hover: hover) and (pointer: fine) {
  .export-button:hover svg:first-child { transform: none; }
  .export-button:hover svg:last-child  { transform: translateY(150%); }
}
```

The travel is `150%`, not `100%`: the percentage is measured on the arrow, and one arrow-height of travel does not clear the larger button's edge.

### A toast stack that can be interrupted

New toasts push the stack up. When one arrives while the last is still moving, the target changes halfway, which is exactly the case for a transition rather than keyframes.

```tsx
{toasts.map((toast, i) => (
  // React's style type has no custom properties: the cast types "--index".
  <Toast key={toast.id} style={{ "--index": toasts.length - 1 - i } as React.CSSProperties} />
  /* reversed: the newest toast gets index 0, at the bottom */
))}
```

`Toast` and `toasts` stand for your toast component and its list.

```css
.toast {
  --gap: 12px;
  position: absolute;
  bottom: 0;
  transform: translateY(calc(-1 * var(--index) * (100% + var(--gap))));
  transition:
    opacity 250ms cubic-bezier(0.215, 0.61, 0.355, 1),  /* ease-out-cubic */
    transform 250ms cubic-bezier(0.215, 0.61, 0.355, 1);

  @starting-style {
    opacity: 0;
    transform: translateY(100%); /* enters from below by its own height */
  }
}
```

Each toast sits at index × (its height + gap), negated to move up. `@starting-style` gives the first frame without a `useEffect(() => setMounted(true))`, which React may run before the browser paints ([React useEffect](https://react.dev/reference/react/useEffect), checked 3 October 2026), so the entrance could be skipped. The 250ms stays inside the UI ceiling; Sonner ships a slower 400ms `ease`, and a project that wants that feel declares it in VISION.md's timing table.

## Showcase recipes

**Opt-in.** These are decorative and belong to marketing, editorial and illustration surfaces. Product UI does not use them: Linear-style restraint and an Apple-soft surface both argue against motion for its own sake.

### Hover reveal of a description

A description parked below a card slides up on hover:

```css
.feature-card {
  overflow: hidden; /* without it the parked text shows below the card */
}

.feature-card p {
  --margin: 8px; /* on the spacing scale */
  --expo: cubic-bezier(0.19, 1, 0.22, 1);
  margin: var(--margin);
  transform: translateY(calc(1px + var(--margin) + 100%));
  transition: transform 500ms var(--expo);
}

@media (hover: hover) and (pointer: fine) {
  .feature-card:hover p { transform: none; }
}

.feature-card:focus-visible p {
  transform: none;
  transition-duration: 0s; /* started by the keyboard: instant */
}
```

> **Delta knowledge:** park the text by its own height **plus its margin** (one custom property keeps them in step), **plus 1px** when an outer `box-shadow` serves as a border and would otherwise show a sliver.

The 500ms does not feel slow because the curve covers most of the distance at once. On a contract project it needs a row in VISION.md's timing table. The `:focus-visible` branch is required: without it a keyboard user never sees the text.

### Orbit

A small circle circling a larger one while always facing the viewer:

```css
.orbit-scene {
  position: relative;
  perspective: 500px;
  transform-style: preserve-3d; /* lets the satellite pass behind */
}

.satellite {
  position: absolute;
  top: 50%;
  left: 50%;
  translate: -50% -50%; /* the translate property applies before transform, so it centres every frame */
  animation: circle 6s linear;
  animation-iteration-count: infinite;
}

@keyframes circle {
  from { transform: rotateY(0deg) translateZ(72px) rotateY(360deg); }
  to   { transform: rotateY(360deg) translateZ(72px) rotateY(0deg); }
}
```

Read the transform as three parts: the first `rotateY` carries the satellite round, `translateZ` sets the radius, and the last `rotateY` turns it back the opposite way so it keeps facing you. It is `linear` because orbits do not speed up. Keep it slow and pause it under reduced motion.

### Coin flip

Two faces and an edge, with the parent spinning:

```css
.coin {
  position: relative;
  width: 52px; /* radius 26px, edge 6px thick */
  height: 52px;
  transform-style: preserve-3d;
  animation: spin 2s linear;
  animation-iteration-count: infinite;
}

.coin-face {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  backface-visibility: hidden; /* each face vanishes when turned away */
}

.coin-front { transform: translateZ(3px); }
.coin-back  { transform: rotateY(180deg) translateZ(3px); }

.coin-edge {
  position: absolute;
  width: 6px;
  height: 100%;
  transform: translateX(23px) rotateY(90deg); /* centred on the coin's axis: 26px minus half the edge */
}

@keyframes spin {
  to { transform: rotateY(360deg); }
}
```

### Marquee

An endless constant-speed slide, one of the few honest uses of `linear`:

```css
.ticker { overflow: hidden; }

.ticker-track {
  display: flex;
  width: max-content;
  animation: slide 20s linear;
  animation-iteration-count: infinite;
}

@keyframes slide {
  to { transform: translateX(-50%); }
}
```

Put the content in the track twice. At `-50%`, half the track's own width, the second copy sits where the first started, so the loop has no seam.

### Card stack

A collapsed stack: each card further back is smaller and raised a little.

```tsx
{cards.map((card, i) => (
  <div className="stack-card" key={card.id} style={{ "--index": cards.length - 1 - i } as React.CSSProperties} />
))}
```

```css
.stack-card {
  --shrink: 0.05;
  --lift: -12%;
  transform:
    scale(calc(1 - var(--index) * var(--shrink)))
    translateY(calc(var(--index) * var(--lift)));
}
```

The custom property handles any number of cards without new CSS, which an `nth-child` version cannot.

### Letter-by-letter heading

Each letter of `WORD` (the heading text) rises a beat after the one before:

```tsx
<h1 className="letters" aria-label={WORD}>
  {WORD.split("").map((glyph, position) => (
    <span key={position} aria-hidden="true" style={{ "--index": position } as React.CSSProperties}>
      {glyph}
    </span>
  ))}
</h1>
```

```css
.letters { overflow: hidden; }

.letters span {
  --stagger: 50ms;
  display: inline-block;
  animation: rise 1s cubic-bezier(0.19, 1, 0.22, 1); /* the expo curve */
  animation-fill-mode: backwards;
  animation-delay: calc(var(--index) * var(--stagger));
}

@keyframes rise {
  from { transform: translateY(100%); }
}
```

Four details, each of which breaks it alone:

1. `display: inline-block`, or the letters have no box to move.
2. `overflow: hidden` on the heading, or the waiting letters show below the line.
3. `animation-fill-mode: backwards`, or each letter sits in place until its delay ends.
4. A small `--stagger`: 50ms per letter is the ceiling, and the delays add up over the word; long words drop toward 30ms.

Split letters are read one at a time by some screen readers, so the heading carries the whole word in `aria-label` and each letter is `aria-hidden`. The 1s only works because the curve front-loads the movement.

## Reduced motion

Every recipe here falls into one of two groups ([accessibility](accessibility.md) has the tiers).

**State changes and entrances** (arrows, toasts, reveals, letters): remove the movement entirely, never just shorten it, and keep a fade where it helps people follow the change.

```css
@media (prefers-reduced-motion: reduce) {
  .export-button svg, .feature-card p { transition: none; }
  .letters span { animation: none; }
  .toast { transition: opacity 200ms ease; } /* the fade stays; the movement happens at once */
}
```

**Loops** (orbit, coin, marquee): pure decoration, so they stop, held on a frame that looks finished rather than on frame 0. Choose the delay per loop: it is a point in that loop's own timeline.

```css
@media (prefers-reduced-motion: reduce) {
  .satellite, .coin, .ticker-track { animation-play-state: paused; }
  .satellite    { animation-delay: -1.5s; } /* a quarter of the 6s orbit */
  .coin         { animation-delay: -0.4s; } /* a fifth of the 2s spin */
  .ticker-track { animation-delay: -5s; }   /* a quarter of the 20s marquee */
}
```

## Learning from other sites

When a CSS animation impresses you, open the browser's developer tools: the properties, durations and curves are all visible. Motion driven by script still shows which properties change. Keep a short list of products whose motion you trust and study those, rather than copying whatever is popular.
