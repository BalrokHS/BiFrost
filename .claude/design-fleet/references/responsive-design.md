
# Design Fleet -- Responsive design

Read the [Fleet policy](../../policy.md) for instruction precedence, existing authorization, interaction defaults, and evidence requirements.

How interfaces adapt to screens, input methods, and device capabilities. The house file carries three of these lines for every session: no hover-only actions, never disable zoom, adapt rather than remove.

## Basics a strong model already does

A cold model already does these (Fleet 11 run artifacts, 2 October 2026; the weakest measured rule since June). They stay here as reference.

- `responsive-mobile-first` -- The unqualified styles are the phone layout; `min-width` queries add to it as the screen grows. Exception: a `VISION.md` north star that declares the product desktop-first overrides this default.
- `responsive-content-driven-breakpoints` -- Don't chase device sizes. Start narrow, stretch until the design breaks, add a breakpoint there. Three breakpoints usually suffice.
- `responsive-container-over-viewport` -- Use container queries (`@container`) for component-level responsiveness. Viewport queries are for page layouts. A card in a sidebar adapts to its container, not the window.
- `responsive-detect-pointer` -- Use `@media (pointer: coarse)` for touch (larger padding, bigger targets) and `@media (pointer: fine)` for mouse and trackpad. Screen size doesn't tell you the input method.
- `responsive-detect-hover` -- Use `@media (hover: hover)` for hover effects. Touch devices can't hover; never rely on hover for function.
- `responsive-no-hover-only-actions` -- Never hide actions behind hover. Touch users will never discover them. Use hover to enhance, not to reveal.
- `responsive-safe-area-insets` -- Use `env(safe-area-inset-*)` for padding on phones with notches, rounded corners and home indicators.
- `responsive-viewport-fit-cover` -- Set `viewport-fit=cover` in the viewport meta tag to enable safe area insets.
- `responsive-adapt-dont-amputate` -- A phone gets every feature the desktop has. Rearrange, reflow or fold the interface away into menus and sheets; never drop a task because the screen is small.
- `responsive-navigation-stages` -- A common pattern, not a rule: a drawer on phones, a compact bar on tablets, full labels on desktop. Follow the project's own navigation first.
- `responsive-never-disable-zoom` -- Never ship `user-scalable=no`: people with low vision rely on zoom. When 200% zoom breaks the page, the layout is what needs fixing.

## Extra mile

What a strong model skips under build pressure. Measured probes decide which of these join the craft file that loads with the house file in every profile; until then they load here in the full profile and on demand in lean. Brackets give the count in the Fleet 11 run artifacts of 2 October 2026.

- `responsive-srcset-and-picture` -- Use `srcset` and `sizes` (width descriptors) for resolution switching; reach for `<picture>` with `<source media>` only for art direction (different crops), not for resolution. [the one line in this rule that measured a gain]
- `responsive-auto-fit-min` -- Write an auto-fit grid as `minmax(min(Npx, 100%), 1fr)`, so a column never overflows a screen narrower than N. [0 of 6 bare grids]
- `responsive-table-semantics` -- A table that reflows on a narrow screen keeps its semantics: when its parts become stacked blocks with `data-label` captions, restore `role="table"`, `row` and `cell`, or render a real list. Horizontal scroll with a sticky first column often reads better for data. [both reflowed tables dropped their semantics, 0 of 2]
- `responsive-hover-by-capability` -- Decide hover reveals by `(hover: hover)` and `(any-pointer: coarse)`, never by viewport width: a touch tablet wider than a breakpoint still cannot hover. [one width-gated reveal hid Remove on touch tablets; `any-pointer` in 0 of about 100 units]
- `responsive-dynamic-viewport` -- Use `dvh` or `svh` for a full-height layout, with `100vh` only as a fallback. [0 of 9 applicable cold units]
- `responsive-field-size` -- Keep input, select and textarea text at 16px or more on touch screens. [15 fields under 16px, 0 with a touch override]
- `responsive-overscroll` -- A scrolling drawer, sheet or modal sets `overscroll-behavior: contain`, so its end does not scroll the page behind. [0 of 3 bare drawers]
- `responsive-check-320` -- When a layout is done, check it at 320px wide: no sideways scroll, nothing clipped. [probe pending]
