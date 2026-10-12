# Colour and contrast

Reuse the project's tokens first; a missing colour is a proposal, never a new literal. Themes work in two layers: a raw palette, and semantic tokens (`--surface-1`, `--foreground`) that components use. Dark mode redefines only the semantic layer, on the selector the project already uses (`.dark` in shadcn and next-themes).

```css
:root {
  color-scheme: light; /* light-dark() follows color-scheme, so each theme sets it */
  --surface-1: oklch(98.5% 0.005 250); /* neutrals carry the brand hue at 0.005-0.01 chroma */
  --shadow-elevation-1: 0 1px 3px oklch(18% 0.01 250 / 0.08);
}
.dark {
  color-scheme: dark;
  --surface-1: oklch(16% 0.01 250); /* never pure black: lightness 12-18% */
  --shadow-elevation-1: none;       /* depth comes from lighter surfaces, not shadows */
}
```

- Work in OKLCH: equal lightness steps look equal. Lower chroma as a colour nears white or black.
- In dark mode, raised surfaces get lighter, accents lose about 0.03-0.05 chroma, and body text can drop to about weight 350 on a variable font, because light text on dark reads heavier.
- Set the theme on `<html>` before first paint, from the saved choice or `prefers-color-scheme`.
- No pure black or pure white as a default surface or text colour; tint them toward the palette. The exception is forced-colors (high contrast) mode, where the system's own colours apply.

Grey text on a coloured fill looks dead. Use a shade of the fill's own hue, and move the fill away from the middle: around 55% lightness, even white barely clears 4.5:1.

```css
/* GOOD: a light shade of the fill's hue on a darker fill */
.banner { background: oklch(47% 0.13 250); color: oklch(95% 0.02 250); } /* 5.91:1 */
/* ALSO GOOD: a pale fill with a dark shade of the same hue */
.notice { background: oklch(95% 0.02 250); color: oklch(40% 0.09 250); } /* 7.96:1 */
```

WCAG AA asks 4.5:1 for ordinary text and 3:1 for large text: at least 18pt regular (24 CSS px) or 14pt bold (56/3 CSS px, about 18.7px). Do not round the threshold down ([WCAG technique G18](https://www.w3.org/WAI/WCAG22/Techniques/general/G18.html)). Controls, their states and focus indicators need 3:1 against the colours next to them ([WCAG 2.2 SC 1.4.11, non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html), read 3 October 2026).

Three checks the ratio misses:

- **White on a saturated fill.** A saturated colour looks brighter than a grey of the same luminance (the Helmholtz-Kohlrausch effect, strong in blues, reds and magentas, weak in yellows; [Bhaumik and Leloup, CIE 2025](https://doi.org/10.25039/x051.2025/54p79z), checked 3 October 2026). A white label on it reads weaker than its ratio says; dark text reads stronger. Treat 4.5:1 as the floor and darken the fill until the label clears it with room.
- **The fluorescent zone.** Above OKLCH lightness about 0.78, keep chroma under about 0.18, or the colour reads as a highlighter.
- **Primary against accent.** Below about 1.7:1 between them, they blur into one brand colour.

```css
/* BAD: passes on paper, reads weak on the vivid fill */
.btn-primary { background: oklch(54.5% 0.13 250); color: oklch(97% 0.005 250); } /* 4.54:1 */
/* GOOD: the same hue a step darker gives the label room */
.btn-primary { background: oklch(46% 0.125 250); color: oklch(97% 0.005 250); } /* 6.54:1 */
```

Alpha is right where see-through is the point: borders that cross several surfaces, scrims, focus rings, hover tints. Text and solid surfaces stay opaque: their final colour depends on what sits behind them, so one contrast check proves nothing on the next background.
