## Mode: draft

Produce a filled `VISION.md` at the **project root**, and only because the person asked for a contract: this mode, or a yes to the offer at the end of assess. Building, reviewing or planning never writes one. Without a contract, say that drafting one is an option and keep working from the existing code.

Pick the path before writing anything:

| Path | When | Template |
|---|---|---|
| **Short** (default) | Every project, unless the person asks for the full contract | [vision-template.md](vision-template.md): north star, five rules, six tables, 41 lines |
| **Full** | The person asks for the full contract, or the product needs its optional sections (app shell, selection patterns, modal rules, goals, error copy, empty states) | [vision-template-full.md](vision-template-full.md) |

A short contract grows one section at a time: copy a section from the full template, with its anchor and header, when the project starts to use it. Errors (with the `error-helper` hook) and canonical examples are the usual first two. An existing full contract stays full; never shorten a contract the person did not ask to shorten.

### Step 1: mechanical pre-fill

Run the [assess extraction](assess.md) (Steps 1 and 2) if it has not run this session, then map findings into the tables the chosen path has:

| Table | Pre-fill from |
|------------------|---------------|
| Lint hooks | `tokens-path`: the tokens file (a Tailwind v4 entry with `@theme`, a CSS variables file, theme JSON); `icon-package` from package.json; `error-helper`, `field-error-class` and `app-shell-helper` only when their sections are kept |
| Tokens | Values from the tokens file; from `DESIGN.md` too when the project has one (see below) |
| Spacing | The gap and padding values actually in use, one row per step of the scale |
| Typography | Family, size and line height, and weight per role, from extraction 2a |
| Animation | Durations and easings from extraction 2e |
| Components | Only the families the person names, from COMPONENTS.md or the component folders; states from what the canonical file already styles |
| Canonical examples, errors, empty states, goals | Full path or an added section only: the best existing file per pattern, the error strings in the code, the empty-state copy, the goals the person states |

Pre-fill only what the code actually shows. Never invent a literal to make a table look complete. Every Components row switches on the component checks across the whole library, so a row the person did not name can flood a legacy codebase with findings.

### Reading a DESIGN.md (read only)

When the project has a `DESIGN.md`, read its tokens as a source and never write or edit the file. The format (Google's DESIGN.md, [google-labs-code/design.md](https://github.com/google-labs-code/design.md), README checked 3 October 2026) keeps tokens in YAML front matter: `colors`, `typography`, `rounded`, `spacing` and `components`, with references written `{colors.primary}`.

- **Names map** to VISION.md rows: `colors.primary` to `color.primary`, `rounded.md` to `radius.md`, a `spacing` step to a Spacing row, a `typography` entry to a Typography row (`fontFamily`, `fontSize` and `lineHeight`, `fontWeight`), a component's `height` to a size token named for that component. Resolve `{...}` references first. Spacing cells take px, so `1rem` is `16px`. Compare colors in one color space: `#1f5c4a` and its OKLCH form are the same color.
- **Both files name a token with the same value:** one VISION.md row.
- **Both name it with different values:** VISION.md wins for builds and lint. Report the pair and ask which one governs. A change to VISION.md is a proposed row diff; a change to `DESIGN.md` is the person's own edit.
- **A DESIGN.md token VISION.md lacks** is proposed, not approved, until a VISION.md row holds it. Propose the rows the project uses; never copy the whole file in.
- DESIGN.md has no motion, copy, component-state or goal tables: those come from the code and the interview.

### Step 2: ingest the taste profile

Read the installed profile path, including root `design-taste.md` or a legacy `.cursor/rules/design-taste.mdc` / `.claude/rules/design-taste.md`. If multiple profiles disagree, report the conflict. Its signature detail seeds the full template's **Signature visual technique** section; its aesthetic direction, motion philosophy, and font preferences inform the interview defaults. Do not re-ask what the profile or current request already answers. Ask only about a material unresolved requirement.

### Step 3: gap interview

Interview for what code cannot reveal, **one question at a time**, waiting for each answer. Ask only about sections the chosen path has, and skip anything extraction or the taste profile already answered.

Short path:

1. **North star:** who it serves, the one outcome it is built for, the standing constraint (demo or production, desktop first or mobile first, a performance or accessibility floor).
2. **Component families:** which file is canonical for each family the person names, and which of `default`, `hover`, `focus-visible`, `active`, `disabled`, `loading`, `error`, `success` it must cover.
3. **Project rules:** anything beyond the five rules the template carries, such as a fixed set that must not grow or a demo boundary. Each one becomes a bullet under the rules.

Full path, in addition:

4. **Optional rules:** which of the full template's optional rules apply. Move each confirmed one into the Always or Never list and delete the rest.
5. **Errors:** under the field, through a helper, or both with when each applies (decision 7: the project chooses; the full template describes both). Then the exact error strings, titles and descriptions verbatim.
   - While the phrasing table is open, pin **verb and noun precision**: one name per concept, one concept per name across the UI. The app never says Delete here, Remove there, and Trash in a third place for the same operation. And verbs distinguish genuinely different operations: "Correct address" (fix a typo) and "Register change of address" (the person moved) are different intents that deserve different verbs.
6. **App-shell protocol:** how screens report actions, overlay state and navigation, or "no shell", which deletes the section.
7. **Selection patterns:** required-selection behavior, skip affordances, the selected-state recipe, or delete the section.
8. **Signature visual technique:** confirm the taste-profile seed or capture one; "None, by decision" is a valid answer.

### Step 4: fill the template

Fill the chosen template with the pre-fill plus the interview answers. A parser reads this file, and these are its rules:

- **Keep the interface byte for byte:** the `<!-- qd-vision-template: v1 -->` marker, every `<!-- qd:* -->` anchor kept on its own line, and every table header. Never rename a column, reorder columns, or rename a Lint hooks row: a renamed hook switches itself off silently.
- **Delete what the project does not use.** Filled means every present section filled, so a section left out costs nothing, and doctor offers the lean profile only once every section kept is filled. A section whose decision is still open may keep its `[UPPERCASE]` placeholders: it reads as empty and switches on no check, and the contract does not count as filled until it is filled or deleted. Never invent a value to fill one.
- **Completed rows:** the first column and every value-bearing cell. Goals need all four cells. Token and spacing rows need a name and Value; typography needs Role, Family, Size / leading and Weight; error, animation, canonical-example and empty-state rows need every cell; lint exclusions need Path. Use cells can be blank. Escape a literal pipe as `\|`. Blank required cells, wrong column counts, and invalid spacing or duration values are contract diagnostics, not completed rows.
- **Canonical literals:** `#0f172a`, `oklch(0.55 0.2 250)`, `2.5px`, `200ms`, `cubic-bezier(0.32, 0.72, 0, 1)`, `components/ui/feedback.ts`. Colors take the form the tokens file uses; a Tailwind v4 or shadcn tokens file is usually OKLCH. Preserve approved project values, pure black or white included, instead of replacing them with template examples.
- **The token table is the approved set,** not a sample. A token the tokens file holds and the table lacks is reported as proposed, not approved, so give every approved token a row. A family can be one wildcard row, such as `color.chart-*` with its values listed `#... / #...`.
- **Spacing:** non-negative px lengths with a unit, fractional allowed (`2.5px`, `.5px`); zero is `0px`, never a bare `0`; bare numbers and `rem` are invalid. The rows are the project scale and do not have to match Fleet's default 4/8/12/16/24/32/48/64. V7 compares a negative margin by its magnitude, so `-16px` meets a `16px` row.
- **Durations:** a non-negative number with `ms` or `s`; ranges, bare numbers and `spring` are invalid. Convert by API: Motion `duration: 0.2` is `200ms`; WAAPI `duration: 200` is `200ms`. In Motion, `duration: 200` means 200 seconds: Motion takes seconds. P7 reads inline Motion component and `MotionConfig` transition objects, imported Motion `animate` calls, WAAPI `element.animate` and `KeyframeEffect` options, unit-bearing CSS timings and Tailwind duration utilities; it does not infer units for detached objects or unknown APIs. A spring written with a duration (`type: "spring", duration: 0.3`) gets that duration; a spring set only by stiffness and damping has no duration, so describe it in prose and leave it out of the table.
- **Lint hooks:** identifiers (`error-helper`, `field-error-class`, `icon-package`) are written as they appear in code (`showError`, `field-error`, `lucide-react`); paths (`tokens-path`, `app-shell-helper`) are repo-relative. A file path in `error-helper` is a contract diagnostic and switches P5 off. `tokens-path` names the canonical tokens file: P1 and P3 skip it, and token integrity compares it with the token table both ways.
- **Components:** Required states come from the fixed vocabulary above, comma-separated; Anatomy and Variants are descriptive. A filled row switches on P13 (the canonical file exists), P14 (each required state has a source signal in that file, a heuristic to confirm in the running UI), P15 (an error for a file named as a version, such as `NewButton.tsx` or `ButtonV2.tsx`), P16 (a warning for a sibling by shape, such as a `SubmitButton.tsx` that renders its own `<button>` or copies the Button's classes), and N1 for a Button, Input, Select or Textarea row (no raw element outside its canonical file). A sibling that must stay gets its own Components row or a **Lint exclusions** row; either records the decision.
- **Goals:** a Statement is one checkable sentence. Verification takes one of four forms: `exists: <path>`, `lint: <path>` (bare `lint` is the whole project), `render: <path or URL>` (a complete `node .claude/design-fleet/run.mjs render` report for that subject; `verify` never opens a browser), or `agent: <how to judge>` (needs a design-review session; `verify` never passes it on its own). Status is `proposed`, `active` or `met`, and promotion is a human edit.
- **Lint exclusions** are configuration, not contract: gitignore-style globs, repo-relative (`*` within a segment, `**` any depth). `prototypes/**` is excluded by default. The section never counts as unfilled.
- **Migration appendix** (full template, optional): at most 10 bullets of the form "from [current state] to [target]"; delete it when migration is done.

Write the result to `VISION.md` at the project root, then show the person what was filled, what was deleted and what was left open.

Run `node .claude/design-fleet/run.mjs lint` after writing the contract and report its diagnostics. Exit 2 means an invalid contract or target; exit 1 means source errors; warnings stay visible without failing. Fix invalid rows rather than claiming success from checks that did not activate. A zero exit does not establish full design compliance, and goal completion remains a separate `verify` or `loop` result.

**Greenfield path:** no UI code, so skip Step 1 and run the interview only. The tables that need code (lint hooks, tokens, spacing, animation) keep their placeholders; they fill in as the project grows, and reconcile mode tracks the gap.

**Migration note:** if `.cursor/rules/design-context.mdc` or `.claude/rules/design-context.md` exists (output of the old design-audit skill), fold its "Migration Targets" into the full template's migration appendix, respecting its 10-bullet cap, then suggest deleting the old file. VISION.md supersedes it.

### Step 5: wire it

Use the installed, pinned Fleet runtime:

```sh
node .claude/design-fleet/run.mjs vision --wire
```

The installer selects the target and updates only its managed pointers: Claude imports VISION.md with `@VISION.md` in a managed `CLAUDE.md` block, Cursor uses an always-on `.cursor/rules/vision.mdc` rule, and Codex uses a managed `AGENTS.md` block. When VISION.md is absent, `vision --wire` seeds the short template. Do not manually overwrite these user documents or infer installation ownership merely from a directory name. A copied pointer is not proof that the host loaded it; if the runtime or target is missing, report what is needed before continuing.
