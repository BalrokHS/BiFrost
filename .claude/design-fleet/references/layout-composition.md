
# Design Fleet -- Layout composition

Read the [Fleet policy](../../policy.md) for instruction precedence, existing authorization, interaction defaults, and evidence requirements.

How components relate to each other on a page. These rules govern the space between things, not the things themselves.

## Sibling consolidation

- `layout-merge-related-siblings` -- When two or more components show closely related data (scoreboard + chart, stats + timeline, filters + results), merge them into one visual block. Four cards competing for attention is worse than one integrated section with four values.
- `layout-no-redundant-headers` -- If a section title repeats information already visible in its content, remove the title. "Edition performance" above a table whose first column says "Edition #1, #2, #3" is redundant. "Performance" is enough.
- `layout-inline-supporting-values` -- Move secondary metrics inline with their labels instead of stacking vertically. "1,800 (1,525 active)" reads faster than a label above a number above a subtitle.

## Layout rhythm

- `layout-equal-sibling-gaps` -- Adjacent sections at the same hierarchy level must share the same gap. If two tables sit side by side with 16px between them, the gap between the chart and the tables must also be 16px. Uneven gaps break the grid.
- `layout-match-sibling-heights` -- Side-by-side components should match height when possible. Mismatched heights create visual instability. Pad the shorter sibling or let it stretch to align.
- `layout-vertical-compression` -- Dashboards, admin panels and data-heavy screens people use all day benefit from compact vertical space. Elsewhere follow the project's own rhythm: a calm, spacious product stays spacious. Density follows how often people visit, not a default.

## Visual primitive reuse

- `layout-shared-icon-vocabulary` -- Establish 4-6 icons from the project's icon library and reuse them everywhere. If the scoreboard uses a people icon for subscribers, the table header can carry the same icon beside its text label. An icon alone is not an accessible name. A small, repeated icon set unifies the interface faster than any other technique.
- `layout-shared-color-meaning` -- Each color must mean one thing across the entire page. If red means clicks in the chart, red means clicks in the table. Never assign the same color to different metrics in different components.
- `layout-few-visual-elements` -- A considered page uses 3-4 colors, 4-6 icons, 2-3 font sizes (drawn from the type scale, which holds up to 5; see `typography`), and one spacing rhythm. More than that and the composition fragments. Constraint creates cohesion.

## Typographic roles

- `layout-display-type-sparingly` -- Reserve display/serif/decorative typefaces for the page title only. Section headers, card titles, and table headers use the body sans. When every header is a display moment, none of them are special.
- `layout-label-hierarchy` -- Three levels of text are enough for most screens: title (large, display), section header (medium, sans bold), body/data (regular, sans). If you need more than three, the information architecture is too complex for one screen.

## Information density

- `layout-density-matches-context` -- Dashboards and admin screens should feel dense and efficient. Marketing pages and onboarding should feel spacious and guided. Match density to how often the user visits this screen.
- `layout-progressive-detail` -- Show the summary first, reveal the detail on interaction. A row's background intensity can communicate relative performance; no need for inline progress bars when the pattern is obvious.
