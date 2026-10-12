## Mode: assess

Scan an existing codebase, extract its design profile, rate each dimension, and produce a prioritized migration report. Follow this sequence exactly — each step feeds the next.

### Step 1: locate the design surface

Find the files that define the project's visual language:

```
Search for (in order):
1. globals.css, global.css, app.css, index.css — global styles; in Tailwind v4 the theme lives here, in `@theme` blocks
2. tailwind.config.js, tailwind.config.ts — Tailwind v3 theme
3. theme.ts, theme.js, tokens.ts, tokens.js — design tokens
4. DESIGN.md — tokens in YAML front matter; read it, never write it
5. components.json, components/ui/ — shadcn configuration and the shared UI component library
6. layout.tsx, layout.jsx — root layout (fonts, providers)
7. package.json — check for styling/animation dependencies
```

Read each file found. These are the source of truth for what the project considers its design system.

### Step 2: extract the design profile

From the files found, extract concrete values. Be specific — count things, name things, quote values.

#### 2a. typography

| Question | How to Find |
|----------|-------------|
| What font families are in use? | Search for `font-family`, `--font-`, `next/font`, `@font-face`, Google Fonts imports |
| How many distinct font sizes? | Search for `font-size`, `text-{size}` Tailwind classes, `--font-size-` variables |
| How many font weights? | Search for `font-weight`, `font-{weight}` classes |
| Is there a type scale? | Check if sizes follow a ratio or are arbitrary |
| Is `font-display: swap` used? | Check `@font-face` declarations and `next/font` config |
| Is antialiasing set? | Search for `-webkit-font-smoothing` |

#### 2b. colors

| Question | How to Find |
|----------|-------------|
| How many unique color values? | Search for hex codes (`#[0-9a-fA-F]{3,8}`), `rgb()`, `hsl()`, `oklch()`, Tailwind color classes |
| How many are in CSS variables? | Count `--color-` or `--{name}` variables in globals |
| How many are hardcoded? | Count hex/rgb values in component files (not in globals or config) |
| Is there a palette? | Check Tailwind config `colors` or CSS variable definitions |
| Are alpha colors used for borders? | Search for `rgba`, `hsla`, `/0.` patterns on borders |

#### 2c. spacing

| Question | How to Find |
|----------|-------------|
| What spacing values are used? | Search for `padding`, `margin`, `gap`, `p-`, `m-`, `gap-` |
| Do they follow a scale? | Check if values are multiples of 4 (4, 8, 12, 16, 24, 32, 48, 64) |
| Are there arbitrary values? | Look for odd numbers or non-scale values like `13px`, `37px`, `p-[23px]` |

#### 2d. shadows & borders

| Question | How to Find |
|----------|-------------|
| How many shadow definitions? | Search for `box-shadow`, `shadow-`, `--shadow` |
| Are shadows layered? | Check if any shadow uses multiple comma-separated values |
| Are shadows consistent direction? | Compare offset-x/offset-y across shadows |
| Are border colors hardcoded or variable? | Search for `border-color`, `border-{color}` |

#### 2e. animation & motion

| Question | How to Find |
|----------|-------------|
| What animation library is used? | Check package.json for framer-motion, motion, react-spring, gsap |
| What durations are in use? | Search for `duration`, `transition:`, `animation:`, timing values |
| What easings are in use? | Search for `ease`, `cubic-bezier`, `ease-in`, `ease-out`, `ease-in-out` |
| Is `prefers-reduced-motion` respected? | Search for `prefers-reduced-motion`, `useReducedMotion` |
| Are `exit` animations present? | Search for `AnimatePresence`, `exit=` |

#### 2f. components

| Question | How to Find |
|----------|-------------|
| Is there a shared UI library? | Check for `components/ui/`, `@your-org/ui`, shadcn components |
| How many button variants exist? | Search for button components, count distinct styles |
| Are inputs/forms consistent? | Compare form components across features |
| Is `cn()` or `clsx` used? | Search for the class merging utility |
| Which states does each shared component style? | Per component file, look for `:hover`/`hover:`, `focus-visible`, `:active`, `disabled`, `aria-busy`/`loading`, `aria-invalid`/`error`, `success`; `node .claude/design-fleet/run.mjs inventory` lists components |
| Which variants does it expose? | Read the `variant` union type, the cva `variants.variant` map, or `data-variant` values |

#### 2g. keyboard & interaction

| Question | How to Find |
|----------|-------------|
| Are keyboard shortcuts defined? | Search for `useHotkeys`, `addEventListener('keydown'`, `Cmd+`, `Ctrl+` |
| Does Escape close overlays? | Search for `Escape` key handling in modals/dialogs |
| Is focus management handled? | Search for `focus-visible`, `FocusTrap`, `autoFocus` |
| Are hover states touch-safe? | Search for `@media (hover: hover)`, `pointer: fine` |

### Inspect the rendered UI when relevant

If a runnable UI is available, inspect representative screens and exercise relevant keyboard, focus, touch, and motion states before rating visual or behavioral consistency. Record viewports and evidence. If only source can be inspected, label the assessment source-only and list untested behavior; do not infer visual acceptance from code.

### Step 3: rate each dimension

| Rating | Meaning |
|--------|---------|
| **Solid** | Consistent, follows a system, matches or exceeds Design Fleet standards |
| **Partial** | Has a system but inconsistently applied, or the system has gaps |
| **Missing** | No system, arbitrary values, no consistency |

### Step 4: produce the audit report

```
## Design audit report

### Project: [name] — Date: [date]
### Overall assessment: [1-2 sentences]

### Design profile
[One block per dimension — Typography, Colors, Spacing, Shadows & Borders,
Animation, Components, Keyboard & Interaction. Each block: the concrete
findings (counts, names, quoted values) and a Solid/Partial/Missing rating.]

### Top 5 opportunities (by impact)
1-5. [Highest impact finding first — what to fix, where, why it matters]

### Migration order
1. **[Highest-impact correction]** — [specific actions, affected users, and evidence]
2. **[Next correction]** — [specific actions and any prerequisite]
3. **[Further correction, when needed]** — [specific actions and verification]
```

Order work by user impact, then by dependencies. An interaction failure that
blocks checkout takes priority over a typography refinement. If a prerequisite
must run first, name it and explain why. Include only relevant dimensions;
do not add work merely to fill a fixed sequence.

### Step 5: continue the requested workflow

- If the user already requested feedback planning, continue to plan mode using
  these findings and the existing contract. Do not pause for another approval.
- If the user already authorized drafting a contract, continue to draft mode
  using the extracted evidence. Preserve existing requirements unless their
  replacement was authorized.
- If the task is only an assessment, finish the report and state the relevant
  next action. When no contract exists, contract drafting can be that next
  action. When one exists, identify the needed reconciliation, proposed goals,
  or implementation work instead of offering to create it again.

Reuse the extraction. Do not create documents or make implementation changes
outside the requested next step.
