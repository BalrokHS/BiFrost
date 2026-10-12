---
name: design-review
description: Review UI code, screenshots, or running pages. Run supported design lint, inspect rendered appearance and interactions, or provide an explicit Nielsen, motion, or scored review. Keep executable findings separate from agent judgment. Use design-contract for codebase-wide consistency or contract reconciliation and frontend-design for implementation.
argument-hint: "[description, file path, glob, screenshot, or 'last changed files']"
---

# Design review

Read the [Fleet policy](../../policy.md) for precedence, authorization,
evidence, and scoring boundaries. Review the scope the user gave. A review
request does not authorize product edits.

## Choose the procedure

| Request | Read |
| --- | --- |
| Lint, validate, check generated code, or a design PR review | [Code checks](references/code-checks.md) |
| Critique, polish feedback, a screenshot, a component, or live UI | [Visual critique](references/critique.md) and [review voice](references/review-guidance.md) |
| Explicit Nielsen, heuristic, or usability audit | [Nielsen review](references/nielsen-review.md) |
| The behaviour or feel of a motion change | [Motion review](references/motion-review.md) |
| Explicit scan for animation opportunities | [Motion opportunities](references/motion-opportunities.md) |
| Explicit scored review, or a project scoring policy | [Scored review](references/scored-review.md) |

Load only the references the request needs. Ordinary polish does not authorize
an opportunity scan. For codebase-wide motion plans use explicitly invoked
`motion-audit`; for contract consistency, `design-contract`; for building UI,
`frontend-design`.

## Check for drift

Run `node .claude/design-fleet/run.mjs lint` for executable findings: it runs seventeen base checks
and twelve conditional contract checks, and the
[code checks](references/code-checks.md) say what each one reads and misses.
Then check new UI against what the project already has (`COMPONENTS.md`, the
contract's Components and Design tokens tables, the tokens file) and flag:

- a raw `<button>`, `<input>`, `<select>` or `<textarea>`, or a hand-built widget, where a component exists;
- palette or scale classes, or literals, off the tokens (`bg-blue-600`, `p-5`, a `#0f172a` that `--ink` already holds);
- a new custom property the contract does not hold;
- a second component for a job an existing one already does.

Each finding names the existing component or token to reuse, by file. The fix is reuse: never add a token or variant. When nothing fits, say so and propose one; the user decides.

## Keep evidence separate

Report the lint's scope, exclusions and exit code as it prints them. Checklist
items the lint does not run are agent review or rendered tests; never give
them a lint result.

For visual claims, inspect pixels from the running UI when available. A
screenshot proves only the captured appearance. Exercise the relevant
keyboard, focus, touch, reduced-motion and state-transition behaviour. When
tools or the runtime are unavailable, label findings source-only and behaviour
untested; never infer a passing render or interaction from source code alone.
When `node .claude/design-fleet/run.mjs render` evidence exists for the subject, cite its
`.design-fleet/render/<slug>/report.json` path and check results; when it does
not, those checks stay source-only.

Ordinary critique is advisory. A subjective gate requires explicit project
policy and current independent calibration. The verification CLI never
promotes goals; proposed, active, invalid and pending agent goals cannot be
reported as complete from a clean lint result.
