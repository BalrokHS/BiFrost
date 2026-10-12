# Motion audit catalogue

The eight categories behind `motion-audit`. Each row names a signal to look for, why it is a defect or how to fix it, and the severity to file. Exact values come from the project's `VISION.md` first, then from the `frontend-design` reference the row names (timing-and-duration.md, easing-curves.md, practical-tips.md, performance.md, accessibility.md, spring-animations.md, exit-animations.md, view-transitions.md). Plans quote the value and where it came from.

What the lint covers: A3 and A6 are executable, and P7 checks durations when `VISION.md` has an animation timing table. A3 only looks at Motion components and a reduced-motion reference in the same file; it does not read CSS, keyframes or Tailwind classes. A1, A2, A4 and A5 are agent review. A finding under an agent-review ID is your judgement, never a lint result.

---

## 1. Frequency and purpose

The first question is whether this should move at all, and frequency answers it. The bands, from many times a session down to once, live in timing-and-duration.md; the audit spots surfaces filed in the wrong band.

| Signal | Why it is a defect | Severity |
| --- | --- | --- |
| Motion on anything a keyboard shortcut toggles | It runs hundreds of times a day and puts a delay between the key and the result. Keyboard-driven changes are instant, or take a zero-duration branch (practical-tips.md) | HIGH |
| A highlight that eases after arrow-key or pointer selection | It trails one step behind the input; the highlight should land with no transition | HIGH |
| A row hover with a transition, on a list used dozens of times a day | At that rate any delay is friction; timing-and-duration.md says remove it or make it instant | MEDIUM |
| Menu or list items that stagger in | Charming once, slower every time after | MEDIUM |
| Motion on a daily surface whose only reason is delight | The novelty wears off and the wait stays | MEDIUM |

Every animation needs a reason you can say in one sentence: feedback, keeping the person's place, showing a state, softening an abrupt change, explaining something, or, on rarely seen surfaces only, delight. When everything moves, nothing stands out.

Marketing pages are seen less often and are rarely interactive, so longer reveals and one-time intros can fit there. They are allowed when the project declares those bands in `VISION.md`'s animation timing table, which P7 then checks in place of the generic A2 ceiling.

---

## 2. Easing and duration

Easing families and named curves live in easing-curves.md, sorted from weakest to strongest. Durations, the UI ceiling and its one exception live in timing-and-duration.md.

| Signal | Why it is a defect | Severity |
| --- | --- | --- |
| `ease-in` on an interaction | The slow start lands exactly when the person is watching for a response, so the same duration feels much slower (easing-curves.md) | HIGH |
| A CSS keyword curve on a deliberate animation | The keywords accelerate too gently and the motion looks flat. Treat the keyword as a family and pick a named curve from that family in easing-curves.md. Plain `ease` on a large surface opened all day is the documented exception and passes | MEDIUM |
| `linear` anywhere but a spinner or marquee, a progress fill that shows time, or a scroll-scrubbed timeline | Constant speed reads as mechanical everywhere else | HIGH |
| A UI duration over the A2 ceiling with no `VISION.md` row | The ceiling and its exception for gesture surfaces are in timing-and-duration.md. With a timing table in the contract, P7 governs instead | MEDIUM |
| Enter and exit with the same duration | Leaving should be quicker than arriving; the ratio is in timing-and-duration.md | MEDIUM |
| A large or far-travelling element on a short duration | Duration grows with distance and size (timing-and-duration.md) | MEDIUM |
| `ease-in-out` on an element the person just pressed | The slow start reads as lag between the press and the response | MEDIUM |
| `transition: all` | It animates properties nobody chose, layout ones included, which can cost frames and breaks the transform and opacity rule in performance.md | HIGH |

Duration and easing work as a pair. A curve that front-loads its travel can carry a longer duration than a weak one, which is why a drawer on a steep curve can run past the usual ceiling without feeling slow. The tuning order is in timing-and-duration.md: choose the family first; if it feels slow, cut the duration; if it feels flat, strengthen the curve and leave the duration alone.

Perceived speed counts too: a faster spinner makes the same wait feel shorter (practical-tips.md).

---

## 3. Origin and physicality

| Signal | Fix | Severity |
| --- | --- | --- |
| An entrance from `scale(0)` | Start close to full size with opacity: from `scale(0.95)` and opacity 0, with larger surfaces starting closer to 1 (practical-tips.md). Nothing real grows out of a point | HIGH |
| A popover, menu or tooltip that scales from its own centre | Scale from the trigger with the library's origin variable: `--radix-<component>-content-transform-origin` in Radix, `--transform-origin` in Base UI (both written out in PLAN-TEMPLATE.md). Modals are exempt: they open centred | MEDIUM |
| Hover styling with nothing on press | Add press feedback: `scale(0.97)`, or `scale(0.94)` for an icon-only control, in at most 150ms (the interaction-feedback rule). Without it a click feels unheard | MEDIUM |
| A press scale you can plainly see | Press should be felt more than seen; a visible shrink is past the press value above | MEDIUM |
| `hover:scale-105`, or a hover that grows anything past 1.02 | The hover cap is 1.02 over 120 to 180ms (practical-tips.md); only very small targets go further | MEDIUM |
| A hover `translateY` on the element under the pointer | Move a child instead. Otherwise the element lifts away from the pointer, loses its hover, falls back under the pointer and loops | MEDIUM |
| A fixed pixel offset that hides an element of variable size | Use a percentage such as `translateY(100%)`, so the travel always equals the element's own size | LOW |

---

## 4. Interruption and springs

Transitions and springs retarget: interrupted halfway, they head for the new value from wherever they are. `@keyframes` restart from their first frame, however short they are (practical-tips.md). That is why keyframes on something triggered again mid-flight make it jump.

| Signal | Why it is a defect | Severity |
| --- | --- | --- |
| `@keyframes` on a surface that can be re-triggered before it finishes, such as a toast, toggle, accordion or drawer | A second trigger restarts the animation and the element jumps. Move it to transitions, except on Radix, where the exit must stay a CSS animation (the Radix carve-out below) | HIGH |
| A spring on something that must follow a finger exactly | A spring trails the pointer. Track with a raw motion value and spring only the release (spring-animations.md) | MEDIUM |
| Bounce on a press, a dismissal, a dashboard or anything serious | No bounce is the default. A small overshoot fits only when a drag is released, because the drag carries momentum. A6 catches overshooting curves and bounce keywords; everything else here is review | MEDIUM |

### The Radix carve-out

Radix primitives, and shadcn styles built on them, keep closing content mounted only while a CSS animation runs: Presence compares the element's `animation-name` before and after `data-state` turns to `closed`, and waits for `animationend` only when the name changed. A transition is never waited for, so content whose exit is written as a transition unmounts at once and the exit never plays. On Radix, keep `@keyframes` keyed to `data-state="open"` and `data-state="closed"`, give the closing state its own animation name, and accept that a quick re-open restarts the keyframes: do not file that, and never plan a move to transitions.

Base UI waits for transitions and animations alike, through `element.getAnimations()`, so on Base UI the move to transitions with `data-starting-style` and `data-ending-style` stands. shadcn can sit on either library: read `components.json` and the imports (`radix-ui` or `@base-ui/react`) before choosing.

Sources, checked 3 October 2026: Radix [animation guide](https://www.radix-ui.com/primitives/docs/guides/animation) and [Presence source](https://github.com/radix-ui/primitives/blob/67cbe801b93768e273e2549388a27490e26df5f3/packages/react/presence/src/presence.tsx); Base UI 1.8.0 [animation handbook](https://base-ui.com/react/handbook/animation) and [Menu](https://base-ui.com/react/components/menu).

Spring settings belong to spring-animations.md: the default with no bounce, the option for gestures, smaller bounce for larger elements, and the repair rule that a spring which feels odd usually needs more damping. CSS cannot make a real spring; `linear()` only approximates one. A spring library also costs bundle size, which is a real trade-off.

For an enter transition in plain CSS without a mounted flag, `@starting-style` gives the start values (practical-tips.md).

---

## 5. Performance

The frame budget and the rule to animate only `transform` and `opacity` are in performance.md. The lint does not check this category: animating layout properties is A4, an agent-review criterion.

| Signal | Fix | Severity |
| --- | --- | --- |
| Animating `width`, `height`, `padding`, `margin`, `top` or `left` | Use `transform` and `opacity`: `scale` in place of padding, `translate` in place of margin (performance.md). It can be tolerable on an absolutely positioned element, or one with almost no children | HIGH |
| Children's transforms driven by an inherited custom property that changes every frame | Set the transform on the element itself; a changing inherited variable restyles every descendant (performance.md) | HIGH |
| Motion's `x`, `y` and `scale` shorthands on an animation that plays during heavy main-thread work | Write the whole `transform` value instead; the shorthands are driven from the main thread (performance.md) | MEDIUM |
| Motion driven by `requestAnimationFrame` during heavy work such as page loads or long lists | Move it to CSS or the Web Animations API, which keep running smoothly when the main thread is busy (performance.md) | MEDIUM |
| Animating through React state every frame | Bypass React: update the element's style or a motion value, since a state change re-renders on every frame (performance.md) | MEDIUM |
| An animated `blur()` above the cap in performance.md | Large blurs get slow quickly, Safari most of all | MEDIUM |
| A transform animation that shifts by one pixel as it starts or settles | Promote that element with `will-change: transform` (practical-tips.md) | LOW |

`will-change` treats jank you have seen; it is not a default, and the promoted layer should stay small (performance.md).

---

## 6. Reduced motion and access

Under `prefers-reduced-motion: reduce`, the movement goes and the meaning stays. The tiers are in accessibility.md: anything that travels, scales or rotates is removed, not shortened; opacity and colour changes may stay; decorative loops stop on a representative frame; direct manipulation keeps tracking the finger one to one and settles without bounce.

| Signal | Fix | Severity |
| --- | --- | --- |
| Movement with no reduced-motion branch | Apply the tiers: under `reduce` nothing travels, and a fade may carry the change. A3 only checks Motion components, so CSS, keyframes and Tailwind classes need your own reading | HIGH |
| A Tailwind reduce class that loses to the class it should cancel | On shadcn components, adding `motion-reduce:animate-none` changes nothing: shadcn's `data-open` variant adds no specificity (it is wrapped in `:where()`) and Tailwind writes it after the `motion-reduce` rule, so `data-open:animate-in` wins. Gate the movement classes with `motion-safe:` instead (`motion-safe:data-open:zoom-in-95`, `motion-safe:data-[side=bottom]:slide-in-from-top-2`), which keeps the fade. Measured on 3 October 2026 with Tailwind 4.3.3, tw-animate-css 1.4.0 and shadcn 4.21.1 in Chromium 153 | HIGH |
| Video, a GIF or an animation that plays on its own and ignores `reduce` | Stop the autoplay; the static `<picture>` fallback and the play-button pattern are in accessibility.md | MEDIUM |
| A decorative loop still running under `reduce` | Stop it on a representative frame, with `animation-play-state: paused` and a negative `animation-delay`, never frame 0 (accessibility.md) | LOW |
| `scroll-behavior: smooth` set for everyone | Make smooth scrolling the opt-in: set it inside a `no-preference` query instead of removing it inside a `reduce` query (accessibility.md) | LOW |
| Hover motion that also fires on touch | Gate it with `@media (hover: hover) and (pointer: fine)` (accessibility.md). Tailwind v4 already wraps its `hover:` variant in `@media (hover: hover)`; hand-written `:hover` is not covered, and neither is `pointer: fine` ([Tailwind variant reference](https://tailwindcss.com/docs/hover-focus-and-other-states), checked 3 October 2026) | MEDIUM |
| A control below the minimum target size | Grow the hit area with a pseudo-element, not the visual: 44px on touch, 32px with a pointer (the interaction-feedback rule) | MEDIUM |
| An explanatory animation deleted outright under `reduce` | Keep the meaning: step between its key frames instead of tweening (accessibility.md) | MEDIUM |
| Gesture tracking weakened or removed under `reduce` | The person's own movement keeps tracking one to one; only the release changes, settling with no bounce (accessibility.md) | MEDIUM |

In apps that use Motion, `<MotionConfig reducedMotion="user">` makes every Motion component follow the system setting, and `useReducedMotion()` lets one component choose different values. It defaults to `"never"`, so set it explicitly (accessibility.md).

---

## 7. Cohesion and space

| Signal | Fix | Severity |
| --- | --- | --- |
| Parts of one component on unrelated durations and curves | Put them on one timing family so the component moves as one object (easing-curves.md) | MEDIUM |
| Something that slides in from a side and fades out | Leave the way it came: the exit mirrors the entry (exit-animations.md). A sidebar that arrived from the left lives on the left | MEDIUM |
| Back and next moving in the same direction | Forward and back travel opposite ways, so the motion agrees with the direction of travel | MEDIUM |
| A card or thumbnail that vanishes while its full-screen view fades in | Grow the view from where the thumbnail sits. Shared elements across pages use the View Transitions API; morphs within a page that it cannot express use `layoutId` (view-transitions.md) | MEDIUM |
| A panel that animates in and then staggers its children | Animate the container once and let its content arrive with it, so reading can start at once | MEDIUM |
| A stagger with the same delay, distance and curve for every item | Lead with the most important item and give it the most travel; minor items can simply fade | LOW |
| A stagger step past the product cap | Product stagger is 30 to 50ms per item (timing-and-duration.md); longer bands are marketing choices a project declares in `VISION.md`. A stagger never blocks input | LOW |
| A full-width slide inside a small container | Swap the content with a fade and a few pixels of shift; it is calmer and the eye barely has to travel | LOW |
| A crossfade that reads as two objects however it is timed | A small blur during the change joins them (practical-tips.md) | LOW |
| Motion that goes against the declared personality | Match what phase 1 read from `VISION.md`, DECIDED feedback and the taste profile, never your own taste | LOW |

---

## 8. Missing motion

Not this skill's hunt: design-review's motion opportunities reference owns the search. During an audit, note what you happen to see, list it after the findings table, and go no further. Each item still has to earn its place under category 1: used often enough to matter, with a reason you can state. Items nobody takes become OPEN entries in `FEEDBACK.md`.

Worth noting when you see it:

- A pressable element with hover styling and no response to the press.
- A toast, dialog, popover or drawer that pops in with no transition where the jump is jarring.
- Two states of one object, such as a selection turning into a delete confirmation or a form turning into its success message, that would read better as one morph.
- A view opened from a card that crossfades to full screen instead of growing out of the card.
- A height that jumps between the steps of a flow.
- Text whose change alters what the next click does, where making the change visible helps.
- An instant destructive action that would be safer as hold to confirm: a `linear` fill that shows the time, which springs back quickly with an ease-out when the person lets go.
- A spinner that turns slowly: a faster one makes the same wait feel shorter.
- On marketing pages only: scroll reveals, a hero whose staggered timing guides the eye, an animation that explains better than a still image, a hidden detail for people who look.

---

## Exempt from filing

- A modal with `transform-origin: center`: a modal belongs in the middle of the screen.
- `linear` on a marquee, a spinner, a fill that shows time passing (hold to confirm, timers, progress) or a scroll-scrubbed timeline.
- Marketing durations, staggers and one-time intros that sit in rows of the project's `VISION.md` timing table: P7 checks those.
- Plain `ease` on a large surface opened all day: the softening exception in easing-curves.md.
- Bounce a design note explains as a brand choice.
- `@keyframes` on something that cannot be triggered again while it plays.
- `@keyframes` that drive a Radix exit (the carve-out in category 4).
- Motion the code documents as a deliberate trade-off.
