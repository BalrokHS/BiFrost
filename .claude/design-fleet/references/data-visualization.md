
# Design Fleet -- Data visualization

Read the [Fleet policy](../../policy.md) for instruction precedence, existing authorization, interaction defaults, and evidence requirements.

Rules for charts, tables, and any component that communicates data visually. The goal is clarity: maximize the data, minimize the decoration.

## Charts

- `dataviz-reduce-gridlines` -- Remove gridlines by default. A hover or keyboard-focus line can handle precise reading; provide a touch detail view. The default state should be calm. If gridlines are necessary, use faint dotted lines at wide intervals, never on every tick.
- `dataviz-sparse-axis-labels` -- Show 4-6 axis labels across the range, not one per data point. Dense labels compete with the data. The user reads the trend, not individual ticks.
- `dataviz-color-from-palette` -- Chart colors must come from the product's palette, not from the charting library's defaults. An arbitrary blue or green breaks the system feel. Align the chart line/fill with the metric's assigned color.
- `dataviz-trend-over-scaffolding` -- Emphasize the data line/bars, de-emphasize everything else. Axis lines, labels, and legends should be lighter than the data itself. The chart's structure is scaffolding: it supports the trend, not the other way around.
- `dataviz-no-chartjunk` -- Remove 3D effects, gradient fills, decorative borders around chart areas, drop shadows on bars, and background patterns. If it doesn't encode data, it's noise.
- `dataviz-area-fill-subtle` -- Area fills under line charts should be low opacity (0.05-0.15). The line communicates the trend; the fill provides context. Heavy fills dominate the chart.

## Tables

- `dataviz-earn-every-column` -- Every column must earn its place. If a column repeats information available elsewhere on the page, or if its values are uniform across rows, remove it. Fewer columns = faster scanning.
- `dataviz-icons-with-labels` -- When table columns map to metrics already represented by icons elsewhere (scoreboard, nav, legend), put the same icon beside the column's text label. The icon reinforces the visual vocabulary; the text stays the header's accessible name. In a tight column, keep the label as visually hidden text, never the icon alone.
- `dataviz-visual-encoding-over-widgets` -- Prefer ambient visual encoding (background intensity, font weight, subtle color shifts) over explicit widgets (progress bars, sparklines, badges) when communicating relative values. A row with a slightly tinted background communicates "this performed better" without adding UI elements. Reserve widgets for when the user needs precise values.
- `dataviz-favicon-over-domain` -- When showing links or external sources, use favicons instead of domain text. Favicons are recognizable at a glance; "theverge.com" takes a full read. Provide the domain through an accessible name and a keyboard/touch-accessible detail view; a hover tooltip can supplement it.
- `dataviz-row-padding-consistency` -- All rows in a table share the same vertical padding. Match the table's overall height to adjacent components when they sit side by side.

## Numbers

- `dataviz-tabular-nums-always` -- Data tables, scoreboards, and dashboards always use `font-variant-numeric: tabular-nums`. Fixed-width digits align in columns.
- `dataviz-abbreviate-large-numbers` -- Show "1.4K" not "1,426" when the exact value doesn't matter. Show the precise value on hover and keyboard focus, with a tap-accessible or persistent detail view. Abbreviation reduces cognitive load.
- `dataviz-percentage-one-decimal` -- Percentages get one decimal place maximum (63.9%, not 63.912%). More precision than users need is noise.

## Visual encoding hierarchy

When choosing how to communicate data, follow this priority:

| Priority | Encoding | Best for |
|----------|----------|----------|
| 1 | Position (bar height, line position) | Comparing exact values |
| 2 | Length (bar width, progress fill) | Showing proportions |
| 3 | Color intensity (background tint) | Showing relative performance across rows |
| 4 | Font weight (bold vs regular) | Highlighting key values inline |
| 5 | Size (number scale, icon size) | Showing magnitude |
| 6 | Shape (icons, badges) | Categorizing, not quantifying |

Higher-priority encodings are more accurately perceived by users. Use the highest-priority encoding that fits the context.

## Interaction

- `dataviz-hover-reveals-detail` -- Charts may show precise values on hover with a tooltip or crosshair. Also expose values through keyboard focus and a touch-accessible detail view or data table. Keep essential labels visible.
- `dataviz-clickable-rows` -- A table row that opens an item (an edition, a link, a user) puts a real link in its primary cell and stretches that link's hit area over the row with a pseudo-element, with a subtle hover background. Never `onClick` on the `<tr>` alone: it has no keyboard path and no accessible name.
