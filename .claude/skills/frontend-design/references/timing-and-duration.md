# Timing and duration

How long motion lasts, and how often someone sees it, which decides whether it should exist at all. Curves live in [easing-curves](easing-curves.md).

---

## Durations

| Element | Duration |
| --- | --- |
| Press feedback | 120-150ms |
| Hover | 120-180ms |
| Tooltips, dropdowns, popovers | 150-250ms |
| Small state changes | 180-260ms |
| Dialogs, drawers | 200-300ms |
| Stagger step, product lists | 30-50ms per item |
| Stagger step, marketing scroll reveals | 80-120ms, varied by importance |
| Marketing scroll reveals | 400-600ms |

- UI animations must stay under 300ms.
- The 400-600ms reveal and the 80-120ms stagger belong to marketing pages. A project that wants them declares them in VISION.md's animation-timing table (P7); product UI never borrows them. A stagger never holds up interaction, and one container gets one entrance: the section, or its children, never both.
- Bigger elements and longer travel take a little longer; small ones are quicker.
- An exit can run about 20% faster than its entrance.
- If it feels slow, shorten the duration before touching the curve.

## The gesture-surface exception

A surface the person drags is the one place longer motion is allowed, and there are two equal ways to settle it.

- **Spring-settled** sheets, drawers and swipe-dismissed toasts have no fixed duration: the settle time comes from the spring and the release velocity, and a full-height move can land between 300 and 500ms.
- **A fixed transition on the steep drawer curve** (`--ease-drawer`) is the same exception with a set length: 500ms for a full-height sheet, about 200ms for a floating drawer. The curve covers most of the distance early, so the tail reads as settling, not as slowness.

This is no licence for slow discrete transitions: a dropdown, a dialog fade or a tab switch still stays inside the ceiling. A project that needs longer declares it in VISION.md's animation-timing table, which executable lint P7 enforces (A2 is a manual review criterion). Physics in [gesture-and-drag](gesture-and-drag.md).

## Height that follows content

A container growing to fit its content has no single right duration. Scale it with the distance:

```js
// duration = clamp(deltaPx / 500, 0.15s, 0.27s)
const duration = Math.min(Math.max(deltaPx / 500, 0.15), 0.27);
```

A one-line change stays quick; a panel-sized jump gets room. Pair it with `--ease-drawer-height`.

## Tuning order

Duration and curve work as a pair, so name the symptom before changing either:

- **Starting fresh:** choose the curve family first, then a duration that suits it.
- **Feels slow:** shorten the duration.
- **Feels flat or lifeless:** strengthen the curve; leave the duration.

## How often it is seen

Count how many times a day one person sees the motion:

- **A hundred times or more** (a primary action, a row someone opens all day): no decorative or entrance motion. Brief pointer or touch press feedback, up to 150ms, is the one allowance ([Fleet policy](../../../policy.md#interaction-defaults)).
- **Dozens of times** (hovering through a list, moving between items): no movement; an instant colour change at most. A 200ms hover repeated fifty times a day feels like drag.
- **Now and then:** standard motion from the table above.
- **Rarely, or once** (a first-run welcome): room to be expressive.

No guideline removes more bad motion than this one. A control used two hundred times a day should feel instant; a welcome seen once can take its time.

Context menus count as frequent: they open at once, and only their exit may fade.

One thing moves at a time. When several elements change together, let one carry the movement and keep the rest still or fading only; two things travelling at once split attention.

## Reduced motion

Every duration above is for full motion. Under `prefers-reduced-motion` the movement is removed, never just shortened; the tiers are in [accessibility](accessibility.md).
