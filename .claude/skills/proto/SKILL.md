---
name: proto
description: Builds several genuinely different, working versions of one UI piece behind a switcher so you choose by looking, then promotes the one you keep. Explicit invocation only.
disable-model-invocation: true
argument-hint: "[<description> | <description> x5 | riff <variant> | keep <variant>]"
---

# Proto

One piece of UI per run. For a whole screen, pick the piece that matters most and say why.

## Build

- Read VISION.md, the tokens and the existing components first. Variants use them; sharing tokens is not convergence.
- Three directions, five at most. Each gets a sentence-case name that says what it is, never "Option A", and its axis in a phrase. Two that differ only in colour or wording are one direction.
- Everything works: real copy, plausible names and numbers, every control does something. No dead buttons, no lorem. No autofocus in variants.
- Build one `index.html` in `prototypes/<slug>/`. In an app with a dev server, a route in a `prototypes/` folder may use the real components. The lint skips these folders; no production code imports them.
- Show each variant at full size in realistic surroundings, never as thumbnails.
- Copy the switcher, never retype or edit it: `cp <this skill's folder>/switcher.js prototypes/<slug>/`. Load it with `<script src="switcher.js">`, then call `mountSwitcher({ stage, variants: [{ label, render(stage, signal) }], replay })`. `render` fills the stage; stop its timers when `signal` aborts. Set `replay: true` only when a variant has motion.
- A variant may use a token or timing the contract lacks. List it in the hand-over as a proposed row; never write VISION.md.

## Check

Re-read the page once for dead controls, stale timers and console errors, and fix them in one pass. If two variants converged, cut one and say so. If a browser tool is already available, flip through every variant; if not, say "not rendered". Never install tools or write files outside the repo.

## Hand over, then stop

| Variant | Axis | Right when | Costs you |
|---|---|---|---|

One honest line each. Never pick a winner; if asked, answer from the product and how often the piece is used. Say how to open the page and flip: Tab to the switcher, then 1 to N or the arrows; R replays; Escape returns to the page.

## keep <variant>

1. Integrate it with the existing components, tokens and conventions. Anything the contract lacks stays out until approved: propose the row in chat.
2. Delete the prototype: `rm -r prototypes/<slug>`. Never git.
3. Record the decision in FEEDBACK.md, creating it if needed, as a decided entry: `- <YYYY-MM-DD>: DECIDED (<who picked>): <piece> is "<winner>" (proto). Lost: "<name>" (<axis>), ...`
4. Offer to draft the short contract rows the winner implies. Never write VISION.md unasked.

## riff <variant>

Keep the switcher; build a fresh set around that direction.

Open the [Fleet policy](../../policy.md) only for a conflict this page does not settle.
