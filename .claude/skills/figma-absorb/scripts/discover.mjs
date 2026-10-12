#!/usr/bin/env node
/**
 * figma-absorb discover tally.
 *
 *   node discover.mjs <log-dir>                                      summary as JSON
 *   node discover.mjs <log-dir> --seed --vision <VISION.md> [--map <map.json>]
 *                                                                    proposed token table as Markdown
 *   --allow-use-figma   accept use_figma calls (the read-only fallback the person asked for);
 *                       the run is then reported as "read-only by intent, not provable"
 *
 * <log-dir> holds one file per Figma MCP call, in call order:
 * { "tool": "...", "request": { the exact arguments }, "response": the exact response }.
 * A bare response also works when its file name names a read tool (01-get_libraries.json).
 * whoami is saved as { "tool": "whoami", "request": {}, "response": "ok" }: never its email or plans.
 *
 * Exit codes: 0 counted; 1 usage or input error (one line on stderr); 2 refused, because a
 * saved call is not a Figma read tool, a file is not a call this tally recognises, or a whoami
 * file holds the email or plans. A refused log is never counted.
 *
 * The tally reads local files and prints. It makes no network request, so it cannot reach
 * Figma. Shapes follow the official Figma MCP server as it answered on 3 October 2026.
 */

import { readFileSync, readdirSync, existsSync, statSync, realpathSync } from "node:fs";
import { join, basename } from "node:path";
import { fileURLToPath } from "node:url";

// Figma's "Read tools" table, all 18 rows:
// https://developers.figma.com/docs/figma-mcp-server/tools-and-prompts/ (fetched 3 October 2026).
// use_figma, create_new_file, upload_assets and the Code Connect writes sit in its "Write tools" table.
export const READ_TOOLS = new Set([
  "download_assets", "get_code_connect_map", "get_code_connect_suggestions", "get_context_for_code_connect",
  "get_design_context", "get_figjam", "get_generative_plugin", "get_libraries", "get_metadata",
  "get_motion_context", "get_screenshot", "get_shader", "get_variable_defs", "list_file_shaders",
  "list_generative_plugins", "list_shaders", "search_design_system", "whoami",
]);
const FALLBACK = "use_figma";
const NOT_PROVABLE = "read-only by intent, not provable";

/** `mcp__<server>__get_libraries` and `get_libraries` are the same tool. */
export const toolName = (name) => (name == null ? null : String(name).split("__").pop());

/** The text of a response: a string, an MCP content array, or an object. */
export function responseText(response) {
  if (typeof response === "string") return response;
  if (Array.isArray(response) && response.every((part) => part && typeof part.text === "string")) {
    return response.map((part) => part.text).join("\n");
  }
  return JSON.stringify(response ?? null);
}

/** The first JSON object in a text. Tools sometimes append a prose line after it. */
export function firstJson(text) {
  const start = text.indexOf("{");
  if (start === -1) return null;
  let depth = 0, inString = false, escaped = false;
  for (let i = start; i < text.length; i++) {
    const ch = text[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === '"') inString = false;
    } else if (ch === '"') inString = true;
    else if (ch === "{") depth++;
    else if (ch === "}" && --depth === 0) {
      try { return JSON.parse(text.slice(start, i + 1)); } catch { return null; }
    }
  }
  return null;
}

const json = (response) => (response && typeof response === "object" && !Array.isArray(response) ? response : firstJson(responseText(response)));

/** get_metadata without a nodeId lists top-level pages as "- <id>: <name>". */
export function parsePages(text) {
  const pages = [];
  for (const m of text.matchAll(/^- (\d+:\d+): (.*)$/gm)) pages.push({ id: m[1], name: m[2].trim() });
  return pages;
}

/** The tool a bare response's file name names, as a whole word: a read tool or use_figma. */
function toolFromFileName(file) {
  const names = [...READ_TOOLS, FALLBACK].sort((a, b) => b.length - a.length);
  return names.find((name) => new RegExp(`(^|[^a-z_])${name}([^a-z_]|$)`).test(basename(file))) ?? null;
}

/**
 * Saved calls from a folder, in file-name order. Every .json and .txt file is a call: one the
 * tally cannot recognise is kept with `unknown: true`, so the audit refuses it instead of
 * dropping it.
 */
export function loadLog(dir) {
  if (!existsSync(dir) || !statSync(dir).isDirectory()) return [];
  const entries = [];
  for (const file of readdirSync(dir).filter((f) => /\.(json|txt)$/.test(f)).sort()) {
    const raw = readFileSync(join(dir, file), "utf8");
    const parsed = file.endsWith(".json") ? (() => { try { return JSON.parse(raw); } catch { return undefined; } })() : undefined;
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed) && typeof parsed.tool === "string") {
      entries.push({ tool: toolName(parsed.tool), request: parsed.request ?? null, response: parsed.response, file });
      continue;
    }
    const tool = toolFromFileName(file);
    const response = parsed === undefined ? raw : parsed;
    entries.push(tool ? { tool, request: null, response, file } : { tool: null, request: null, response, file, unknown: true });
  }
  return entries;
}

const EMAIL_RE = /[^\s"'<>@]+@[^\s"'<>@]+\.[a-z]{2,}/i;
function holdsKey(value, keys) {
  if (!value || typeof value !== "object") return false;
  return Object.entries(value).some(([k, v]) => keys.includes(k) || holdsKey(v, keys));
}

/**
 * Refuse, never just flag. A call that is not on Figma's read list, a file that is not a call
 * this tally recognises, or a whoami file that holds the email or plans makes the log refused.
 * use_figma passes only with `allowUseFigma`, and the run is then read-only by intent, not provable.
 */
export function auditLog(log, { allowUseFigma = false } = {}) {
  const refused = [];
  const notOnReadList = new Set();
  let useFigmaCalls = 0;
  log.forEach((e, i) => {
    const file = e.file ?? `call ${i + 1}`;
    const tool = toolName(e.tool);
    if (e.unknown || !tool) {
      refused.push({ file, tool: null, reason: "not a saved call this tally recognises: name a read tool in the file name, or save { tool, request, response }" });
      return;
    }
    if (tool === FALLBACK) {
      notOnReadList.add(tool);
      useFigmaCalls++;
      if (!allowUseFigma) refused.push({ file, tool, reason: "use_figma is in Figma's write tools table; run again with --allow-use-figma only if the person asked for the read-only fallback" });
      return;
    }
    if (!READ_TOOLS.has(tool)) {
      notOnReadList.add(tool);
      refused.push({ file, tool, reason: `${tool} is not on Figma's read tools list` });
      return;
    }
    if (tool === "whoami") {
      const body = typeof e.response === "string" ? firstJson(e.response) : e.response;
      if (holdsKey(body, ["email", "plans"]) || EMAIL_RE.test(responseText(e.response))) {
        refused.push({ file, tool, reason: 'the whoami response holds an email or plans; save { "tool": "whoami", "request": {}, "response": "ok" } instead' });
      }
    }
  });
  const proof = refused.length ? "refused" : useFigmaCalls ? NOT_PROVABLE : "provable";
  return { proof, refused, notOnReadList: [...notOnReadList], useFigmaCalls };
}

const ITEMS = { component: "components", variable: "variables", style: "styles" };
const assetKey = (entity, item) => (entity === "component" ? item.componentSetKey ?? item.componentKey ?? item.key : item.key);
const bump = (counts, key) => { counts[key] = (counts[key] ?? 0) + 1; };

/** Counts from a list of saved calls. Every count is "found by the calls made", never a library total. */
export function discover(log, { allowUseFigma = false } = {}) {
  const entries = log.map((e) => ({ ...e, tool: toolName(e.tool) }));
  const audit = auditLog(entries, { allowUseFigma });

  // Libraries: get_libraries, paged through libraries_available_to_add_next_offset.
  const subscribed = new Map(), available = new Map();
  let pagingComplete = false, sawLibraries = false;
  for (const e of entries.filter((x) => x.tool === "get_libraries")) {
    const body = json(e.response) ?? {};
    sawLibraries = true;
    for (const lib of body.libraries_added_to_file ?? []) subscribed.set(lib.libraryKey, { name: lib.name, key: lib.libraryKey, source: lib.source ?? "unknown" });
    for (const lib of body.libraries_available_to_add ?? []) available.set(lib.libraryKey, lib.source ?? "unknown");
    pagingComplete = body.libraries_available_to_add_next_offset == null;
  }
  const bySource = {};
  for (const lib of subscribed.values()) bump(bySource, lib.source);

  // Pages: get_metadata without a nodeId.
  const pages = [];
  for (const e of entries.filter((x) => x.tool === "get_metadata" && !x.request?.nodeId)) {
    for (const page of parsePages(responseText(e.response))) if (!pages.some((p) => p.id === page.id)) pages.push(page);
  }

  // Library assets: search_design_system, one query per call, scoped with includeLibraryKeys.
  const byLibrary = {};
  for (const lib of subscribed.values()) {
    byLibrary[lib.key] = { name: lib.name, source: lib.source, searched: false, components: new Map(), variables: new Map(), styles: new Map() };
  }
  const queries = [];
  let calls = 0, unscopedCalls = 0, outOfScopeHits = 0, queriesNotProcessed = 0, largestResult = 0, missingKeys = 0;
  for (const e of entries.filter((x) => x.tool === "search_design_system")) {
    calls++;
    const scope = Array.isArray(e.request?.includeLibraryKeys) ? e.request.includeLibraryKeys : [];
    if (!scope.length) unscopedCalls++;
    for (const key of scope) if (byLibrary[key]) byLibrary[key].searched = true;
    const body = json(e.response) ?? {};
    const clamp = String(body.warning ?? "").match(/(\d+) quer(?:y|ies) (?:was|were) not processed/);
    if (clamp) queriesNotProcessed += Number(clamp[1]);
    for (const result of body.results ?? []) {
      const items = result[ITEMS[result.entity]] ?? [];
      largestResult = Math.max(largestResult, items.length);
      let counted = 0;
      for (const item of items) {
        const lib = byLibrary[item.libraryKey];
        if (!lib) { outOfScopeHits++; continue; }
        counted++;
        const key = assetKey(result.entity, item);
        if (!key) { missingKeys++; continue; }
        lib[ITEMS[result.entity]].set(key, item);
      }
      queries.push({ entity: result.entity, query: result.query, libraryKeys: scope, hits: items.length, counted });
    }
  }

  const libraries = {};
  const totals = { components: 0, componentSets: 0, variables: 0, collections: 0, styles: 0 };
  for (const [key, lib] of Object.entries(byLibrary)) {
    const components = [...lib.components.values()];
    const sets = components.filter((c) => c.assetType === "component_set").length;
    const collections = new Map();
    for (const v of lib.variables.values()) {
      const c = collections.get(v.variableSetKey) ?? { key: v.variableSetKey, name: v.variableCollectionName, found: 0, types: {} };
      c.found++;
      bump(c.types, v.variableType);
      collections.set(v.variableSetKey, c);
    }
    const byType = {};
    for (const s of lib.styles.values()) bump(byType, s.styleType);
    libraries[key] = {
      name: lib.name, source: lib.source, searched: lib.searched,
      components: { total: components.length, componentSets: sets, components: components.length - sets },
      variables: { total: lib.variables.size, collections: [...collections.values()].sort((a, b) => String(a.name).localeCompare(String(b.name))) },
      styles: { total: lib.styles.size, byType },
    };
    totals.components += components.length;
    totals.componentSets += sets;
    totals.variables += lib.variables.size;
    totals.collections += collections.size;
    totals.styles += lib.styles.size;
  }

  // get_variable_defs: names in use on the nodes read, resolved for each node's mode.
  const names = new Set();
  const defs = entries.filter((x) => x.tool === "get_variable_defs");
  for (const e of defs) for (const name of Object.keys(json(e.response) ?? {})) names.add(name);

  return {
    calls: {
      total: entries.length,
      byTool: entries.reduce((acc, e) => (bump(acc, e.tool ?? "unknown"), acc), {}),
      readOnly: audit.proof === "provable",
      proof: audit.proof,
      notOnReadList: audit.notOnReadList,
      refused: audit.refused,
    },
    pages: { listed: pages.length, list: pages },
    libraries: { seen: sawLibraries, subscribed: [...subscribed.values()], bySource, availableToAdd: available.size, pagingComplete },
    search: { calls, unscopedCalls, outOfScopeHits, queriesNotProcessed, largestResult, missingKeys, queries },
    byLibrary: libraries,
    counts: {
      libraries: subscribed.size,
      librariesSearched: Object.values(libraries).filter((l) => l.searched).length,
      ...totals,
      pagesListed: pages.length,
    },
    variableDefs: { reads: defs.length, names: names.size },
  };
}

// ---- the token seed: a proposed table in VISION.md's format ----

const PLACEHOLDER_RE = /\[[A-Z0-9][A-Z0-9 _\/-]*\]/; // as lib/vision-parser.mjs reads it
const cellText = (cell) => cell.replace(/`/g, "").trim();

/** The rows of VISION.md's token table (`<!-- qd:tokens -->`, columns Token | Value | Use). */
export function parseTokenSlots(markdown) {
  const at = markdown.indexOf("<!-- qd:tokens -->");
  if (at === -1) return [];
  const rest = markdown.slice(at + 1);
  const end = rest.search(/<!-- qd:[a-z-]+ -->/);
  const lines = (end === -1 ? rest : rest.slice(0, end)).split("\n");
  const split = (line) => line.trim().replace(/^\||\|$/g, "").split("|").map((c) => c.trim());
  const header = lines.findIndex((line) => line.trim().startsWith("|") && split(line).map((c) => c.toLowerCase()).join("|") === "token|value|use");
  if (header === -1) return [];
  const slots = [];
  for (const line of lines.slice(header + 1)) {
    if (!line.trim().startsWith("|")) break;
    const cells = split(line);
    if (cells.length < 3 || cells.every((c) => /^:?-+:?$/.test(c))) continue;
    const token = cellText(cells[0]);
    if (!token) continue;
    const declared = PLACEHOLDER_RE.test(cells[1]) || !cellText(cells[1]) ? null : cellText(cells[1]);
    const kind = /^colou?r\./i.test(token) || /\[HEX\]/i.test(cells[1]) || /^#[0-9a-f]{3,8}$/i.test(declared ?? "") ? "color" : "px";
    slots.push({ token, kind, declared, use: cells[2].trim() }); // the Use cell as written
  }
  return slots;
}

/** A value in VISION.md's canonical form (`#rrggbb`, `#rrggbbaa`, `8px`), or null. */
export function canonicalValue(raw, kind) {
  const value = String(raw ?? "").trim();
  if (kind === "color") {
    const m = value.match(/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i);
    if (!m) return null;
    let hex = m[1].toLowerCase();
    if (hex.length === 3) hex = [...hex].map((c) => c + c).join("");
    if (hex.length === 8 && hex.endsWith("ff")) hex = hex.slice(0, 6);
    return `#${hex}`;
  }
  const m = value.match(/^((?:\d+\.)?\d+)(px)?$/);
  return m ? `${Number(m[1])}px` : null;
}

const words = (text) => String(text).replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);

/** Variable names that could fill a slot. A hint for the person choosing, never a choice. */
function candidatesFor(slot, values) {
  const tail = words(slot.token.split(".").slice(1).join(" "));
  const need = slot.token.startsWith("radius.") ? [...tail, "radius|corner"] : tail;
  const out = [];
  for (const [name, reads] of values) {
    const have = words(name);
    const fits = need.every((k) => k.split("|").some((w) => have.some((h) => (w.length <= 2 ? h === w : h.startsWith(w)))));
    if (fits && reads.some((r) => canonicalValue(r.value, slot.kind))) out.push(name);
  }
  return out.slice(0, 8);
}

/**
 * Propose values for the slots the table already has, from values that were read.
 * `map` is the person's or agent's choice of variable per slot; without it, only candidates.
 */
export function proposeSeed({ log, slots, map = null }) {
  const values = new Map(); // variable name -> [{ value, node }]
  for (const e of log.filter((x) => toolName(x.tool) === "get_variable_defs")) {
    for (const [name, value] of Object.entries(json(e.response) ?? {})) {
      const reads = values.get(name) ?? [];
      reads.push({ value: String(value), node: e.request?.nodeId ?? "unknown node" });
      values.set(name, reads);
    }
  }
  const bySlot = new Map(slots.map((s) => [s.token, s]));
  const rows = [], declared = [], skipped = [], candidates = {};
  if (!map) {
    for (const slot of slots) candidates[slot.token] = candidatesFor(slot, values);
    return { rows, declared, skipped, candidates, slots: slots.length };
  }
  for (const [token, variable] of Object.entries(map)) {
    const slot = bySlot.get(token);
    if (!slot) { skipped.push({ token, reason: "no such slot in the token table: slots are never added" }); continue; }
    const reads = values.get(variable);
    if (!reads) { skipped.push({ token, reason: `${variable} was not read on any node` }); continue; }
    const forms = [...new Set(reads.map((r) => canonicalValue(r.value, slot.kind) ?? r.value))];
    if (forms.length > 1) {
      const where = reads.map((r) => `${canonicalValue(r.value, slot.kind) ?? r.value} on ${r.node}`).join(", ");
      skipped.push({ token, reason: `read with different values on different nodes (${where}): pick the mode first` });
      continue;
    }
    const value = canonicalValue(reads[0].value, slot.kind);
    if (!value) {
      skipped.push({ token, reason: `${variable} is not a ${slot.kind === "color" ? "colour" : "pixel length"} (${reads[0].value})` });
      continue;
    }
    if (slot.declared) {
      const same = (canonicalValue(slot.declared, slot.kind) ?? slot.declared.toLowerCase()) === value;
      declared.push({ token, declared: slot.declared, figma: value, variable, same });
      continue;
    }
    rows.push({ token, value, use: slot.use, variable, nodes: [...new Set(reads.map((r) => r.node))] });
  }
  return { rows, declared, skipped, candidates, slots: slots.length };
}

/** The proposal as Markdown: a paste-ready table in VISION.md's format, then where each value came from. */
export function renderSeed(seed) {
  const out = ["Proposed token table (for review)", "", "Nothing has been written. These rows fill slots the token table already has; the person approves or changes each one.", ""];
  if (seed.rows.length) {
    out.push("| Token | Value | Use |", "|---|---|---|", ...seed.rows.map((r) => `| \`${r.token}\` | \`${r.value}\` | ${r.use} |`), "");
    out.push("Where each value came from (get_variable_defs resolves one node's mode):", "", "| Token | Figma variable | Read on node |", "|---|---|---|");
    out.push(...seed.rows.map((r) => `| \`${r.token}\` | ${r.variable} | ${r.nodes.join(", ")} |`), "");
  } else {
    out.push("No rows proposed yet: choose a variable for each slot (candidates below) and run again with --map.", "");
  }
  if (seed.declared.length) {
    out.push("Already declared in VISION.md (left as they are):", "");
    out.push(...seed.declared.map((d) => `- \`${d.token}\`: VISION.md \`${d.declared}\`, Figma ${d.variable} \`${d.figma}\`${d.same ? " (same)" : " (differs: a finding for the person)"}`), "");
  }
  if (seed.skipped.length) out.push("Not proposed:", "", ...seed.skipped.map((s) => `- \`${s.token}\`: ${s.reason}`), "");
  const listed = Object.entries(seed.candidates).filter(([, names]) => names.length);
  if (listed.length) out.push("Candidates by slot:", "", ...listed.map(([token, names]) => `- \`${token}\`: ${names.join(", ")}`), "");
  return out.join("\n");
}

// ---- CLI ----

class InputError extends Error {}

function readMap(path) {
  let map;
  try { map = JSON.parse(readFileSync(path, "utf8")); } catch (error) {
    throw new InputError(`Invalid --map file ${path}: ${String(error.message).split("\n")[0]}`);
  }
  if (!map || typeof map !== "object" || Array.isArray(map) || !Object.values(map).every((v) => typeof v === "string")) {
    throw new InputError(`Invalid --map file ${path}: expected one JSON object of slot name to Figma variable name`);
  }
  return map;
}

function main(argv) {
  const [dir, ...rest] = argv;
  const flag = (name) => { const i = rest.indexOf(name); return i === -1 ? null : rest[i + 1] ?? null; };
  const allowUseFigma = rest.includes("--allow-use-figma");
  const log = dir ? loadLog(dir) : [];
  if (!log.length) {
    process.stderr.write(`No saved calls found in ${dir ?? "(no folder given)"}. Save each Figma MCP call as one JSON file first.\n`);
    return 1;
  }
  const audit = auditLog(log, { allowUseFigma });
  if (audit.proof === "refused") {
    for (const r of audit.refused) process.stderr.write(`Refused: ${r.file}: ${r.reason}.\n`);
    process.stderr.write("Nothing was counted.\n");
    return 2;
  }
  if (audit.proof === NOT_PROVABLE) {
    process.stderr.write(`Note: ${audit.useFigmaCalls} use_figma call(s); this run is ${NOT_PROVABLE}.\n`);
  }
  if (rest.includes("--seed")) {
    const visionPath = flag("--vision");
    if (!visionPath || !existsSync(visionPath)) {
      throw new InputError("--seed needs --vision <file>: the project's VISION.md, or design-contract's vision-template.md when there is none.");
    }
    const mapPath = flag("--map");
    const map = mapPath ? readMap(mapPath) : null;
    process.stdout.write(renderSeed(proposeSeed({ log, slots: parseTokenSlots(readFileSync(visionPath, "utf8")), map })) + "\n");
    return 0;
  }
  process.stdout.write(JSON.stringify(discover(log, { allowUseFigma }), null, 2) + "\n");
  return 0;
}

function run(argv) {
  try { return main(argv); } catch (error) {
    process.stderr.write(`${error instanceof InputError ? error.message : `discover.mjs: ${String(error && error.message).split("\n")[0]}`}\n`);
    return 1;
  }
}

const invoked = process.argv[1] && existsSync(process.argv[1]) ? realpathSync(process.argv[1]) : null;
if (invoked && invoked === realpathSync(fileURLToPath(import.meta.url))) process.exitCode = run(process.argv.slice(2));
