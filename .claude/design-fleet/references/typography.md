
# Design Fleet -- Typography

Read the [Fleet policy](../../policy.md) for instruction precedence, existing authorization, interaction defaults, and evidence requirements.

Rules for typographically considered interfaces. Apply when setting any font or text property. A family the project already uses wins over every suggestion here.

## Sizing and scale

- `type-fluid-headings` -- Use `clamp(min, preferred, max)` for headings on marketing/content pages, e.g. `clamp(2rem, 5vw + 1rem, 4rem)`. Include a rem offset so text doesn't collapse to zero on small screens.
- `type-fixed-rem-for-apps` -- Use fixed `rem` scales for app UI, dashboards, and data-dense interfaces. No major design system uses fluid type in product UI.
- `type-fewer-sizes-more-contrast` -- 5 sizes maximum *in the scale*: xs (captions), sm (metadata), base (body), lg (subheadings), xl+ (headlines) — and any single screen uses only 2-3 of them (see `layout-composition`). Not 14/15/16/18px — near-identical sizes make muddy hierarchy.
- `type-measure-in-ch` -- `max-width: 65ch` for readable line lengths. Narrow columns need tighter leading, wide columns more.

## Font selection

- `type-avoid-invisible-defaults` -- For a new choice, avoid families that read as generic defaults: Roboto, Arial, Open Sans, Lato, Montserrat, Inter, and the burned tier of first-generation "alternatives" (see `type-better-alternatives`). `system-ui` is fine when the goal is the platform's own face. A family the project already uses is not a violation: keep it.
  Enforced: the deterministic lint flags Roboto/Arial/Open Sans/Lato as the primary family (T1), and warns on Inter and the burned display tier Montserrat/Fraunces/Newsreader/Space Grotesk/Instrument Serif (T5). `system-ui` is allowed. A family that VISION.md declares, or that the project's global styles or root layout already use as the primary family, is never flagged.
- `type-better-alternatives` -- Don't swap one default for another: the burned tier now includes not just Inter/Roboto but the first-generation alternatives — Fraunces, Newsreader, Space Grotesk, Instrument Serif — and any font you've recently seen across multiple AI-generated sites. Select by method, not by list: derive the pairing from the product's domain and era (a legal tool and a music app should not share a face); pick from broad foundry pools, not the same 10 Google Fonts; rotate choices across projects; and apply the recency test — "have I seen this exact font on AI-generated sites lately?" — if yes, it no longer differentiates. Exception: when the project's `VISION.md` locks font families, or the existing code already sets them, never introduce new families — work within what is there.
- `type-one-family-is-enough` -- One family in multiple weights beats two competing typefaces. Add a second font only for genuine contrast (display headlines + body serif).
- `type-never-pair-similar` -- Two typefaces that are close but not the same look like a mistake, not a pairing: never set two geometric sans-serifs side by side.
- `type-dark-mode-lighter-weight` -- Reduce font weight by one step in dark mode.

## Numeric formatting

- `type-tabular-nums-for-data` -- `font-variant-numeric: tabular-nums` for columns, dashboards, pricing.
- `type-oldstyle-nums-for-prose` -- `font-variant-numeric: oldstyle-nums` only in long-form editorial prose, in a face that has old-style figures. Product UI body text keeps the default lining figures.
- `type-slashed-zero` -- `font-variant-numeric: slashed-zero` in code-adjacent UIs.
- `type-proper-fractions` -- `font-variant-numeric: diagonal-fractions` for typographic fractions.

## OpenType features

- `type-opentype-contextual-alternates` -- Keep `font-feature-settings: "calt" 1` enabled.
- `type-disambiguation-stylistic-set` -- In code-facing UIs, enable the stylistic set that distinguishes I/l/1 and 0/O, where the font defines one. Set numbers are font-specific ([OpenType `ss01`-`ss20`](https://learn.microsoft.com/en-us/typography/opentype/spec/features_pt#tag-ss01---ss20)): it is `ss02` in [Inter](https://rsms.me/inter/), but check each font's feature list.

## Rendering

- `type-optical-sizing-auto` -- Leave `font-optical-sizing: auto` for size-adaptive glyph shapes.
- `type-antialiased-on-retina` -- Set `-webkit-font-smoothing: antialiased` and `-moz-osx-font-smoothing: grayscale` on body. Both act on macOS only.
- `type-no-font-synthesis` -- Set `font-synthesis: none` on display/icon fonts to prevent faux bold/italic.
- `type-font-display-swap` -- Use `font-display: swap` in `@font-face` so text renders immediately with fallback.

## Text wrapping

- `type-text-wrap-balance-headings` -- `text-wrap: balance` on headings.
- `type-text-wrap-pretty` -- `text-wrap: pretty` on body text to reduce orphans.
- `type-justify-with-hyphens` -- Pair `text-align: justify` with `hyphens: auto`, and set `lang` on the page: hyphenation needs to know the language.

## Spacing and decoration

- `type-underline-offset` -- `text-underline-offset: 3px` with `text-decoration-skip-ink: auto`.
- `type-letter-spacing-uppercase` -- Add `letter-spacing: 0.05em` to uppercase and small-caps text.
<!-- retired before admission: type-tracking-size-specific + type-leading-inverse-to-size
     (Wave-1 absorption) — cold baseline passed at 100% on the dedicated
     eval case (claude-opus-4-8, 2026-07-11). The model already applies size-specific
     tracking and inverse leading unprompted; per CONTRIBUTING.md's admission rule the
     rules never earned their tokens. See ABSORPTION.md. -->

- `type-variable-weight-continuous` -- A variable font takes any weight its `wght` axis covers (CSS accepts 1 to 1000): use `font-weight: 450` or `550`, not just standard stops.

## Quick reference

| Where | Set | What you get |
|-------|-----|--------------|
| Tables, prices, counters | `font-variant-numeric: tabular-nums` | Digits that line up in columns |
| Long editorial articles | `font-variant-numeric: oldstyle-nums` | Figures that sit with the lowercase letters |
| Code-facing screens | `font-variant-numeric: slashed-zero` | 0 and O told apart |
| Code-facing screens, Inter (the set number differs per font) | `font-feature-settings: "ss02"` | I, l and 1 told apart |
| Every text style | `font-optical-sizing: auto` | Letter shapes tuned to the size |
| Body text on macOS | `-webkit-font-smoothing: antialiased` | Lighter, crisper rendering |
| Headings | `text-wrap: balance` | Lines of similar length, no stranded word |
| Links | `text-underline-offset: 3px` | The underline clears g, j, p and y |
| Display and icon fonts | `font-synthesis: none` | No fake bold or italic drawn by the browser |
