/*
 * Prototype switcher for the proto skill. Copy this file next to the prototype page and
 * leave it unchanged. It is out of system on purpose: its own font, colours and sizes, so
 * it never reads as part of the work being compared. prototypes/** is skipped by the lint.
 *
 * Use it as a classic script, so the page also works opened from file://:
 *
 *   <main id="stage"></main>
 *   <script src="switcher.js"></script>
 *   <script>
 *     mountSwitcher({
 *       stage: document.getElementById("stage"),
 *       variants: [
 *         { label: "One at a time", render: function (stage, signal) { ... } },
 *         { label: "Checklist", render: function () { return "<section>...</section>"; } }
 *       ],
 *       replay: true,  // a Replay button and the R key; only when a variant has motion
 *       edge: "top"    // only when a variant owns the bottom of the screen
 *     });
 *   </script>
 *
 * render(stage, signal) builds one variant: fill stage, or return an HTML string or a node.
 * Each switch and each replay empties the stage and calls render on the next frame, so
 * entrances run again. signal aborts when the variant leaves: stop its timers and remove
 * anything it added outside the stage there. In a framework route, import this file for
 * its side effect (import "./switcher.js"), call window.mountSwitcher in an effect without
 * a stage, re-render the chosen variant with a new key in render(null, signal), and call
 * destroy() on cleanup.
 *
 * Keyboard, only while focus is in the switcher (Tab reaches it; the tabs are one stop):
 * Left and Right move the way they point and wrap (right-to-left pages included), Home and
 * End jump, 1 to 9 pick, R replays, Escape hands focus back to the page. Keys pressed
 * anywhere else belong to the page.
 *
 * Focus: after a switch made from the switcher, until 120 ms after the variant renders,
 * focus that the variant moves out of the switcher (a field that focuses itself as it
 * mounts) is sent back. A key, the pointer or another switcher ends that early. Focus moved
 * later, by the page or a screen reader, is left alone, and so is focus an iframe takes for
 * its own field: the page does not see it move inside the frame.
 *
 * The choice survives reload through ?v= (a second switcher on the page uses ?v2=).
 * Nothing in the switcher animates.
 */
(function () {
  "use strict";
  /** @type {any} */
  var host = typeof window === "undefined" ? null : window;
  if (!host || host.mountSwitcher) return;

  var STYLE_ID = "qd-switcher-style";
  var CSS = [
    ".qd-switcher {",
    "  position: fixed; z-index: 2147483000; left: 0; right: 0; bottom: 16px;",
    "  box-sizing: border-box; width: max-content; max-width: calc(100vw - 24px); margin: 0 auto;",
    "  display: flex; flex-wrap: wrap; align-items: center; justify-content: center; gap: 4px;",
    "  padding: 4px; border-radius: 20px;",
    "  background: rgb(11 13 16 / 0.86);",
    "  -webkit-backdrop-filter: blur(14px) saturate(140%); backdrop-filter: blur(14px) saturate(140%);",
    "  box-shadow: inset 0 0 0 1px rgb(255 255 255 / 0.1), 0 10px 30px rgb(11 13 16 / 0.32);",
    "  font: 500 13px/1 system-ui, -apple-system, BlinkMacSystemFont, sans-serif;",
    "  -webkit-font-smoothing: antialiased; color-scheme: dark; user-select: none;",
    "}",
    ".qd-switcher[data-edge=\"top\"] { bottom: auto; top: 16px; }",
    ".qd-switcher__tabs { display: flex; flex-wrap: wrap; gap: 4px; }",
    ".qd-switcher button {",
    "  appearance: none; margin: 0; border: 0; min-height: 32px; padding: 0 12px;",
    "  border-radius: 16px; background: none; color: rgb(255 255 255 / 0.66);",
    "  font: inherit; cursor: pointer; transition: none;",
    "}",
    ".qd-switcher button:hover { color: rgb(255 255 255 / 0.92); }",
    ".qd-switcher button:active { scale: 0.97; }",
    ".qd-switcher button:focus-visible { outline: 2px solid rgb(255 255 255 / 0.72); outline-offset: 2px; }",
    ".qd-switcher button[aria-selected=\"true\"] { background: rgb(255 255 255 / 0.14); color: rgb(255 255 255); }",
    ".qd-switcher__rule { width: 1px; height: 16px; margin: 0 4px; background: rgb(255 255 255 / 0.14); }",
    "@media (pointer: coarse) {",
    "  .qd-switcher { border-radius: 26px; }",
    "  .qd-switcher__rule { display: none; }",
    "  .qd-switcher button { min-height: 44px; padding: 0 16px; border-radius: 22px; }",
    "}",
    "@media (forced-colors: active) {",
    "  .qd-switcher button[aria-selected=\"true\"] { outline: 2px solid CanvasText; }",
    "}"
  ].join("\n");

  var mounted = 0;
  // How long after a variant renders focus it moves out of the switcher is sent back: long
  // enough for a field that focuses itself as it mounts (on render, with autofocus on the next
  // frame, or from a short timer), short enough that later moves are the person's own.
  var HOLD_MS = 120;

  /**
   * Mount the switcher.
   * @param {object} options
   * @param {Array<{label: string, render: (stage: HTMLElement | null, signal: AbortSignal) => (string | Node | void)}>} options.variants
   * @param {HTMLElement} [options.stage] Where a variant renders. Omit in a framework route.
   * @param {boolean} [options.replay] Show a Replay button and bind R. Only when a variant has motion.
   * @param {"bottom" | "top"} [options.edge] "top" when a variant owns the bottom of the screen.
   * @returns {{ select: (index: number) => void, replay: () => void, destroy: () => void, readonly index: number }}
   */
  function mountSwitcher(options) {
    var opts = options || {};
    var variants = opts.variants;
    if (!Array.isArray(variants) || variants.length === 0) {
      throw new Error("mountSwitcher: pass variants: [{ label, render }], one per direction");
    }
    variants.forEach(function (v, i) {
      if (!v || typeof v.label !== "string" || !v.label.trim() || typeof v.render !== "function") {
        throw new Error("mountSwitcher: variant " + (i + 1) + " needs a label (text) and a render function");
      }
    });
    var stage = opts.stage || null;
    var count = variants.length;
    var uid = "qd-switcher-" + ++mounted;
    // The first switcher on a page keeps its choice in ?v=, a second in ?v2=, and so on.
    var param = mounted === 1 ? "v" : "v" + mounted;

    if (!document.getElementById(STYLE_ID)) {
      var style = document.createElement("style");
      style.id = STYLE_ID;
      style.textContent = CSS;
      document.head.appendChild(style);
    }

    var root = document.createElement("div");
    root.className = "qd-switcher";
    root.setAttribute("data-qd-switcher", "");
    root.setAttribute("role", "region");
    root.setAttribute("aria-label", "Prototype switcher");
    if (opts.edge === "top") root.setAttribute("data-edge", "top");

    var list = document.createElement("div");
    list.className = "qd-switcher__tabs";
    list.setAttribute("role", "tablist");
    list.setAttribute("aria-label", "Prototype variants");
    root.appendChild(list);

    if (stage) {
      if (!stage.id) stage.id = uid + "-stage";
      stage.setAttribute("role", "tabpanel");
      stage.setAttribute("data-qd-stage", "");
      stage.tabIndex = -1;
    }

    /** @type {HTMLButtonElement[]} */
    var tabs = variants.map(function (v, i) {
      var tab = document.createElement("button");
      tab.type = "button";
      tab.id = uid + "-tab-" + (i + 1);
      tab.setAttribute("role", "tab");
      tab.textContent = v.label;
      if (stage) tab.setAttribute("aria-controls", stage.id);
      tab.addEventListener("click", function () { select(i); });
      list.appendChild(tab);
      return tab;
    });

    /** @type {HTMLButtonElement | null} */
    var replayButton = null;
    if (opts.replay) {
      var rule = document.createElement("span");
      rule.className = "qd-switcher__rule";
      rule.setAttribute("aria-hidden", "true");
      root.appendChild(rule);
      replayButton = document.createElement("button");
      replayButton.type = "button";
      replayButton.textContent = "Replay";
      replayButton.addEventListener("click", function () { show(); });
      root.appendChild(replayButton);
    }

    var index = 0;
    /** @type {AbortController | null} */
    var controller = null;
    var paint = 0;
    /** @type {HTMLElement | null} Where focus goes back to if a variant takes it as it mounts. */
    var hold = null;
    /** When the hold ends: Infinity until the variant has rendered, then HOLD_MS after. */
    var holdUntil = 0;

    /** @param {Element | null} el */
    function inSwitcher(el) { return !!el && root.contains(el); }
    /** @param {Element | null} el Inside this or any other switcher on the page. */
    function inAnySwitcher(el) { return !!el && typeof el.closest === "function" && !!el.closest("[data-qd-switcher]"); }

    // A variant that focuses one of its fields as it mounts would pull focus out of the
    // switcher and strand the keyboard. So, after a switch made from the switcher and until
    // HOLD_MS after the variant renders, focus that moves out of the switcher is sent back.
    // A key in the switcher or the pointer anywhere ends the hold, and so does focus that
    // reaches another switcher. A screen reader moving focus later is never bounced.
    function release() { hold = null; }
    function holding() {
      if (hold && performance.now() > holdUntil) hold = null;
      return hold;
    }
    /** @param {FocusEvent} e */
    function onFocusIn(e) {
      var target = /** @type {Element | null} */ (e.target);
      var back = holding();
      if (!back || inSwitcher(target)) return;
      if (inAnySwitcher(target)) { release(); return; }
      back.focus({ preventScroll: true });
    }

    function show() {
      if (controller) controller.abort();
      controller = new AbortController();
      var signal = controller.signal;
      var variant = variants[index];
      hold = inSwitcher(document.activeElement) ? /** @type {HTMLElement} */ (document.activeElement) : null;
      holdUntil = Infinity;
      if (!stage) { run(variant, null, signal); holdUntil = performance.now() + HOLD_MS; return; }
      var surface = stage;
      surface.replaceChildren();
      var ticket = ++paint;
      requestAnimationFrame(function () {
        if (ticket !== paint || signal.aborted) return;
        var out = run(variant, surface, signal);
        if (typeof out === "string") surface.innerHTML = out;
        else if (out && typeof out === "object" && "nodeType" in out) surface.appendChild(/** @type {Node} */ (out));
        var back = holding();
        if (back && !inAnySwitcher(document.activeElement)) back.focus({ preventScroll: true });
        holdUntil = performance.now() + HOLD_MS;
      });
    }

    /**
     * @param {{label: string, render: Function}} variant
     * @param {HTMLElement | null} target
     * @param {AbortSignal} signal
     */
    function run(variant, target, signal) {
      try {
        return variant.render(target, signal);
      } catch (err) {
        console.error("mountSwitcher: " + variant.label + " failed to render", err);
        if (target) target.textContent = variant.label + " failed to render: " + (err instanceof Error ? err.message : String(err));
        return undefined;
      }
    }

    /**
     * @param {number} next
     * @param {boolean} [moveFocus]
     */
    function select(next, moveFocus) {
      index = ((next % count) + count) % count;
      tabs.forEach(function (tab, i) {
        var on = i === index;
        tab.setAttribute("aria-selected", on ? "true" : "false");
        tab.tabIndex = on ? 0 : -1;
      });
      if (stage) stage.setAttribute("aria-labelledby", tabs[index].id);
      try {
        var url = new URL(location.href);
        url.searchParams.set(param, String(index + 1));
        history.replaceState(history.state, "", url.href);
      } catch (e) { /* some file:// setups refuse; the choice just does not survive reload */ }
      if (moveFocus) tabs[index].focus();
      show();
    }

    root.addEventListener("keydown", function (e) {
      release(); // a key press is the person's own move; focus may follow it out
      if (e.defaultPrevented || e.altKey || e.ctrlKey || e.metaKey) return;
      var onTab = tabs.indexOf(/** @type {HTMLButtonElement} */ (document.activeElement)) !== -1;
      var key = e.key;
      if (key === "ArrowRight" || key === "ArrowLeft") {
        // The arrows move the way they point: in a right-to-left tablist the next tab is to the left.
        var forward = (key === "ArrowRight") !== (getComputedStyle(list).direction === "rtl");
        select(index + (forward ? 1 : -1), true);
      }
      else if (key === "Home") select(0, true);
      else if (key === "End") select(count - 1, true);
      else if (/^[1-9]$/.test(key) && Number(key) <= count) select(Number(key) - 1, onTab);
      else if ((key === "r" || key === "R") && replayButton) show();
      else if (key === "Escape") {
        if (stage) stage.focus({ preventScroll: true });
        else if (document.activeElement instanceof HTMLElement) document.activeElement.blur();
      } else return;
      e.preventDefault();
    });

    document.addEventListener("pointerdown", release, true);
    document.addEventListener("focusin", onFocusIn, true);
    (document.body || document.documentElement).appendChild(root);

    var saved = Number(new URLSearchParams(location.search).get(param));
    select(Number.isInteger(saved) && saved >= 1 && saved <= count ? saved - 1 : 0);

    return {
      select: function (i) { select(i); },
      replay: function () { show(); },
      destroy: function () {
        if (controller) controller.abort();
        document.removeEventListener("pointerdown", release, true);
        document.removeEventListener("focusin", onFocusIn, true);
        root.remove();
      },
      get index() { return index; }
    };
  }

  host.mountSwitcher = mountSwitcher;
})();
