# Responsive design

The responsive-design rule holds the strategy: mobile first, breakpoints where the content breaks, container queries for components, never a hover-only action, never disabled zoom. This file keeps the details that go wrong in code.

## Grids that never scroll sideways

```css
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(280px, 100%), 1fr));
  gap: var(--space-md);
}
```

The `min(280px, 100%)` matters: a bare `minmax(280px, 1fr)` overflows a 320px phone once the page has gutters. Use it for collections that really are uniform; a page built from identical cards is the stock look the fleet avoids.

## Components follow their container

```css
.card-slot { container-type: inline-size; }

@container (min-width: 400px) {
  .card { grid-template-columns: 120px 1fr; }
}
```

In Tailwind v4, mark the parent `@container` and style children with `@md:` and friends ([Tailwind responsive design](https://tailwindcss.com/docs/responsive-design), checked 3 October 2026).

## Hybrid devices

`pointer` and `hover` describe only the primary input. A tablet with a trackpad, or a laptop with a touch screen, needs `any-pointer`: size targets up when any input is coarse.

```css
@media (any-pointer: coarse) {
  .toolbar-button { min-block-size: 44px; }
}
```

Keep hover effects behind `(hover: hover)`, which follows the primary input.

## Full-height layouts and safe areas

- Use `100dvh` (or `svh` for the smallest viewport) instead of `100vh`, which hides content behind a phone's browser bar. The units work in every major browser since December 2022 (web-features 3.40.1, checked 3 October 2026).
- Apply each `env(safe-area-inset-*)` once, on the element that touches that edge. Padding the body and a footer inside it adds the bottom inset twice. Safe areas also need `viewport-fit=cover` in the viewport meta.

## Images

Give every image its `width` and `height` (or an `aspect-ratio`) so the page does not jump when it loads, and a `sizes` value that matches the layout. In Next.js, `next/image` does both.

## Tables on small screens

Prefer a horizontal scroll container with the first column sticky. Restyling table elements with `display: block` or `grid` removes their table semantics in some browsers, so a screen reader no longer hears rows and headers ([Adrian Roselli, tables and CSS display](https://adrianroselli.com/2018/02/tables-css-display-properties-and-aria.html), checked 3 October 2026). If rows must restack as cards, put the roles back explicitly (`role="table"`, `row`, `columnheader`, `cell`) and keep each value's label visible.
