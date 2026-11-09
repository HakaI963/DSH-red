---
# dsh-go:managed — the dsh-go app keeps this skill up to date; delete this line to keep your own edits.
name: dsh-go-plugin
description: Write a small local plugin for the dsh-go phone app that shows up in the **native phone UI** — capsules above the composer, actions in the reply long-press menu, the status strip, native panels, tool-result cards, plus read-aloud, stop-on-speech and captions; check it with the bundled checker, then install it into the current host. Load it first whenever the user wants to add something with logic or data to the dsh-go app, such as "add a button above the composer that translates the clipboard into English", "add a 'Save to notes' item to the message long-press menu", "show today's usage above the composer", "make a panel for my to-dos", "draw this tool's result as a card", "add a button that reads the reply aloud". Only for the dsh-go phone native UI; when the user wants a Cordis plugin, changes to the Harness Web UI / desktop, or explicitly means a web plugin, use the official cordis-plugin-development skill instead — its directory layout and install entry are different. Write a small local DSH plugin that shows up natively in the dsh-go phone app; for Cordis / Harness Web UI plugins use the official skill instead.
whenToUse: The user wants to add something of their own to the dsh-go phone app (phone app / native UI) that needs logic or data. For fixed buttons, layout, theme or hiding things use the dsh-go-ui skill (ui.json) instead. For Cordis plugins or the Harness Web UI / desktop, use the official cordis-plugin-development skill — different directory and install entry.
---

# Write a local plugin for dsh-go

A plugin is an npm package directory on the host: the `dshGo` manifest in `package.json` declares what shows up in the app, and `lib/index.js` handles taps and pushes data inside the engine. The app only draws declarations and JSON views; it never executes plugin code.

## Split with the official skill (identify the UI carrier first)

This skill covers only the **native UI of the dsh-go phone app**. Create mode also loads the official `cordis-plugin-development` skill, which covers plugins for the **Harness Web UI / desktop**; the two have different directories, manifests and install entries. **Identify the UI carrier first, then pick the skill**; do not go by load order and do not mix them:

| The user wants | Use | Directory / install |
|---|---|---|
| Capsules, menu items, a status strip, native panels, tool-result cards, read-aloud / captions in the phone app | This skill | `$DSH_HOME/dsh-go/plugins/<name>/`, `dsh plugin --profile web add <dir>` |
| Change how the dsh-go app itself looks (top-bar buttons, theme, hiding elements) | `dsh-go-ui` (ui.json) | `$DSH_HOME/dsh-go/ui.json` |
| Cordis / Harness Web UI plugins, decorations, slots, MCP, pages | Official `cordis-plugin-development` | Create a package in the workspace + `plugin_manager` → `install_bundle` |
| Agent presets, Cordis compositions | Official composition skills | Official workflow |

- When the user does not name a UI carrier: inside this app the default target is the dsh-go phone native UI (`AGENTS.md` says the same); if the user explicitly wants the Web UI / desktop, follow the official skill.
- The official skill's rules "do not create packages outside the workspace, do not create packages under `$DSH_HOME`, do not hand-write a profile's package.json / cordis.patch.yml" are about **Cordis bundles**. A dsh-go native plugin is not a Cordis bundle: it is an npm package under `$DSH_HOME/dsh-go/plugins/`, installed with `dsh plugin --profile web add`. The two rule sets are independent, do not conflict, and their directories and install entries are not interchangeable.
- When "add a button" could go either way: build the native version in dsh-go first; if the user also wants a web version, let the official skill build a separate one.

## Decide which mechanism to use

| The user wants | How |
|---|---|
| A button with fixed text, a top-bar button, hiding elements, theme | No plugin; use the dsh-go-ui skill to edit ui.json |
| A button that reads the clipboard / composer / a reply, or computes something | This skill: `composer.actions` / `message.actions` + `on(id)` |
| A line of numbers that is always visible | This skill: `composer.strip` + `strip(id)` |
| A full page of information | This skill: `panels` + `panel(id)` |
| An infrequent but handy tool | This skill: `composer.tools` (the plus panel; needs a newer app) |
| Act on a whole conversation: export, archive | This skill: `session.actions` (the chat page's "Info" sidebar; needs a newer app) |
| A number visible at a glance each turn | This skill: `turn.note` + `turnNote(id)` (turn footnote; needs a newer app) |
| A tool's result drawn as a card | This skill: the tool's `output.presentationMeta` returns `{ "dsh-go/view": view }`; no manifest needed |
| Read a reply aloud, stop when the user speaks, follow-along captions | This skill: `capabilities` + `media` / `micro` / `overlays` (see "Audio and captions" below) |

Capsules, menus, the strip and panels appear only on hosts with the dsh-go bridge: the phone's local engine has it (`/etc/dsh-app/runtime.json` exists); other hosts get tool cards only.

## Steps

1. **Create the directory** (under `$DSH_HOME/dsh-go/plugins/`, kept across engine resets; `DSH_HOME` defaults to `~/.dsh`):
   ```sh
   P="${DSH_HOME:-$HOME/.dsh}/dsh-go/plugins/local-quote"
   mkdir -p "$(dirname "$P")" && cp -r "${DSH_HOME:-$HOME/.dsh}/skills/dsh-go-plugin/template" "$P"
   ```
2. **Rename**: the `name` in `package.json`, the `name` in `cordis.patch.yml` and the `name` in `lib/index.js` must all match; start with `local-`, lowercase letters, digits and `-`.
3. **Write the manifest** (`package.json` → `dshGo`, see the table below); declare only what you use, and put only what you really read in `wants`.
4. **Write the handlers** (`lib/index.js`): always inside `ctx.inject(['dshGo'], (ctx) => { … })`.
5. **Self-check** and fix until there are no more "error" lines:
   ```sh
   node "${DSH_HOME:-$HOME/.dsh}/skills/dsh-go-plugin/kit/bin/check.mjs" "$P" --load
   ```
   `--load` loads your code in an isolated environment: it checks that handlers exist and that the views your view functions return are drawable by the app. `--json` is for machines.
6. **Install** (takes effect immediately, no restart):
   ```sh
   dsh plugin --profile web add "$P"
   ```
   The phone's local engine uses the `web` profile. Installation links to this directory: do not delete the directory.
7. **After code changes**: manifest (`package.json`) changes are re-read automatically; changes to code in `lib/` take effect only after the user restarts the engine on the app's "Engine" page.
8. **Tell the user** what changed and where to see it: capsules above the composer; menu items in the long-press menu of assistant messages, grouped by plugin; the strip above the composer; panels on the chat details page's "Plugins" tab or in "All features". The first time a button reads the clipboard / composer / a message, the app asks the user once.

Uninstall: `dsh plugin --profile web remove local-quote`, then delete the directory.

## Manifest (`package.json` → `dshGo`)

```json
{
  "v": 1,
  "title": { "zh": "Quote", "en": "Quote" },
  "icon": "bolt",
  "wants": ["clipboard"],
  "contributes": {
    "composer.actions": [
      { "id": "summarize", "label": "Summarize", "effect": { "type": "insert", "text": "Summarize the conversation above and list three key points." } },
      { "id": "paste-quote", "label": { "zh": "Quote clip", "en": "Quote clip" }, "icon": "document" }
    ],
    "message.actions": [{ "id": "save", "label": "Save note", "icon": "note" }],
    "composer.strip":   [{ "id": "today", "icon": "chart", "panel": "stats" }],
    "panels":           [{ "id": "stats", "title": "Stats", "icon": "chart", "placement": ["session.tab", "features"] }]
  }
}
```

| Slot | Per plugin | Text limit | Fields | On tap |
|---|---|---|---|---|
| `composer.actions` | 2 | `label` 10 chars | `id` `label` `icon?` `effect?` | with `effect`: the app runs it directly, no code; otherwise calls `on(id)` |
| `message.actions` | 2 | `label` 12 chars | as above | as above |
| `composer.strip` | 1 | `text` 24 chars | `id` `icon?` `text?` `panel?` | `panel` → opens that panel; otherwise `on(id)` |
| `panels` | 4 | `title` 16 chars | `id` `title` `icon?` `placement?` `presentation?` `view?` | buttons / rows / options in the view → `actions` |
| `composer.tools` | 2 | `label` 8 chars | `id` `label` `icon?` `effect?` `panel?` `requires?` | `panel` / `effect` run directly in the app (write only one of them); otherwise `on(id)` |
| `session.actions` | 2 | `label` 12 chars | `id` `label` `icon?` `effect?` `requires?` | like capsules |
| `turn.note` | 1 | 16 chars per segment | `id` | not tappable; in `turnNote(id, (scope, emit) => …)` call `emit({ turnNumber: { text, tone? } })` |

- `title`, `label` and `text` take a string or `{ "zh": "…", "en": "…" }`; neither language may exceed the limit. The plugin `title` is ≤ 24 chars.
- `id`: starts alphanumeric, then alphanumeric and `_ . -`, ≤ 40 chars; **must be unique across the whole plugin** (including across slots).
- `wants`: `clipboard` and `draft` (composer text) are only for capsules and `composer.tools`; `message` (the long-pressed reply body) is only for menu items.
- `placement`: `session.tab` (chat details page, scope carries sessionId; the default), `features` (All features), `chat.panel` (the sheet opened by the "Plugins" capsule above the composer on the chat page, scope carries sessionId).
- A static `effect` may only use `insert` `command` `open` `link` `toast` `copy`.
- `icon`: bolt star sparkle heart flag bookmark pin bell clock alarm calendar todo note document folder search code terminal globe chart lightbulb book puzzle robot chat mail translate image camera mic link summary wrench bug travel school home play refresh archive team wallet palette coin money speaker read copy quote share edit write save paste add remove delete clear fork regenerate reply select-text qr download downloads external info warning check done success error question pending running tip list table panel sidebar menu more expand collapse file folder-open workspace storage pdf zip slides article text diff gallery audio music video video-file play-video pause stop replay generate-image generate-video diagram plugin bot agent skill model tool workflow goal plan job automation command trajectory web web-search browser history time today timezone schedule repeat reminder user account group chats mention invite announcement reaction poll notification send community forum feedback wechat qq telegram discord phone computer cloud server power restart retry theme color text-size pet featured badge favorite settings

## Handlers (`ctx.dshGo`)

```js
export const name = 'local-quote'
export function apply(ctx) {
  ctx.inject(['dshGo'], (ctx) => {
    // Taps on capsules / menu items / the strip: (scope, event) → effects
    ctx.dshGo.on('paste-quote', (scope, event) => scope.clipboard ? { insert: `> ${scope.clipboard}` } : { toast: 'The clipboard is empty' })

    // Status strip: push { text ≤ 24, icon?, tone? }; return the unsubscribe function
    ctx.dshGo.strip('today', (scope, emit, caps) => {
      const tick = () => emit({ text: `Today ${count()}` })
      tick()
      const timer = setInterval(tick, 60_000)
      return () => clearInterval(timer)
    })

    // Panel: view (structure) + data (push whole objects; the bridge computes deltas) + handlers for taps inside the view
    ctx.dshGo.panel('stats', {
      view: (scope, caps) => ({ type: 'stack', children: [
        { type: 'metric', label: 'Today', value: { $: 'data.today' } },
        { type: 'actions', items: [{ label: 'Reset', action: 'reset' }] },
      ] }),
      data: (scope, emit, caps) => { emit({ today: count() }); return () => {} },
      actions: { reset: (scope, event) => ({ toast: 'Counter reset', patch: { today: 0 } }) },
    })
  })
}
```

| Argument | Contents |
|---|---|
| `scope` | `{ sessionId?, turnId?, messageId?, callId? }`; on a tap, also the declared `clipboard` / `draft` / `message` |
| `event` | `{ surface, id, action?, value?, locale }`; for panel taps, `action` is the action id from the view and `value` is the args (`options` → `{ value }`, `confirm` → `{ confirmed }`) |
| `caps` | View functions: `{ protocol, app, locale, surfaces, components }`; data functions: `{ protocol, locale }` |

**Returned effects** (≤ 4 at a time; only executed when returned within 3 s of the tap):

| Shape | Effect |
|---|---|
| `{ insert: '…' }` | Put into the composer (≤ 2000 chars), **never auto-sent** |
| `{ toast: '…' }` | A one-line toast (≤ 40 chars) |
| `{ copy: '…' }` | Copy (≤ 8000 chars) |
| `{ link: 'https://…' }` | Opens in the browser after the user confirms; https only |
| `{ open: 'panel:stats' }` / `{ open: 'page id' }` | Open a panel of this plugin or an app page |
| `{ command: 'compact' }` | Run a slash command in the current conversation |
| `{ refresh: true }` / `{ patch: {…} }` | Panel: re-fetch the view / merge data |
| Several keys in one object | All run in order, e.g. `{ copy: md, toast: 'Copied' }` |

**Slow work (model calls, network) uses a deferred result**: answer `pending` first and the app shows a waiting state; the result arrives within ≤ 60 s and may only carry `insert` `copy` `toast` `patch`; at most 2 pending per plugin at a time; `signal` fires on cancel / timeout / disconnect — stop when it does.

```js
ctx.dshGo.on('translate', (scope) => ({
  pending: { label: 'Translating', timeoutMs: 60_000 },
  result: async (signal) => ({ insert: await translate(scope.clipboard, signal) }),
}))
```

## Views (panels, tool cards)

A tree of JSON components. Any value can be a binding `{ "$": "data.a.b" }`, read from the pushed data and shown as "—" when missing; tool cards have no data, so write literal values.

**Pick the view version first**: with no `v` or `v: 1` at the root, use the v1 components and the original styles; write `v: 2` at the root when you need the added controls, structural components or bounded styles. The manifest's `dshGo.v` stays `1`; it is separate from the view version.

The table below lists only the basic v1 components. For the full v2 components and fields see the bundled `kit/schema/view.schema.json`; `docs/plugins/components.md`, `styles.md` and `inputs.md` in the app repository describe the added components, styles and forms. Do not reject v2 just because a component is not in the table below. When supporting older apps, degrade with `caps.components` / the SDK's `adaptView`, keeping text in basic fields such as `text`.

```json
{"v":2,"type":"stack","accent":"teal","children":[
  {"type":"text","text":"Example","style":{"size":"title","weight":"bold"}},
  {"type":"emptyState","title":"Nothing here yet"}
]}
```

| Component | Fields |
|---|---|
| `stack` / `row` | `children` (row wraps automatically on narrow screens); the root may carry `title` |
| `text` | `text`, `tone?: muted` |
| `metric` | `label` `value` `tone?: good\|warn\|bad\|info` `caption?` |
| `chart` | `kind: bar\|hbar\|line\|donut` `categories` `series: [{ name?, values }]` `unit?` `caption?` |
| `compare` | `items: [{ title, badge?, rows: [[name, value]] }]` (2–4 items) |
| `steps` | `items: [{ label, status: done\|current\|todo\|failed, detail? }]` |
| `callout` | `text` `tone?: info\|good\|warn\|bad` |
| `list` | `items: [{ title, subtitle?, trailing?, icon?, tone?, action? }]` (≤ 50) |
| `keyValue` | `items: [[name, value], …]` or `[{ label, value, tone? }]` or `{ name: value }` (≤ 24) |
| `progress` | `value` `max?` (default 100) `label?` `caption?` `tone?` |
| `table` | `columns: [text \| { label, align? }]` (≤ 8) `rows: [[…]]` (≤ 50) |
| `actions` | `items: [{ label, action, icon?, style?: primary\|plain }]` (≤ 4, at most one primary) |
| `options` | `id` `options: [{ label, value? }]` `multi?` `selected?` |
| `confirm` | `id` `confirmLabel?` `cancelLabel?` |
| `image` | `src`: a same-origin `/dsh-go/v1/…` path or a ≤ 64 KiB `data:image/…`; `alt?` `aspect?` |

`action` is an action-id string or `{ "id": "open", "args": { … } }` (args ≤ 1 KiB). Limits: panel 32 KiB / 120 components / 8 levels; tool card 8 KiB / 40 / 6 levels, not tappable in phase 0.

Tool card:

```js
presentationMeta: (args, value) => {
  try {   // throwing or returning undefined / NaN fails the whole tool call
    const text = JSON.stringify({ type: 'stack', title: `${value.city} · Today`, children: [{ type: 'metric', label: 'Temp', value: `${value.temp}°` }] })
    return text.length < 8000 ? { 'dsh-go/view': JSON.parse(text) } : {}
  } catch { return {} }
},
```

## Audio and captions (v1.2, optional)

Add `"capabilities": ["audio", "voice", "micro", "overlay"]` to the manifest (list only what you use), add `media: [{ id }]`, `micro: [{ id }]`, `overlays: [{ id, channel }]` to `contributes` (each ≤ 2, ids unique across contributions); buttons that need audio carry `"requires": ["audio"]`.

```js
ctx.dshGo.on('read', (scope) => [   // the same instance: the app treats them as one session
  { type: 'audio', op: 'play', instance: 'reading', src: 'media:speech', key: 'k1' },
  { type: 'voice', op: 'start', instance: 'reading' },
  { type: 'overlay', op: 'show', instance: 'reading', id: 'subtitle' },
])
ctx.dshGo.media('speech', async (scope, { key, signal }) => ({ body: wavBuffer, contentType: 'audio/wav' }))   // the whole clip, ≤ 16 MiB, within 30 s
ctx.dshGo.micro('caption', { data: (scope, emit) => { emit({ text: 'Read up to here', progress: 0.3 }); return () => {} } })   // only { text ≤ 240 chars, progress 0–1 }
ctx.dshGo.onCapability((scope, { event }) => {})   // audio.ended / voice.speechStart / …; return values are not executed
```

Put slow work (TTS) in `media`, not in `on`. The app handles: stopping playback before listening when the user speaks, asking whether it may listen, listening only in the foreground, and stopping listening and closing captions when the audio ends. Without TTS you can synthesize a placeholder tone the way `examples/plugins/dsh-go-example-readaloud` does.

## Rules

- v1 keeps the original styles; v2 may use the documented colors, semantic text sizes, weights, spans and container styles. Do not write arbitrary CSS, font files, sizes, opacities, gradients or animation parameters; actual geometry, readable colors and content bounds are still decided by the app.
- Keep copy short; make errors read like plain speech ("The clipboard is empty"), not raw exceptions.
- No keys or tokens in views, manifests or code; clipboard / message content you read is for this one tap only.
- No side effects without a tap; `insert` never sends.
- Write fields exactly as the schema and component catalogue of the chosen view version define, and validate with the bundled checker; do not invent unsupported fields. Full documentation lives in `docs/plugins/` of the app repository.
