# Container animation

Animating a container's height or width as its content changes: a button whose label grows while loading, an accordion, an expanding section. Reduced motion, once for the file: a size change is movement, so under `reduce` the container snaps to its new size while the content may crossfade ([accessibility](accessibility.md)); the recipes below carry that branch.

## CSS first, where the browser can

`interpolate-size: allow-keywords`, set once on `:root`, lets a plain CSS transition animate `height` to and from `auto`, with no measuring at all. It works in Chrome and Edge 129 and later; Firefox and Safari do not support it yet and simply snap, which is an acceptable fallback for a disclosure ([MDN interpolate-size](https://developer.mozilla.org/en-US/docs/Web/CSS/interpolate-size); web-features 3.40.1; both checked 3 October 2026). Use it first where that fallback is fine, with `transition: none` under `prefers-reduced-motion: reduce`. Measure-and-animate is for when every browser must animate, or when the content swaps inside Motion.

## Measure-and-animate

One element reports its natural size; another animates to it.

> **Delta knowledge:** models reliably miss two details here. The measuring hook needs a callback ref, not `useRef`, so the observer attaches when the node actually exists. And the first measurement is 0, so animate to `"auto"` until a real number arrives.

**Two elements, never one.** Measuring and animating the same element is a loop: the animation changes the size, the new size restarts the animation.

**Incorrect (measures and animates one element):**

```tsx
function AnimatedContainer({ children }) {
  const [measureRef, bounds] = useMeasure();
  // The node being measured is also the one changing height: each tween step resizes it.
  return <motion.div ref={measureRef} animate={{ height: bounds.height }}>{children}</motion.div>;
}
```

**Correct (the outer element animates, the inner one is measured):**

```tsx
function AnimatedContainer({ children }) {
  const [measureRef, bounds] = useMeasure();
  const reduce = useReducedMotion();
  const target = bounds.height > 0 ? bounds.height : "auto";

  // Reduced motion: no height tween; the shell jumps straight to the content's size.
  const animate = reduce ? {} : { height: target };

  return (
    <motion.div className="shell" style={{ overflow: "hidden" }} animate={animate}>
      <div className="content" ref={measureRef}>
        {children}
      </div>
    </motion.div>
  );
}
```

- **The zero guard:** `bounds.height > 0 ? bounds.height : "auto"`. Without it the container grows from 0 on mount, a visible pop.
- **`overflow: hidden` on the animated element**, so content clips cleanly while the box is smaller or larger than it.
- **Padding goes on the measured element, and you measure its border box.** If the padding sits on the outer element, or the hook reads `entry.contentRect` (the content box), the number comes out short by the padding and the container clips the content by exactly that much.

## A measuring hook

`react-use-measure` does this already, with the same `const [ref, bounds] = useMeasure()` shape; it reads `getBoundingClientRect()`, which is the border box (react-use-measure 2.1.7 source, read 3 October 2026). Check `package.json` before writing your own. If you must:

```tsx
function useMeasure() {
  // The state setter doubles as a callback ref: React calls it with the node on attach and null on detach.
  const [node, setNode] = useState(null);
  const [size, setSize] = useState({ width: 0, height: 0 });

  useEffect(() => {
    if (node === null) return undefined;
    const watcher = new ResizeObserver((entries) => {
      // borderBoxSize counts the padding; contentRect would drop it.
      // In horizontal writing, inlineSize is the width and blockSize the height.
      const { inlineSize, blockSize } = entries[0].borderBoxSize[0];
      setSize({ width: inlineSize, height: blockSize });
    });
    watcher.observe(node);
    return () => watcher.disconnect();
  }, [node]);

  return [setNode, size];
}
```

- `ResizeObserver` reports only when the size changes, instead of measuring on every render ([MDN ResizeObserver](https://developer.mozilla.org/en-US/docs/Web/API/ResizeObserver), checked 3 October 2026). `borderBoxSize` works in Chrome and Edge 84, Firefox 92 and Safari 15.4 ([MDN borderBoxSize](https://developer.mozilla.org/en-US/docs/Web/API/ResizeObserverEntry/borderBoxSize), checked 3 October 2026).
- **The callback ref** stores the node in state (here the setter itself is the ref), so the effect runs when the node is attached. With `useRef`, `ref.current` can still be empty when the effect first runs, and the effect never runs again when the node appears.

## Timing

```tsx
const reduce = useReducedMotion();

<motion.div
  className="shell"
  style={{ overflow: "hidden" }}
  animate={{ height: bounds.height > 0 ? bounds.height : "auto" }}
  // Reduced motion: the height snaps, with no tween and no delay.
  transition={reduce ? { duration: 0 } : { duration: 0.2, delay: 0.05 }}
>
  <div className="content" ref={measureRef}>
    {children}
  </div>
</motion.div>
```

A small delay lets the content change first and the box follow, which reads as natural. A fixed 0.2s treats a 40px change like a 400px one; when changes vary a lot, take the duration from the distance with the formula in [timing-and-duration](timing-and-duration.md).

## Use it where size really changes

Good places: buttons that change state, accordions, expanding sections, questions and answers. Not a default wrapper for every container, and never for elements whose size does not change.
