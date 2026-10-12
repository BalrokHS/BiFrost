# Storyboard pattern

A way to lay out a choreographed sequence so it stays easy to read and retime: a written shot list at the top, every number in named constants, and one counter that walks the sequence forward.

**Where it belongs:** a narrative or marketing moment with several timed steps, such as a hero that assembles itself or a product walkthrough. Product UI rarely needs a sequence; a single entrance is enough there. Reduced motion, once for the file: a staged entrance is movement, so under `reduce` the same steps run as opacity fades only ([accessibility](accessibility.md)).

---

## 1. Write the shot list first

Open the component with a comment that reads like a cue sheet, one line per moment, times counted from the trigger:

```text
/* Sequence: pricing card
 *
 *    0ms   card fades in, scale 0.95 → 1
 *  100ms   plan name brightens
 *  150ms   feature rows rise into place, 40ms apart
 *  200ms   call-to-action fades in
 */
```

Line the times up on the right, use an arrow for a value that changes, and put the stagger step in words. The cues overlap: each starts before the previous one has settled. With the 0.3s house spring and a 40ms stagger, the whole card lands in about half a second, inside the bands in [timing-and-duration](timing-and-duration.md).

## 2. One object for every start time

All start times live in one constant, in milliseconds from the trigger (not gaps between steps). Nothing else in the file holds a delay.

```tsx
const TIMING = {
  card: 0,
  planName: 100,
  rows: 150,
  cta: 200,
};
```

## 3. One object per moving part

Each element gets its own constant holding everything that shapes its motion: start and end values, the spring, the stagger, and the data it repeats over.

```tsx
const CARD = {
  fromScale: 0.95,
  toScale: 1,
  spring: { type: "spring" as const, duration: 0.3, bounce: 0 }, // house default
};

const FEATURES = {
  stagger: 0.04, // seconds per row: product band, 30-50ms
  rise: 12,      // px
  spring: { type: "spring" as const, duration: 0.3, bounce: 0 },
  list: [
    { name: "Unlimited projects" },
    { name: "Priority support" },
  ],
};
```

Retiming the sequence then means editing these objects and the shot list together, never hunting through JSX. Organising the numbers does not license bigger ones: the stagger stays in the product band.

## 4. A single step counter

One integer says how far the sequence has got. It only moves forward, and it starts once: when the card first enters the viewport.

```tsx
const [step, setStep] = useState(0);

useEffect(() => {
  if (!hasEnteredView) return; // plays once; scrolling away never rewinds it

  const timers: ReturnType<typeof setTimeout>[] = [
    setTimeout(() => setStep(1), TIMING.card),
    setTimeout(() => setStep(2), TIMING.planName),
    setTimeout(() => setStep(3), TIMING.rows),
    setTimeout(() => setStep(4), TIMING.cta),
  ];

  return () => timers.forEach(clearTimeout);
}, [hasEnteredView]);
```

`hasEnteredView` comes from an observer that fires once, such as Motion's `useInView(ref, { once: true })`. To replay the sequence while tuning, remount the component with a new `key`.

## 5. Read the counter in the JSX

Each element compares against its step with `>=`, so later steps never undo earlier ones. Under reduced motion the scale and the rise drop out and only the fades remain.

```tsx
const reduce = useReducedMotion();
const cardFrom = reduce ? CARD.toScale : CARD.fromScale;
const featureFrom = reduce ? 0 : FEATURES.rise;

<>
  <motion.div
    initial={{ opacity: 0, scale: cardFrom }}
    animate={{
      opacity: step >= 1 ? 1 : 0,
      scale:   step >= 1 ? CARD.toScale : cardFrom,
    }}
    transition={CARD.spring}
  />

  {FEATURES.list.map((feature, index) => (
    <motion.div
      key={feature.name}
      initial={{ y: featureFrom, opacity: 0 }}
      animate={{
        y:       step >= 3 ? 0 : featureFrom,
        opacity: step >= 3 ? 1 : 0,
      }}
      transition={{ ...FEATURES.spring, delay: index * FEATURES.stagger }}
    >
      {feature.name}
    </motion.div>
  ))}
</>
```

## Check before you ship

- The shot list matches the `TIMING` values.
- No number sits in the JSX or the effect; each one comes from a constant.
- Springs live in the element objects, not inline.
- Repeated parts render from a data array.
- Steps compare with `>=`, and the sequence plays once.
- Under reduced motion only fades remain.
