---
name: frontend-design
description: Build, fix or polish UI, small fixes included. Use when something feels janky, slow, laggy or dead when pressed, the page jumps sideways, spacing feels off, or someone asks to add dark mode, an empty state, a menu, dropdown, modal, command palette or tooltip, a transition or animation between states or pages, a layout that works on phones, or to make it feel like Linear or another product. Also covers easing, springs, reduced motion, drag and gestures, scrollbars, colour and contrast, UI copy, and Next.js and Tailwind setup. Points each job to the one reference to read before editing. Use design-review to critique or review UI, design-contract for VISION.md and project-wide consistency, and animation-vocabulary to name an effect.
---

# Frontend design

Read the [Fleet policy](../../policy.md) for instruction precedence, existing authorization, interaction defaults, and evidence requirements.

## Start from what exists

Product UI is the default. Before changing anything:

1. Read `VISION.md` when it exists. Its tokens, type ramp, timings and wording tables win over everything here. Run its pre-edit checklist on existing surfaces.
2. Find the existing pattern: the VISION.md Components table, then `COMPONENTS.md` searched by the problem (a modal? a data table?), then the nearest feature that already does it. Extend the canonical component in place; never add a sibling such as `ButtonV2`. Build new only after searching, and say what you searched.
3. Work inside the system: its tokens, spacing scale, type ramp and component families. Fonts too: an existing project keeps the families it already uses. Propose a missing token, dependency or contract row with its value, then stop. Never add one unasked.
4. Restraint over novelty. Bold direction belongs only to surfaces nothing governs yet: [greenfield direction](references/greenfield-direction.md).

## Read before you edit

Find the row that matches the request and open its reference before you change code. The notes further down are reminders, not the procedure. When two rows match, read both.

| When the request says | Read |
|---|---|
| It feels janky, slow, laggy, choppy or off | [debugging-animations](references/debugging-animations.md), then [timing-and-duration](references/timing-and-duration.md) |
| How long, which easing; a modal, drawer or menu opening | [timing-and-duration](references/timing-and-duration.md) and [easing-curves](references/easing-curves.md) |
| The page or a panel jumps sideways; scrollbars | [scrollbars](references/scrollbars.md) |
| A button feels dead when pressed; hover; tap targets | [practical-tips](references/practical-tips.md); loading and result feedback follow the interaction-feedback rule |
| Animate a state change: a status badge, a count, a toggle | [timing-and-duration](references/timing-and-duration.md), then [accessibility](references/accessibility.md) |
| Something appears or disappears; list items added or removed | [exit-animations](references/exit-animations.md) |
| Add or build a menu, row actions, dropdown, popover, tooltip, select, tabs, modal, command palette, cmd+k | [library-selection](references/library-selection.md), then [interaction-design](references/interaction-design.md); for a command palette or shortcuts, also [keyboard-shortcuts](../../design-fleet/references/keyboard-shortcuts.md) |
| Focus, keyboard, skip links, form fields and their errors | [interaction-design](references/interaction-design.md) |
| Dark mode, colours, contrast, a palette or theme | [color-and-contrast](references/color-and-contrast.md) |
| An empty state, an error message, a button label, any copy | [ux-writing](../../design-fleet/references/ux-writing.md) and [interaction-design](references/interaction-design.md) |
| Phones, mobile, touch, tablets, breakpoints | [responsive-design](references/responsive-design.md) |
| A smooth transition between pages or routes | [view-transitions](references/view-transitions.md) |
| Reduced motion, motion sickness, autoplay | [accessibility](references/accessibility.md) |
| Drag, swipe, a bottom sheet, springs | [gesture-and-drag](references/gesture-and-drag.md) and [spring-animations](references/spring-animations.md) |
| Motion for React: AnimatePresence, layout, layoutId | [motion-react](references/motion-react.md) |
| Height auto, an accordion, a container resizing | [container-animation](references/container-animation.md) |
| Keyframes, transforms, 3D, `@starting-style` | [css-animation-mechanics](references/css-animation-mechanics.md) |
| Dropped frames, `will-change`, GPU | [performance](references/performance.md) |
| Next.js or Tailwind: tokens, fonts, `cn()`, server components | [nextjs-tailwind](references/nextjs-tailwind.md) |
| Spacing feels off, cramped or uneven | The project's spacing tokens first: equal gaps between siblings, larger gaps between groups, density matched to how often the screen is used, display sizes kept rare |
| A chart, a dashboard, figures in a table | [data-visualization](../../design-fleet/references/data-visualization.md); `tabular-nums` for figures that line up |
| Make it feel like Linear or another product; a new page with no system | [greenfield-direction](references/greenfield-direction.md) |
| Help me decide how this should animate; a motion brief | [motion-brief](references/motion-brief.md) |
| Scroll effects, parallax (marketing pages only) | [scroll-animation](references/scroll-animation.md) |
| SVG drawing, path morphs | [svg-animation](references/svg-animation.md) |
| A clip-path reveal or wipe | [clip-path-animation](references/clip-path-animation.md) |
| `::before`, `::after`, `::backdrop`, a bigger hit area | [practical-tips](references/practical-tips.md) |

Opt in only when the condition holds: [materials-and-depth](references/materials-and-depth.md) when the direction is translucent and layered; [predictive-prefetch](references/predictive-prefetch.md) when navigation feels slow, and ask before its dependency; [storyboard-pattern](references/storyboard-pattern.md) for a choreographed marketing sequence.

## Hold these while you work

- **Frequency decides motion.** Seen tens or hundreds of times a day (buttons, hovers, list navigation, context menus): no decorative, entrance or hover animation; a felt pointer or touch press of at most 150ms is the one exception. Occasional: standard motion. Rare moments can do more. Keyboard-driven changes are always instant.
- **Product UI motion stays under 300ms**, and a VISION.md timing table overrides it. Ease-out for entering and leaving, ease-in-out for moving on screen, ease for hover and colour. Exits run a little faster than entrances.
- **Entrances start from scale 0.95 plus opacity**, 0.98 for large panels, never from `scale(0)`. Press is `scale(0.97)`, ease-out, 150ms at most.
- **Interactive state uses CSS transitions, not keyframes.** A transition can be interrupted and retargeted; keyframes restart. Keep `@keyframes` for fixed sequences such as loaders. Springs, bounce 0 by default, for drag and for motion that must keep its velocity.
- **Reduced motion has tiers.** Remove movement (transform, scale, position, layout); keep the opacity and colour fades that carry meaning; stop decorative loops on a still frame; keep direct manipulation 1:1. With Motion, wrap the app in `<MotionConfig reducedMotion="user">`: its default, `"never"`, ignores the setting ([Motion docs](https://motion.dev/docs/react-motion-config), checked 3 October 2026).
- **Widget primitives, not hand-rolled ones.** Check `package.json`. Menus, selects, comboboxes, tabs, tooltips and dialogs come from what the project already uses; when nothing fits, propose Radix or Base UI. Native `<dialog>` and `popover` cover simple cases and projects that take no new dependency. Never hand-roll focus or keyboard handling. A destructive confirm focuses the least destructive button.
- **Only the states an element can reach.** Do not invent loading or success states.
- **Scrollbars overlay.** No `overflow-y: scroll`, no hidden thumb; `scrollbar-gutter: stable` on `html` only.
- **Never in product UI:** cards inside cards, a placeholder as the only label, an absolutely positioned dropdown inside an overflow container, bounce easing by default, scroll reveals, grey text on a coloured fill, `outline: none` without a `:focus-visible` ring.

## Fit the codebase

- Use the project's utilities and tokens; no inline styles for what the framework can express. Push client code down to the smallest component that needs it.
- Extend `components/ui` or the shared library with a variant; never write a parallel component.
- Follow the project's cursor convention; Tailwind v4 gives buttons the default cursor ([upgrade guide](https://tailwindcss.com/docs/upgrade-guide), checked 3 October 2026).
- `<td>` ignores `overflow: hidden`: truncate on an inner wrapper, and give a flex cell `min-w-0`.

## Before you finish

Run `node .claude/design-fleet/run.mjs lint` on the files you changed. Say what you verified and what you did not; rendered behaviour needs a browser and `design-review`.

Not this skill: review or critique (`design-review`), VISION.md and consistency audits (`design-contract`), naming an effect (`animation-vocabulary`). `/proto` (variants to compare) and `/motion-audit` (a codebase motion audit) run only when invoked by name.
