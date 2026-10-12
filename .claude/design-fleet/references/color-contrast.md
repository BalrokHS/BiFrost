
# Design Fleet -- Color and contrast

Read the [Fleet policy](../../policy.md) for instruction precedence, existing authorization, interaction defaults, and evidence requirements.

Every color must have a job. Directives only; the theory is in the weights. In an existing product, reuse its tokens and redefine only the semantic layer; a color it lacks is a proposal (house file).

## Color space

- `color-use-oklch` -- Build palettes in OKLCH, not HSL.
- `color-reduce-chroma-at-extremes` -- Reduce chroma as lightness approaches white or black.

## Palette structure

- `color-tint-your-neutrals` -- Add a hint of brand hue to all grays (chroma 0.005-0.01 in OKLCH).
- `color-no-pure-black-or-white` -- No `#000`/`#fff` as defaults: tint, even subtly. A white the project declares, such as white cards floating on a tinted ground, is a choice, not a default. Exception: forced-colors and high-contrast modes, where pure values are required.
- `color-60-30-10` -- For a new palette, split by area: about 60% neutral ground and empty space, about 30% supporting colour for text, borders and idle states, and about 10% accent, kept for the main action, focus rings and highlights.
- `color-one-accent-is-enough` -- One accent color; add secondary/tertiary accents only when genuinely needed.
- `color-semantic-roles` -- A new palette needs: primary (brand, CTAs), neutral (text, backgrounds, borders: 9-11 shades), semantic (success, error, warning, info: 2-3 shades each), surface (cards, modals: 2-3 elevation levels). An existing palette keeps the roles it has; propose a missing one, never scaffold a scale.

## Contrast and accessibility

- `color-wcag-body-text` -- Body text: 4.5:1 minimum (AA), target 7:1 (AAA).
- `color-wcag-large-text` -- Large text (at least 18pt regular = 24 CSS px, or 14pt bold = 56/3 CSS px, approximately 18.7px): 3:1 minimum. Smaller text needs 4.5:1 for AA. See [WCAG G18](https://www.w3.org/WAI/WCAG22/Techniques/general/G18.html).
- `color-wcag-ui-components` -- UI components and icons: 3:1 minimum against adjacent colors.
- `color-placeholder-needs-contrast` -- Placeholders still need 4.5:1; the usual light gray fails.
- `color-hk-white-on-saturated` -- Saturated fills (vibrant buttons/badges) look brighter than their measured luminance (the Helmholtz-Kohlrausch effect, strongest in blues, reds and magentas; see [CIE 2025](https://doi.org/10.25039/x051.2025/54p79z)), so white text on them has less perceived contrast than its ratio, and dark text more. For white on a saturated fill, treat 4.5:1 as the floor: darken the fill until the white clears it with room to spare.
- `color-fluorescent-zone` -- Above OKLCH lightness ~0.78, cap chroma at ~0.18; high-lightness, high-chroma colors read as fluorescent and toy-like.
- `color-accent-separation` -- Primary and accent must be distinguishable: at least ~1.7:1 contrast between them, or they read as one muddled brand color.

## Dangerous combinations

- `color-no-gray-on-color` -- Never gray text on a colored background. Use an opaque light or dark shade of the background's own hue, and check the ratio.
- `color-no-red-on-green` -- Never red and green as the sole differentiator; about 8% of men can't tell them apart.
- `color-no-yellow-on-white` -- Yellow text on white almost always fails contrast.
- `color-no-thin-text-on-images` -- No thin light text over images. Add a scrim (gradient overlay) or a solid background.

## Dark mode

- `color-dark-not-inverted` -- Design the dark theme on its own terms. Flipping the light theme's values gives muddy surfaces and glaring accents.
- `color-dark-elevation-by-lightness` -- Depth comes from lighter surfaces, not shadows. Higher elevation = lighter background.
- `color-dark-desaturate-accents` -- Slightly desaturate accent colors in dark mode.
- `color-dark-reduce-font-weight` -- Reduce font weight by one step in dark mode (400 to 350 for variable fonts; for static fonts step to the next lighter named weight, e.g. 300).
- `color-dark-never-pure-black-bg` -- Dark backgrounds are dark gray (OKLCH lightness 12-18%), not `#000`.

## Token architecture

- `color-two-layer-tokens` -- Keep two layers of tokens: raw values (`--blue-500`) and tokens named by role that point at them (`--color-primary: var(--blue-500)`). The dark theme changes only the role layer.
