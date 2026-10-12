# Scroll animation

Scroll gets more motion added to it than any other trigger, so this file starts with when not to, and only then how. Scrolling belongs to the person: motion may answer it, but never takes it over and never makes content wait.

---

## Should it exist at all

Ask these before writing any scroll animation:

- **Product UI gets none.** Tables, dashboards, settings and feeds show their content at once. Scroll reveals belong to marketing and editorial pages, which people read once. The one product exception is chrome reacting to scroll position, such as the edge fade under a sticky header in [materials-and-depth](materials-and-depth.md).
- **Nothing above the fold is revealed on scroll.** It is already on screen; waiting for a scroll can only delay it.
- **Two to four reveals per page at most.** When every section fades in, nothing stands out.
- **Each reveal has a job**: to explain, to set a pace, or to give weight. If removing it changes nothing about how the page reads, remove it.

## Triggered or scrubbed

Every scroll animation is one of two kinds, and they follow different rules:

- **Triggered:** crossing a point starts an animation that then plays by itself, with its own duration and curve.
- **Scrubbed:** the scroll position is the timeline. It has no duration and no curve; the person's scrolling sets the speed, and any easing between position and progress breaks the one-to-one link. This is one of the few places `linear` is required ([easing-curves](easing-curves.md)).

## Reveal once

A reveal plays once. Playing it again on the way back up turns emphasis into noise: stop observing an element after it fires, and remember that it played when back-navigation would otherwise replay the page's entrance ([debugging-animations](debugging-animations.md) has the remembered flag).

## The reveal recipe

Content ships visible. Script adds the hidden state just before it starts watching, so a page whose script fails or loads late still shows everything:

```css
.reveal {
  --reveal-ease: cubic-bezier(0.19, 1, 0.22, 1); /* the expo curve from easing-curves.md */
  opacity: 0;
  transform: translateY(12px); /* 10-16px: a settle, not a journey */
  transition: opacity 500ms var(--reveal-ease), transform 500ms var(--reveal-ease);
}
.reveal.is-visible {
  opacity: 1;
  transform: none;
}
@media (prefers-reduced-motion: reduce) {
  .reveal { transform: none; transition: opacity 300ms ease; }
}
```

```js
const observer = new IntersectionObserver(
  (entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      entry.target.classList.add("is-visible");
      observer.unobserve(entry.target); // once
    }
  },
  { rootMargin: "0px 0px -10% 0px" } // negative: fires when the element is a tenth of the way in
);

document.querySelectorAll("[data-reveal]").forEach((element) => {
  element.classList.add("reveal"); // hidden only now that the script is running
  observer.observe(element);
});
```

- The 500ms sits in the 400-600ms marketing band ([timing-and-duration](timing-and-duration.md)), which a project declares in VISION.md's timing table. A 200ms product-speed reveal looks jittery on a landing page.
- The margin is negative, so the element is already partly visible when it animates. A positive margin fires while it is still off screen, and nobody sees the motion.
- A clip-path version of the same reveal is in [clip-path-animation](clip-path-animation.md).

## Staggered sections

On marketing pages, sibling reveals start 80-120ms apart, and the gap varies with importance in both delay and distance: the main element moves first and travels furthest, minor ones only fade. An even stagger ticks like a metronome and flattens the hierarchy. Product lists keep the 30-50ms cap. One entrance per container: reveal the section or its children, never both.

## CSS scroll-driven timelines first

For scrubbed motion, CSS needs no script and can run off the main thread:

```css
@supports (animation-timeline: view()) {
  .progress-figure {
    animation: fill-bar linear both; /* the shorthand comes first: it resets the timeline */
    animation-timeline: view();
    animation-range: entry 0% entry 100%; /* runs while the figure scrolls in */
  }
}
@keyframes fill-bar {
  from { transform: scaleX(0); }
  to   { transform: scaleX(1); }
}
```

Scroll-driven animations work in Chromium and Safari 26; Firefox does not support them yet (web-features 3.40.1, checked 3 October 2026). The `@supports` guard is why that is fine: without support the figure simply shows at its full size instead of sticking at the first frame.

## Which tool, in order

1. **CSS `animation-timeline`:** scrubbed, no script.
2. **Motion's `useScroll` with `useTransform`:** motion values update outside React's render, for mappings that need logic CSS cannot express.
3. **Never a raw scroll listener that sets state.** It runs every frame on the main thread and re-renders every frame, for work a single threshold check does once.

## Parallax

- Keep the speed difference at or under about 15%; beyond that, layers look detached.
- Decorative layers only, never body text.
- Scrubbed only, with no easing, and skipped on phones, where fast scrolling makes small offsets jitter.
- Off entirely under reduced motion.

## Pinned storytelling

A section that stays in place and plays a sequence as the person scrolls through it:

- Progress only moves forward: scrolling down never steps back.
- Pin for two or three screen heights at most; longer feels broken.
- Scrolling through must always get past it; the story never blocks the page.

## Never take over scrolling

No scroll hijacking, no snapping that fights the person, no smooth-scroll library that reimplements scrolling in script: each one adds delay to every wheel movement and breaks find-in-page. `scroll-behavior: smooth` is switched on only under `prefers-reduced-motion: no-preference` ([accessibility](accessibility.md)).

## `will-change` by how long it lasts

A scrubbed element animates for as long as someone scrolls, so a promoted layer earns its cost; declare it. A one-off reveal does not, and promoting it only wastes GPU memory. More in [performance](performance.md).

## Reduced motion

Following the tiers in [accessibility](accessibility.md): reveals keep their fade and lose the travel, decorative scrubbed motion (parallax, floating shapes) stops completely, and smooth scrolling goes off.
