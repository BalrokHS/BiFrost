---
paths: "**/*.{tsx,jsx,vue,svelte,html,css,scss}"
---

# Craft

VISION.md and the existing code win over every line. Do brackets: cold misses per model over its runs of a probe (W3.12). Never brackets: counts from the 2 October runs, bare against fleet, and the cold probes.

## Do

- When a control starts work, show its spinner only after 200ms, inside it, same size, with aria-busy. [missed: Opus 5.5 3/3, Fable 5.1 1/1, P5]
- When a key press opens a palette or menu, show it at once, with no entrance animation. [missed: Opus 5.5 3/3, Fable 5.1 2/2, P1]
- A page-level shortcut, cmd+k included, skips contenteditable: an editor may own the key. [missed: Opus 5.5 3/3, Fable 5.1 2/2, P1]
- When a shortcut deletes or toggles, ignore event.repeat. [missed: Opus 5.5 2/3, Fable 5.1 0/2, P2]

## Never

- A link or button with no target: no href="#", no alert() stand-in. [14/14 bare pages, 8/10 fleet]
- A display serif hard-coded over Inter on a new surface. [8/8 bare pages, 0/8 fleet]
- A serif-italic accent word in a headline. [7/10 bare, 0/12 fleet]
- An eyebrow label or decorative dot above a headline. [8/8 bare pages, 0/8 fleet]
- Text glyphs or emoji as icons; use the icon library. [12/25 bare, 7/23 fleet]
- Title Case in UI copy. [5/6 bare Opus cards, 0/9 fleet]
- Identical card grids, centred heroes, purple gradients, gradient text, monospace in UI. [grid 4/4 bare; mono 2/8 bare]
- A palette class or a colour literal outside the token block. [palette 7/9 bare cards; literals 14/14 bare pages]
- A Tailwind default size the system lacks. [2/2 bare sequences, 0/6]
- A raw button, input or select where the library has one. [3/4 contract runs, 0/4 fleet; 5/5 cold palettes]
- A hand-rolled modal, listbox or menu. [12/12 contract dialogs, 0/18 fleet]
- disabled to show loading; mark it aria-busy and ignore repeat presses. [6/6 non-fleet sequences; 8/9 cold saving buttons]
- navigator.platform to pick a modifier; read metaKey or ctrlKey. [3/5 cold palettes]
- transition: all. [5/25 bare, 0 fleet]
- CSS :hover outside @media (hover: hover), or a hover lift. [18/19 and 9/25 bare]
- An action shown only on hover, or gated by width. [1/1 contract, 0/1 fleet]
- 100vh or h-screen for full height; use dvh. [7/8 prototypes]
- A field under 16px on touch. [15 fields, 0 touch overrides]
- Focus moved into a field on mount where page keys need it. [3/8 prototypes]
- A timer or listener left running after unmount. [3/4 bare prototypes, 0/4 fleet]
- An outline removed without a focus-visible ring. [3/6 bare cards]
- A scrollbar that pushes layout. [2/2 routing sessions]
- Invented data or controls. [2/2 bare sequences, 0/6]
