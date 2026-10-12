---
name: figma-absorb
description: Read an accessible Figma design system through Figma's official MCP read tools and create a local HTML reference with token swatches, modes, aliases, and coverage gaps, plus a proposed VISION.md token table. Read-only; never writes to the Figma file and never imports library variables. Use only on explicit invocation.
disable-model-invocation: true
argument-hint: "[<figma-file-url> | <figma-file-url> discover | <figma-file-url> <collection-name>]"
---

# Figma absorb

Read the [Fleet policy](../../policy.md) for instruction precedence, existing authorization, interaction defaults, and evidence requirements.

Turns the design system in a Figma file into **one self-contained HTML
document** a person can read, search, and switch: every variable rendered
live, with its alias chain traced to the endpoint no inspector shows. The
document is for comprehension and reference. It is not a code mirror: a
pipeline that wants `tokens.css` with verified baselines is a sync tool's job.

## Read-only, always

**The Figma file is the source of truth. Nothing in this skill writes to it.**

- **Read tools only.** `whoami`, `get_libraries`, `search_design_system`,
  `get_metadata`, `get_variable_defs`, and `get_screenshot` for a visual
  check. All six are among the 18 tools in Figma's read tools table
  ([tools and prompts](https://developers.figma.com/docs/figma-mcp-server/tools-and-prompts/),
  fetched 3 October 2026).
- **`use_figma` is in Figma's write tools table.** Recommend against it. Use
  it for the read-only fallback in discover and sweep only when the person
  asks for it, only when the host has it, and only after loading the
  `figma-use` skill, as Figma requires. The script calls getters and reads
  properties, nothing else: `getLocalVariableCollectionsAsync`,
  `getLocalVariablesAsync`, `getVariableByIdAsync`,
  `getVariableCollectionByIdAsync`, `figma.root.children`, and
  `figma.teamLibrary` inside a `try` block. A run that used it cannot be
  proved read-only by the tally: the tally refuses its log unless run with
  `--allow-use-figma`, and then reports the run as
  `read-only by intent, not provable`. Say exactly that to the person.
- **Never call** `create_new_file`, `upload_assets`, `generate_figma_design`,
  `add_code_connect_map`, `send_code_connect_mappings` or any other write
  tool, and never a Plugin API setter, `create*`, `set*` or `import*` method.
  `variables.importVariableByKeyAsync` registers a library variable in the
  file: it is a mutation, so the values it would unlock are reported as
  unavailable instead.

A wrong value in the file is a **finding for the appendix**, reported to the
file's owner, never fixed in place. Never invent a token to fill a gap; the
gap is the finding.

Every call is saved and the tally checks each one against Figma's read list.
It refuses, and names the file, when a saved call is not a read tool or a file
is not a call it recognises; a refused log is never counted. A clean run ends
with `calls.proof: "provable"`: evidence that nothing was written, not a
promise.

**Privacy.** The `whoami` response holds the person's email and plans; they
never go in a file. `<outDir>` (by default `design-absorb/`) holds raw
responses with the client's names and values: tell the person to keep it out
of git, and propose the line `design-absorb/` for `.gitignore`;
never write it unasked.

## Prerequisites

- Check which Figma tools the host exposes. Load `figma-use` before any
  `use_figma` call. Do not invent tools in another host.
- Confirm access with `whoami`. If a tool is missing or access is denied,
  report it and stop the work that depends on it.
- A file key from the URL, `figma.com/design/:fileKey/:name`. For a branch
  URL, `figma.com/design/:fileKey/branch/:branchKey/:name`, use the branch key.

## The traps: read before starting

1. **`get_variable_defs` returns resolved values for one node's active mode.**
   The same variable read on two frames pinned to different modes gives two
   answers, and neither is the system. Use it for spot checks and for the
   seed's values, always with the node it came from. **Never learn the system
   from it.**
2. **The page list can be short.** Figma documents `get_metadata` without a
   `nodeId` as returning the document's top-level pages. On a live library
   file on 3 October 2026 it listed one page while another page id still
   resolved, to a page whose metadata ran past 500,000 characters. Treat the
   list as a floor: confirm with `figma.root.children` through the fallback
   when the host has `use_figma`, otherwise report "pages listed: N, possibly
   more".
   Never fetch a whole page's metadata just to count it.
3. **`search_design_system` without `includeLibraryKeys` is org-wide.** On 3
   October 2026 an unscoped query returned 20 hits from 8 libraries, none of
   them subscribed to the file: other teams' work. Figma's
   `figma-generate-library` skill says leaving the keys out scopes the search
   to the file; live, it did not. Always scope to keys from `get_libraries`,
   and never show the person hits from a library the file does not subscribe
   to.
4. **Search finds; it does not list.** Results are relevance-ranked and
   capped (14 to 20 hits per query on 3 October 2026), with no paging, and
   two runs of the same query can differ at the cut-off. Variable hits carry
   name, type, scopes and collection key (`variableSetKey`), never a value.
   The server clamped a three-query call to one query and said so in a
   `warning` field. A count from search means "found by these queries",
   never a library's total.
5. **Response size is the real constraint.** Large responses fail or get cut.
   Keep each call small: one query per search, one frame per metadata read,
   chunked sweeps. On a parse failure, halve the chunk and retry; do not
   assume the data is bad.
6. **Reading does not expose library values.** `search_design_system` and,
   where it works, `figma.teamLibrary` give names and types, not values.
   Values come from the library's own source file, read in place, or from
   `get_variable_defs` on a node that uses them (trap 1).

## Discover

Always first. Never assume a structure: map it, save every call, and let the
tally count.

Save each Figma call, in order, as one file in `<outDir>/discover/`:
`01-whoami.json`, `02-get_libraries.json`, and so on, each holding
`{ "tool": "<tool>", "request": <exact arguments>, "response": <exact response> }`.

1. **`whoami`** for access. Save it as
   `{ "tool": "whoami", "request": {}, "response": "ok" }`, never the
   response itself: the tally refuses a whoami file that holds an email or
   plans.
2. **`get_libraries`** with the file key. Follow
   `libraries_available_to_add_next_offset` until it is null. The subscribed
   libraries are `libraries_added_to_file`; the rest are recorded as
   available, not searched.
3. **`get_metadata` without a `nodeId`** for the page list (trap 2).
4. **`search_design_system`**, one query per call, `includeLibraryKeys` set to
   one subscribed library, `disableCodeConnect: true`. Search every team and
   organization library. List community UI kits with their count, and search
   one only when the person asks for it or when no team or organization
   library is subscribed. The plan, per library:
   - variable: color, background, text, border, spacing, radius, size, font
   - component: button, input, icon, card, navigation
   - style: heading, body, shadow, color

   A follow-up query is allowed only for a name the results revealed, such as
   a collection or a group, never a synonym. Every query goes in the config,
   so a re-run repeats the same plan.
5. **`get_variable_defs`** on a frame the person names, or one that clearly
   uses the system, for spot checks and seed values (trap 1).
6. **Read-only fallback**, only when the person asks for it, the host has
   `use_figma`, and `figma-use` is loaded: the full page list, local
   collections, and the library listing, wrapped so its failure is a finding
   instead of a crash. The tally then needs `--allow-use-figma`, and the run
   is read-only by intent, not provable. Figma's
   `figma-use` API reference lists `figma.teamLibrary.*` as not implemented
   inside `use_figma` (checked 3 October 2026), while its variable patterns
   still show the call, so expect `libraryError`.

```js
const out = { pages: figma.root.children.map((p) => ({ id: p.id, name: p.name })) };
const cols = await figma.variables.getLocalVariableCollectionsAsync();
out.local = cols.map((c) => ({
  name: c.name, id: c.id, modes: c.modes.map((m) => m.name),
  defaultMode: (c.modes.find((m) => m.modeId === c.defaultModeId) || {}).name,
  count: c.variableIds.length,
}));
try {
  const lib = await figma.teamLibrary.getAvailableLibraryVariableCollectionsAsync();
  out.library = lib.map((c) => ({ key: c.key, name: c.name, libraryName: c.libraryName }));
} catch (error) {
  out.library = null;
  out.libraryError = String((error && error.message) || error);
}
return out;
```

Then tally, with the script in this skill's folder:

```sh
node <skill-folder>/scripts/discover.mjs <outDir>/discover > <outDir>/discover.json
```

It counts, per library, components (sets and single components), variables
grouped into collections by `variableSetKey`, and styles by type, plus pages
listed, unscoped calls, hits from unsubscribed libraries (dropped, never
shown), queries the server did not process, and `calls.proof`. It exits 2 and
counts nothing when it refuses a call. Report the counts as found by the plan.
A query whose hit count equals `search.largestResult` probably had more.

**Derive the alias topology from edges, never from names**, once local values
are readable. Tally which collection each collection's aliases point into;
drop self-edges; sort the rest topologically. A non-DAG is ordered by
majority edge direction and recorded under `topologyExceptions`, never
stalled on, never hidden.

**Branch: the system lives elsewhere.** If the file has few or no local
collections but subscribes to a team library, the system lives in that
library. Ask for the library's source file and absorb it there, where its
values read in place. **Never reconstruct a library from a consuming file's
resolved endpoints**: those are one mode's answers, not the system.

Config, `<outDir>/figma.absorb.json` (slim by design: no export formats, no
baselines):

```jsonc
{
  "fileKey": "…", "fileName": "…", "outDir": "design-absorb",
  "libraries": [ /* name, key, source, searched */ ],
  "queries": [ /* entity, query, libraryKey */ ],
  "pages": { "listed": 0, "confirmed": null },
  "layerOrder": ["Primitives", "Semantic", "Components"],   // topology-justified
  "collections": [ /* name, id|key, origin: "local"|"library:<name>", modes, defaultMode, count */ ],
  "modeSwitch": { "Theme": { "attr": "data-theme", "modes": ["light", "dark"] } },
  "topologyExceptions": [],
  "absorbedAt": null, "counts": {}
}
```

The `discover` invocation stops here and prints the counts and the shape.

## Sweep

Every variable, chunked, through the read-only fallback. Per collection,
batched to trap 5, collect for each variable: name, `resolvedType`,
`valuesByMode`, `description`, `scopes`, `hiddenFromPublishing`,
`codeSyntax`. Within a chunk, run independent reads together with
`Promise.all`, as `figma-use` advises. Resolve alias IDs to **names**; a
target in no local collection is tried with `getVariableByIdAsync`, then in
the library's source file. If a value is still unreadable, mark the variable
`external-unresolved`; never import it.

Without `use_figma`, the sweep holds only what `get_variable_defs` returned on
the nodes read, each value with its node. Say so in the masthead.

Every variable carries an **origin**: `local` or `library:<name>`.

**Sanity invariant:** variables collected per collection must equal the
collection's count, or account for each missing item as unreadable. On an
unexplained mismatch, retry a bounded read sweep and report the gap; never
claim complete coverage silently.

## Render: the sandbox contract

One HTML file, zero dependencies: `<outDir>/<slug(fileName)>-system.html`.

The trick that makes it a sandbox rather than a table dump: **the tokens are
emitted as real CSS custom properties**, each collection's default mode into
`:root` and every other mode under `[<attr>="<slug(mode)>"]` on the document
element, and every swatch and specimen is painted with `var(--…)`. Flipping
the mode switcher restyles the whole document at once. The swap gets no
animation: switching is a 100+/session action, and the frequency rule says
instant. Multiple multi-mode collections are independent switches with
independent selector groups, never combined `[data-a][data-b]` blocks.

Required elements:

- **Masthead**: file name, absorbed date, counts (local, library, total),
  collections with their modes, and what the run could not read.
- **Mode switcher** per multi-mode collection.
- **Filter input**: client-side substring match on name, value, and
  description; non-matching rows hide; per-collection match counts update.
- **Collections as collapsible sections in `layerOrder`**, each with a count.
- **One row per variable**: name (click copies it), type letter (C, F, S,
  B), live rendering (COLOR as a swatch, FLOAT as a number plus a
  proportional bar or radius chip where scopes suggest a dimension, STRING as
  a type specimen where scopes say font family,
  BOOLEAN as the text `true` or `false`), per-mode raw values, the **alias chain to the endpoint** as text
  (`button/bg` to `semantic/action` to `primitive/blue-600` to `#2563EB`; a chain that
  crosses into another multi-mode collection continues through that
  collection's default mode), description verbatim, scopes when not
  `ALL_SCOPES`, origin badge, inline flags.
- **Inline flags**: dangling alias, missing mode value, off-grid colour (a
  channel where `|c × 255 − round(c × 255)| > 0.01`; show the exact floats;
  tighter tolerances flood float32 noise), `hiddenFromPublishing`,
  `codeSyntax` names.
- **Findings appendix**: danglings with consumer counts, cycles, missing-mode
  and off-grid lists, unresolved externals, with totals. Findings are for
  the file's owner; the document displays them, the skill fixes nothing.

Wiring, verbatim (adapt selectors to the generated markup):

```js
// mode switch: one group per multi-mode collection, instant
document.querySelectorAll("[data-mode-switch]").forEach((group) => {
  if (!(group instanceof HTMLElement)) return;
  group.addEventListener("click", (event) => {
    const button = event.target instanceof Element ? event.target.closest("button") : null;
    const attr = group.dataset.modeSwitch;
    const mode = button ? button.dataset.mode : undefined;
    if (!button || !attr || !mode) return;
    document.documentElement.setAttribute(attr, mode);
    group.querySelectorAll("button").forEach((b) => b.setAttribute("aria-pressed", String(b === button)));
  });
});

// filter: substring across name, values, description
const filter = document.getElementById("filter");
if (filter instanceof HTMLInputElement) {
  filter.addEventListener("input", () => {
    const term = filter.value.trim().toLowerCase();
    document.querySelectorAll("[data-var]").forEach((row) => {
      if (row instanceof HTMLElement) row.hidden = Boolean(term) && !(row.dataset.search || "").includes(term);
    });
  });
}
```

The document's own chrome stays deliberately neutral (system font stack,
plain greys, painted by none of the absorbed tokens) so it never competes
with the system on display. Keyboard focus stays visible; there is no motion
beyond the none the frequency rule already demands.

`slug()` is defined once, used everywhere: lowercase; every run of
non-alphanumerics becomes a single `-`; trim leading and trailing `-`. Two
names that slug identically collide: append an index and record it in the
config; never silently overwrite.

## Report

How every full run ends: counts per collection and origin, modes rendered,
findings totals, the document's path, `calls.proof` from the tally, and the
`.gitignore` line for `design-absorb/` if the project does not ignore it yet.

Then the **token seed**, the step that matters most for a project's contract.
It is a proposal in VISION.md's format, and nothing is written:

1. Take the slots from the project's `VISION.md` token table, or from the
   vision template in the design-contract skill when the project has none.
2. Pick one Figma variable per existing slot, by role, from the variables
   read with `get_variable_defs`. Running the tally with `--seed` and no map
   lists candidates per slot. Save the choice as `map.json`
   (`{ "color.primary": "<variable name>" }`).
3. Run
   `node <skill-folder>/scripts/discover.mjs <outDir>/discover --seed --vision VISION.md --map map.json`.
   It prints a paste-ready `| Token | Value | Use |` table with backticked
   canonical values (`#0f172a`, `8px`), where each value came from (variable
   and node), the slots VISION.md already declares (left as they are; a
   difference is a finding), and what it could not propose, with the reason.
4. Show it to the person as a proposal for the slots the table already has.
   Never one row per absorbed variable, never a new slot, and never written
   to `VISION.md`, a `DESIGN.md` or a tokens file unasked. When the project
   has a `DESIGN.md`, read its tokens to compare; never write it.

## Boundaries

- **Not a code mirror.** No `tokens.css` or `tokens.json` for consumption, no
  hashes, no baselines. A repo that must *prove* its tokens match Figma needs
  a sync pipeline; this skill's output is a reference document.
- **Not a builder.** Rendering sample components from the tokens belongs to
  `/proto` or `frontend-design`.
- **Not contract authoring.** VISION.md belongs to `design-contract`; this
  skill only proposes the seed.
- If the absorbed file's variables later publish as a library, origins shift:
  re-run `discover` before trusting an old document.

## Invocation

| Invocation | Behavior |
| --- | --- |
| `<figma-file-url>` | Full run: discover, sweep (local and library), render, report with the proposed seed |
| `<figma-file-url> discover` | Map the shape, print the counts, save the config; no document |
| `<figma-file-url> <collection-name>` | Absorb one collection into the full document structure |
