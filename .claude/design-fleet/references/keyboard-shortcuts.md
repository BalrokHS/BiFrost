
# Design Fleet -- Keyboard shortcuts

Read the [Fleet policy](../../policy.md) for instruction precedence, existing authorization, interaction defaults, and evidence requirements.

Add a shortcut, a command palette or a shortcut sheet only when the person asks for one. A shortcut nobody asked for is an invented action. When they do ask, use the conventions below. The keyboard lines every interface needs (Escape closes overlays, browser keys stay the browser's, shortcuts skip text fields, keyboard moves are instant) live in `interaction-feedback`.

## Conventions

| Shortcut | Action | Notes |
|----------|--------|-------|
| `Escape` | Close the current overlay | Modals, drawers, popovers, dropdowns, command palette: Escape always exits. |
| `Enter` | Confirm the primary action | Submit the form, press the focused button. Enter does the obvious thing. |
| `Cmd+K` | Open the command palette or search | The launcher people know from Linear, Slack, GitHub, Vercel and Raycast. Only when the app has a palette. |
| `Cmd+/` | Toggle the shortcut sheet | Show the available shortcuts in context. Only when the app has a sheet. |
| `Cmd+B` or `Cmd+\` | Toggle the sidebar | Never `Cmd+S`: that is the browser's save. |
| `Cmd+Backspace` | Delete the selected item | Reversible deletion gets undo; confirm only the irreversible or expensive. Never delete silently. |
| `Cmd+A` | Select all | Keep the native behaviour in text fields. Override only in a custom list or grid, to select its items. |
| `Arrow keys` | Move through lists, menus, tabs | Move focus instantly; never animate a keyboard move. |
| `Tab` / `Shift+Tab` | Move focus forward and back | Standard focus order. Never trap focus outside a modal. |

## Basics a strong model already does

A cold model already does these (Fleet 11 run artifacts, 2 October 2026). They stay here as reference.

- `kb-modifier` -- `Cmd` on macOS is `Ctrl` on Windows and Linux: accept `event.metaKey || event.ctrlKey`. Never sniff the platform with `navigator.platform`; MDN calls it unreliable and not recommended ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/platform), checked 3 October 2026). To label the key, show the modifier the person pressed last, or both.
- `kb-browser-keys` -- Never override the browser's shortcuts: copy, paste, cut, new tab, close tab, reload, the address bar, save.
- `kb-scope-inputs` -- A page-level shortcut never fires while the person types in an input, textarea or select.
- `kb-scope-context` -- `Cmd+Backspace` deletes only when an item is selected; arrow keys move only inside a focused list, menu or tab set.
- `kb-focus-visible` -- Every element Tab reaches shows a focus ring; use `:focus-visible` so the ring follows the keyboard, not the mouse.

## Extra mile

What a strong model skips under build pressure. Measured probes decide which of these join the craft file that loads with the house file in every profile; until then they load here in the full profile and on demand in lean. Brackets give the count in the Fleet 11 run artifacts of 2 October 2026.

- `kb-hint-and-name` -- Show every shortcut in a `<kbd>` hint in its tooltip or menu item, and set `aria-keyshortcuts` on the control. The attribute only announces the shortcut; the handler still does the work ([MDN](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-keyshortcuts), checked 3 October 2026). [aria-keyshortcuts 0 of 25 shortcut units; `<kbd>` hints 3 of 25]
- `kb-ime` -- When Enter or a letter key acts beside a text field, ignore `event.isComposing` (and `keyCode` 229), so a Japanese or Chinese input method can confirm its text ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/isComposing), checked 3 October 2026). [0 of 25 applicable units, both arms, both models]
- `kb-contenteditable` -- A page-level shortcut skips anything `contenteditable` as well as inputs. [1 of 4 non-fleet units]
- `kb-no-repeat` -- A shortcut that deletes or toggles ignores `event.repeat`, so a held key acts once. [probe pending]
- `kb-instant-highlight` -- A highlight, marker or panel moved by a key moves instantly; animate only moves the pointer started. A palette opened by a key has no entrance animation. [probe pending; a bare palette added a 150ms colour transition to arrow-key moves]
- `kb-return-focus` -- When an overlay closes, focus returns to the control that opened it. [command palette 0 of 2]
