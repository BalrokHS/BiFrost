
# Design Fleet -- Visual design

Read the [Fleet policy](../../policy.md) for instruction precedence, existing authorization, interaction defaults, and evidence requirements.

The rules that separate considered interfaces from default ones. Apply when writing any visual CSS.

> **Enforced deterministically:** the design lint catches V1 (pure black shadows) in CSS, inline styles and Tailwind shadow classes, V7 (off-scale px spacing) in CSS, inline styles and Tailwind arbitrary values such as `p-[23px]`, and T1 (Roboto, Arial, Open Sans or Lato as the primary font), and warns on V5 (pure `#000`/`#fff` defaults), V10 (indigo-to-pink AI gradient) and T5 (Inter and burned display fonts). Tailwind scale classes such as `p-5` are checked only by S1, with a contract that has a spacing table. Values VISION.md declares, and fonts the project already uses, are not flagged. These are variance-class rules, known but slipped under build pressure; the lint is the backstop, not an excuse to skip them.

## Border radius

- `visual-concentric-radius` -- Inner radius = outer radius minus padding. Same radius on nested elements creates uneven curves.

## Shadows

- `visual-layered-shadows` -- Build a shadow from several: each next one wider in blur and fainter in opacity. One shadow alone looks pasted on.
- `visual-shadow-direction` -- All shadows share the same offset direction (single light source). Mixed directions feel broken.
- `visual-no-pure-black-shadow` -- Tint shadows with the palette's dark neutral; pure black reads as dirt. `rgba(17, 24, 39, 0.08)` over `rgba(0, 0, 0, 0.25)`.
- `visual-shadow-matches-elevation` -- Larger blur and offset = higher elevation. Use a consistent shadow scale (`--shadow-1`, `--shadow-2`, `--shadow-3`).
- `visual-animate-shadow-pseudo` -- Never transition `box-shadow` directly. Animate opacity on a pseudo-element with the target shadow instead.
- `visual-shadow-not-clipped` -- A shadow paints *outside* the element's border box, so an ancestor with `overflow: hidden` (or `clip`/`auto`/`scroll`) **amputates it**. This is a variance-class bug: `overflow-hidden` gets added reflexively to round a child's corners or make a scroll area, silently cutting the shadow of everything inside. Separate the clip from the shadow — never put both jobs on the same boundary.

```jsx
/* Incorrect: the rounding wrapper clips the card's shadow */
<div className="rounded-2xl overflow-hidden">
  <Card className="shadow-lg" />        {/* shadow cut at the wrapper edge */}
</div>

/* Correct: outer carries shadow + radius (NO overflow); inner clips */
<div className="rounded-2xl shadow-lg">
  <div className="rounded-2xl overflow-hidden"><img /></div>
</div>
```

Other fixes by cause: if nothing actually needs clipping, drop `overflow-hidden`; for a scroll area, pad the scroll container by ≥ the shadow's reach (blur + spread + offset) so the shadow lands inside the clip box. Reliable detection is at runtime (rendered bounds vs the clipping ancestor) — catch it in the live preview, not by eye.

```css
/* Incorrect: single pure-black shadow */
box-shadow: 0 4px 8px rgba(0, 0, 0, 0.25);

/* Correct: layered, tinted, increasing blur / decreasing opacity */
box-shadow:
  0 1px 2px rgba(15, 23, 42, 0.06),
  0 4px 8px rgba(15, 23, 42, 0.08),
  0 12px 24px rgba(15, 23, 42, 0.05);
```

## Spacing

- `visual-consistent-spacing-scale` -- Every gap and padding comes from one scale (4, 8, 12, 16, 24, 32, 48, 64), never a one-off pixel value. Without a contract, V7 flags px values off this set; a VISION.md spacing table replaces it.

```css
/* Incorrect: off-scale value */
padding: 13px;

/* Correct: nearest step on the scale */
padding: 12px; /* or 16px */
```

## Borders

- `visual-border-alpha-colors` -- Semi-transparent borders (an alpha step such as Radix's `--gray-a4`) adapt to any background. Hardcoded hex borders break on theme changes. Reuse the project's border token first.
