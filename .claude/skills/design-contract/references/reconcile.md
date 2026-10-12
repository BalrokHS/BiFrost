## Mode: reconcile

The staleness pass. VISION.md is a contract; when it drifts from the code, every agent reading it inherits the lie.

### Start with the deterministic checks

Run these first and reason over their output; do not redo by hand what they already check:

1. `node .claude/design-fleet/run.mjs vision --json`: each section's status (filled, partial, empty, missing) and every contract diagnostic.
2. `node .claude/design-fleet/run.mjs lint`: the project checks the contract switches on. P12 and P13 report canonical paths that do not exist; P14 required states with no source signal; P15 and P16 siblings; N1 raw elements under a Components row.

### The token check, both ways

Compare the token table with the file named in `tokens-path`, in both directions. Lint's token-integrity checks do this deterministically when the installed Fleet has them (K2 to K4); otherwise do it by reading, with the same rules:

| Direction | Finding |
|-------|-----|
| **Contract to file** | A contract token missing from the tokens file (K4), or present with another value (K2). A missing value the table declares is a sync: add it to the tokens file with the declared value and say so. A different value is a contradiction: ask which side governs |
| **File to contract** | A token the tokens file holds and the table lacks: proposed, not approved (K3). This is how a token slips in behind the contract's back. Report it; never approve it by adding a row unasked |
| **Same value twice** | Two tokens with one value that are not a `var()` alias of each other (K2, or K3 when neither is in the contract) |

Map names before comparing: `color.primary` matches `--color-primary`, and `--primary` in a shadcn file. Compare colors in one color space: hex in VISION.md and OKLCH in a Tailwind v4 or shadcn file are the same color when they convert to the same value. Spacing rows compare in px against the spacing utilities and `--spacing` steps the code uses.

**DESIGN.md:** when the project has one, compare its front-matter tokens with the table the same two ways (the name map is in [draft.md](draft.md)). VISION.md wins for builds and lint; a different value is a finding, and a DESIGN.md token the table lacks is proposed, not approved. Never write or edit `DESIGN.md`: a change there is the person's own edit.

### Checks only an agent can make

| Check | How |
|-------|-----|
| Identifier hooks exist | The identifier hooks are real in the code: call sites of the `error-helper` function, uses of the `field-error-class` class, and the `icon-package` in package.json and imports |
| Typography matches | Declared families and weights are the ones actually loaded and used |
| Timings match | Declared durations and easings appear in the animation code; flag undeclared durations in the code too |
| Error strings match | Phrasing-table wording appears verbatim in the code |
| Feedback is settled | No decided entry in FEEDBACK.md contradicts the contract; a contradiction is a finding, with the decided entry quoted |
| Placeholders aging | A section still all placeholders months in: remind the person to fill it or delete it |
| Appendix staleness | Migration appendix present but its targets completed, or over the 10-bullet cap |

### Report and resolve

For each contradiction produce a finding:

```
**Finding:** VISION.md says modal cards animate at `200ms`; `Modal.tsx:31` uses `280ms`.
**Source of truth?** (a) the doc — I'll fix Modal.tsx to `200ms`, or
(b) the code — I'll update VISION.md to `280ms`.
```

Use the source of truth and authorization already established for this task. If a material conflict remains unresolved, show the exact document or code change and ask which source should govern. Apply authorized changes; otherwise keep the result as a proposal. Do not repeat permission requests for a decision already made.

A clean pass deserves a clear verdict: "VISION.md matches reality. N claims checked, 0 contradictions."
