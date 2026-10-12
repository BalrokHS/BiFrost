# Greenfield direction

How to set a direction for a surface nothing governs yet. Most work is not this: in an existing product, the contract or the existing code is the system, and [SKILL.md](../SKILL.md) applies.

## When this file applies

Check before reading on:

- **A VISION.md, a token file, a theme or a component library already exists** (look at `VISION.md`, `package.json`, the global stylesheet and `components/ui`): skip the direction step and the bold direction. Follow the product-UI default in SKILL.md, even where the contract is silent. Only the section on named products applies.
- **A new screen or feature with no contract and no system behind it:** run the direction step below. Keep product restraint; the bold direction section does not apply.
- **A new brand, landing, campaign or narrative page with no contract:** run the direction step, then the bold direction section.

Someone naming a product ("make it feel like Linear") has its own section, for new and existing work alike.

## The direction step

Answer each in a sentence before writing code. Skip what the request already answers, and skip all of it for an edit to an existing surface.

1. **One word for the feel.** Calm, fast, warm, precise, playful, dense, editorial. Type, spacing, density and motion all follow from it.
2. **The person's state when they arrive.** Under pressure (checkout, an error, a deadline), focused (an editor, a form, a dashboard) or browsing. Design for that state, not against it.
3. **The one element that matters most.** If you cannot name it, the hierarchy is not decided yet.
4. **A real product that already feels right,** and the specific qualities you are taking from it (see the section on named products).
5. **What can go.** Every element has to help the task. Remove what does not.
6. **One considered detail,** once the basics work: an empty state that helps, a confirmation that lands. Never an extra hover effect on something people use all day.
7. **The squint test.** Blur a screenshot. The most important element and the groups should still read. If everything has the same weight, the hierarchy is broken.

Then check the result against the list of AI tells at the end of this file.

Write the decisions down. On a project with no contract, propose them as the first VISION.md rows through the `design-contract` skill, with values, for the person to approve. Never write VISION.md unasked.

What sits behind the questions:

- Settle the feeling first. It picks the font, the spacing and the motion, not the other way round.
- Less than you expect. Room where people read, density where they need speed.
- Feeling is part of the product working: a calm checkout loses fewer people, a fast dashboard earns trust.
- Nobody notices consistent spacing, matching shadows and aligned type. Everybody feels it when one is off.

## Bold direction (new brand and marketing pages only)

A brand page is allowed to be remembered. Product UI is not: there, invisible craft wins.

- **Tone.** Choose one and carry it through every decision: quiet and exact, editorial, warm, playful, industrial, luxurious. Loud or quiet both work when chosen on purpose. Match the effort to the tone: a quiet page lives on exact spacing and type, a loud one on effects that are built well.
- **One thing to remember.** A typeface, an image, a single interaction. Keep everything around it calm.
- **Type.** Pick a pairing for this brand instead of the usual defaults. Not Roboto, Arial, Open Sans or Lato as a new choice (T1); not the burned display faces (Montserrat, Fraunces, Newsreader, Space Grotesk, Instrument Serif) or Inter as a reflex (T5 warnings); not a display serif over Inter, the pairing generated pages now share. `system-ui` is right when the goal is the platform's own face. One family is often enough; add a second only for real contrast. Load fonts through the framework (`next/font` in Next.js) and self-host them.
- **Colour.** One dominant colour with a sharp accent reads stronger than many colours spread evenly. Light or dark is a decision for this brand, not a habit. Define every colour as a token with a semantic name before using it. No purple or indigo gradients, no gradient text.
- **Motion.** One well-made entrance on load does more than many small effects. A staggered reveal is allowed here inside the marketing bands in [timing-and-duration](timing-and-duration.md), declared in the VISION.md timing table. Scroll effects follow [scroll-animation](scroll-animation.md): reveal once, never take over scrolling. CSS first; Motion for React only when CSS cannot do it. Reduced motion follows [accessibility](accessibility.md). A choreographed sequence can use the [storyboard pattern](storyboard-pattern.md).
- **Composition.** Asymmetry, overlap, a large type moment or generous space are allowed when they serve the tone. Still no centred-everything hero, no identical card grid, no image and text zigzag repeated three or more times.
- **Depth and texture.** A gradient mesh, grain, a pattern, layered surfaces or a deep shadow can build atmosphere when the tone asks for it. A flat ground is just as valid. Every colour in them is a token, and an animated blur stays small ([performance](performance.md)). Translucent chrome follows [materials-and-depth](materials-and-depth.md).

## When someone names a product

"Make it feel like Linear", or Raycast, Stripe, Airbnb, Apple.

- **On an existing product, never re-skin.** Name the qualities you can see in the reference: density, type size and weight, corner radius, motion speed, how much colour is used and where. Map each one to the project's existing tokens and components. What the tokens cannot express becomes a proposed token value or VISION.md row, with the value, for the person to approve.
- **On a new surface,** those qualities are the answer to question 4 of the direction step.
- **A reference's typeface is not wrong because it is common.** Inter is a T5 warning, not an error, and it is never flagged once VISION.md declares it or the project already uses it.

## AI tells

Never ship these, on any surface:

- A generic default font as a new choice (Roboto, Arial, Open Sans, Lato). Fonts the project already uses are not this.
- A serif-italic accent word inside a sans headline. Accents come from the product's own marks and motifs, never from a type-pairing trope.
- Purple or indigo gradients on white, and gradient text.
- Identical card grids, centred-everything heroes, generic hero sections built from stock patterns.
- Section-number eyebrows ("00 / INDEX"), an eyebrow label above every headline, uppercase tracked labels repeated section after section.
- Decorative status dots ("All systems operational") and fake locale, weather or time strips with no live data behind them.
- Fake product screenshots built from styled divs. Show the real product or nothing.
- The cream or beige with brass, clay or oxblood "premium" palette as a default direction.
- The same image and text zigzag repeated three or more times in a row.
- Large rounded icon tiles above every heading.
- Monospace as shorthand for "technical". Never monospace in product UI.
- Emoji or typographic glyphs as icons. Use the project's icon library.
- Title Case in UI copy. Sentence case for every heading, label, button, menu item and toast.
- A link or button with no target: no `href="#"`, no `alert()` stand-in, no call to action that goes nowhere.
