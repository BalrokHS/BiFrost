# Nielsen review

A formal heuristic evaluation. Use it only when the user asks for a Nielsen review, a heuristic review or evaluation, a formal usability audit, or a pass against the ten heuristics. A plain "review" or "critique" uses the [visual critique](critique.md); the two formats never mix in one answer. The [review voice](review-guidance.md) applies here too.

The ten heuristics are Jakob Nielsen's ([NN/g, 10 usability heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/)). This file pins the severity words, the sweep, and how the fleet reads them where its interaction rules have a view.

## Severity

Rate every violation with exactly one of these four words.

| Severity | Meaning | Example |
| --- | --- | --- |
| cosmetic | Noticed, but the task goes on. Fix when there is time | Icon stroke widths differ slightly across a toolbar |
| minor | Hesitation or mild irritation; people recover on their own | Truncated cell text with no way to read it in place |
| major | Real confusion, slowdown or failure for some people | Column headers show raw field names such as `instructorId` |
| catastrophic | Blocks the task or loses data. Fix before release | Delete with no undo and no confirmation |

Rate the actual impact, not the heuristic's number: a missing loading state on a ten-second save can be major, while a missing shortcut is almost always minor.

## The ten, in order

| # | Heuristic | Ask | The fleet's reading |
| --- | --- | --- | --- |
| H1 | Visibility of system status | Does the UI show loading, saving, success and error? | A working control is busy (`aria-busy="true"`, ignores repeat presses), never `disabled`. Success shows where the person acted; a toast only when the result is out of view |
| H2 | Match with the real world | Are these the person's words, not the code's? | "Instructor", never `instructorId`; dates, numbers and currency in the person's locale |
| H3 | User control and freedom | Can people undo, cancel, go back and escape? | Reversible deletion gets undo; Escape closes overlays; back always works |
| H4 | Consistency and standards | Same action, same word, same place? Platform conventions? | The project's own components and tokens; one word per action |
| H5 | Error prevention | Are mistakes stopped before they happen? | Constrain input (types, ranges, pickers). Confirm only the irreversible or expensive. Keep submit enabled and show what is missing when it is pressed; never disable it until valid |
| H6 | Recognition over recall | Can people see the options instead of remembering them? | Persistent labels, never placeholder-only; a tooltip on every icon-only button |
| H7 | Flexibility and efficiency | Are there shortcuts and bulk actions for frequent users? | Shortcuts follow the project's existing map and the platform's; never take over a browser key |
| H8 | Aesthetic and minimalist design | Does every element earn its place? | Secondary actions recede; complexity is disclosed when needed |
| H9 | Error recovery | Are errors plain, specific and actionable? | Say what happened and how to fix it. Inline field errors and toasts both fit; the project chooses (below) |
| H10 | Help and documentation | Is help where people need it? | Helper text on non-obvious fields; empty states that say what is missing and the next step |

### Errors: inline or toast, the project chooses

Neither pattern is the fleet default. Follow what `VISION.md` or the existing code already does; where neither says, propose one and ask. A form can use both.

| Pattern | Fits when |
| --- | --- |
| Inline field error | The problem belongs to one field the person can see and fix: a format, a missing value, a name already taken. The message sits under the field, tied with `aria-describedby`, and the field carries `aria-invalid` |
| Toast | The result is not tied to one visible field, or lands out of view: a save that failed on the network, an undoable delete. One sentence and at most one action, such as Retry; an error that needs action does not time out |

Flag a break from the project's choice, an error that does not say how to recover, or a field error far from its field. Do not flag the pattern itself.

## Output

Walk H1 to H10 in order; never skip or reorder one.

```markdown
### H1. Visibility of system status
- **major** Saving shows nothing for three seconds (`SettingsForm.tsx:42`). Make the button busy while it works, then show "Saved" in its label.
```

A heuristic with no violation gets one line: "No violations found." Close with a summary that ranks every violation catastrophic, major, minor, cosmetic, one line each, so the user knows what to fix first.

Reviewing existing UI: walk each flow as a first-time user, map each issue to the one heuristic it most violates, rate it and give the fix. Building new UI: scan the ten before building, weight H1, H3 and H5, and pass all ten again after.

## Admin and CMS screens

| Pattern | Heuristic | Fix |
| --- | --- | --- |
| Nothing visible after save or delete | H1 | Show the result in place ("Saved" in the label); undo in a toast for a delete |
| A form submits with no validation | H5 | Validate before submit and show the errors the project's way |
| No way to cancel mid-flow | H3 | A cancel action and Escape |
| The primary action moves between screens | H4 | One position, as the project's other screens have it |
| Raw error codes on screen | H9 | Plain words and a recovery step |
| Empty states with no guidance | H10 | Say what is missing and the next step |
| Truncated text with no way to read it | H6 | A tooltip or an expandable row |
| Deletion with no recovery | H5 | Undo for reversible deletion; confirm only the irreversible or expensive |
| No loading signal on async work | H1 | Loading inside the control, or a skeleton for content |
| Field names as labels (`instructorId`) | H2 | Human labels ("Instructor") |
