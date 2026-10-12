# Materials and depth (translucency)

Translucent materials as a functional layer: chrome that floats over content instead of consuming a fixed strip, with material weight encoding hierarchy. Web implementation of Apple's materials system via `backdrop-filter`.

---

## When not to use this

Materials are an **aesthetic commitment, not a default**. Skip this file when:

- The design system is flat and opaque (shadcn/ui's default look, most admin and dashboard systems): translucency fights the system. Solid surfaces and the shadow scale in the visual-design rule are the house style.
- The taste profile or `VISION.md` doesn't call for depth or glass. The contract wins; don't introduce a signature technique the contract doesn't declare.
- Performance budgets are tight: `backdrop-filter` blur is expensive, especially in Safari. Every blurred layer is a compositing cost.

Reach for it when the direction is explicitly layered or glassy (media, creative tools, iOS-adjacent aesthetics), then commit to it coherently.

## The core pattern

Let the page scroll *under* nav bars, toolbars and sheets, and make those surfaces see-through, instead of solid bars that take a fixed slice of the screen:

```css
.toolbar {
  background: rgba(255, 255, 255, 0.6);
  backdrop-filter: blur(20px) saturate(180%);
  border-top: 1px solid rgba(255, 255, 255, 0.4); /* bright edge = light catching the material */
}
```

The `saturate()` boost keeps colours under the glass alive instead of milky.

## Weight and depth

A surface's material tells people what kind of thing it is.

| Surface | Material | Why |
|---|---|---|
| Sidebar, backdrop, app frame | Dense and dark | It holds the page together and should stay out of the way |
| Button, chip, popover | Light and clear | It is something to press, so it should catch the eye |
| Large sheet or panel | More blur, a deeper shadow | Size reads as thickness, so a big pane gets more of both than a small chip |

- **Never put one light glass layer on top of another**: the text on them turns to mush.
- Where you can, let the shadow follow what sits underneath: stronger over text and busy content, softer over a plain fill.

## Focus or flow

Decide first whether the new surface interrupts the person or works beside them.

- **It interrupts** (confirm, sign in, a form that must finish): darken the page behind it and let the page sink slightly.
- **It works beside them** (inspector, filters, a chat pane): no darkening. Offset it and let the page show through, so they keep their place.
- **Sheets on sheets**: each new sheet darkens and sinks the one under it a little more, so the stack is readable at a glance.
- Moving layers keep their order while they move: a closing menu slides under the sticky header, never over it, and the dark layer of a dialog stays between the page and the dialog for the whole transition.

## Vibrancy: text over glass

Text over a translucent surface sits over unpredictable content. Flat grey text dies here:

- Raise contrast and step the weight up slightly; add a small letter-spacing bump on small text.
- Put **colour on a solid layer, never the translucent foreground**: a coloured button on glass gets a solid fill.

## Soft edges instead of divider lines

Where a sticky header floats over the page, skip the 1px border. Show a short fade at the header's lower edge, and only while content is actually passing beneath it. This is chrome answering the scroll position, not a scroll animation, so it is the one scroll-linked effect product UI allows.

```css
.header::after {
  content: "";
  position: absolute; inset: auto 0 -12px 0; height: 12px;
  background: linear-gradient(var(--color-surface), transparent);
  opacity: var(--scrolled, 0);           /* set to 1 by a scroll listener once content passes under */
  transition: opacity 200ms ease;
  pointer-events: none;
}
```

Chromium can toggle this without script through scroll-state container queries (Chrome 133 and later; not yet in Safari or Firefox, per web-features 3.40.1, checked 3 October 2026), so keep the script path as the fallback.

## Materialize, don't just fade

A glass surface entering the screen should read as a *material arriving*: animate a small blur and scale together with opacity, not a plain opacity fade. Keep animated blur in the 2-5px band ([performance](performance.md)), even when the resting material uses a 20px blur: fade the surface in on its final blur and animate only a light extra blur on the content. Exit reverses the same path.

## Accessibility: three independent signals

Materials respond to all three; bake them into the component, not the page:

```css
@media (prefers-reduced-transparency: reduce) {
  .toolbar { background: var(--color-surface); backdrop-filter: none; }
}
@media (prefers-contrast: more) {
  .toolbar { background: var(--color-surface); border: 1px solid var(--color-border-strong); }
}
@media (prefers-reduced-motion: reduce) {
  .sheet { transition: opacity 200ms ease; } /* only opacity animates; the transform change lands at once */
}
```

- `prefers-reduced-transparency` is Chromium only: Safari, whose own setting it mirrors, does not support the query (web-features 3.40.1, checked 3 October 2026). Pair it with `prefers-contrast` and make sure the solid fallback is what a browser without support can reach.
- Under reduced motion, swap the movement for a fade. Never `transform: none !important`: a closed sheet that rests off screen at `translateY(100%)` would be pinned into view.

Contrast floors still apply *over the worst-case background* the glass can sit on: test text over the busiest content that can scroll beneath, not over the empty state. Ratios are in the color-contrast rule; dark-mode elevation by lightness (see [color-and-contrast](color-and-contrast.md)) composes with materials: higher glass gets a lighter tint, same rule.
