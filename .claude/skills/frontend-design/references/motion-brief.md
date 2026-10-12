# Motion brief

An interview that settles how one animation should behave before anyone builds it. Run it when someone asks for it ("grill me" on an animation, a motion brief, a decision on how something should move), or when an animation has been rebuilt twice and still feels wrong, which usually means nobody decided what it was for. Ask until every field of the brief is filled, then stop. The brief is the result; building is a separate step. Go on to build only if that is already in scope, and never ask again for a permission already given.

---

## Three rules for the interview

- `brief-one-decision-at-a-time`: ask one thing and wait. Later answers depend on earlier ones, and five questions at once get five vague replies. Attach your recommendation to every question so a one-word yes settles it.
- `brief-no-unfeelable-numbers`: do not ask for values nobody can judge in the abstract, such as a duration or a cubic-bezier. Ask what it should feel like, or which product does it well, then propose the number and the curve yourself and let the person react. Nobody can choose 240ms from nothing; anyone can tell you 240ms feels slow.
- `brief-facts-vs-decisions`: look up what the code can tell you; ask only for what a person must decide. A question the repository could have answered wastes their time and your credibility.

## Before the first question

Read:

- **The component itself**, and the before and after states.
- **`package.json`**: which tools exist (motion/react, Tailwind, plain CSS, WAAPI).
- **VISION.md's timing table** and the **Motion section of the taste profile**. Declared curves, durations and personality limits bind every answer.
- **Existing motion tokens** (`--ease-*`, duration variables) and what neighbouring components do.
- **Reduced motion**: is it handled globally already?

You are ready when you can state each of these, or say plainly that it does not exist here. Summarise what you found in three or four lines and go straight to the first question, with no preamble. Ground every question in what you read: "this drawer animates with `@keyframes`; if they drag it closed while it is still opening, what should happen?" is better than "should it be interruptible?".

## Q1 and Q2: either can end the interview

**Q1, how often.** "How many times a day will one person see this?" Keyboard-driven changes stay instant whatever the answer. Seen a hundred times or more: no decorative or entrance motion, and pointer or touch press feedback only as the [Fleet policy](../../../policy.md#interaction-defaults) allows. Dozens of times: remove it or make it instant. Now and then: standard motion. Rarely: room for expression. Bands in [timing-and-duration](timing-and-duration.md).

**Q2, why.** "What does the movement tell people that the change alone does not?" Six answers count: **feedback**, **keeping place in space**, **showing state**, **explaining**, **softening a jarring change**, and, only for something rarely seen, **delight**. "It looks nice" on something seen all day is none of them.

> Delta: a cut is a good outcome, and agents almost never offer it unprompted. If Q1 or Q2 points to removing it, the brief records a cut with its reason, and the interview ends. Do not water it down into "a very subtle version".

## Q3 to Q6: how it moves

**Q3, what starts it.** A click, a hover, a route change, data arriving, a drag? Confirm what you found, then settle the keyboard path: moves started from the keyboard never animate, so they are instant or take a `{ duration: 0 }` branch next to the pointer path. A drag means direct manipulation: the surface follows the finger exactly and settles on release.

**Q4, curve and duration together.** They are one decision. A steep curve can carry a longer duration and a weak one cannot, so propose them as a pair: the curve first, then a duration that suits it. Families are in the defaults below, named values in [easing-curves](easing-curves.md), bands in [timing-and-duration](timing-and-duration.md). If the person says it feels slow, shorten the duration first; if it feels flat, strengthen the curve and leave the duration.

**Q5, what actually changes.** Have the person describe both states aloud and list the properties that differ. This is where `transition: all` goes, and where an animation of four properties often turns out to need two. Then settle direction and origin: from the trigger or from the centre, which way is forward, entering from `scale(0.95)`, never `scale(0)`. An element leaves the way it came, about 20% faster; two different elements swapping follow one direction instead. Press and hover feel: [practical-tips](practical-tips.md).

**Q6, interruption.** "What should happen if they fire it a second time, or turn it back, while it is still moving?" This question picks the technique: transitions and springs carry on from where the element is, `@keyframes` start over. Toasts that jump when they stack are what skipping it looks like.

## Q7 to Q9: the edges

**Q7, scale and load.** Ask only when your reading turned up lists, dragging, filtering or blur; without those it has no subject. How does it behave with 200 items instead of three, on an ordinary phone, with the data not yet loaded? Budgets in [performance](performance.md).

**Q8, reduced motion.** "With the movement taken away, what should remain?" Use the four tiers: movement (transform, translate, scale, layout) goes entirely, never just shortened; opacity, colour and background fades may stay; decorative motion (idle floats, loops, parallax, marquees) stops, paused on a chosen frame with `animation-play-state: paused` and a negative `animation-delay`, never frame 0; direct manipulation still tracks 1:1 and settles critically damped. Recipes in [accessibility](accessibility.md).

**Q9, personality.** "Which product does this well?" One good example says more than a list of adjectives, and you can study it frame by frame. If there is none, offer two options: crisp and serious, or playful with a little bounce. A playful answer revisits Q4's pair on purpose and sets the spring's bounce ([spring-animations](spring-animations.md)).

## The brief

The interview is over when the brief has no empty field: not when the person seems content or when building feels within reach. An empty field is the next question.

```markdown
## Motion brief: <component>

**Decision:** animate | cut
**Started by:** <the trigger>
**Seen:** <how often> → <why that allows motion>
**Job:** <one of the six reasons, in a sentence>

**In:** <properties, start → end>
**Out:** <properties, start → end, or "reverse of in, about 20% faster">
**Origin:** <transform-origin or direction>
**Curve:** <curve> · **Length:** <ms>
**If interrupted:** <what happens on a repeat or a reversal>
**Reduced motion:** <what stays, tier by tier>
**Built with:** <CSS transition / @starting-style / spring / layout animation>

**Least certain:** <the riskiest assumption and how to test it>
```

Present the brief. If only a brief was asked for, stop there with no changes to the product. If building is already approved, carry on once the material decisions are made. Ask again only about an open decision or a change of scope; the brief records the decision before any code.

## When the person cannot decide

"Just make it nice" hands the decision back to you. Turn it into two named options, your pick first, each with a short description of the feel: "A quick 180ms snap, the way a Linear menu opens, or a softer 300ms ease with a gentle settle, like a Stripe panel? I'd take the first, because this opens on every row hover." If there is still no choice, take the default, mark it **assumed** in the brief, and move on. A written assumption is better than an open question.

## When VISION.md has no row for it

If the agreed brief uses a timing or curve the VISION.md timing table does not declare, there is one more step: propose the exact row (surface, duration, curve, in the table's own format) and send it through design-contract so later edits inherit it. Never quietly use the undeclared value. The same route covers a marketing surface that needs more than the UI ceiling, such as a scroll reveal: it enters the table as declared doctrine, never as a lint exemption.

## Your default recommendations

Every question comes with a recommendation. These are the standing ones; each number's full table lives in its own file.

| Decision | Recommend |
| --- | --- |
| Animate at all | Q1's frequency answer decides; bands in timing-and-duration.md |
| Properties | `transform` and `opacity` only; reasons in performance.md |
| Entrance | `scale(0.95)` with a fade, never `scale(0)`; larger surfaces start nearer 1, a nav menu at 0.98 |
| Press and hover | Felt rather than seen; scales, hover gating and the hover band in practical-tips.md |
| Origin | From the trigger for popovers, dropdowns and menus (`var(--radix-popover-content-transform-origin)` in Radix, `var(--transform-origin)` in Base UI); from the centre for dialogs |
| Curve | ease-out to enter and leave; ease-in-out to move on screen; ease for hover and colour; linear just for steady loops; no ease-in in UI; a named curve over a keyword, values in easing-curves.md |
| Duration | Under 300ms for UI; dialogs and drawers 200-300ms; a steep curve can take the longer end; bands in timing-and-duration.md |
| Interruption | Transitions or springs, which carry on from the current value; `@keyframes` start over |
| Spring | Bounce 0. Above zero only for gestures and playful moments, smaller elements more; configs in spring-animations.md |
| Reduced motion | Q8's four tiers; recipes in accessibility.md |
| Stagger | 30-50ms per item, a hard cap in product UI (marketing reveals have their own band in timing-and-duration.md); vary it by importance rather than keeping it even; one entrance per container; never block interaction |

## Related

design-review's motion review ([motion-review](../../design-review/references/motion-review.md)) checks the built result against this brief. animation-vocabulary gives a loosely described effect its exact name, so the brief can specify it.
