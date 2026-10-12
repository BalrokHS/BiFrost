# VISION: [PROJECT NAME]

<!-- qd-vision-template: v1 -->

> **Read this before every non-trivial change.** This is the contract for working in this project. If a rule below conflicts with something you are about to do, **stop and ask**; do not improvise. The goal is one coherent product. Run `node .claude/design-fleet/run.mjs lint` after editing this contract.

---

## North star

North star: [WHO IT SERVES AND THE ONE OUTCOME IT IS BUILT FOR]. Standing constraint: [WHAT WINS OVER CONVENIENCE].

---

## Rules

These tables, then the existing code, are the system. Where this file is silent, the existing code wins over any default.

**Always**

1. **Use design tokens.** Every color, font, radius, spacing, and size comes from the token map (see **Design tokens**). A one-off "close enough" value is the most common drift.
2. **Use the canonical component** listed in **Components** as it is. If it lacks a variant or state you need, propose the extension (variant name, states, call sites); never create a sibling, never add a variant unasked.
3. **Follow the canonical layout pattern** for the surface you are on (see **Layout pattern**). Do not invent a new composition for one screen.
4. **Match the wording style.** Sentence case for buttons and labels. Plain language. No emojis in shipping copy. No "Oops", "Whoops", "Yay" or "Awesome". See **CTAs and wording**.
5. **Read the decided entries in `FEEDBACK.md`** before deciding copy or behavior; they bind like this file. A conflict with this contract becomes a proposed amendment, never a silent override.
6. **Use icons from the package named in `icon-package`** and nothing else. Never an emoji or a typographic glyph as an icon.

**Never**

1. **Never introduce a new color, font, radius, or spacing value** without an approved token. Propose a missing one with its name, value and use, and wait for approval. No siblings of existing tokens.
2. **Never break the canonical layout pattern** without flagging it in the response.
3. **Never use emojis** in shipping UI strings or in code unless the user explicitly asked.
4. **Never introduce a new dependency** without asking. The existing toolkit usually covers it.
5. **Never edit this file during a build.** Propose the exact row diff in your response; the user decides.

## Optional rules

Not in force. A rule here binds only once it moves into the lists above, which happens when the person confirms it applies to this project. Delete this section once the contract is filled.

- **Form errors under the field:** a field error shows under its field, tied to it with `aria-describedby`, and clears as the person edits. Fits forms where the person fixes a value in place. See **Errors and validation**.
- **Form errors through a helper:** one toast or banner from the helper named in `error-helper`, plus the class named in `field-error-class` on each bad field. Fits short forms and results the person cannot see from where they are (a background save, a send that fails after a dialog closed).
- **App shell:** talk to the app shell through the documented protocol (see **App-shell protocol**) and report overlay state, so global UI can yield while an overlay owns the viewport. Never render your own copy of a global UI element.
- **Required selection:** never let a required selection end up empty through a re-click or a background click. The only no-selection path is an explicit skip. See **Selection patterns**.
- **Fixed sets:** never expand a client-approved fixed set (countries, currencies, plan tiers) without a decided `FEEDBACK.md` entry behind it.
- **Commits:** never amend a previous commit to fix something; create a new one.
- **Demo:** never write real network calls, payments or auth. This project is a demo.

---

<!-- qd:goals -->
## Goals

What the product must achieve, as checkable statements. `node .claude/design-fleet/run.mjs verify` checks what it can and treats a failing `met` goal as a regression. Promotion is a human edit: no agent or loop changes `proposed` to `active`, or `active` to `met`, on its own.

| Goal | Statement | Verification | Status |
|---|---|---|---|
| G1 | [ONE CHECKABLE STATEMENT OF WHAT MUST BE TRUE] | [VERIFICATION FORM] | proposed |

---

<!-- qd:lint-hooks -->
## Lint hooks

| Hook | Value |
|---|---|
| `error-helper` | [ERROR HELPER FUNCTION NAME] |
| `field-error-class` | [FIELD ERROR CLASS NAME] |
| `app-shell-helper` | [PATH/TO/SHELL HELPER] |
| `icon-package` | [ICON PACKAGE NAME] |
| `tokens-path` | [PATH/TO/TOKENS] |

---

<!-- qd:tokens -->
## Design tokens

The canonical source is the file named in `tokens-path`. This table is the approved token set: a token the tokens file holds and this table lacks is proposed, not approved, until a row here holds it. Screen-local aliases mirror the canonical source exactly. Declared values override the matching Fleet defaults; they never remove an accessibility requirement.

| Token | Value | Use |
|---|---|---|
| `color.primary` | [COLOR] | Brand color: primary CTAs, selected ring, active links |
| `color.onPrimary` | [COLOR] | Text on primary surfaces |
| `color.ink` | [COLOR] | Default body text |
| `color.background` | [COLOR] | Page background |
| `color.surface` | [COLOR] | Cards, inputs, modals |
| `color.muted` | [COLOR] | Secondary text, hints |
| `color.border` | [COLOR] | Default borders |
| `color.danger` | [COLOR] | Error states, destructive actions |
| `radius.input` | [PX] | Form fields |
| `radius.button` | [PX] | Buttons |
| `radius.card` | [PX] | Cards, modals |
| `size.fieldHeight` | [PX] | Inputs and buttons |
| `size.formWidth` | [PX] | Standard form width |

If you need a value that is in neither this table nor the canonical source, propose it with its name, value and where it is used, and use it once approved. Never write it to either unasked. If this table declares a value the canonical source lacks, add it to the canonical source with the declared value and say so in your response: that is a sync, not a new decision.

When the project also has a `DESIGN.md`, read its tokens and never write them. Where it and this table name the same token, this table wins and the difference is a reconcile finding; a `DESIGN.md` token this table lacks is proposed, not approved.

---

<!-- qd:spacing -->
## Spacing

Name the gaps here so every file uses the same scale. These rows are the project scale.

| Spacing token | Value | Use |
|---|---|---|
| `space.page` | [PX] | Page edge padding |
| `space.block` | [PX] | Between major content blocks |
| `space.section` | [PX] | Between sections inside a block |
| `space.field` | [PX] | Between stacked form fields |
| `space.inline` | [PX] | Between inline siblings (icon and label, button groups) |

---

<!-- qd:typography -->
## Typography

Each role has exactly one family, size, line height and weight. Never mix families in one word, button or sentence. A display family is for display moments only, never for body copy or inputs.

| Role | Family | Size / leading | Weight |
|---|---|---|---|
| H1 (screen titles) | [DISPLAY FAMILY] | [SIZE/LEADING] desktop, [SIZE/LEADING] mobile | [WEIGHT] |
| H2 (section titles) | [DISPLAY FAMILY] | [SIZE/LEADING] | [WEIGHT] |
| Body | [BODY FAMILY] | [SIZE/LEADING] | [WEIGHT] |
| Label / button | [BODY FAMILY] | [SIZE/LEADING] | [WEIGHT] |
| Small text | [BODY FAMILY] | [SIZE/LEADING] | [WEIGHT] |

---

## Signature visual technique

[THE TECHNIQUE, ITS CANONICAL CODE PATTERN AND EVERY SURFACE IT APPLIES TO, OR NONE BY DECISION]

A signature technique is the thing that makes screens recognizably this product: a layered shadow, a glass recipe, a hand-drawn underline on links, a precise grid, an easing fingerprint. Every surface on its list gets it. "None, by decision" is a valid entry.

---

## Layout pattern

[THE ONE LAYOUT MOST SCREENS FOLLOW, IN ONE OR TWO SENTENCES]

New screens follow it and diff against the canonical layout file in **Canonical examples**. All gaps come from **Spacing**; do not reinvent them per file.

---

## App-shell protocol (optional)

[HOW A SCREEN REPORTS ITS ACTIONS, ITS OVERLAY STATE AND NAVIGATION TO THE SHELL, OR DELETE THIS SECTION]

Pass stable handlers to global UI so it does not tear down and remount on every change in the screen. A screen that opens an overlay reports it, so sticky footers and breadcrumbs can yield; a missing report is the usual cause of double buttons.

---

<!-- qd:errors -->
## Errors and validation

Two patterns, and the project chooses (see **Optional rules**):

- **Under the field:** the message sits under its field, linked with `aria-describedby`; the field takes the class named in `field-error-class`. The person sees what to fix where they are. Most forms.
- **Through a helper:** one toast or banner from the helper named in `error-helper`, at one documented position with a close button, plus the field-error class on each bad field. Short forms, and results the person cannot see from where they are.

Either way, clear a field's error state as soon as the person edits it.

**Phrasing:** every error string in the product, once, so it cannot drift.

| Situation | Title | Description |
|---|---|---|
| [ERROR SCENARIO] | [EXACT WORDING] | [EXACT WORDING OR NONE] |

**Tone:** plain, neutral, no blame, no exclamation marks. Sentence case for title and description. End descriptions with a full stop. Say only what the person can act on; never confirm whether an account exists.

---

## Modals and overlays (optional)

- **Use the project's dialog and popover primitive** (Radix, Base UI or a native `<dialog>` and `popover`). They own outside click, Escape, the focus trap and focus return; never hand-roll them.
- **Scroll lock never shifts the page.** Keep `scrollbar-gutter: stable` on `html` (the page root only). Base UI's Dialog already locks with a stable gutter: add nothing. Radix's Dialog adds a right margin the width of the scrollbar: zero it with `html body[data-scroll-locked] { margin-right: 0 !important; }`. A native `<dialog>` does not lock scrolling: add `html:has(dialog:modal) { overflow: hidden; }`, and the root gutter keeps its width. The recipe and its sources are in the frontend-design skill's scrollbars reference ([frontend-design/references/scrollbars.md](../../frontend-design/references/scrollbars.md)), under modal scroll lock.
- **Backdrop:** [BACKDROP COLOR TOKEN] at [OPACITY], with the backdrop fade from **Animation timing**.
- **Card:** enters with the modal card timing from **Animation timing**, scaling from [START SCALE] to 1.
- **Header:** the modal title uses the screen H1 role. The close button sits top right inside its own 44 by 44 target.
- **Footer:** secondary left, primary right. A pending primary stays enabled and shows that it is busy; it is never hidden.
- **Edit flows reuse the create component** (one component with a mode prop), never a parallel implementation.

---

## CTAs and wording

- **Primary CTA:** brand color, the label and button type role, `radius.button`, `size.fieldHeight`, the signature technique where it applies, `color.onPrimary` text.
- **Secondary CTA:** the documented variant (outlined, ghost), never reinvented per screen.
- **Tertiary, "Skip" or "Not now":** a muted text link, not a button, and only for genuinely optional steps.
- **State-aware labels:** reflect state in the label rather than disabling silently ("Continue to checkout" when a selection exists, "Continue" when it does not).
- **Busy, not disabled:** while an action is pending, its button stays enabled and shows progress. A control that cannot act yet stays visible with the documented disabled style.
- **Sentence case:** "Save changes", "Create account", "Back to sign in". Not Title Case.

---

## Selection patterns (optional)

- **Pick one:** clicking a different item switches the selection; clicking the selected item does nothing. Background clicks do not clear it.
- **Pick many:** clicking toggles. Background clicks do not clear.
- **Required steps** default to a sensible value where they can.
- **Selected state** uses one documented recipe (border, fill, indicator): [SELECTED STATE RECIPE].

---

<!-- qd:empty-states -->
## Empty states

Every collection screen has an empty-state line under its title that says what is missing and what to do next. Empty states are never silent.

| Surface | Empty copy | Non-empty copy |
|---|---|---|
| [SURFACE] | [EXACT WORDING] | [EXACT WORDING] |

---

## Iconography

- **One icon library:** the package named in `icon-package`. Stroke width and sizes belong to the design system, not to each icon. Never an emoji or a typographic glyph as an icon.
- **Exported and brand SVGs** live in one documented folder. Wrap them; do not edit them. If a nested export renders oddly, redraw it as one clean centered SVG before debugging the export.
- **Color icons with `currentColor`** or a color token. Never hard-code a hex value in an icon.

---

<!-- qd:animation -->
## Animation timing

Use the approved values. An unresolved change is a proposed amendment.

| Where | Duration | Easing |
|---|---|---|
| Press feedback | [DURATION] | [EASING] |
| Hover and focus colors | [DURATION] | [EASING] |
| Screen content fade in and out | [DURATION] | [EASING] |
| Modal backdrop fade | [DURATION] | [EASING] |
| Modal card enter | [DURATION] | [EASING] |
| Modal card exit | [DURATION] | [EASING] |
| Progress and state transitions | [DURATION] | [EASING] |
| Scroll-triggered reveal (marketing surfaces only) | [DURATION] | [EASING] |
| Sheet or drawer (spring duration) | [DURATION] | [EASING] |

[SPRING PARAMETERS IN PROSE, OR DELETE THIS LINE]

Reduced motion: under `prefers-reduced-motion: reduce`, movement is removed entirely; opacity and color fades may remain; decorative loops stop or pause on a representative frame; gesture tracking stays 1:1. Any deviation from this default is declared here.

---

## File hygiene

- **One screen, one file.** Pickers, cards and small reusable pieces get their own file.
- **Primitive UI** (buttons, toggles, feedback helpers) lives under [PRIMITIVES PATH].
- **Exported and brand assets** live under [ASSETS PATH]. Wrap them; do not edit them.
- **Comment the why, not the what,** especially around a non-obvious framework pattern (stable refs, effect dependencies).
- **Naming:** PascalCase for components, camelCase for hooks and utilities, kebab-case for route files. One convention per category.

---

## Pre-edit checklist (before every change)

1. **Tokens?** Am I introducing any value not already in the token map?
2. **Signature visual technique?** Is it applied to every surface on its list?
3. **Layout?** Does the screen follow the canonical layout pattern?
4. **Errors?** Do messages follow the chosen error pattern, with wording from the phrasing table?
5. **Animation?** Am I reusing documented timings, not inventing new ones?
6. **Wording?** Sentence case, no emojis, no exclamation marks, in line with the decided feedback?
7. **Accessibility?** Is every interactive element keyboard-reachable, labeled, and at least 44 by 44 to touch?
8. **State leaks?** Does this change add global state, a side effect or a DOM mutation the rest of the app does not know about?
9. **Components?** Am I using the canonical component as it is, and was any new variant proposed and approved?
10. **Optional rules in force?** App shell, selection, fixed sets: does this change keep them?

If an item fails, explain the deviation to the user before shipping the change.

---

<!-- qd:canonical -->
## Canonical examples (look here when in doubt)

For each repeated pattern, the one file that does it right. New work diffs against it, not against each other.

| Pattern | Look at |
|---|---|
| Canonical layout | [PATH] |
| App-shell protocol and stable refs | [PATH] |
| Modal open and close | [PATH] |
| State-aware primary CTA | [PATH] |
| Popover | [PATH] |
| Signature visual technique applied | [PATH] |
| Empty-state copy and count | [PATH] |
| Error wiring | [PATH] |
| Form validation pattern | [PATH] |

---

<!-- qd:components -->
## Components

One row per component family. **Canonical file** is the one file that defines it: changes to the family happen in that file, after the user approves the new variant or state; never add a sibling. A sibling that must stay gets its own row here or a **Lint exclusions** row; either records the decision.

| Component | Canonical file | Required states | Anatomy | Variants |
|---|---|---|---|---|
| [COMPONENT] | [PATH] | [STATES] | [PARTS] | [VARIANTS] |

---

<!-- qd:lint-ignore -->
## Lint exclusions (optional)

Paths where raw literals are content, not styling: gallery pages that render token values, preview art, demo fixtures. Lint skips them and reports the count. `prototypes/**` is skipped by default.

| Path |
|---|
| [PATH GLOB] |

---

## What "done" looks like for any change

A change is shippable when all of these are true:

- [ ] The pre-edit checklist passes, or each deviation is called out.
- [ ] No regressions: surfaces I did not touch look and behave the same.
- [ ] Verified in the live preview or the running app, not only type-checked.
- [ ] Tokens only: no inline magic numbers or colors.
- [ ] Wording matches the decided feedback.
- [ ] Global UI (sticky footers, breadcrumbs, headers) still behaves across breakpoints.
- [ ] The accessibility floor is met (focus, labels, targets, contrast).
- [ ] The summary to the user describes the actual change (file and line), not the intent.

---

## When this doc and reality disagree

If you find code that breaks a rule above, it's either (a) a bug to flag, or (b) this doc is stale and needs updating. **Don't silently follow the broken pattern** — flag it. If this doc is stale, propose the change in your response as an exact diff for the user to approve; never edit it unasked. To run a full staleness pass, ask for `design-contract` reconcile mode.

---

## Appendix: migration targets (optional)

[MIGRATION TARGETS, AT MOST 10 BULLETS, OR DELETE THIS APPENDIX]
