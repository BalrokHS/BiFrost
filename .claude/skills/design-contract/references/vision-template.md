# VISION: [PROJECT NAME]
<!-- qd-vision-template: v1 -->
North star: [WHO IT SERVES AND THE ONE OUTCOME IT IS BUILT FOR]. Standing constraint: [WHAT WINS OVER CONVENIENCE].
- These tables, then the existing code, are the system. Use the file a Components row names and icons from `icon-package` only; never build a second one.
- Propose, never add: a token, component, variant or dependency missing here is proposed with its name, value and use, and used once approved.
- A token the tokens file holds and the table lacks is proposed, not approved, and so is a DESIGN.md token the table lacks. Where DESIGN.md and this file both name a token, this file wins.
- The one exception is a sync: a value the table already declares and the tokens file lacks is a sync, not a new decision; add it to the tokens file with that value and say so.
- Never edit this file during a build; propose the row diff. Decided entries in FEEDBACK.md bind like this file: read them before you build. Fill or delete each table: a table you keep is filled. Run `node .claude/design-fleet/run.mjs lint` after editing this contract.
<!-- qd:lint-hooks -->
| Hook | Value |
|---|---|
| `tokens-path` | [PATH/TO/TOKENS] |
| `icon-package` | [ICON PACKAGE NAME] |
<!-- qd:tokens -->
| Token | Value | Use |
|---|---|---|
| `color.primary` | [COLOR] | Primary actions, focus ring |
| `color.ink` | [COLOR] | Body text |
| `color.surface` | [COLOR] | Page and card background |
| `radius.control` | [PX] | Buttons and fields |
| `size.controlHeight` | [PX] | Button, Input |
<!-- qd:spacing -->
| Spacing token | Value | Use |
|---|---|---|
| `space.inline` | [PX] | Icon to label, gaps in a row |
| `space.block` | [PX] | Between blocks, page edge |
<!-- qd:typography -->
| Role | Family | Size / leading | Weight |
|---|---|---|---|
| Heading | [FAMILY] | [SIZE/LEADING] | [WEIGHT] |
| Body | [FAMILY] | [SIZE/LEADING] | [WEIGHT] |
<!-- qd:animation -->
| Where | Duration | Easing |
|---|---|---|
| Press, hover, exit | [DURATION] | [EASING] |
| Enter | [DURATION] | [EASING] |
<!-- qd:components -->
| Component | Canonical file | Required states | Anatomy | Variants |
|---|---|---|---|---|
| Button | [PATH] | [STATES] | [PARTS] | [VARIANTS] |
| Input | [PATH] | [STATES] | [PARTS] | [VARIANTS] |
