# Practical animation tips

Small recipes for the moments that come up in every interface. Every recipe here follows [accessibility](accessibility.md) for reduced motion: movement goes, opacity and colour fades may stay. Numbers come from the interaction-feedback rule and [timing-and-duration](timing-and-duration.md).

## Press feedback

A press answers with a small scale on the house press curve: `ease-out`, at most 150ms, transform only.

```css
button {
  transition: transform 150ms ease-out;
}

button:active {
  transform: scale(0.97);
}

/* Keyboard presses show instantly */
button:focus-visible {
  transition: none;
}
```

Keep any squash or stretch within 0.95 to 1.05; past that, an interface starts to look cartoonish.

Brief pointer or touch press feedback up to 150ms may stay on frequent actions as long as it adds no delay; keyboard actions stay immediate, and non-essential movement goes under reduced motion ([Fleet interaction policy](../../../policy.md#interaction-defaults)).

## A one-pixel jump when a transform starts or stops

A transform animation can jump by a pixel as it starts or ends, when the browser hands the element between rendering paths. Promote that one element for the duration:

```css
.element {
  will-change: transform;
}
```

This is one of the two sanctioned uses of `will-change` in [performance](performance.md); it is a fix for an observed shift, never a default.

## Never enter from scale(0)

Something growing out of nothing looks wrong. Start close to full size, with a fade:

**Bad:**

```css
.element {
  transform: scale(0);
}
.element.visible {
  transform: scale(1);
}
```

**Good:**

```css
.element {
  transform: scale(0.95);
  opacity: 0;
}
.element.visible {
  transform: scale(1);
  opacity: 1;
}
```

The starting scale grows with the element: 0.95 is the house UI entrance, and a large floating surface starts nearer 1, about `scale(0.98)` for a panel the size of a nav menu.

## Tooltips and popovers

### Instant after the first tooltip

The first tooltip waits and animates. While one is open, moving to the next shows it at once.

```css
.tooltip {
  transition:
    transform 125ms ease-out,
    opacity 125ms ease-out;
  transform-origin: var(--transform-origin);
}

.tooltip[data-starting-style],
.tooltip[data-ending-style] {
  transform: scale(0.97);
  opacity: 0;
}

.tooltip[data-instant] {
  transition-duration: 0ms;
}
```

`data-instant`, `data-starting-style` and `data-ending-style` are Base UI's tooltip attributes ([Base UI tooltip](https://base-ui.com/react/components/tooltip), checked 3 October 2026). Base UI keeps the popup mounted until its running animations finish (it checks `element.getAnimations()`, which includes CSS transitions), which is what gives `[data-ending-style]` a frame to run at all ([Base UI animation](https://base-ui.com/react/handbook/animation), [MDN getAnimations](https://developer.mozilla.org/en-US/docs/Web/API/Element/getAnimations), checked 3 October 2026). Radix has no `data-instant`; its tooltip content reports `[data-state="instant-open"]` instead ([Radix tooltip](https://www.radix-ui.com/primitives/docs/components/tooltip), checked 3 October 2026).

### Scale from the trigger

A popover grows out of the control that opened it, not out of its own centre. Each library exposes the origin as a variable:

```css
.popover {
  transform-origin: var(--transform-origin); /* each Base UI positioned popup sets it */
}
```

Radix names one per component: `--radix-dropdown-menu-content-transform-origin`, `--radix-popover-content-transform-origin`, `--radix-tooltip-content-transform-origin` ([Radix tooltip](https://www.radix-ui.com/primitives/docs/components/tooltip), checked 3 October 2026).

## Speed

A quicker spinner makes the same wait feel shorter, and a 180ms select feels more responsive than a 400ms one. UI animations stay under 300ms.

Keyboard work gets no animation at all: arrow-key moves through a list, shortcut results, Tab and focus moves. People repeat these hundreds of times a day, so any duration is lag. An indicator must still follow keyboard focus (that is accessibility), but the move itself is instant: branch to `{ duration: 0 }` and keep the animation for pointer-driven moves.

Hover effects on something used all day are worth removing too. Use the product daily; the motion that starts to grate is the motion to cut.

## Enter with @starting-style

The CSS way to animate an element's first render, with no `useEffect(() => setMounted(true))`:

```css
.toast {
  transform: none;
  opacity: 1;
  transition: transform 200ms ease-out, opacity 200ms ease-out;

  @starting-style {
    opacity: 0;
    transform: translateY(100%);
  }
}
```

`@starting-style` is Baseline since August 2024 (web-features 3.40.1, checked 3 October 2026). Where support is missing, set a `data-mounted` attribute after the first render and key the transition off it.

## Transitions, not keyframes, for bursty UI

A CSS transition can change target halfway and carry on from where the element is; a `@keyframes` animation starts again from its first frame. Toasts arriving in bursts, fast toggles and items added in quick succession flash and restart with keyframes and stay smooth with transitions. Keep keyframes for fixed sequences nobody interrupts: loaders, marquees, one-shot reveals.

## Hover

### A moving hover target flickers

If the hover effect moves the element, the cursor can fall off it, the hover ends, the element moves back, and it flickers.

**Problem:**

```css
.tile:hover {
  transform: translateY(-20%);
}
```

**Solution:** move a child and keep the hovered parent still.

```html
<div class="tile">
  <div class="tile-body"></div>
</div>
```

```css
.tile-body {
  transition: transform 150ms ease;
}

.tile:hover .tile-body {
  transform: translateY(-20%);
}
```

### Hover only where hover exists

A tap on a touch screen triggers `:hover` and leaves it stuck. Wrap hover effects in a media query:

```css
@media (hover: hover) and (pointer: fine) {
  .tile:hover {
    /* hover scale cap: 1-2% — scale(1.02); scale(1.05) is the anti-value */
    transform: scale(1.02);
  }
}
```

Tailwind v4 already wraps every `hover:` utility in `@media (hover: hover)` ([Tailwind states](https://tailwindcss.com/docs/hover-focus-and-other-states), checked 3 October 2026). On v3, opt in:

```js
// tailwind.config.js
module.exports = {
  future: { hoverOnlyWhenSupported: true },
};
```

### Information on hover needs a keyboard path

When hover reveals something people need (row actions, help text, a preview), give keyboard users the same reveal with `:focus-visible`, or `:focus-within` when the reveal lives on a container:

```css
.row:hover .row-actions,
.row:focus-within .row-actions {
  opacity: 1;
}
```

Use `:focus-visible`, not `:focus`: `:focus` also matches after a mouse click and leaves a stuck reveal. Purely decorative flourishes, such as a hover scale, stay pointer-only; a keyboard focus move never animates.

## Hit areas

Small controls are hard to hit. Grow the hit area with a pseudo-element and leave the layout alone.

**Target size:** WCAG 2.2 AA asks for at least 24 by 24 CSS px
([SC 2.5.8, W3C](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html)).
44 by 44 is WCAG AAA
([SC 2.5.5, W3C](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html))
and, in points, the default control size in Apple's HIG for iOS and iPadOS
([Apple HIG accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)),
all checked 3 October 2026. The fleet uses 44px on touch and 32px with a
pointer (`states-target` in the interaction-feedback rule).

```css
@utility touch-hitbox {
  position: relative;

  &::before {
    content: "";
    position: absolute;
    display: block;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 100%;
    height: 100%;
    min-height: 44px;
    min-width: 44px;
  }
}
```

The pseudo-element is nested inside the one `@utility` block: Tailwind v4
defines anything more complex than a single class by nesting, and
`@utility touch-hitbox::before` is not a valid utility name
([Tailwind adding custom styles](https://tailwindcss.com/docs/adding-custom-styles),
checked 3 October 2026). It needs no `z-index`: the pseudo-element is
part of the button, so its hits already go to the button, and a high
`z-index` would lift the hit area over menus and popovers that overlap it.

Usage, with the icon from the project's icon library (lucide-react here):

```jsx
import { Bell } from "lucide-react";

<button type="button" className="touch-hitbox" aria-label="Notifications">
  <Bell aria-hidden="true" />
</button>
```

## Pseudo-elements: three things that bite

- `::before` and `::after` render nothing without `content: ""`, and an absolutely positioned one needs a positioned parent ([MDN pseudo-elements](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Selectors/Pseudo-elements), checked 3 October 2026).
- To paint one behind the element's text, give the parent `isolation: isolate` and the pseudo-element `z-index: -1`. That makes a stacking context without joining the page's z-index contest.
- `::backdrop` styles a dialog's scrim but does not close the dialog on a click. `closedby="any"` adds that in Chromium and Firefox, not Safari (web-features 3.40.1, checked 3 October 2026), so keep a close button.

## Easing in one line each

- Entering or leaving: `ease-out`, so the response starts at once.
- Moving something already on screen: `ease-in-out`.
- Hover and colour: `ease`.
- For deliberate motion, pick a named curve from [easing-curves](easing-curves.md) over a built-in keyword.

## Blur as a bridge

When a crossfade still reads as two objects swapping, whatever the curve, a light blur on both layers makes the eye see one thing changing. Put it on the two layers that crossfade, never on a label people need to read and never on a press. Here a copy icon swaps to a check in one grid cell:

```css
.icon-swap {
  display: grid;
}

.icon-swap > * {
  grid-area: 1 / 1;
  transition:
    opacity 150ms ease-out,
    filter 150ms ease-out;
}

.icon-swap > [data-hidden] {
  opacity: 0;
  filter: blur(2px);
}
```

Keep animated blur small, 2px here and never above 20px, and test it in Safari, where blur costs most.

## Unseen details add up

Each detail here is too small to notice alone. Together they make an interface that feels right without anyone knowing why, and that is the goal: people finish the task, they do not admire the animation.
