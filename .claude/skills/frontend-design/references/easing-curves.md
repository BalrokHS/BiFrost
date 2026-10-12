# Easing curves

The named cubic-bezier values the fleet uses, and the rule for animations that run together. SKILL.md says which family fits which moment; open this file when you need an exact value or want to compare shapes. Durations live in [timing-and-duration](timing-and-duration.md).

---

## Pick the family, then the strength

| Family | For | Shape |
| --- | --- | --- |
| ease-out | Anything entering or leaving: menus, dialogs, tooltips, toasts | Fast at the start, then slows into place, so the response is visible at once |
| ease-in-out | Something already on screen moving or changing shape | Speeds up, then brakes, like a physical object |
| ease | Hover and colour changes | A gentle asymmetric curve for small, low-stakes changes |
| linear | Constant motion only: marquees, spinners, a progress fill that shows elapsed time, scroll-scrubbed motion | No change in speed, which reads as mechanical anywhere else |
| ease-in | Almost never in UI | Starts slowly, so the feedback arrives late |

The CSS keywords (`ease-out`, `ease-in-out`) name a family, not a deliberate choice. They are fine for hover, colour and the press, as the house rules use them. For an entrance, a move or a drawer, pick a named curve from the tables below.

## The values

Ordered from gentlest to strongest within each family.

```css
:root {
  /* ease-out: entering and leaving */
  --ease-out-quad:  cubic-bezier(0.25, 0.46, 0.45, 0.94);
  --ease-out-cubic: cubic-bezier(0.215, 0.61, 0.355, 1);
  --ease-out-quart: cubic-bezier(0.165, 0.84, 0.44, 1);
  --ease-out-quint: cubic-bezier(0.23, 1, 0.32, 1);
  --ease-out-expo:  cubic-bezier(0.19, 1, 0.22, 1);    /* scroll reveals, card hovers */

  /* ease-in-out: moving on screen */
  --ease-in-out-quad:  cubic-bezier(0.455, 0.03, 0.515, 0.955);
  --ease-in-out-cubic: cubic-bezier(0.645, 0.045, 0.355, 1); /* back-and-forth moves */
  --ease-in-out-quart: cubic-bezier(0.77, 0, 0.175, 1);
  --ease-in-out-quint: cubic-bezier(0.86, 0, 0.07, 1);
  --ease-in-out-expo:  cubic-bezier(1, 0, 0, 1);

  /* special purpose */
  --ease-drawer:        cubic-bezier(0.32, 0.72, 0, 1);  /* iOS-like sheet curve (Ionic): the house curve for bottom sheets */
  --ease-drawer-height: cubic-bezier(0.25, 1, 0.5, 1);   /* a container's height following its content */
}
```

The circ curves (`--ease-out-circ: cubic-bezier(0.075, 0.82, 0.165, 1)`, `--ease-in-out-circ: cubic-bezier(0.785, 0.135, 0.15, 0.86)`) sit outside the ordering: their shape bends differently, not more strongly. [easing.dev](https://easing.dev/) and [easings.co](https://easings.co/) show more variants; take a catalogued curve over one drawn by hand.

**The press is the exception:** plain `ease-out`, at most 150ms (`press-scale` in the interaction-feedback rule).

A large surface opened constantly, such as a command menu or the main sidebar, may soften from a strong ease-out to plain `ease`, because a steep curve on a big element seen all day reads as twitchy. On a contract project, propose it as a VISION.md timing row and wait for approval, so the choice does not look like an accident.

## Things that move together share one curve

A dialog and its scrim, a tooltip and its arrow, a drawer and its backdrop move as one object, so they share the same curve and the same duration. Models miss this often.

```css
.modal {
  transition: transform 200ms var(--ease-out-cubic);
}
.overlay {
  transition: opacity 200ms var(--ease-out-cubic);
}
```

The same holds inside one component. An auto-height drawer's open slide, its height change and its content crossfade use one family: `--ease-drawer` for travel and `--ease-drawer-height` for height. Three unrelated curves in one gesture read as three separate events.
