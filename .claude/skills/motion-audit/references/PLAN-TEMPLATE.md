# Plan template

A plan is read by an agent that has not seen the audit and brings no taste of its own. Whatever the plan leaves out, that agent fills with a guess, usually a keyword curve and a default duration. So a plan:

- Writes every value out: a number, a curve, a file path. Never "subtle", never "as discussed", never "a suitable duration".
- Quotes the current code, so the executor finds the spot by matching the excerpt; line numbers drift.
- Points to one file in this codebase where the pattern is already done well.
- Fills the stack block, because the right mechanism depends on the primitive library (see the worked targets below).
- Says what must not change.
- Gives the commands to run, then lists the checks only a person can do, marked as human checks.

Copy the block below into `plans/motion/NNN-slug.md` and replace every `<...>`.

````markdown
# NNN: <short imperative title>

- **Commit:** <the short hash `git rev-parse --short HEAD` printed at the time of writing>
- **Category:** <which AUDIT.md category, 1 to 8>
- **Severity:** HIGH | MEDIUM | LOW
- **Contract:** <the VISION.md animation timing row this follows, quoted> | or: a proposed row diff, below, for the person to apply; this plan never edits VISION.md
- **Scope:** <n files, about n lines>

## Before you start

- If `git rev-parse --short HEAD` differs from the commit above and an excerpt under Where no longer matches its file, stop and report. Do not adapt the plan.
- Do not commit, branch or stash. Leave every change in the working tree for review.
- Do not add a dependency, a token or a VISION.md row. If the plan cannot be done without one, stop, propose it (name, value, where it is used) and wait for the person.

## Problem

<What happens on screen today and how it feels, then the rule it breaks, by name, in two or three sentences. Write "ease-in delays the moment the person is watching for a response", not "it feels slow".>

## Stack

| What | Value |
| --- | --- |
| Framework and version | <e.g. Next.js 16.3.8> |
| Primitive library and version | <Radix (`radix-ui` x.y.z) or Base UI (`@base-ui/react` x.y.z) or none; the shadcn style if shadcn wraps it> |
| Motion library and version | <`motion` x.y.z, or CSS only> |
| Tailwind version and animation plugin | <Tailwind 4.x.y with `tw-animate-css` x.y.z, or `tailwindcss-animate`, or none> |
| How to reach the state | <the route, story or steps that open the animated surface> |
| Type-check command | <e.g. `npx tsc --noEmit`> |
| Lint commands | <the project's own, e.g. `npm run lint`>, and `npx node .claude/design-fleet/run.mjs lint <path>`, run once per changed file or on the folder that holds them |

## Where

| File | Lines at the commit above | What is there |
| --- | --- | --- |
| `<path>` | <first to last line> | <what the code does> |

### Current code

```tsx
// <path>, at the commit above
<the excerpt, copied exactly, long enough to be unique in the file>
```

## Target

<The end state with every value written out. Start from the worked target for this stack in PLAN-TEMPLATE.md (Radix or Base UI) and change only names and values.>

```css
<the target code>
```

**Why these values:** <one line per value, naming its source: the VISION.md row, or the reference file it was copied from>

## Conventions to follow

- Easing and duration tokens live in `<file>`. Use `<token>`. If none fits, propose a new one (name and value, in the naming already there) for the person to approve; the executor never adds it. If `VISION.md` declares the value but `<file>` lacks it, adding it with the declared value is a sync: list it as a step.
- `<path/to/exemplar>` already does this well. Match its structure.
- <anything else this codebase does differently from the references>

## Steps

1. <a single action, written so it can be checked off>
2. <the action after it>
3. <and so on, in the order the executor takes them>

## Out of scope

- <files and behaviour that must not change>
- The timing of every other component, even where it looks the same.
- Any new animation library or other dependency. Propose it instead.
- `VISION.md`, the tokens file and `FEEDBACK.md`.

## Verification

Run these and paste each result:

- [ ] Type-check: `<type-check command>` passes.
- [ ] Lint: `<lint command>` passes, and `npx node .claude/design-fleet/run.mjs lint <path>` reports no error and no finding the code did not have before.
- [ ] <the test or story that covers this component>

Observe these in a browser, and say how you did it (a browser tool, or Playwright):

- [ ] <the visible change, e.g. the menu grows from its trigger, not from its centre>
- [ ] Open and close it quickly several times. With transitions it heads for the new state from wherever it is; with Radix keyframes it restarts without a visible jump.
- [ ] With reduced motion emulated (the DevTools rendering panel, or Playwright's `reducedMotion: "reduce"`): nothing travels, scales or rotates; opacity and colour may still fade; a decorative loop rests on a representative frame, not frame 0; a gesture still tracks one to one and settles without bounce.

Human checks. A person does these; an executor without one lists each under Not verified and never reports it as done:

- [ ] Human: record it and step through frame by frame. If it feels slow, shorten the duration first. If it looks flat, strengthen the curve, not the duration.
- [ ] Human: for gestures and drawers, try it on a real device as well as the desktop browser.
- [ ] Human: look at it again later, with a rested eye, before you call it finished.

## Notes

<Anything the code could not settle, for example whether a bounce fits the brand or whether two layers blend into a single object during the fade. Write each as an open question for the person.>
````

## Default numbers

Use these only when `VISION.md` declares nothing for the surface, and say so in the plan's "Why these values" line.

| What | Value | Where it is taught |
| --- | --- | --- |
| Enter: menus, popovers, dialogs | 200ms | timing-and-duration.md |
| Exit | 150ms | timing-and-duration.md |
| Entrance start | `scale(0.95)` and opacity 0, never `scale(0)` | practical-tips.md |
| Press | `scale(0.97)`, icon-only `scale(0.94)`, at most 150ms | the interaction-feedback rule |
| Hover | grows at most 1.02, over 120 to 180ms, only inside `@media (hover: hover)` | practical-tips.md |
| UI ceiling | under 300ms; gesture surfaces up to 500ms | timing-and-duration.md |
| Stagger step | 30 to 50ms per item | timing-and-duration.md |
| Springs | no bounce, 0.3s | spring-animations.md |
| Enter and exit curve | `cubic-bezier(0.23, 1, 0.32, 1)`, the strong ease-out named `--ease-out-quint` | easing-curves.md |

## Worked targets

Two correct versions of the same dropdown, one per primitive library, using the default numbers. Copy the one that matches the stack block; mixing them animates in neither library. Both checked against the libraries' current documentation on 3 October 2026: Radix [animation guide](https://www.radix-ui.com/primitives/docs/guides/animation) and [Dropdown Menu](https://www.radix-ui.com/primitives/docs/components/dropdown-menu); Base UI 1.8.0 [animation handbook](https://base-ui.com/react/handbook/animation) and [Menu](https://base-ui.com/react/components/menu).

### Radix

Radix (`radix-ui`, or a shadcn style built on it) keeps the closing content mounted only while a CSS animation runs, and only when the closing state has its own animation name. So enter and exit are separate `@keyframes` keyed to `data-state`, and the origin comes from the component's own variable, here `--radix-dropdown-menu-content-transform-origin`. A quick re-open restarts the keyframes: that is the accepted cost of a Radix exit (AUDIT.md, category 4).

```css
.menu-content {
  transform-origin: var(--radix-dropdown-menu-content-transform-origin);
}

.menu-content[data-state="open"] {
  animation: dropdown-in 200ms cubic-bezier(0.23, 1, 0.32, 1);
}

.menu-content[data-state="closed"] {
  animation: dropdown-out 150ms cubic-bezier(0.23, 1, 0.32, 1);
}

@keyframes dropdown-in {
  from {
    opacity: 0;
    transform: scale(0.95);
  }
}

@keyframes dropdown-out {
  to {
    opacity: 0;
    transform: scale(0.95);
  }
}

@keyframes dropdown-fade-in {
  from {
    opacity: 0;
  }
}

@keyframes dropdown-fade-out {
  to {
    opacity: 0;
  }
}

@media (prefers-reduced-motion: reduce) {
  .menu-content[data-state="open"] {
    animation-name: dropdown-fade-in;
  }

  .menu-content[data-state="closed"] {
    animation-name: dropdown-fade-out;
  }
}
```

### Base UI

Base UI (`@base-ui/react`, or a shadcn style built on it) waits for transitions and animations alike, and a transition retargets when it is interrupted, so use transitions with `data-starting-style` and `data-ending-style`. The Positioner sets `--transform-origin` for the popup inside it.

```css
.menu-popup {
  transform-origin: var(--transform-origin);
  transition:
    opacity 200ms cubic-bezier(0.23, 1, 0.32, 1),
    transform 200ms cubic-bezier(0.23, 1, 0.32, 1);
}

.menu-popup[data-starting-style],
.menu-popup[data-ending-style] {
  transform: scale(0.95);
  opacity: 0;
}

.menu-popup[data-ending-style] {
  transition-duration: 150ms;
}

@media (prefers-reduced-motion: reduce) {
  .menu-popup[data-starting-style],
  .menu-popup[data-ending-style] {
    transform: none;
  }
}
```

### shadcn with Tailwind

shadcn's components animate with `tw-animate-css` keyframes behind its `data-open:` and `data-closed:` variants, which match both Radix's `data-state` and Base UI's `data-open`. For reduced motion, gate only the movement classes with `motion-safe:` (`motion-safe:data-open:zoom-in-95`, `motion-safe:data-[side=bottom]:slide-in-from-top-2`) and keep the fade classes as they are. Adding `motion-reduce:animate-none` instead changes nothing, because shadcn's `data-open:animate-in` wins over it (AUDIT.md, category 6).
