---
name: design-contract
description: Establish or maintain project design requirements. Set up a taste profile, assess codebase consistency, draft or reconcile VISION.md, and turn feedback into proposed goals. Use for project design contracts, design debt, and codebase-wide audits ("audit the codebase", "how consistently do we build dropdowns", "consistency across the app"); use design-review to critique a single screen or rendered UI, and frontend-design for implementation.
argument-hint: "[setup | assess | draft | reconcile | plan] [project path or 'this project']"
---

# Design contract

Read the [Fleet policy](../../policy.md) for instruction precedence, existing authorization, interaction defaults, and evidence requirements.

Own the contract end to end, from the person's taste profile to the `VISION.md` that makes every change look like the same hand drew it. Five modes: **setup** (establish the taste profile), **assess** (rated audit of what exists), **draft** (write the contract), **reconcile** (check the contract against reality), **plan** (turn feedback and the north star into proposed goals).

---

## Mode selection

Decide the mode before doing anything else, in this order:

| Signal | Mode |
|--------|------|
| User explicitly asks to set up, configure, or regenerate a project or personal taste profile | **setup** |
| User says "reconcile", "is the vision stale", "does VISION.md match the code" | **reconcile** |
| `VISION.md` exists at the project root and the user re-runs this skill without a more specific ask | **reconcile** (the default for re-runs) |
| User says "audit", "assess", "evaluate", "design debt", "how consistent is this codebase", "what needs fixing" | **assess** |
| User says "create a vision", "design contract", "project design rules", "hard rails", "draft the vision", "prototype contract", "short contract" — or accepts the offer at the end of assess | **draft**, short path |
| User asks for the "full contract" or the full template | **draft**, full path |
| User says "plan", "propose goals", "what should we build next", "process the feedback" — or asks to turn FEEDBACK.md into goals | **plan** |
| `VISION.md` already exists and the user asks to draft | Preserve hand-tuned rules and the contract's length. If the existing request does not authorize replacement, show the intended change and ask; otherwise use that authorization. |

Setup is not a prerequisite for ordinary work covered by an existing contract. If setup was only inferred and the profile is absent, offer it without changing the current task. The other four modes are the recurring design-contract work.

**Not this skill:** Critiquing a screenshot or mockup, or running a formal Nielsen heuristic checklist — use `design-review`. Building new UI — use `frontend-design`. Verifying just-generated code against grep-able rules — use `design-review`. Asking how to implement a motion, easing, or CSS/SVG pattern — use `frontend-design`.

Use the shared Fleet policy for precedence and authorization. Read the existing contract before the taste profile; do not repeat answered questions.

## Read the selected procedure

Load only the relevant mode procedure and its required resources:

| Mode | Procedure |
| --- | --- |
| Setup | [Taste interview and profile](references/setup.md) |
| Assess | [Source extraction and consistency assessment](references/assess.md) |
| Draft | [Contract drafting](references/draft.md), then the [short template](references/vision-template.md) (default, 41 lines) or the [full template](references/vision-template-full.md) (on request) |
| Reconcile | [Contract-to-code reconciliation](references/reconcile.md) |
| Plan | [Feedback classification and proposed goals](references/plan.md) |

## What makes a contract parseable

A parser reads `VISION.md` and switches lint checks on from it. Its interface:

- The marker `<!-- qd-vision-template: v1 -->` near the top.
- Each machine-read section starts with an anchor on its own line, such as `<!-- qd:tokens -->`, followed by one table.
- Table headers are frozen: exact text, exact column order. Lint hook names are frozen too.
- An unfilled value is an `[UPPERCASE PLACEHOLDER]`. A section of placeholders is empty and switches on nothing; a section left out is missing, which is fine.
- Filled means every present section filled. The short template has six tables; the full one has eleven, ten contract tables and the optional lint exclusions.

## Rules for every mode

- **Propose, never add.** A token, component, variant or dependency the contract lacks is proposed with its name, value and use, and waits for the person. A token the tokens file holds and the token table lacks is proposed, not approved. A value the contract declares and the tokens file lacks is a sync: add it with the declared value and say so.
- **The contract is written only on request.** Draft writes `VISION.md` when the person asks for a contract; reconcile and plan propose row diffs; assess writes nothing unless the person asks (it can suggest `node .claude/design-fleet/run.mjs inventory`, which writes COMPONENTS.md). The CLI never promotes goals.
- **FEEDBACK.md decided entries bind** like the contract and are read before building; rejected entries are never re-proposed. The format is in [plan.md](references/plan.md).
- **DESIGN.md is read, never written.** When a project has one, its tokens feed draft and reconcile; where it and VISION.md disagree, VISION.md wins and the difference is a finding. The mapping is in [draft.md](references/draft.md).

## Voice

Factual and direct. No hedging, no softening. Count things. Name things. Quote values. "There are 47 unique hex values across 23 component files, 12 in CSS variables and 35 hardcoded" — not "the color system could use some improvement."

Frame findings as opportunities, not failures. The project works — the goal is to make it feel considered, and to write the contract down so it stays that way.
