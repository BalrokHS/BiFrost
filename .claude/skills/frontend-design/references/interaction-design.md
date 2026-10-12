# Interaction design

How controls, overlays, focus and forms behave. The order of choice is the project's own component, then the platform, then the primitive library, and only then your own code. Press, loading and result numbers live in the interaction-feedback rule; this file is the structure around them.

## Native or library: pick before you build

| Need | Use | Why |
| --- | --- | --- |
| Menu, select, combobox, tabs, navigation menu | The primitive library the project already has: Base UI or Radix, or the shadcn component built on it | Arrow keys, typeahead, focus return and ARIA roles are long work to get right |
| Tooltip | The library's Tooltip | `popover` adds no tooltip role; `popover="hint"` and interest invokers are not Baseline ([web-features 3.40.1](https://www.npmjs.com/package/web-features)) |
| Modal or confirmation | Native `<dialog>` opened with `showModal()`, or an invoker button with `command="show-modal"` | Top layer, Escape, a backdrop, and the rest of the page made inert |
| Simple menu or disclosure outside React | `popover` plus anchor positioning | Light dismiss and the top layer, no script |
| Toast, drawer | The installed library's own, see [library-selection](library-selection.md) | A second toast or drawer library is a finding |

Never hand-roll a portal dropdown, a focus trap or roving tabindex in a React app: that is the primitive library's job. Invoker commands (`commandfor`, `command`) are Baseline since December 2025 and `popover` since January 2025 (web-features 3.40.1, checked 3 October 2026).

## States: only the ones an element reaches

Hover, `:focus-visible` and active belong to every control. The rest are earned:

- **Disabled** only where the control can truly be unavailable. Say why next to it; `pointer-events: none` also kills the tooltip that would explain it.
- **Busy** only on controls that start slow work: `aria-busy`, same size, never `disabled` (`load-busy-not-disabled` in the interaction-feedback rule).
- **Error** only on inputs and on actions that can fail.
- **Result** only on actions with an outcome: a past-tense label in place, with an icon from the project's icon library, never a text glyph.

A link or a tab never gets a loading or success state.

## Focus

Style `:focus-visible` only. Browsers already decide when a ring helps (keyboard yes, a mouse click on a button no), and the selector has worked everywhere since March 2022 ([MDN :focus-visible](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Selectors/:focus-visible)). A `:focus { outline: none }` reset adds nothing, and wherever the `:focus-visible` rule is missing it leaves no ring at all.

```css
:focus-visible {
  outline: 2px solid var(--color-ring);
  outline-offset: 2px;
}

html {
  scroll-padding-top: var(--header-height); /* placeholder: the project's own sticky-header height */
}
```

- `--header-height` above stands for whatever the project already uses for its sticky header's height; add no new variable for it.
- Use the project's ring token (shadcn calls it `ring`). The ring needs 3:1 against what touches it; an offset is a style choice, not a rule.
- A sticky header or footer must not cover the element that has focus. That is WCAG 2.2 SC 2.4.11, level AA, and `scroll-padding` is one of its listed fixes ([W3C Understanding 2.4.11](https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html)).
- Focus never falls to `<body>`. Opening an overlay moves focus into it; closing returns it to the trigger. The skip link is `kb-skip-link` in the interaction-feedback rule.

## Dialogs

```html
<dialog id="confirm-dialog">
  <h2>Delete project?</h2>
  <p>This can't be undone.</p>
  <form method="dialog">
    <button value="cancel" autofocus>Keep project</button>
    <button value="confirm">Delete project</button>
  </form>
</dialog>
```

```js
const dialog = /** @type {HTMLDialogElement} */ (document.querySelector('#confirm-dialog'));
dialog.showModal(); // top layer, Escape closes, ::backdrop, the page behind becomes inert
```

- In a destructive confirmation, first focus lands on the least destructive button, so a stray Enter cannot delete, as the [WAI-ARIA APG dialog pattern](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/) advises.
- The buttons name the outcome. Native `confirm()` cannot: it only offers OK and Cancel, and MDN points to `<dialog>` instead ([MDN confirm()](https://developer.mozilla.org/en-US/docs/Web/API/Window/confirm)).
- With no script at all, `<button commandfor="confirm-dialog" command="show-modal">` opens it.
- `showModal()` already makes the rest of the page inert. Reach for the `inert` attribute yourself only for content hidden some other way, such as a closed off-canvas panel.
- `::backdrop` styles the scrim but does not close on a click. `closedby="any"` adds that in Chromium and Firefox, not Safari (web-features 3.40.1), so keep a visible close button.

Run the action from the dialog's result, so nothing deletes on Escape or Keep:

```js
dialog.addEventListener('close', () => {
  if (dialog.returnValue === 'confirm') deleteProject(projectId);
});
```

`deleteProject` and `projectId` stand for the product's own call and record.

## Menus and anchor positioning

The common menu bug is `position: absolute` inside an `overflow: hidden` parent, which clips it. Anchor positioning places the menu against its trigger from the top layer:

```css
.trigger {
  anchor-name: --menu-trigger;
}

.dropdown {
  position: fixed;
  position-anchor: --menu-trigger;
  position-area: block-end span-inline-end;
  position-try-fallbacks: --flip-above;
  margin-top: 4px;
}

@position-try --flip-above {
  position-area: block-start span-inline-end;
  margin-bottom: 4px;
}
```

`position-try-fallbacks` is what puts the `@position-try` rule to use: when the menu would overflow below the trigger, the browser tries `--flip-above` ([MDN position-try-fallbacks](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/position-try-fallbacks)). The keyword `flip-block` does the same in one word. A `popovertarget` button is the popover's anchor without any `anchor-name`. All of this is Baseline since January 2026, when Firefox 147 shipped it ([web.dev, January 2026](https://web.dev/blog/web-platform-01-2026); web-features 3.40.1, checked 3 October 2026).

In React, use the project's primitive library for menus; anchor positioning is for stacks without one.

## Forms

- Build forms from the project's own field components first. A shadcn project ships `Field`, `FieldLabel`, `FieldError` and `Input` in `components/ui`; the raw `<label>`, `<input>` and `<p>` in the examples below show the behaviour, and copying them literally beside those components draws N1 from the fleet's lint.
- Every field has a visible label. A placeholder is a hint that disappears on input, never the label, and its text still needs 4.5:1 (`color-placeholder-needs-contrast`). Radix designs its grey step 11 for low-contrast text and documents it as APCA Lc 60 on step 2 ([Radix scale](https://www.radix-ui.com/colors/docs/palette-composition/understanding-the-scale), read 3 October 2026); by WCAG 2 computation, step 11 (#646464 in @radix-ui/colors 3.0.0) on step 2 (#f9f9f9) is 5.62:1, so it passes. The lighter steps fail.
- Check a field when it loses focus or on submit, not on every keystroke (password strength is the exception).
- Mark a failing field with `aria-invalid` and tie its message with `aria-describedby`. When you write the message element yourself, leave `role="alert"` off it; live announcements are for a form-level summary or a submit result.
- When the project's component already carries it, keep it: shadcn's `FieldError` renders with `role="alert"` ([shadcn field source, base-nova style](https://ui.shadcn.com/r/styles/base-nova/field.json), read 3 October 2026). Do not strip it in one form or wrap it in a second live region. Since each message is announced as it appears, show errors on blur or submit, not on every keystroke, and still give the input `aria-invalid` and point its `aria-describedby` at the error's `id` (shadcn's Field docs add `aria-invalid` themselves). If the announcements pile up on a long form, propose a change to the component instead of working around it.
- After a failed submit, move focus to the first invalid field, or to a summary that links to each one.
- Pick the mobile keyboard with `type` or `inputmode`: `type="tel"` for phone numbers, `inputmode="email"` for email. Keep `inputmode="numeric"` and digit-only patterns for digit-only codes; a phone number can contain `+`, spaces and brackets.

```html
<label for="phone">Phone number</label>
<input
  id="phone"
  type="tel"
  autocomplete="tel"
  aria-describedby="phone-help"
/>
<p id="phone-help">Include country code (e.g., +1 555 123 4567)</p>
```

### Errors and results: inline or toast, the project chooses

Both patterns are right in their place, and neither is the fleet default. Use what VISION.md or the existing code already does. Where neither says, propose one with your reason and ask; a form can use both.

| Pattern | Fits when | How |
| --- | --- | --- |
| Inline field error | The problem belongs to one field the person can see and fix: a format, a missing value, a name already taken | The message sits under the field, tied with `aria-describedby`, `aria-invalid` on the field; it stays until the value is fixed |
| Toast | The result is not tied to one visible field, or lands out of view: a save that failed on the network, a finished export, an undoable delete | One sentence and at most one action (Retry, Undo); the toast library announces it politely; an error that needs action does not time out |

```tsx
<label htmlFor="email">Email</label>
<input
  id="email"
  type="email"
  aria-invalid={emailError ? true : undefined}
  aria-describedby={emailError ? "email-error" : undefined}
/>
{emailError && <p id="email-error">{emailError}</p>}
```

`emailError` is the field's message from your form state, written by the error formula in the writing rule: what happened and what to do.

An ordinary, reversible delete gets undo rather than a confirmation: hide the item now and commit only when the toast closes without undo.

```tsx
import { toast } from 'sonner';

function handleDelete(id: string) {
  let undone = false;
  hideItem(id);
  const commit = () => { if (!undone) permanentlyDelete(id); };
  toast('Item deleted', {
    action: { label: 'Undo', onClick: () => { undone = true; restoreItem(id); } },
    duration: 5000,
    onAutoClose: commit,
    onDismiss: commit,
  });
}
```

`hideItem`, `restoreItem` and `permanentlyDelete` stand for the app's own data calls. The toast call is Sonner's API: the action runs `onClick` and closes the toast, `onAutoClose` runs when the timer ends, and `onDismiss` runs when the person closes or swipes it away (Sonner 2.0.8). With another toast library, keep the same three parts.

Counts in a label or message come from `Intl.PluralRules` or the project's message format, never from string concatenation ("1 items"); relative times come from `Intl.RelativeTimeFormat`.

## Gestures need a visible path

A swipe or long press is invisible. Show part of the action (a delete peeking from the edge), offer the same action in a menu or button, and never make a gesture the only way to do something.

Sources in this file were read on 3 October 2026.
