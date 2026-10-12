# View transitions

The browser animates between two DOM states by taking a snapshot of each ([MDN View Transition API](https://developer.mozilla.org/en-US/docs/Web/API/View_Transition_API), checked 3 October 2026): a route change, a thumbnail growing into a detail view, a list reordering. Same-document view transitions are Baseline since October 2025 (web-features 3.40.1, checked 3 October 2026). The work is choosing which elements pair, naming them correctly, and keeping reduced motion honest.

Two rules decide most bugs. A name may sit on only one rendered element while a transition runs; if two share it, the browser skips the transition. And names you set by hand must be cleared afterwards, or the next transition finds a duplicate ([Chrome view transitions guide](https://developer.chrome.com/docs/web-platform/view-transitions/same-document), checked 3 October 2026).

## Which tool

- **Across a navigation, or a whole region swapping content:** view transitions.
- **An in-page morph the person may interrupt** (a tab indicator, a card expanding while they click again): Motion `layout` or `layoutId`. Only one view transition runs at a time, and a new one makes the running one skip to its end, so a fast second click jumps; Motion retargets from where the element is.

## React: `<ViewTransition>`

`<ViewTransition>` is stable in React 19.3 ([React 19.3](https://react.dev/blog/2026/09/09/react-19-3)). It only animates updates React treats as a Transition: `startTransition`, a `<Suspense>` reveal, or `useDeferredValue`. A plain `setState` does not animate ([ViewTransition reference](https://react.dev/reference/react/ViewTransition)). In the Next.js App Router it works without configuration, and route navigations are already transitions ([Next.js view transitions guide](https://nextjs.org/docs/app/guides/view-transitions), updated 25 August 2026). Both read 3 October 2026.

```tsx
import { ViewTransition, startTransition, useState } from "react";

type Photo = { id: string; src: string; title: string };

export function Gallery({ photos }: { photos: Photo[] }) {
  const [openId, setOpenId] = useState<string | null>(null);
  const show = (id: string | null) => startTransition(() => setOpenId(id));
  const open = photos.find((photo) => photo.id === openId);

  if (open) {
    return (
      <button type="button" onClick={() => show(null)} aria-label={`Close ${open.title}`}>
        <ViewTransition name={`photo-${open.id}`} share="morph" default="none">
          <img src={open.src} alt={open.title} />
        </ViewTransition>
      </button>
    );
  }

  return (
    <ul>
      {photos.map((photo) => (
        <li key={photo.id}>
          <button type="button" onClick={() => show(photo.id)}>
            <ViewTransition name={`photo-${photo.id}`} share="morph" default="none">
              <img src={photo.src} alt={photo.title} />
            </ViewTransition>
          </button>
        </li>
      ))}
    </ul>
  );
}
```

- Give `name` only to elements that pair across the two states, derived from the record's id. Everywhere else React generates unique names itself.
- `share="morph"` puts a class on the pair; `default="none"` stops each named element from animating on every unrelated transition. With `default="none"`, keep the explicit `share`, or the pair silently stops morphing.
- Style the pair through the class, with the `::view-transition-group()`, `::view-transition-old()` and `::view-transition-new()` pseudo-elements:

```css
::view-transition-group(.morph) {
  animation-duration: 250ms;
  animation-timing-function: cubic-bezier(0.645, 0.045, 0.355, 1); /* ease-in-out-cubic: it moves on screen */
}

@media (prefers-reduced-motion: reduce) {
  ::view-transition-group(*) { animation: none; } /* nothing travels; old and new still crossfade */
}
```

React does not switch these animations off for reduced motion; the media query is yours to write. Under `reduce` the travel goes and the crossfade may stay, as the tiers in [accessibility](accessibility.md) say. Durations follow [timing-and-duration](timing-and-duration.md): 250ms for a page-level move.

## A raw call: `document.startViewTransition`

The callback must change the DOM before it returns. React batches state updates, so inside the callback wrap the update in `flushSync`, or the second snapshot still shows the old screen. Prefer `<ViewTransition>` on React 19.3 or later.

```tsx
import { flushSync } from "react-dom";

document.startViewTransition(() => {
  flushSync(() => setView("detail"));
});
```

`setView` stands for your component's state setter.

Without React, hand the name from source to target inside the callback, and clear it when the transition ends:

```ts
export function openDetail(thumb: HTMLElement, renderDetail: () => HTMLElement) {
  let detail: HTMLElement | undefined;
  thumb.style.viewTransitionName = "photo";

  const transition = document.startViewTransition(() => {
    thumb.style.viewTransitionName = "";
    detail = renderDetail(); // puts the detail view in the DOM and returns it
    detail.style.viewTransitionName = "photo";
  });

  // Clear the name afterwards, or the next transition finds two elements called "photo".
  transition.finished.finally(() => {
    if (detail) detail.style.viewTransitionName = "";
  });
}
```

- For many elements that each animate on their own (a reordering list), `view-transition-name: match-element` names every element uniquely without ids. It works in Chrome 137, Firefox 144 and Safari 18.4 for same-document transitions (web-features 3.40.1, checked 3 October 2026). Pairing two different elements still needs a shared explicit name.
- `view-transition-class` styles a group of named elements with one rule, Baseline since October 2025 (same source).

## Across pages

A multi-page site opts in with one rule in the CSS of both pages, no script: `@view-transition { navigation: auto; }`. It needs same-origin navigations and works in Chrome 126 and Safari 18.2; Firefox does not support it yet, and those visitors simply get an instant page change (web-features 3.40.1, checked 3 October 2026).

## Theme switch

Animate a light and dark flip on the root snapshot rather than duplicating the page:

```js
function switchTheme(applyTheme) {
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (!document.startViewTransition || reduce) {
    applyTheme();
    return;
  }
  document.startViewTransition(applyTheme);
}
```

```css
::view-transition-old(root) { animation: none; }
::view-transition-new(root) { animation: theme-wipe 250ms cubic-bezier(0.77, 0, 0.175, 1); } /* ease-in-out-quart */

@keyframes theme-wipe {
  from { clip-path: inset(0 100% 0 0); }
}
```

`applyTheme` is your function that sets the theme class or attribute on `<html>`. Under reduced motion the theme changes at once.
