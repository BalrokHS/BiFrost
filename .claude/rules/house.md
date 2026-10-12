
# Design Fleet house rules

## Whose rules win

- VISION.md wins, then the existing code, then the person's taste profile, then these defaults.
- With no VISION.md, the existing code is the design system.
- When FEEDBACK.md exists, read its decided entries before building; they bind like VISION.md.
- Never create or edit DESIGN.md; read its tokens when there is one.
- A small fix applies what exists; no design questionnaire.

## Reuse before you build

- Before writing a component, search by the problem for how the codebase already solves it: VISION.md, COMPONENTS.md, shared components.
- Name the file you reuse. Extend the canonical file; never add a sibling.
- No raw button, input or select in a page when a component exists.
- Improve a weak pattern in place and say so; never fork it.
- If you cannot name what you reuse, or what you searched, stop and search.

## Propose, never add

- Every colour, font, size, spacing, radius, shadow and duration comes from the project's tokens: no literals, no palette classes.
- A value the tokens lack is a proposal: name, value and use. Until approved, use the nearest declared value.
- Never write a token, a VISION.md row or a dependency unasked: propose it and build with what the project has.
- A value VISION.md declares but the tokens file lacks is a sync: add it with the declared value and say so.
- For a decision the contract leaves open, choose what fits the existing patterns and state the decision, the choice and why in your reply.
- Never invent actions, data or a backend; render no control without a target.
- Git only when asked; delete with rm. Edit with the edit tools, never sed -i. Write only inside the project.

## Interaction numbers

- The project's own press, loading, result and toast patterns and the contract's timing table come first; these numbers fill only the gaps, and every duration stays on that table.
- Press: scale(0.97), icon-only scale(0.94), at most 150ms, ease-out. Keyboard activation does not animate.
- Hover: only in @media (hover: hover), scale at most 1.02, 120 to 180ms. Never on frequent actions.
- Entrance: from scale(0.95) and opacity 0, never scale(0). Enter 200ms, exit 150ms, UI motion under 300ms. Springs: bounce 0, 0.3s.
- Loading: in the control after 200ms, same size, aria-busy, never disabled. Skeleton after 1s; progress and cancel after 5s.
- Result: a past-tense label for 1.5s in place. Reversible deletes get undo for at least 5s, not a confirm.
- Never remove a focus outline without a visible focus-visible ring.
- Targets: 44px on touch, 32px with a pointer. Grow the hit area, not the visual.
- States: the ones the Components table requires, else only those an element can reach.
- Reduced motion keeps the meaning and drops the movement.

## Words and look

- Sentence case for every heading, label, button, menu item and toast.
- Buttons say verb and object.
- Errors say what happened and what to do.
- One word per thing, everywhere.
- No invented proof: no fake metrics, logos, quotes or status dots. No "Not X. Y." lines, no em-dash chains.
- No emoji or text glyphs as icons; use the icon library.
- No monospace in product UI; aligned digits use tabular-nums.
- Scrollbars overlay and never take layout space: scrollers use the project's ScrollArea; app roots never scroll.
- Never hide an action behind hover.
- Never disable zoom.
- Adapt small screens; never drop a feature.
- No serif-italic accent word, purple gradient, identical card grid, centred hero, eyebrow label or decorative dot.

## Say what you verified

- End with Verified (each check you ran and its result) and Not verified.
- Never claim a check you did not run.
- Keep apart what a tool checked, what you reviewed and what you saw rendered. Clean lint is not proof; a screenshot shows only the look.
- Report a missing tool; never invent its result.
- Run node .claude/design-fleet/run.mjs lint before you report.

## On demand

Skills by job: frontend-design to build or fix UI, design-review to review it, design-contract for VISION.md, proto when the person asks to compare options.

[Interaction feedback](../design-fleet/references/interaction-feedback.md) for loading, saving and deleting, [writing](../design-fleet/references/ux-writing.md), [type](../design-fleet/references/typography.md), [colour](../design-fleet/references/color-contrast.md), [visual](../design-fleet/references/visual-design.md), [layout](../design-fleet/references/layout-composition.md), [charts](../design-fleet/references/data-visualization.md), [shortcuts](../design-fleet/references/keyboard-shortcuts.md) when asked, [responsive](../design-fleet/references/responsive-design.md), [UX laws](../design-fleet/references/ux-laws.md) for review, [design intent](../design-fleet/references/design-intent.md) for a new surface.

With UI files: [craft](craft.md), the extra mile cold models skip and the mistakes they make.
