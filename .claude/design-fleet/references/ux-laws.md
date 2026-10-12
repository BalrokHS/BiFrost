
# Design Fleet -- UX laws

Read the [Fleet policy](../../policy.md) for instruction precedence, existing authorization, interaction defaults, and evidence requirements.

> **Contract precedence:** if the project has a `VISION.md` contract, its values win. These laws apply where the contract is silent.

The reasoning is in the weights; use these lines as a review checklist. Each is one directive.

## Basics a strong model already does

- `ux-fitts-target-size` -- Pressable targets are at least `44px` on touch and `32px` with a pointer, the house defaults. WCAG 2.2 sets the AA floor at 24 by 24 CSS pixels, with exceptions for spacing and inline links ([SC 2.5.8](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html), checked 3 October 2026).
- `ux-hicks-minimize-choices` -- Minimize visible choices; use progressive disclosure.
- `ux-millers-chunking` -- Miller's law is about working memory, not menu length: chunk what people must remember (codes, steps, numbers) into small groups. It sets no cap on a list people can see.
- `ux-doherty-under-400ms` -- Interactions respond within 400ms.
- `ux-doherty-perceived-speed` -- Can't be fast? Show progress: skeletons, optimistic updates, progress indicators.
- `ux-postels-accept-messy-input` -- Accept messy human input, output clean normalized data.
- `ux-progressive-disclosure` -- Show what matters now; reveal complexity incrementally.
- `ux-teslers-complexity` -- Irreducible complexity goes to the system, not the user.
- `ux-cognitive-load-reduce` -- Every element on the screen must serve the task in hand; cut what does not.
- `ux-jakobs-familiar-patterns` -- Familiar patterns by default; deviations must be intentional improvements.
- `ux-proximity-grouping` -- Tighter spacing within groups, larger spacing between them.
- `ux-similarity-consistency` -- Same function, same look.
- `ux-common-region-boundaries` -- Group related content with boundaries: cards, sections, dividers.
- `ux-uniform-connectedness` -- Connect related elements with lines, color, or frames.
- `ux-pragnanz-simplify` -- Simplify complex visuals to their clearest form.
- `ux-von-restorff-emphasis` -- Make the most important element visually distinct.
- `ux-serial-position` -- Key items go first or last in sequences.
- `ux-aesthetic-usability` -- Polish compounds into perceived usability and trust.
- `ux-peak-end-finish-strong` -- End flows with a clear success state.
- `ux-goal-gradient-progress` -- Show progress toward completion.
- `ux-zeigarnik-resume` -- Show where an unfinished task stands so people can pick it up again. Never use it to nag.
- `ux-pareto-prioritize-features` -- Optimize the critical-path 20% of features first.

## Extra mile

What a strong model skips under build pressure. Measured probes decide which of these join the craft file that loads with the house file in every profile; until then they load here in the full profile and on demand in lean. Brackets give the count in the Fleet 11 run artifacts of 2 October 2026.

- `ux-fitts-hit-area` -- When a control is smaller than the target size, grow its hit area with a pseudo-element or padding and keep the visual size. Flagging the conflict is not a fix. [15 build replies noticed a target under 44px and left it; 2 grew it]
- `ux-fitts-never-below-floor` -- Never ship a pointer target under 24 by 24 CSS pixels unless one of the WCAG exceptions applies; say which.
