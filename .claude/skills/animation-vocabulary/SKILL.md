---
name: animation-vocabulary
description: Names a motion effect from a loose description. Use when someone asks what an effect is called, such as what do you call it, what's the name for it, or the word for an animation, transition or effect. Carries the fleet's house terms and links the full motion glossary. Naming only; frontend-design builds the effect and design-review judges one.
---

# Animation vocabulary

Read the [Fleet policy](../../policy.md) for instruction precedence and evidence requirements.

Someone describes what they see or feel ("it springs open too far", "the page jumps when the scrollbar shows up") and wants the word to ask for it.

## How to answer

- Lead with the term and one line on what it looks like. Add one or two close terms only when they compete, and say how they differ.
- Any correct term is fine, including terms not listed here. This list is a guide, not a fence.
- When no single term fits, describe the effect with the nearest terms and say it is an approximation.
- Stay in naming. Offer frontend-design once, for building it; do not build here.

## Extra mile

What a cold Opus missed or half named in the 2 October naming probe (24 descriptions, no fleet). Measured probes decide whether any join the craft file that loads with the house file; until then they stay here. Brackets give the probe's answer.

- **Layered entry**: a container enters, then its contents enter again inside it. One entrance per container. [missed: "over-choreography"]
- **Trackability threshold**: motion so fast the eye cannot follow it. Too fast fails just as too slow does. [missed: "reads as a jump cut"]
- **Pop in**: an entrance that overshoots its size slightly and settles. [partial: "overshoot"]
- **Two-tap pattern**: on touch, the first tap shows what hover would show and the second acts. [partial: "sticky hover, double-tap"]

## House terms

A cold model names these; they stay for the rule the fleet attaches.

- **Scale from zero**: an entrance that grows from nothing. Start close to full size instead: `scale(0.95)` with a fade, `scale(0.98)` for a large panel.
- **The lift**: a hover that raises a card, done on an inner element so the hovered box stays under the pointer.
- **Hover flicker**: the loop when a hover moves the element off the pointer, the hover drops, and it starts again. The lift fixes it.
- **Perceptual duration**: when a spring looks done although it is still settling (Motion's `visualDuration`).
- **Blur transition**: a light blur across a state swap, so two frames read as one change. Never on text someone reads.
- **Ease**: the plain CSS keyword, the house curve for hover and colour changes, at 120 to 180ms.
- **Linear**: only for constant motion and time shown as progress: marquees, spinners, timers, hold-to-confirm fills, scrubbed scroll.
- **Scrubbed vs triggered reveal**: scrubbed follows the scroll both ways; triggered plays once as the element enters view.
- **Reduced motion**: in tiers. Remove movement, keep fades that carry meaning, pause decorative loops on a representative frame, keep gestures one to one.
- **Hardware acceleration**: transform and opacity are the safe properties; others composite in some engines only, so acceleration is a bonus.
- **Animations as proof of care**: motion no screenshot shows and no framework supplies, added on purpose.

## Basics

Fade, slide, stagger, springs, the easing families, view transitions, jank and the rest are standard words a strong model names unaided. The glossary lists them for people. Interface motion stays under 300ms; the frontend-design references hold every other number.
