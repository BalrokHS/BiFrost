
# Design Fleet -- UX writing

Read the [Fleet policy](../../policy.md) for instruction precedence, existing authorization, interaction defaults, and evidence requirements.

> **Contract precedence:** if the project has a `VISION.md` contract, its exact phrasing tables and wording rules override the defaults below. These rules apply where the contract is silent.

Every word in the interface is a design decision. Make each one earn its place. The house file carries the short form for every session: sentence case, verb and object, what happened and what to do, one word per thing, no invented proof, no AI cadence.

## Case

- `writing-sentence-case` -- Sentence case for every label, heading, button, menu item, tab, tooltip and toast: "Save changes", "Account settings". Capitalise only the first word and proper nouns. Never Title Case.

## Button labels

- `writing-specific-verbs` -- Use verb + object: "Save changes", "Create account", "Download PDF". Never "OK", "Submit", "Yes/No", or "Click here".
- `writing-name-the-destruction` -- Destructive buttons name the action: "Delete project" not "Remove". Show count: "Delete 5 items" not "Delete selected".
- `writing-cancel-means-what` -- "Cancel" is ambiguous. Say what happens: "Keep editing", "Discard changes", "Go back".

## Error messages

- `writing-error-formula` -- Every error answers three questions: What happened? Why? How to fix it? "Email isn't valid. Include an @ symbol." not "Invalid input."
- `writing-dont-blame-the-user` -- "Enter a date like 31 December 2026" not "You entered an invalid date." Reframe errors as guidance, and show the format the field expects in the reader's locale.
- `writing-specific-over-generic` -- "We couldn't save your changes. Check your connection and try again." not "Something went wrong."

## Empty states

- `writing-empty-states-teach` -- An empty screen is the first lesson in what the page is for. Say in a few words that there is nothing here yet, what it will hold, and offer the action the product actually has: "No invoices yet. Your sent invoices will show up here." with the real "Create invoice" button, not a bare "No data." Never name a control the screen does not have.

## Terminology

- `writing-one-term-one-meaning` -- Pick one word per concept and use it everywhere. Delete, not Delete/Remove/Trash. Settings, not Settings/Preferences/Options. Sign in, not Sign in/Log in/Enter. Keep a glossary and follow it; where the project already has one, its words win.

## Redundancy

- `writing-say-it-once` -- A subheading that restates the heading goes. A clear button needs no helper text that repeats it. Never tell people what is already on the screen in front of them.

## Loading and confirmation

- `writing-specific-loading` -- Name the work in progress: "Uploading 3 photos..." not "Please wait..." When it takes a while, say how long it usually takes: "About 30 seconds."
- `writing-undo-over-confirm` -- Use reliable undo for ordinary reversible deletion. Show the result and make recovery possible; a delayed delete or soft delete must honor undo reliably. Confirm irreversible or high-cost actions before execution.

## Tone

- `writing-tone-matches-moment` -- The voice (who the product sounds like) never changes. The tone follows the moment: short and warm when it worked ("Published. Anyone with the link can see it."), calm and useful when it failed ("The upload stopped. Check the file is under 20 MB and try again."), steady while waiting ("Publishing your changes..."), plain and grave before something permanent ("Delete this workspace? Its files go too, and this can't be undone."). Celebration never needs an exclamation mark.
- `writing-no-humor-for-errors` -- Never joke in an error message. The person is already stuck; give them the way out, not a pun.
- `writing-no-ai-copy-cadence` -- Avoid the recognizable AI marketing cadence in UI and marketing copy: "Not a X. A Y." constructions, em-dash-chained aphorisms, buzzword pairs ("effortless ... seamless"). Write like a person describing a product, not a manifesto.
- `writing-real-proof-only` -- Never fabricate authority props: no "Trusted by teams everywhere", no invented logos, metrics or status dots ("All systems operational" beside a dot) on surfaces that have no live status. If there's no real proof, make the product's actual capability the proof.

## Accessibility

- `writing-meaningful-link-text` -- A link names where it goes: "Compare plans", "Read the refund policy", never "Click here". Screen reader users often jump from link to link, so "here" and "more" tell them nothing.
- `writing-alt-text-describes-information` -- Alt text gives the point the image makes, not its type: "Sign-ups doubled after the March launch", not "Line chart". An image that only decorates gets `alt=""`.

## Translation readiness

- `writing-plan-for-expansion` -- German text is often about 30% longer than English. Design layouts that tolerate text expansion without breaking.
- `writing-numbers-separate` -- Keep numbers as separate parameters: "New messages: {count}" not "You have {count} new messages"; word order varies by language.
