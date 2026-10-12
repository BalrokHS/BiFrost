# Scrollbars

Read this when a page or a panel jumps sideways as content grows or a dialog opens, when a scrollbar appears and disappears, or when someone asks for thin, subtle or hidden scrollbars.

Scrollbars float over the content. They never take layout space, never shift it, and never have their thumb hidden. Where the platform already overlays them, that is free; where it does not, the project's ScrollArea draws the scrollbar over the content.

- **Already overlay, so do nothing:** iOS and iPadOS; Android; macOS with "Show scroll bars" set to "When scrolling", or to the automatic setting with a trackpad or another gesture device; Firefox on Windows 11 while the Windows setting "Always show scrollbars" is off.
- **Take space:** Chrome on Windows 10 and 11, whatever that Windows setting says (Chromium's overlay mode is off by default there); Edge on Windows 10 and 11 (Microsoft added overlay scrollbars only as an opt-in flag, in Edge 98 in February 2022, and no later Microsoft statement was found); Firefox on Windows 10 (Firefox turns on overlay scrollbars only from Windows 11); Firefox on Windows 11 once "Always show scrollbars" is on; macOS set to "Always", or on the automatic setting with a plain mouse. CSS cannot make these overlay: `overflow: overlay` now behaves as `auto`.
- **Every scroller** (sidebar, nav list, menu, command palette, table body, the main page pane): use the project's `ScrollArea` (shadcn, Radix or Base UI). It keeps native scrolling, hides the native bar and draws its own thumb over the content on every platform, so nothing takes space or jumps on Windows either. Base UI's ScrollArea already renders its scrollbar whenever the viewport overflows. Radix's defaults to `type="hover"`, which shows the thumb only when the pointer enters and never for keyboard scrolling, so pass `type="auto"` (shadcn's wrapper passes it through): the thumb then shows whenever content overflows and still sits over the content. Never hand-roll one or add a library for it. A project without a ScrollArea proposes adding the library's one; until it is approved, the pane stays on `overflow-y: auto` with `scrollbar-width: thin`.
- **App roots never scroll:** in an app (dashboard, tool, admin), the document is a fixed-height shell (`height: 100dvh; overflow: hidden` on the shell) and the main pane scrolls inside a ScrollArea. The root has no scrollbar to come and go, so nothing shifts. The pane now owns scroll restoration on back navigation and anchor jumps (`scroll-padding-top` on the ScrollArea viewport), and iOS Safari no longer collapses its toolbar on scroll; both are accepted for apps.
- **Document pages, and only there:** a marketing page, docs or a long read keeps scrolling the root, so the browser keeps its toolbar collapse, find-in-page and restoration. CSS cannot make the root scrollbar overlay where the platform does not (`overflow: overlay` now behaves as `auto`), so when that root's length changes at runtime or a modal lock hides its overflow, put `scrollbar-gutter: stable` on `html` as the fallback. It reserves the gutter where scrollbars take space and does nothing where they overlay.
- **Styling:** `scrollbar-width: thin` and `scrollbar-color`, with the project's existing neutral token for the thumb and `transparent` for the track. `scrollbar-color` is inherited, so on `html` it colours every native scroller on the page; `scrollbar-width` is not, so each native inner pane sets `scrollbar-width: thin` itself (or uses a ScrollArea). Do not add `::-webkit-scrollbar`: the standard properties override it, and on its own it turns an overlay scrollbar into one that takes space (measured in Chromium 153 and Playwright's WebKit 26.6 on macOS, 3 October 2026).
- **Modal scroll lock:** never stack a second lock on top of the dialog's own. Base UI's Dialog already locks the root with a stable gutter, so add nothing. Radix's Dialog adds a right margin the width of the scrollbar, which doubles up with the root gutter and still shifts the page (open bug, radix-ui/primitives#3251), so zero that margin. A native `<dialog>` does not lock scrolling: hide overflow on the root while a modal is open, and the root gutter keeps its width.

```css
/* App shell: the root never scrolls; the main pane is a ScrollArea */
html, body { height: 100%; }
.app-shell { height: 100dvh; overflow: hidden; }

/* Document pages only: the root scrolls, so reserve the gutter */
html {
  scrollbar-gutter: stable;
  scrollbar-width: thin;
  scrollbar-color: var(--color-muted) transparent;
}

/* Native <dialog>: the root gutter keeps its width while locked */
html:has(dialog:modal) {
  overflow: hidden;
}

/* Radix Dialog: the root gutter already holds the scrollbar's space */
html body[data-scroll-locked] {
  margin-right: 0 !important;
}
```

Never `overflow-y: scroll` to reserve space: it draws an empty track on every system where scrollbars take space, even when nothing overflows. Never `overflow: overlay`. Never hide the thumb yourself while content overflows: no `scrollbar-width: none` unless a ScrollArea draws its own scrollbar in its place, no transparent thumb, no thumb that appears only on hover (Radix's default `type="hover"` included). Keyboard and touch users never hover, so the thumb is their only sign that the area scrolls.

Support, from MDN's compat data (checked 3 October 2026): `scrollbar-gutter` in Chrome and Edge 94, Firefox 97 and Safari 18.2; `scrollbar-width` in Chrome and Edge 121, Firefox 64 and Safari 18.2; `scrollbar-color` in Chrome and Edge 121, Firefox 64 and Safari 26.2. Sources, all checked 3 October 2026: MDN [scrollbar-gutter](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/scrollbar-gutter), [scrollbar-width](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/scrollbar-width), [scrollbar-color](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/scrollbar-color) and [::-webkit-scrollbar](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Selectors/::-webkit-scrollbar); Apple, [Appearance settings](https://support.apple.com/guide/mac-help/change-appearance-settings-mchlp1225/mac); Mozilla, [Firefox 100 release notes](https://www.firefox.com/en-US/firefox/100.0/releasenotes/); Firefox source, [WindowsUIUtils.cpp](https://github.com/mozilla-firefox/firefox/blob/7c5a815c926360e51e8a5160c783789789a4f15c/widget/windows/WindowsUIUtils.cpp#L412-L439) (overlay only from Windows 11); Chromium source, [native_theme_features.cc](https://chromium.googlesource.com/chromium/src/+/refs/tags/154.0.8037.129/ui/native_theme/features/native_theme_features.cc#19) (overlay on by default on Android, iOS and macOS, off on Windows, where the OS setting is then ignored); Chrome Platform Status, [`overflow: overlay` as `auto`](https://chromestatus.com/feature/5194091479957504); WebKit source, [ScrollbarThemeIOS.mm](https://github.com/WebKit/WebKit/blob/b58109b70bd3b70d4150878ac16d5a318bac9968/Source/WebCore/platform/ios/ScrollbarThemeIOS.mm#L64-L67) (iOS scrollbars take no space); Microsoft, [Edge 98 release notes](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-relnote-archive-stable-channel#version-980110843-february-3); Radix [Scroll Area](https://www.radix-ui.com/primitives/docs/components/scroll-area), its [source](https://github.com/radix-ui/primitives/blob/f7ecd5ab16f5e1e820eb5786a1419a98a2d594ae/packages/react/scroll-area/src/scroll-area.tsx#L362-L403) (`type="hover"` listens for pointer enter only) and [radix-ui/primitives#3251](https://github.com/radix-ui/primitives/issues/3251); Base UI [Scroll Area](https://base-ui.com/react/components/scroll-area) and [useScrollLock](https://github.com/mui/base-ui/blob/3dceedea8d705e553adc688a53f137ee93fe6f6e/packages/utils/src/useScrollLock.ts); WHATWG, [whatwg/html#7732](https://github.com/whatwg/html/issues/7732) (no built-in scroll lock for modal dialogs).
