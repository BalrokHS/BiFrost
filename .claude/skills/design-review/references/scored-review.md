# Scored review

A 0 to 1 score for a rendered screen, with a reason for every axis. Ordinary critique is advisory; score only when the user asks for it or an explicit project policy requires it. An `agent:` goal alone does not authorize paid calls or make a score a gate.

The lint is the floor: it checks what a pattern can match. The score is for what no pattern can judge, and a number never travels without the paragraph that explains the gap.

## Steps

1. Capture the rendered screen and the interaction evidence that matters. A score read off code grades an imagined render; without a render, stay advisory and say why. `node .claude/design-fleet/run.mjs render <file-or-url>` saves a full-page screenshot per width when the project has Playwright.
2. Use a separate judge with a model identity distinct from the builder's. Hide condition labels, expected bands and provenance from it. Changing live URLs cannot prove reproducible calibration; use the fixed anchors.
3. Score every calibration anchor before the target. `node .claude/design-fleet/run.mjs calibration --anchors` lists them; the package ships the anchors without their expected bands, which stay in the source repository. Checking the anchor scores with `node .claude/design-fleet/run.mjs calibration --scores <file>` needs a checkout of that repository; an installed package reports the labels missing, and the score stays advisory. Missing, non-finite or out-of-range scores cannot support calibration. The required separation is the packaged margin (0.15).
4. The anchors are provisional: no person has validated them yet, and the CLI always answers `gateEligible: false`. In this release every score is therefore advisory, whatever the separation. A gate needs validated anchors, a passing calibration and a threshold the project defines; never invent a default threshold. A failed or incomplete render is missing evidence, never a passing score.
5. Read the history, then record the result. Report calibrated trends apart from advisory scores; a trend is not proof that the UI meets its goals.

## Axes

| Axis | Weight | What it measures |
| --- | --- | --- |
| design | 0.35 | Hierarchy that leads the eye, deliberate colour, type and spacing rhythm, depth used on purpose |
| craft | 0.25 | The refinement pass in the [visual critique](critique.md): optical alignment, related radii, same-type controls treated alike, quiet off states, considered empty, loading and error states |
| originality | 0.15 | With a contract, how well the screen carries the character `VISION.md` describes and its canonical examples; without one, a point of view rather than unchosen defaults. A font, palette or component style the project already uses never counts against it |
| functionality | 0.25 | Whether the flow works: discoverable actions, handled states, consistent interaction, accessibility floors met in the render (focus, contrast, target size) |

The score is the weighted sum of the four, to two decimals.

| Range | Meaning |
| --- | --- |
| 0.0 to 0.3 | Broken or generic: no hierarchy, unreadable, dead ends, or a default template |
| 0.4 to 0.6 | Competent and forgettable; most output lands here |
| 0.7 to 0.8 | Considered: clear intent, good craft, a coherent point of view |
| 0.9 to 1.0 | Reference quality: the detail that makes someone who cares stop and look |

Every reason cites something visible in the render, never the code or a guess. When a contract exists, the lint has already checked its tables; here, judge whether the screen feels like the product the contract describes. Lean to the honest lower number and say what is missing.

## The record

One shape: the judge writes it, and `node .claude/design-fleet/run.mjs history record --input critique.json` reads it.

```json
{
  "target": "http://localhost:3000/pricing",
  "timestamp": "2026-10-03T12:00:00.000Z",
  "score": 0.66,
  "calibrated": false,
  "axes": {
    "design": { "score": 0.7, "why": "One clear headline, but three accent colours compete across the plan cards." },
    "craft": { "score": 0.6, "why": "The plan toggle's selected chip sits 2px lower than its track; card radii ignore their padding." },
    "originality": { "score": 0.6, "why": "Follows the contract's palette and type, but the plan cards are a stock three-column grid." },
    "functionality": { "score": 0.7, "why": "Every plan action is reachable by keyboard; the focus ring disappears on the dark card." }
  },
  "notes": "The gap to reference quality is hierarchy and finish: one accent, aligned toggle, a visible focus ring on every surface. Calibration unavailable, so the score is advisory."
}
```

- `target` is a resolved path or URL, never a description. `timestamp` is the real time of the run, supplied by the caller.
- `score` is the weighted sum of the axes. `calibrated` is true only when the anchors were scored and checked in this run.
- `history record` keeps `timestamp`, `score`, `calibrated`, `axes` and `notes` per target in `.design-fleet/critique/`; keep that folder as the project's policy says. `node .claude/design-fleet/run.mjs history summary --target <path-or-url>` shows the series, and only calibrated runs set the trend.
- The scores file for `calibration --scores` is an object keyed by the anchor ids, each a number from 0 to 1. The runtime finds its own anchor manifest; never import one from the source repository into a project.

The `verify` and `loop` commands never promote goals, and never read critique history as proof that an `agent:` goal is met; an authorized reviewer judges that evidence.
