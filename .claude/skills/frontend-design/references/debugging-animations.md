# Debugging animations

A method for motion that looks wrong: give "something is off" a name and a cause, then make the smallest change that fixes it. Never nudge values at random; that produces another animation, not an improved one, and you lose track of what helped.

---

## The loop

1. **See it where it runs.** Serve the development build on your local network and open it on the real phone. A gesture that is smooth on a laptop can stutter on a mid-range phone, and a fade can look clean on one refresh rate and rough on another, so check both a 60Hz and a 120Hz screen. Nothing seen on the wrong screen counts.
2. **Slow it down.** Set the DevTools Animations panel to 10-25% speed, or record the screen and step through it frame by frame. This step finds the most: a fade that starts late, an origin in the wrong place, two states that read as two objects, all invisible at full speed and plain at a quarter.
3. **Name what you see.** Find the symptom in the tables below and work down its list; the causes are ordered by how often they are the answer.
4. **Change one thing, record again, compare.** The symptom tells you which thing: if it feels slow, shorten the duration; if it feels flat, make the curve steeper and leave the duration. (Starting from nothing is the exception: pick the curve family first, then a duration to suit it.) Curve and duration depend on each other, since a steep curve can carry a longer duration, so never change both in one round.
5. **Check it at full speed, and again another day.** Something approved only in slow motion has not been approved. For anything that ships, look at it again the next morning: problems you cannot see after an hour of tuning are often obvious after a night's sleep.

## "It feels slow"

| Check, in this order | Fix |
| --- | --- |
| `ease-in` on it | Switch to a strong ease-out. A slow start delays exactly the moment the person is watching; the same duration feels faster at once ([easing-curves](easing-curves.md)). |
| A built-in keyword curve on an entrance, a move or a drawer | Use a named curve from [easing-curves](easing-curves.md). Keywords are fine for hover, colour and the press, where the house rules use them; on bigger motion they read as nobody's choice. |
| Longer than the UI ceiling | Shorten it: a dropdown at 180ms feels quicker than one at 400ms. Bands and the gesture exception are in [timing-and-duration](timing-and-duration.md). Only a very steep curve (`--ease-drawer`) justifies length, and anything over 300ms ships only as a declared row in VISION.md's timing table. |
| It plays on something used constantly (keyboard moves, a shortcut, a hover passed all day) | Remove it. At that frequency every duration is lag; the fix is deletion, not tuning ([timing-and-duration](timing-and-duration.md)). |
| A delay between the action and the response | Remove it or cut it right down. When feedback waits, the interface seems unsure of itself. Delays are for spacing elements in a sequence, never for the first answer to an input. |

## "It feels mechanical or dead"

| Check, in this order | Fix |
| --- | --- |
| `linear` on motion that is not constant | Physical things do not move at one speed. Pick the family that matches the motion; `linear`'s short list of uses is in [easing-curves](easing-curves.md). |
| The curve is too weak | Flat is a curve problem, not a duration problem: steepen it (loop step 4). |
| A fixed duration where motion should feel physical (a drag release, a morphing pill) | Use a spring; a fixed duration cannot take the release velocity or settle naturally ([spring-animations](spring-animations.md)). |
| The spring itself feels wobbly, mushy or overshoots | Raise `damping` first. Most odd-feeling springs are under-damped; touch stiffness or mass only once the wobble is gone. |
| Every item in a list staggers the same | An even delay over an even distance ticks like a clock and gives every item equal weight. Vary both by importance: the main item lands first and travels least, the rest follow later and from further away. |

## "It feels cheap, and I cannot say why"

| Check, in this order | Fix |
| --- | --- |
| It grows from `scale(0)`, or only fades | Enter from `scale(0.95)` (`0.98` for large surfaces) with a fade; starting nearly full size reads as something already there, arriving ([practical-tips](practical-tips.md)). |
| The origin is wrong | Popovers, menus and tooltips grow from their trigger, not their centre. At low speed a wrong origin is obvious ([practical-tips](practical-tips.md) has each library's origin variable). |
| A crossfade shows two overlapping things | A light `filter: blur(2px)` on both layers during the change makes them read as one thing changing ([practical-tips](practical-tips.md)). |
| Parts of one component run on different clocks | Put them on one timing family; see the note below. |
| Entrance and exit do not match | Leave the way you came, about 20% faster and simpler: the decision is made, so get out of the way ([exit-animations](exit-animations.md)). |
| The motion does not fit the product | Bounce suits a playful app; a dashboard wants crisp, settled motion. See the note on documented exceptions below. |

> **Delta knowledge:** one component, one clock. When a component runs several animations at once (opening, a height change, a crossfade), they share one timing family or the component falls apart into pieces. An auto-height drawer that opens on a 500ms library default while its height changes in 200ms reads as two objects; bring the opening down to match. The slowest part is the one people feel.

**Documented exceptions.** A weaker built-in curve can stay when someone chose it on purpose, for the product's personality, and wrote it down: a well-known toast library uses plain `ease` where the general advice says ease-out, because it suited its character. On a contract project, propose it as a VISION.md timing row (where, duration, curve, why) and wait for approval; never write VISION.md unasked. This applies to new work: never rewrite curves the product already uses unless someone asks.

## "It drops frames"

| Check, in this order | Fix |
| --- | --- |
| It animates `width`, `height`, `margin`, `padding`, `top` or `left` | Use `transform` and `opacity` instead; layout properties cost layout, paint and composite every frame ([performance](performance.md)). |
| React state changes every frame (scroll, drag or a frame loop calling `setState`) | Move the value into a motion value, or write the style directly; one render per frame means a dropped frame per frame. |
| A custom property on a parent moves the children | Set `transform` on the moving element. The cost grows with the number of descendants and shows past roughly 20 items: fine in a demo, slow in the product. |
| Motion's `x`, `y` or `scale` stutter only while the app is busy | Motion composes them on the main thread, so data loading and rendering starve them. Animate a full `transform` string, or move that animation to CSS or WAAPI ([performance](performance.md)). |
| An animated `blur()` over about 20px | Keep it under that; blur gets expensive fast as the radius grows, worst in Safari. |

## "It jumps or snaps"

| Check, in this order | Fix |
| --- | --- |
| It jumps when triggered again quickly (stacked toasts, fast toggles) | `@keyframes` start over each time. Use a transition or a spring, which continue from where the element is ([practical-tips](practical-tips.md)). |
| The exit never plays | The `AnimatePresence` child has no `key`, or the wrapper sits inside the condition instead of around it ([exit-animations](exit-animations.md), [motion-react](motion-react.md)). |
| A height snaps instead of animating | Chromium animates to `auto` with `interpolate-size: allow-keywords`; Firefox and Safari do not yet. Where every browser must animate, measure the content and animate to the number ([container-animation](container-animation.md)). Then check the padding note below. |
| A one-pixel shift at the start or end | The browser is moving the element between rendering paths; `will-change: transform` on that element keeps it on one ([practical-tips](practical-tips.md)). |
| Content shows in its final state, then animates | The starting state arrives after the first paint. Set it in CSS, or with `@starting-style`, so the element first appears already hidden. |

> **Delta knowledge:** measure the element that owns the padding. In measure-and-animate, if the padding sits on the animated outer element while the ref measures the content inside, the number comes out short by exactly that padding. The container animates to a height the content never fits, and what looks like a snap is a wrong measurement. Full pattern in [container-animation](container-animation.md).

## "It fires when it should not"

| Check, in this order | Fix |
| --- | --- |
| A hovered element flickers between states | The animation moves it from under the cursor, the hover ends, it moves back. Move a child and keep the hovered parent still ([practical-tips](practical-tips.md)). |
| Hover effects fire on phones | A tap counts as a hover; put hover effects inside `@media (hover: hover) and (pointer: fine)`. |
| Tooltips along a row each animate as the cursor passes | Once one tooltip is open, the next should appear at once. Base UI marks that with `data-instant`; Radix reports `data-state="instant-open"` ([practical-tips](practical-tips.md)). |
| A scroll reveal fires too early or too late | The in-view margin should be negative: `margin: "-100px"` fires once the element is 100px inside the viewport; a positive margin fires while it is still off screen ([motion-react](motion-react.md)). |
| A reveal replays on every pass, and again after going back | Intro and reveal animations play once per visit, not once per intersection. Stop observing after the first time and remember that it played, as below. |

Read the remembered flag in an effect, after hydration. The server has no `sessionStorage`, so reading it during render makes the first browser render differ from the server's HTML, a hydration mismatch React reports and does not repair.

```tsx
import { motion, useInView, useReducedMotion } from "motion/react";
import { useEffect, useRef, useState, type ReactNode } from "react";

export function Reveal({ id, children }: { id: string; children: ReactNode }) {
  const ref = useRef(null);
  const visible = useInView(ref, { once: true, margin: "-100px" }); // stops watching after the first time
  const reduce = useReducedMotion();
  const [shownBefore, setShownBefore] = useState(false); // read after hydration, below

  useEffect(() => {
    if (sessionStorage.getItem(`revealed:${id}`) === "1") setShownBefore(true);
  }, [id]);

  useEffect(() => {
    if (visible) sessionStorage.setItem(`revealed:${id}`, "1");
  }, [visible, id]);

  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, y: 24 }}
      animate={shownBefore || visible ? { opacity: 1, y: 0 } : { opacity: 0, y: 24 }}
      // Seen earlier this visit: show it at once. Reduced motion: fade only, no travel.
      transition={shownBefore ? { duration: 0 } : reduce ? { y: { duration: 0 } } : undefined}
    >
      {children}
    </motion.div>
  );
}
```

`reduce` changes only the transition, never `initial`, so the server and browser markup still match for someone who prefers reduced motion.

## When no row fits

The animation may be built exactly as specified and still be wrong, because the specification is. Work back from the start, each answer narrowing the next:

1. **How often:** should it animate at all ([timing-and-duration](timing-and-duration.md))?
2. **Curve family:** the right family for this kind of motion ([easing-curves](easing-curves.md))?
3. **Duration:** right for that curve and for the element's size?

Tuning the duration under the wrong curve polishes the wrong answer.

**Compare with something that works.** When another product does this exact motion well, record it and step through both recordings side by side at quarter speed. Differences you could not reason about (a pause you lack, a settle twice as long, an origin you misplaced) become visible frame by frame.

When a crossfade resists every curve, the 2px blur bridge in [practical-tips](practical-tips.md) is the accepted last resort.

## Every fix keeps its reduced-motion path

A repaired animation is still an animation. Under `prefers-reduced-motion` its movement goes entirely, never just shortened; opacity and colour fades may stay; decorative loops pause on a chosen frame; direct manipulation stays 1:1. Tiers and code in [accessibility](accessibility.md).
