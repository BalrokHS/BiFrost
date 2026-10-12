## Mode: setup

Establish a persistent design taste profile from the user's aesthetic preferences. Write the profile in the selected host's supported format and location. This mode runs when setup is requested; installation or a missing profile alone does not authorize a questionnaire or a profile write.

### Confirm scope when needed

If the user explicitly requested setup, begin with the first unanswered question.
Do not ask for permission to start again. If automatic selection inferred setup
from unrelated work, offer it briefly and wait for a decision. Existing profiles
are user-owned: read them, reuse answered preferences, and ask about replacement
only when the current request does not already authorize it. A contract-covered
edit does not require setup merely because a taste profile is absent.

### When to use setup

- User explicitly asks to set up, configure, or regenerate their design taste profile
- User wants to create a personal design profile (user-level, not project-level)
- User accepts a setup offer made during other work

This mode runs once — it's setup, not daily work. If the user already has a taste profile and wants to audit existing code or draft a project VISION.md contract, use **assess** / **draft** instead.

### Onboarding process

Follow this sequence exactly. Do not skip the questionnaire. Do not assume answers.

#### Step 1: determine scope

Use the requested scope. Ask only if project versus personal scope remains unresolved. Codex Fleet supports a project profile; its global installation is unsupported. Cursor and Claude can use a personal profile when explicitly requested.

| Host | Project profile | Format |
| --- | --- | --- |
| Codex | `design-taste.md` | Markdown read through the project instructions |
| Cursor | `.cursor/rules/design-taste.mdc` | Native rule with the metadata below |
| Claude Code | `.claude/rules/design-taste.md` | Markdown; omit Cursor-specific metadata |

- **Project-level**: The taste profile describes this specific product's design direction
- **Personal**: The taste profile describes the user's general aesthetic preferences as a baseline for all projects

#### Step 2: ask the questionnaire

The questionnaire should feel like a conversation with a designer who wants to understand the person's taste, not a form. Keep the tone direct and warm. Short answers are fine; work with what you get, and match the energy of detailed ones. Don't judge answers: "I like Notion's design" is valid even though the wiki's own examples use Notion as an anti-reference. The profile captures the person's taste, not the wiki's opinions.

Ask the user one question at a time, waiting for an answer before moving to the next. If the host environment exposes a structured question tool (Cursor's `AskQuestion`, Claude Code's interactive prompts), use it; otherwise present each question as a plain message in the conversation. Do not paste all questions at once and do not move to Group 2 until Group 1 is fully answered.

##### Group 1: aesthetic direction

**Question 1 — Aesthetic gravity**

Which aesthetic directions do you gravitate toward? (allow multiple)

- Minimal and precise (Linear, iA Writer, Things)
- Editorial and expressive (The Verge, Bloomberg, Medium)
- Dense and data-heavy (Stripe Dashboard, Grafana, Bloomberg Terminal)
- Warm and approachable (Airbnb, Notion, Slack)
- Bold and brutalist (Craigslist-intentional, raw structure, exposed grid)
- Luxury and refined (Apple, Aesop, Squarespace)
- Retro or nostalgic (pixel art, skeuomorphic, vintage web)
- No strong preference — surprise me each time

**Question 2 — Color mode**

What's your default color mode?

- Dark-first (light mode secondary)
- Light-first (dark mode secondary)
- Both equally important
- Depends on the project

**Question 3 — Density**

How dense should interfaces feel by default?

- Dense — I want information, not whitespace. Efficiency over aesthetics.
- Balanced — breathe where it helps, dense where it matters
- Spacious — I prefer guided, generous layouts with room to think

**Question 4 — Animation philosophy**

How do you feel about motion in interfaces?

- Almost none — speed over smoothness, instant everything
- Purposeful moments — transitions where they serve comprehension
- Rich and expressive — animation is part of the experience

##### Group 2: specifics

After the user answers Group 1, ask Group 2. These are free-text questions — present them conversationally, not as multiple choice.

**Question 5 — Reference products**

Ask: "Name 2-3 products or apps whose design you admire. What specifically do you like about each?"

Listen for: typography choices, color sensibility, density, motion, layout patterns, tone.

**Question 6 — Anti-references**

Ask: "Any products whose aesthetic you actively dislike? What bothers you about them?"

Listen for: what the user considers generic, noisy, childish, sterile, or overwhelming. These anti-references are as valuable as the positive ones.

**Question 7 — Typography taste**

Ask: "Do you have font preferences? Any fonts you love, or any you never want to see?"

If the user doesn't have strong opinions, note that and leave the typography section open in the profile.

**Question 8 — Signature detail**

Ask: "When you see an interface you love, what's the detail that makes you pause? What separates 'good' from 'this was made by someone who cares'?"

This question reveals what the user values most — it might be typography, micro-interactions, density, whitespace, color restraint, or something unexpected.

#### Step 3: check for existing code (project-level only)

If this is a project-level profile and the project already has UI code:

1. Run a quick scan for the design surface (globals.css, tailwind config, theme files, component library)
2. Note what already exists — fonts in use, color variables, spacing patterns
3. Include these in the profile under "Current Project DNA" so the agent extends rather than fights the existing system

#### Step 4: generate the taste profile

Use the answers to draft the selected profile. The frontmatter below is for Cursor only; omit it for Codex and Claude. Adapt the content to actual answers and preserve project requirements.

```markdown
---
description: Design taste profile for [user name or project name]. Guides aesthetic decisions across all UI work.
globs: "**/*.{tsx,jsx,vue,svelte,css,scss,html}"
alwaysApply: true
---

# Design taste profile

## Aesthetic direction
- Gravitates toward: [from Q1 — e.g. "dense, editorial, precise"]
- Avoids: [from Q6 — e.g. "playful, rounded, bubbly, toy-like"]
- Products admired: [from Q5 — e.g. "Linear (density + keyboard-first), Stripe Dashboard (data clarity), iA Writer (typographic focus)"]
- Products disliked: [from Q6 — e.g. "Notion (too toylike at scale), Canva (visually overwhelming)"]

## Color
- Default mode: [from Q2 — e.g. "dark-first"]
- Accent approach: [inferred — e.g. "sharp and singular, no gradients"]
- Temperature: [inferred from references — e.g. "cool neutrals, blue-tinted grays"]

## Typography
- Preference: [from Q7 — e.g. "geometric sans-serifs, open to serif pairings for editorial contexts"]
- Fonts liked: [from Q7 — e.g. "Söhne, Instrument Sans, Newsreader"]
- Fonts to avoid: [from Q7 only; leave empty when the user names none — e.g. "Roboto, Arial"]

## Density and space
- Default density: [from Q3 — e.g. "dense — information over whitespace"]
- Whitespace philosophy: [inferred — e.g. "earned, not default — generous only on marketing/onboarding pages"]

## Motion
- Philosophy: [from Q4 — e.g. "almost none — speed over smoothness"]
- Acceptable motion: [inferred — e.g. "page transitions under 200ms, no hover animations on frequently-used elements"]
- Never: [inferred from anti-references — e.g. "bounce, elastic easing, decorative loading animations"]

## The signature detail
- What separates good from great: [from Q8 — e.g. "typographic precision — proper numeric formatting, considered line-height, text-wrap: balance on every heading"]

## Current Project DNA (if applicable)
- Fonts in use: [from Step 3 scan]
- Color system: [from Step 3 scan]
- Component library: [from Step 3 scan]
- Patterns to preserve: [from Step 3 scan]
```

#### Step 5: save the profile

Show the proposed profile and resolve unanswered material preferences. Use
existing setup authorization; do not add another permission gate for an
already authorized profile write. Save to the configured target's documented
profile path: root `design-taste.md` for the shared Codex profile, or the
existing Cursor/Claude profile path when that target owns the profile.

Use a personal/global path only when the user requested that scope. Do not
write to every configuration directory merely because it exists. Preserve
conflicting profiles and report the choice needed. Report the saved path and
any remaining loader or configuration limitation.

### After onboarding

Once the taste profile exists:

- The installed host entry tells the agent when to read the profile
- Question 1 ("What one word?") and Question 4 ("What's the reference?") from design-intent now have defaults from the profile
- The `frontend-design` skill uses the profile to guide font selection, color choices, and density decisions
- The user can edit the Markdown profile directly

The taste profile is a living document. Encourage the user to refine it as their preferences evolve or as the project's direction sharpens.
