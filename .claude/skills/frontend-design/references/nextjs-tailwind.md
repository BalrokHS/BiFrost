# Next.js and Tailwind

For Next.js App Router projects on Tailwind v4, usually with shadcn/ui. The project's own setup wins: read it before you write a class.

## Read the project first

- `app/globals.css`: the `@import "tailwindcss"` line, the `:root` and `.dark` variables, the `@theme inline` block. These are the tokens.
- `components.json` (shadcn): the style, which primitive library the components are built on (Base UI or Radix), and whether CSS variables are on.
- `components/ui/`: the components you extend. A new screen composes these; it never brings its own Card or Button.
- A `tailwind.config.js` in a v4 project does nothing unless the CSS loads it with `@config`, so never add one to hold tokens ([Tailwind upgrade guide](https://tailwindcss.com/docs/upgrade-guide)).

## Fonts with next/font

Load fonts through `next/font`, never a `<link>` tag or a CSS `@import`. Google Fonts come from `next/font/google`. A face that is not on Google Fonts (a licensed brand face, say) goes in the project and loads with `next/font/local`:

```tsx
import localFont from 'next/font/local';

const brandSans = localFont({
  src: [
    { path: '../fonts/BrandSans-Regular.woff2', weight: '400', style: 'normal' },
    { path: '../fonts/BrandSans-Medium.woff2', weight: '500', style: 'normal' },
    { path: '../fonts/BrandSans-Bold.woff2', weight: '700', style: 'normal' },
  ],
  variable: '--font-brand-sans',
  display: 'swap',
});
```

`next/font` already uses `font-display: swap`, so text shows in a fallback face at once and switches when the font arrives. A hand-written `@font-face` outside `next/font` needs `font-display: swap` itself.

Put the font's variable class on `<html>`, as create-next-app's root layout does ([Next.js fonts](https://nextjs.org/docs/app/getting-started/fonts)). Custom properties are inherited downwards only: a variable set on `<body>` is invisible to `html`, and Tailwind's preflight sets the page font on `html`.

```tsx
// app/layout.tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={brandSans.variable}>
      <body>{children}</body>
    </html>
  );
}
```

Then point `--font-sans` at that variable in `@theme inline`, under its own name:

```css
/* app/globals.css */
@theme inline {
  --font-sans: var(--font-brand-sans);
}
```

Preflight reads the page font from `--default-font-family`, which falls back to `--font-sans` ([preflight.css](https://github.com/tailwindlabs/tailwindcss/blob/main/packages/tailwindcss/preflight.css), [theme.css](https://github.com/tailwindlabs/tailwindcss/blob/main/packages/tailwindcss/theme.css)), so the whole page and every `font-sans` element get the face. The trap is a line that names itself. `--font-sans: var(--font-sans)` only works when the layout's variable is literally `--font-sans`; otherwise the value is invalid and the text drops to the browser default (Times in Chromium). A fresh create-next-app project after `shadcn init` has exactly this: shadcn 4.21.1 generates `--font-sans: var(--font-sans)` while the layout sets `--font-geist-sans`, and the page renders in the default font until the line reads `--font-sans: var(--font-geist-sans)` (rendered in Chromium 153 on create-next-app 16.3.8 output).

## Colour tokens: `:root` plus `@theme inline`

Colour tokens live in `app/globals.css`. Raw values sit on `:root`, dark values on `.dark`, and `@theme inline` maps each one into Tailwind's `--color-*` namespace, which is what makes `bg-*` and `text-*` utilities exist ([theme variables](https://tailwindcss.com/docs/theme)). This is the layout shadcn/ui generates ([shadcn Tailwind v4](https://ui.shadcn.com/docs/tailwind-v4), [shadcn theming](https://ui.shadcn.com/docs/theming)):

```css
/* app/globals.css */
@import "tailwindcss";

@custom-variant dark (&:is(.dark *));

:root {
  --background: oklch(0.97 0.003 286);
  --card: oklch(0.995 0.001 286);
  --foreground: oklch(0.141 0.005 286);
  --muted-foreground: oklch(0.54 0.016 286);
  --primary: oklch(0.21 0.006 286);
}

.dark {
  --background: oklch(0.141 0.005 286);
  --card: oklch(0.21 0.006 286);
  --foreground: oklch(0.985 0.002 286);
  --muted-foreground: oklch(0.705 0.015 286);
  --primary: oklch(0.92 0.004 286);
}

@theme inline {
  --color-background: var(--background);
  --color-card: var(--card);
  --color-foreground: var(--foreground);
  --color-muted-foreground: var(--muted-foreground);
  --color-primary: var(--primary);
}
```

- Name the raw variables without the `--color-` prefix (`--primary`, not `--color-primary`). `--color-*` is Tailwind's namespace, and `--color-primary: var(--color-primary)` would point at itself.
- Use the variables the file already has. A colour it lacks is a proposal (name, value, where it is used), not a new line you add.
- In components, write `bg-background`, `bg-card`, `text-muted-foreground`, `bg-primary`. Never raw `var()` in an inline style when a utility says the same thing.

## Extend `components/ui`, never fork it

shadcn components keep their variants in a `cva` call ([shadcn button source, base-nova style](https://ui.shadcn.com/r/styles/base-nova/button.json)). A new look is a new entry in that call, in that file. A second `Button` or `Card` beside the first one splits the system.

```tsx
// components/ui/button.tsx: one new entry in the existing cva call
import { cva } from "class-variance-authority";

const buttonVariants = cva(baseClasses, {
  variants: {
    variant: {
      default: "bg-primary text-primary-foreground hover:bg-primary/80",
      // ...the variants the file already has
      quiet: "bg-muted text-foreground hover:bg-muted/80",
    },
  },
  defaultVariants: { variant: "default" },
});
```

`baseClasses` stands for the base class string the file already passes. Callers then write `<Button variant="quiet">`.

## Teach `cn()` your own text sizes

`cn()` merges classes and drops the earlier of two that conflict. It reads any `text-*` name it does not know as a colour, so with a `--text-body` size token, `cn("text-body", "text-muted-foreground")` silently drops the size. Fix it in the helper the project already has; never swap in a second merging library.

**Stock shadcn today.** shadcn 4.21.1 writes `lib/utils.ts` as `export { cn } from "cn"` (the fleet's stock-app fixture, `tests/fixtures/stock-next-shadcn`, has exactly that line). The `cn` package (0.4.0, 22 September 2026, MIT, by shadcn and Aiden Bai) replaces clsx and tailwind-merge and matches tailwind-merge's output, this pitfall included. Its `cn/config` entry point takes tailwind-merge's extension shape ([cn 0.4.0 README](https://www.npmjs.com/package/cn), read 3 October 2026 with its `dist/config.d.ts`):

```ts
// lib/utils.ts: same package, configured once
import { createCn } from "cn/config";

export const cn = createCn({
  extend: { classGroups: { "font-size": [{ text: ["body", "caption", "title"] }] } },
});
```

**Projects that still run clsx and tailwind-merge** (older shadcn setups, with `twMerge(clsx(inputs))` in `lib/utils.ts`) keep them and extend tailwind-merge instead ([tailwind-merge 3.7.0 configuration](https://github.com/dcastil/tailwind-merge/blob/tailwind-merge@3.7.0/packages/tailwind-merge/docs/configuration.md)):

```ts
// lib/utils.ts, only where clsx and tailwind-merge are already the helper
import { clsx } from "clsx";
import { extendTailwindMerge } from "tailwind-merge";

const twMerge = extendTailwindMerge({
  extend: { theme: { text: ["body", "caption", "title"] } },
});

export function cn(...inputs: Parameters<typeof clsx>) {
  return twMerge(clsx(inputs));
}
```

Either way, the names are the `--text-*` tokens without the prefix. Custom colours need no entry.

## Inline styles

```tsx
// BAD
<div style={{ background: 'var(--background)', marginTop: 24 }}>

// GOOD
<div className="bg-background mt-6">
```

Reach for raw CSS in `globals.css` only for what utilities cannot say: `@keyframes`, complex gradients, pseudo-element work. Keep it there, not scattered through component files.

## Server components

In the App Router, components are server components by default. Add `'use client'` only where a component needs hooks, event handlers or browser APIs, and push it down to the smallest leaf that needs it:

```text
page.tsx           → server component (fetches data, renders layout)
  HeroSection.tsx  → server component (static markup + CSS transitions)
  HeroActions.tsx  → 'use client' (the interactive buttons)
```

An effect CSS can do (`transition`, `@keyframes`, `:hover`) keeps the component on the server.

## Never

- A `tailwind.config.js` added to a v4 project to hold colours.
- A second Card, Button or Input beside the one in `components/ui`.
- Inline `style={{ }}` for what a utility expresses, or raw `var()` in it.
- `'use client'` on a whole page when one button needs it.

Sources in this file were read on 3 October 2026.
