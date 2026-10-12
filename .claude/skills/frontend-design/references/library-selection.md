# Library selection

Which tool builds a given piece of UI or motion: a short list of trusted options, not a survey. A situation goes in, one recommendation comes out. Proven libraries usually beat what you would write this afternoon, and the project's own dependencies beat both.

A library named in VISION.md overrides every default here. Every recipe follows the reduced-motion tiers in [accessibility](accessibility.md).

Versions and dates below come from the npm registry and each project's own pages, read on 3 October 2026 by anonymous request.

---

## How to recommend

1. **Look in `package.json` first.** If something installed already does the job, that is the answer; suggesting another animation or primitives library alongside it is a problem to report, not advice.
2. **Answer the need, not the library named in the question.** "Add a toast" is a toast question even if it mentions Motion.
3. **Recommend one thing.** List alternatives only when asked.
4. **Say so when you go beyond this list**, before naming anything that is not on it.

## Which tool for which job

| Situation | Use | Why |
| --- | --- | --- |
| A change the person triggers, maybe many times in a row: hover, open and close, stacked toasts, quick toggles | **CSS transitions** | They redirect halfway from the current value; `@keyframes` start over, which is the classic jumping-toast bug ([practical-tips](practical-tips.md)) |
| An endless loop: marquee, spinner | **CSS `@keyframes`** with `animation-iteration-count: infinite` | Nothing more needed; the one UI home of `linear` ([easing-curves](easing-curves.md)) |
| A one-off sequence that runs by itself: an intro, a staggered entrance | **CSS `@keyframes`** with per-item custom properties | `animation-delay: calc(var(--i) * var(--stagger))` plus `animation-fill-mode: backwards`, no script (example below) |
| A simple entrance nobody interrupts: a dialog fade, a popup | **`@starting-style`** or plain keyframes | No mounted state and no `useEffect` ([practical-tips](practical-tips.md)) |
| Has to keep moving during heavy main-thread work | **CSS**, or **WAAPI** when script must control it | Composite-only properties can run off the main thread; WAAPI keeps a scripted effect next to its logic ([performance](performance.md)) |
| Springs, dragging, momentum, interruption that keeps velocity | **Motion for React** | CSS has no real spring (`linear()` only traces one); `drag` comes with momentum ([spring-animations](spring-animations.md)) |
| Animating out a component React has removed | **Motion**, `AnimatePresence` | The node is gone, so CSS has nothing left to animate ([exit-animations](exit-animations.md)) |
| A shared element across a route change, or a whole region swapping | **View Transitions** (`<ViewTransition>` in React 19.3) | Native, and same-document transitions are Baseline since October 2025 ([view-transitions](view-transitions.md)) |
| A morph within a page that the API cannot express or that must be interruptible: a tab indicator, a `flex-direction` change, a card opening in place | **Motion**, `layout` or `layoutId` | Animates layout CSS cannot, and retargets mid-flight |
| A light and dark theme switch | **View Transitions** | A clipped duplicate of the whole page is a hack; the API animates between snapshots |
| A scroll reveal when Motion is not installed | **IntersectionObserver** | Never add an animation library just to learn that an element scrolled into view |
| Menu, select, combobox, tabs, tooltip, navigation menu | The installed primitive library: **Base UI** or **Radix** | Keyboard, focus and ARIA are hard to get right (table below) |
| A lone dialog or popover, or a project with no dependencies | Native **`<dialog>`**, **`popover`**, **`inert`** | The platform provides the top layer, light dismiss and focus containment ([interaction-design](interaction-design.md)) |

In short: CSS for simple motion on cheap properties, Motion for physical or complex motion. Using both in one project is normal.

A one-off stagger with no script and no library:

```css
/* <li style="--i: 0">, <li style="--i: 1">, … */
.item {
  --stagger: 40ms;
  animation: item-enter 240ms cubic-bezier(0.215, 0.61, 0.355, 1) backwards;
  animation-delay: calc(var(--i) * var(--stagger));
}

@keyframes item-enter {
  from {
    opacity: 0;
    transform: translateY(8px);
  }
}
```

People judge what they see, not whether it was CSS. If the right feel needs a library, use one: bundle size rarely spoils an experience, and animating the right properties keeps frames steady ([performance](performance.md)).

## Primitives: do not build these yourself

An accessible dropdown is hard; so are a select, a toast and a navigation menu. Unstyled primitives handle keyboard support, focus and ARIA and leave the look entirely to you.

| Need | Use |
| --- | --- |
| Dialog, popover, menu, select, tabs, tooltip, navigation menu | The primitive library already installed; on a new project, **Base UI** |
| Toast | The toast that comes with the installed family (shadcn's Base UI Toast in a Base UI project); otherwise **Sonner** |
| Drawer or bottom sheet | The installed library's drawer (**Base UI** ships one); **Vaul** only where it is already installed |

- **Base UI** (`@base-ui/react` 1.8.0, 4 September 2026; stable 1.0 on 11 December 2025) is shadcn/ui's default for new projects since July 2026: "New projects now use Base UI by default. Radix is still fully supported." ([shadcn changelog, July 2026](https://ui.shadcn.com/docs/changelog/2026-07-base-ui-default); [Base UI releases](https://base-ui.com/react/overview/releases)). Its animation hooks are `data-open` and `data-closed`, `data-starting-style` and `data-ending-style`, a `--transform-origin` variable on positioned popups, and `data-instant` for a tooltip that should appear without animating ([Base UI tooltip](https://base-ui.com/react/components/tooltip)). It waits for CSS transitions as well as animations before unmounting ([Base UI animation](https://base-ui.com/react/handbook/animation)). Its Drawer adds swipe gestures and snap points ([Base UI drawer](https://base-ui.com/react/components/drawer)), and shadcn added a Toast built on Base UI in July 2026 ([shadcn changelog](https://ui.shadcn.com/docs/changelog/2026-07-toast)).
- **Radix** (`radix-ui` 1.6.7, 24 July 2026) is mature and still a good choice where installed. shadcn ships every new component for both libraries unless one exists only in Base UI, and tells existing projects they do not need to migrate (same changelog). Its animation hooks are a `transform-origin` variable per component (for example `--radix-tooltip-content-transform-origin` on the [Tooltip page](https://www.radix-ui.com/primitives/docs/components/tooltip) and `--radix-dropdown-menu-content-transform-origin` on the [Dropdown Menu page](https://www.radix-ui.com/primitives/docs/components/dropdown-menu)), `data-state` for enter and exit, and `data-motion` for direction-aware transitions in the [Navigation Menu](https://www.radix-ui.com/primitives/docs/components/navigation-menu); a closing component stays mounted while a CSS keyframe animation plays ([Radix animation guide](https://www.radix-ui.com/primitives/docs/guides/animation)). All read 3 October 2026.
- **React Aria** (`react-aria-components` 1.21.1, 4 September 2026, Apache-2.0) is the other credible option.
- **Sonner** (`sonner` 2.0.8, 9 August 2026) is maintained. Its API is in [interaction-design](interaction-design.md).
- **Vaul** is unmaintained: its README says so (Vaul 1.1.2, last release 14 December 2024). Keep it where it is installed; do not add it to a new project.

> **Delta knowledge:** a new default is no reason to switch. Code that works on Radix keeps working, and shadcn still supports it. Recommend Base UI for a new project with no primitives yet; keep Radix where it is installed. Moving from one to the other is real work (`asChild` becomes `render`, Content splits into Positioner and Popup, the data attributes change), not a quick swap.

## Animation libraries

### Motion for React

`motion` 14.0.0 (2 October 2026, MIT; formerly Framer Motion). Import from `motion/react`; outside React, use vanilla Motion.

- **For:** springs, layout and shared-layout animation, a lot of motion from little code, an API shaped for React.
- **Against:** bundle size, and behaviour that is hard to see into when it goes wrong.

Prefer the declarative API (`initial`, `animate`, `exit`); the imperative `useAnimate` is rarely needed. Details in [motion-react](motion-react.md).

### React Spring

`@react-spring/web` 10.1.2 (24 June 2026, MIT). Spring-based and lighter than Motion, with fine control. Against it: a steeper learning curve and more code for the same result. It is often paired with `@use-gesture/react`, whose last release, 10.3.1, dates from 21 March 2024, so check that pairing before adding it. Recommend React Spring when spring control matters more than speed of development.

### GSAP

`gsap` 3.15.0 (13 April 2026). Works with any framework, has an excellent timeline, and is widely used on award-site work. Against it: no velocity-preserving springs, and it is not shaped for React (a `useGSAP` hook exists). It costs nothing, plugins included, but its licence is Webflow's proprietary GSAP Standard License, not an open-source licence, and it prohibits use in tools for building visual animations without code that compete with Webflow ([GSAP standard license](https://gsap.com/community/standard-license/); the npm licence field names the same terms). Read it before adding GSAP to an open-source package or to a builder or editor product. It suits marketing pieces built on timelines; product UI that needs springs should use something else.

Anime.js and Popmotion are off this list and are not default recommendations.

## Small utilities

| Need | Use |
| --- | --- |
| Read an element's size so its height can follow its content ([container-animation](container-animation.md)) | `react-use-measure` (2.1.7, 30 January 2025) |
| Close on a click outside | `useOnClickOutside` from `usehooks-ts` (3.1.1, 5 February 2025) |
| Conditional and merged class names | The project's `cn()`. Stock shadcn 4.21.1 imports it from the `cn` package (0.4.0, 22 September 2026), which replaces `clsx` and `tailwind-merge`; older projects keep `clsx` (2.1.1) with `tailwind-merge` (3.7.0). Never add one beside the other ([nextjs-tailwind](nextjs-tailwind.md)) |
| Hover gating, hit areas, arbitrary transforms | Tailwind; v4 wraps `hover:` in `@media (hover: hover)` |

## Whether to add a dependency at all

- **Count what it saves.** Someone spent weeks on that navigation menu; an afternoon will not match it.
- **Size is a trade-off, not a veto.** A drawer built without a spring library stays small but cannot give its snap points the slight bounce iOS has. Make that kind of trade explicit: say what the bytes buy and what they cost.
- **Do not chase what is new.** Stitches was the exciting choice and was widely adopted, and then its maintenance ended. Ask which problem a library solves for this project, not how popular it is this month.

## Flag these on sight

1. A hand-built toast, drawer, dropdown, select or tooltip with its own focus and keyboard code.
2. Motion added for a plain hover or a simple fade; CSS does that.
3. A second animation library next to one already installed.
4. `@keyframes` on anything that can fire again while still playing; transitions continue, keyframes restart.
5. A heavy dependency whose only job is noticing an element entering the viewport.

This file picks the tool. How to drive it is elsewhere: curves in [easing-curves](easing-curves.md), durations and frequency in [timing-and-duration](timing-and-duration.md), springs in [spring-animations](spring-animations.md), frame cost in [performance](performance.md).
