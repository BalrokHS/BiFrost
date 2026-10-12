## Mode: plan

The forward pass. Reconcile catches the contract lying about the present; plan decides what the contract should demand next. Output is **proposed rows for the Goals table**, never adopted goals, never built features.

### Inputs (read all that exist)

| Source | What it contributes |
|--------|---------------------|
| `VISION.md` north star and Goals table | The destination, and what is already promised (all statuses; never re-propose a goal that exists). A short contract has no Goals table: add the section from the full template when the person asks for goals |
| `FEEDBACK.md` at the project root | Decisions already made (binding), items still open, and items already rejected |
| Latest critique findings (a design-review report, if the person has one) | Observed UI gaps worth promoting to goals |
| `STATE.md` (when a loop maintains one) | What's in flight or escalated; don't propose what's already being built |

### FEEDBACK.md: one format

One dated bullet per item, never deleted, with a status word after the date:

```markdown
# Feedback

- 2026-10-03: DECIDED (Maria): form errors show under the field; a toast only for results out of view.
- 2026-10-04: OPEN: three support tickets say checkout is confusing. → G7 proposed
- 2026-10-05: REJECTED (Maria): a second accent color for the dashboard. One accent keeps it calm.
- 2026-10-06: DECIDED (Maria): supersedes 2026-10-03: the address form shows its errors under each field too.
```

- **DECIDED** entries bind like VISION.md. Every session reads them before it builds, and a build follows them. A decided entry changes only through a newer DECIDED entry that names the one it supersedes.
- **REJECTED** entries stay rejected: never propose them again in other words.
- **OPEN** entries are the inbox plan works through. A bullet with no status word is open, so an older dated-bullet inbox keeps working as it is.
- **Only the person decides.** DECIDED and REJECTED name who decided. An agent writes one only to record a decision the person made in this conversation, in their words; it never decides on its own judgement or upgrades an open item.
- A decided entry that changes the design system (a token, a spacing value, an error string) is still a contract change: propose the VISION.md row diff; the entry does not edit the contract.

### Classify each open item first

Not all feedback is goal-shaped. Route each open item by where the change belongs, after checking it against every DECIDED and REJECTED entry:

| Shape | Signal | Output |
|-------|--------|--------|
| **Capability:** the product should *do* something | "clients want CSV export", "add a step to onboarding" | A proposed Goals row (steps below) |
| **Contract:** the design system itself should change | "introduce a warmer accent", "buttons feel cramped", new error-copy tone | A **proposed amendment**: quote the exact VISION.md table-row diff (token row, spacing value, phrasing row) in your report. Keep it proposed in this plan-only mode. Existing explicit authorization can cover a later implementation step; do not repeat the same permission request. Only then does the new value exist for builds and lint |
| **Redesign-scale:** many contract sections at once | "full visual refresh", "rebrand" | Recommend a `design-contract` assess then draft session. Don't piecemeal a redesign through single amendments: the contract gets rewritten *with* the person, then every later edit builds to the new rails |

The contract row matters most: "use a new color" must become an approved token-table row *before* any build uses it. The contract's propose-never-add rule says so, and lint backs it: P1 reports a color literal the table lacks, S1 a Tailwind class off the contract's scale, P3 a type size, radius or size off it, and token integrity a token that appeared in the tokens file behind the contract's back. Feedback changes the contract first, never the code first. Annotate classified bullets (`G7`, `amendment proposed`, `vision session`); never delete inbox entries.

### Steps (for capability-shaped items)

1. **Distill candidates.** Each candidate goal must be one checkable statement with a Verification cell in the contract's grammar (`exists:`, `lint:`, `render:`, or `agent:`); `render:` passes on a complete `node .claude/design-fleet/run.mjs render` report for that exact path or URL. Refuse vibes: rewrite "make it feel premium" into the checkable statements behind it, or report it as unplannable and name what's missing. Then run the **flip test**: if a proposed outcome can be restated as a feature ("users can export CSV" flips to "add a CSV export button"), it's a solution in disguise; rewrite it as the user outcome behind it ("a client can hand their accountant the quarter's numbers without retyping them") before it becomes a Goals row. The outcome survives a different implementation; the feature doesn't.
   - **Surface unmade decisions.** Part of plan's value is finding the decisions nobody has made. When a feedback item reveals one (an empty state no one has named, an error path no one has defined, a selection behavior left to whoever builds it), propose it as an explicit decision item in the report, rather than silently defaulting. A named open decision is a plan output; a silent default is a future reconcile finding. Once the person decides, it is recorded as a DECIDED entry.
2. **Dedup** against every existing Goals row, all statuses included, and against every DECIDED and REJECTED feedback entry.
3. **Record the proposals within the authorized scope.** A request to turn feedback into proposed goals authorizes appending new `proposed` rows to the existing Goals table and annotating the corresponding FEEDBACK.md bullets with their goal IDs (`G7`). Preserve all existing rows, statuses, requirements, and inbox text. If the person asks for a read-only review or a separate proposal document, put the proposed rows and feedback mapping in the report instead. Do not ask again for permission already given.
4. **Check the result.** Keep the Goals marker and table headers unchanged. Use unique goal IDs and the supported verification grammar. Run `node .claude/design-fleet/run.mjs verify` after an authorized append; proposed goals must remain unresolved and must not establish completion. Confirm that implementation files and all existing goal rows are unchanged.
5. **Report** each proposal: statement, verification, and the feedback line or finding that motivated it. State whether the rows were appended or supplied separately.

### Hard rails

- **Preserve every existing Status cell.** New rows start as `proposed`. Promotion (`proposed` to `active`) and completion (`active` to `met`) require a separate authorized status decision backed by verification evidence; this planning pass does not promote goals.
- **Never build.** Proposing a goal and implementing it in the same pass removes the human gate this mode exists for.
- **Preserve existing contract requirements.** The authorized addition of `proposed` Goals rows is the only contract-table change in this mode. Propose changes to tokens, spacing, typography, wording, or other requirements as exact diffs in the report; do not apply them during this planning pass.
- **Never mark feedback decided or rejected yourself.** Record a decision only when the person made it.
- Propose few and sharp over many and mushy: an unfillable Goals table is feedback noise relocated, not a plan.
