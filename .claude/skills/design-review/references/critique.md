# Visual critique

A critique of a screen, a component or a flow, judged against the project before taste. The contract and the components and tokens the project already has are the first reference; general craft comes second. For an explicit heuristic audit use the [Nielsen review](nielsen-review.md), for motion the [motion review](motion-review.md), for a number the [scored review](scored-review.md). The [review voice](review-guidance.md) applies to every one of them.

## Evidence

For a running page or a component in a runnable project, inspect the actual UI
with an available browser tool. Capture the viewport and state before making
visual claims. Read source to explain observed defects. Fetched markup or an
imagined rendering is not visual evidence.

A supplied screenshot supports claims about that image only. Inspect relevant
keyboard, focus, touch, reduced-motion, and state-transition behavior in the
running UI when the review concerns them. Record untested states.

If only source is available, label the result **source-only review**. Report
source-backed structure and implementation risks; do not assert rendered
appearance or interaction acceptance. If rendering is unavailable, state the
missing capability and keep those checks incomplete.

## Before you look

Open these first and keep them beside you:

1. `VISION.md`: the character it describes, the Components and Design tokens tables, the canonical examples, and the decided entries in `FEEDBACK.md` when the project keeps one.
2. `COMPONENTS.md` (or run `node .claude/design-fleet/run.mjs inventory`) and the component folder: what already exists for each job on the screen.
3. The tokens file the contract names.

Without a contract, the product's own existing screens are the reference. Compare a new screen with its siblings in the same product before any outside product.

Then say in a sentence or two what the screen is for, who uses it, and in what state of mind. A tax return filed at midnight needs different care from a playlist picked on a Sunday.

## The lenses

Look through one lens at a time; a finding belongs to the lens that explains it best.

### The design system

| Look at | Ask |
| --- | --- |
| Components | Is every control and pattern the project's own component? A raw `<button>` dressed to look like Button, a second card, a hand-built menu beside the existing one: name the component and file to use instead |
| Tokens | Do colour, radius, shadow, spacing and type come from the tokens? A palette class or a literal that equals a token is drift: name the token |
| Contract | Does the screen follow the canonical example for its kind, the signature technique, and the contract's copy and timing? |
| Siblings | Does it match the product's other screens of the same kind: the header, the actions, the empty and loading states? |

Never fix drift by inventing. When the system has no component or token for the need, say so and propose one to the user.

### What it looks like

| Look at | Ask |
| --- | --- |
| Colour | Does each colour carry meaning? Count the backgrounds and accents; more than the hierarchy needs is noise |
| Type | Count the sizes and weights. Do headline, body and label read as three clear steps, or as near-twins? |
| Depth | Are shadows crisp and lit from one side? Do borders give structure, or compete with the content? |
| Weight | Is the heaviest element the most important one, or does decoration pull the eye from the main action? |
| Spacing and alignment | Is spacing on the scale and steady? Does everything sit on one grid? |
| Icons | One family, one stroke, one optical size? |

### How it works

| Look at | Ask |
| --- | --- |
| Entry point | Is it obvious where to look first? |
| Disclosure | Does complexity arrive when it is needed, or all at once? Forty fields where five would do? |
| Density | Right for the job: dense for a daily dashboard, sparse for a first run? |
| Expectations | Does the person know what happens next, how far along they are, and how much is left? |
| Feedback | Does every action get an answer in place: busy while it works, the result where it happened? |
| Repetition | Do titles, labels or descriptions repeat what the screen already makes clear? |

### Consistency and conventions

| Look at | Ask |
| --- | --- |
| Patterns | Is the same action handled the same way everywhere? |
| Platform | Does it follow web and platform conventions, and depart from them only on purpose? |
| One hand | Does it read as one product, or as parts from different kits? |

### The person

Name the feeling the screen is likely to cause (overwhelmed, rushed, unsure, at ease) and whether the design respects the person's situation: anxious and high-stakes, focused and repeated, casual. Then ask where a little more care would matter most: an empty state, an error, a wait, a step that cannot be undone. Care here means clarity and less effort, not added decoration or celebration.

### Refinement pass

A deliberate final sweep for the small, high-craft details the broad lenses
above tend to skip — the difference between "fine" and "considered." A fast
critique reliably misses these, so check each one explicitly:

| Check | The miss it catches |
| --- | --- |
| **Same-type controls match** | Icon buttons of the same kind should share one container, size, and hit area. A bare back chevron next to a more-actions button in a circular chip is inconsistent — give both the same treatment. |
| **The hero value has a home** | The single most important number/stat should sit in its own container/surface, not float unemphasized while everything around it aligns differently. |
| **Row elements share one centerline** | In a row (icon + text + trailing control/avatar), everything should sit optically centered on one horizontal axis, not align to different heights. |
| **Off and unselected states stay quiet** | Unselected checkboxes/toggles/rows shouldn't be visually loud (heavy borders). The "off" state recedes; selection controls match the product's shape language (circular vs square). |
| **Equal segments, uniform inset** | Segmented controls get equal-width segments and a selected chip inset evenly on all sides. |
| **Optical padding around icons** | A trailing icon with built-in whitespace (a chevron) needs its padding trimmed so it looks balanced, not ruler-equal. |
| **Dividers inset to text** | List separators start at the text column, not full-width under the leading icons. |
| **Concentric radii** | Nested rounded elements — inner and outer corner radii should feel related, not arbitrary. |
| **Optical over mathematical** | When equal numbers look unequal, adjust to what the eye reads as balanced. |

Run these as an explicit checklist; do not assume the lenses above already
covered them.

## Output

Write only the sections that have findings, in this order. Context and Top opportunities always appear; any other section with nothing to say is left out.

```markdown
## Context
What this is, who it is for, and the evidence used (rendered, or source-only).

## Design system
**Raw button for delete**: `src/app/transactions/page.tsx:73` renders a hand-styled `<button>` beside four uses of Button. The next change to Button will leave it behind. Use Button from `src/components/ui/Button.tsx`, and propose an icon size to the user, since Button has none.

## Visual design
## Interface design
## Consistency and conventions
## User context
## Craft details
## Top opportunities
Three to five changes, one sentence each, ordered by impact: structural, then behavioural, then visual.
```

Each finding is a short bold name, a colon, then three plain sentences: what you see (counted, quoted or measured), what it does to the person, and what to do instead. When the fix is reuse, the third sentence names the component or token and its file.

**Muddy card shadow**: the cards use a 24px blur at 8% opacity, so they float in a haze instead of resting on the page. The layout loses its sense of what sits above what. Use the project's card shadow token, which is tighter and lit from above.

Not like this: a paragraph that blends every issue ("the colours need work and the spacing feels off"), bare bullets with no names, or findings that open with "I think" or "it might be".
