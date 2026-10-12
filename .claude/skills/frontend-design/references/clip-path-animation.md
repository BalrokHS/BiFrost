# clip-path as an animation tool

`clip-path` is not just for shapes — it's one of the strongest
animation primitives in CSS: no extra DOM, composited off the main
thread in some engines (not all — acceleration is a bonus, see
[performance](performance.md)), and it can do things color/opacity
transitions structurally cannot (seamless color swaps, precise reveals,
comparison wipes).

---

## The inset shape

`clip-path: inset(top right bottom left)` defines a rectangular clip.
Each value cuts that much off the element from its side. Every recipe
below is one inset animating into another:

```css
.hidden-from-right { clip-path: inset(0 100% 0 0); }
.hidden-from-bottom { clip-path: inset(0 0 100% 0); }
.fully-visible     { clip-path: inset(0 0 0 0); }
```

## Reveal on scroll

Start clipped from the bottom, un-clip when the element enters the
viewport (IntersectionObserver, or Motion's `useInView` with
`{ once: true, margin: "-100px" }` — the margin is **negative**: it
shrinks the viewport so the element is 100px inside before firing):

```css
.image-reveal {
  clip-path: inset(0 0 100% 0);
  transition: clip-path 600ms cubic-bezier(0.77, 0, 0.175, 1);
}
.image-reveal.in-view { clip-path: inset(0 0 0 0); }
```

600ms is scroll-reveal territory, not product-UI timing. On a contract
project it needs a row in the VISION.md timing table (P7): propose the row
and wait for the person to approve it, never write it unasked. Bands
live in [timing-and-duration](timing-and-duration.md).

Honor `prefers-reduced-motion`: replace the wipe with a short opacity
fade.

## Hold to delete (slow press, fast release)

A coloured overlay starts clipped to nothing. Holding fills it slowly;
letting go empties it quickly. The person's decision gets time, the
system's answer does not. Two details make it feel built rather than
improvised. The overlay repeats the button's content (same icon, same
label), so the fill uncovers a danger-coloured version of both rather
than a plain bar, the same duplicate-and-clip trick as the tabs below,
at button scale. And the press scale has its own transition, so its
timing never follows the fill's. The label says what to do, so the
hold can be discovered:

```html
<button type="button" class="button">
  <span>…icon + "Hold to delete"…</span>
  <span class="overlay" aria-hidden="true">…same icon + label, danger colour…</span>
</button>
```

```css
.button {
  position: relative;
  /* press feedback on its own channel: the house press, 150ms ease-out */
  transition: transform 150ms ease-out;
}
.button[data-holding="pointer"] { transform: scale(0.97); }  /* keyboard holds skip the scale */

.overlay {
  position: absolute; inset: 0;
  display: inline-flex; align-items: center; justify-content: center;
  color: var(--color-danger);
  clip-path: inset(0 100% 0 0);
  transition: clip-path 200ms ease-out;     /* release: fast */
}
.button[data-holding] .overlay {
  clip-path: inset(0 0 0 0);
  transition: clip-path 2s linear;          /* hold: slow, deliberate */
}

@media (prefers-reduced-motion: reduce) {
  .button[data-holding="pointer"] { transform: none; }  /* the fill stays: it is progress, not decoration */
}
```

The fill finishing while the button is still held is the confirmation,
so the script listens for the end of the overlay's transition and only
then runs the action. Space or Enter held down is the keyboard path:

```js
function holdToConfirm(button, onConfirm) {
  const overlay = button.querySelector(".overlay");
  const start = (source) => button.setAttribute("data-holding", source);
  const stop = () => button.removeAttribute("data-holding");
  const isHoldKey = (event) => event.key === " " || event.key === "Enter";

  button.addEventListener("pointerdown", () => start("pointer"));
  for (const type of ["pointerup", "pointerleave", "pointercancel"]) {
    button.addEventListener(type, stop);
  }
  button.addEventListener("keydown", (event) => {
    if (isHoldKey(event) && !event.repeat) start("key");
  });
  button.addEventListener("keyup", (event) => {
    if (isHoldKey(event)) stop();
  });
  button.addEventListener("blur", stop);

  // Releasing early reverses the fill; its transitionend arrives after stop(), so nothing runs.
  overlay.addEventListener("transitionend", (event) => {
    if (event.propertyName !== "clip-path" || !button.hasAttribute("data-holding")) return;
    stop();
    onConfirm();
  });
}
```

Wire it to the product's own delete call:
`holdToConfirm(button, () => deleteProject(id))`, where `deleteProject`
stands for that call. Without it the button is a control with no
target, and it does not ship.

Linear timing is correct here — the fill *is* a time visualization.
Note the three timings never share a channel: press scale 150ms,
release snap 200ms, decision fill 2s.

## Tabs whose colour changes in one sweep

Animating `color` on each tab cannot do this. Render the tab list
twice. Give the second copy the selected look (background and text
swapped), lay it exactly over the first, and clip it down to the
selected tab. When the selection moves, animate the clip from the old
tab to the new one. Every letter changes colour in one even sweep,
which separate `color` transitions never manage to line up.

```html
<div class="tabs">…plain tabs…</div>
<div class="tabs tabs-active" aria-hidden="true" inert>…same tabs, active style…</div>
```

```css
.tabs-active {
  position: absolute; inset: 0;
  clip-path: inset(0 var(--right) 0 var(--left) round 9999px);
  transition: clip-path 250ms cubic-bezier(0.23, 1, 0.32, 1); /* the quint curve */
}
```

Set `--left` and `--right` from the active tab's measured position. The
copy is paint, not content: `aria-hidden` keeps it from screen readers,
and `inert` keeps its buttons out of the tab order, since a hidden copy
that still takes focus traps keyboard users on invisible controls.

## Theme switches

A light and dark switch belongs to the View Transition API, which wipes between two snapshots without duplicating the page: [view-transitions](view-transitions.md) has the recipe.

## Before and after sliders

Stack the two images and clip the upper one at the handle's position.
The two layers are all the markup it needs:

```css
.after { clip-path: inset(0 calc(100% - var(--pos)) 0 0); }
```

Drive `--pos` from the drag (see [gesture-and-drag](gesture-and-drag.md)
for 1:1 tracking); set it directly on the slider element, not a distant
ancestor, to avoid recalculating styles for unrelated children.

**Text variant:** stack an outlined and a solid copy of the same text
and split them at the clip. The edge fills letterforms instead of
sliding between photos — it reads as a reveal, not a slider:

```html
<div class="compare-text">
  <span class="outline">Momentum</span>
  <span class="solid" aria-hidden="true">Momentum</span>
</div>
```

```css
.compare-text { position: relative; }
.outline { color: transparent; -webkit-text-stroke: 1.5px var(--color-ink); }
.solid {
  position: absolute; inset: 0;
  clip-path: inset(0 calc(100% - var(--pos)) 0 0);
}
```

## Control from script: WAAPI

The Web Animations API gives JavaScript control with CSS-level
performance — composited where the engine composites `clip-path`,
interruptible, no library:

```js
element.animate(
  [{ clipPath: "inset(0 0 100% 0)" }, { clipPath: "inset(0 0 0 0)" }],
  { duration: 600, fill: "forwards", easing: "cubic-bezier(0.77, 0, 0.175, 1)" }
);
```

Use WAAPI when the reveal must be triggered/sequenced from JS but you
don't want a motion library for one effect.

## clip-path vs mask

`clip-path` cuts with a hard edge; `mask` can fade with a gradient
(soft edges, partial transparency). Reach for `mask-image` when the
reveal should feather rather than wipe. For hit-testing note that
`clip-path` also clips pointer events — clicks outside the clip pass
through.

## Reduced motion (covers every recipe here)

A wipe is movement. Under `prefers-reduced-motion`, swap wipes for
short opacity fades (scroll reveals, tabs) or apply the
end state instantly. Two exceptions: the hold-to-delete fill stays —
it is time-as-progress feedback, not decoration — and drag-driven
clips (comparison sliders) stay 1:1 with the pointer because they are
direct manipulation. Specifics in [accessibility](accessibility.md).
