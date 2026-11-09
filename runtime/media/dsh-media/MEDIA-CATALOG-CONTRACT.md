# MEDIA-CATALOG-CONTRACT · v1 / plugin 0.3.0

This file is the contract for how the App reads the plugin catalogue and configuration. It does not modify the frozen tool/result.meta["dsh-go/media"] v1. Status: the Node tests for plugin 0.3.0 pass; the real rc.4 headless results for 0.2.0 are in VERIFICATION.md, and 0.3.0 has not re-run headless. Real settings RPC, App and on-device checks remain UNRUN. Source locations in §2 and §5 were taken from DSH 0.2.1-rc.2 (git 687f282e8625c6b8d11ff58211a90524be2e4317) and the 2026-10-28 App sources; line numbers may drift.

## 1. The single catalogue location

The catalogue lives in the `services` field itself within the plugin namespace schema:

    schema.fields["services"].meta.extra["dsh-go/media/catalog"]

This is the access path on the App's parsed SchemaNode. The raw Schemastery JSON is a {uid,refs} graph; do not hard-code a JSON-root dict path or a fixed numeric uid. Parse the graph first, then find services. Because the candidate's services is a transform(array), the catalogue is on the outer services.meta.extra, so reading only services.effective.meta.extra is not enough; the effective array does not necessarily carry the outer metadata.

Catalogue shape:

    {
      v: 1,
      revision: "2026-11-01.0.3.0",
      asOf: "2026-11-01",
      contract: "dsh-go/media/catalog",
      capabilities: {tools:["generate_image","edit_image","generate_video","get_media_result","resume_media"],commands:[],image:true,video:true,edit:true},
      limits: {maxN:4,promptUtf8Bytes:4096},
      availability: "...",
      sources: [...],
      models: [...],
      presets: [...]
    }

0.2.0 added the optional video fields `durations`, `resolutions`, `videoSizes`, `defaultSize`, `requiresRef`, plus edit-only `editOnly`. `profiles` gives verified native endpoints, queryPath and cancellation ability; they are Host adapter data, and neither the App nor the model may pass arbitrary API fields. Unlisted durations/resolutions must be omitted; no guessed defaults. A catalogue without prices means prices are unknown.

models contain id, label, kind, profile, ratios, sizes, aspectSizes, qualities, maxN, maxRefs, edit, extend, upscale, sources. When price is absent, no reliable price list was provided. The boolean capabilities and maxN are the subset the plugin opens; do not infer that the provider has no other capabilities.

The optional responseFormats field: when present it is the whitelist of return formats the model's service config must pick explicitly; when absent, follow the profile's existing rules, and GPT Image must omit responseFormat. It is not a tool parameter and does not authorize the model to change the service's return format. An empty ratios/sizes/qualities array and an empty aspectSizes mean the plugin opened no verified values; the App should allow omitting the parameter, invent no default and show no empty selector. When the selected model has maxN=1, do not show 2–4 张 as available based on the catalogue's top-level maxN=4.

### presets (new in 0.3.0, optional for the App)

The root `presets` node is an optional array of ≤16 entries providing "new service" templates. Each entry's fields:

    {id, label, labelEn?, provider, profile, baseUrl, responseFormat, models, kind, keyGroup}

- `id` and `keyGroup`: `^[a-z][a-z0-9-]{0,31}$`, `id` unique. Image and video presets with the same `keyGroup` are expected to share one credential.
- `label` is non-empty Chinese, ≤80 bytes; `labelEn` is an optional non-empty English name ≤80 bytes; `provider` is for display only.
- `profile` must belong to the catalogue `profiles` (or the built-in `openai-compatible` / `openai-gpt-image`); `baseUrl` accepts HTTPS only, like a service, with no credentials, query or fragment, and native profiles must also land on a host or workspace suffix declared by the catalogue.
- `responseFormat` is `"" | "url" | "b64_json"`; anything other than `openai-compatible` must be empty.
- `models` is 1..16 catalogue model IDs, consistent with the preset's `profile` and `kind`. The App should still intersect with the installed catalogue and the current service value rather than trusting the preset alone.
- `kind` is `image` or `video`.

The App may use a preset to fill in the service ID, protocol, API root, return format and model list; validation against this contract still runs before saving. 0.2.x catalogues lack this field: on a missing or invalid `presets`, ignore the presets and fall back to the manual flow rather than disabling the settings page. Unknown fields are ignored.

### defaults (extended in 0.3.0)

Besides the legacy `serviceId` / `modelId`, `value.defaults` adds:

    {imageServiceId, imageModelId, videoServiceId, videoModelId}

All four are optional strings; an empty string means unset. `generate_image` / `edit_image` first use the image default service and model, `generate_video` first uses the video default service and model; when the per-kind default resolves to nothing, fall back to the legacy `serviceId` / `modelId`, then to the first available candidate. Configs written by older versions with only `serviceId` / `modelId` behave exactly as before. The App should bind default values to the Host / namespace / service / model identities captured at request time; treat missing fields as empty and do not infer an old service.

The default bundle's entry ID is dsh-media, but the Host may name instances differently. Clients should discover them through the metadata contract in the selected Host's settings namespaces and keep the namespace identity; multiple instances must not be merged by identical label.

## 2. What the source chain has confirmed

| Link | Exact location (DSH rc.2; App-marked rows are App sources) | Conclusion supported |
|---|---|---|
| metadata write | vendor/schemastery/src/index.ts:385–388 | extra(key,value) merges into schema.meta; this candidate uses extra('extra', {...}) |
| JSON serialization | same file:311–321 | toJSON serializes with schema properties and refs; plain JSON extra is preserved |
| volatile projection | packages/settings/settings/src/schema.ts:plainSchema / volatileForm | services itself is volatile, so the whole services schema is cloned, removing only the volatile flag and secret defaults; extra is not deleted |
| root field filtering | same file:volatileForm | non-volatile root objects are rebuilt and root metadata may be lost; that is why the catalogue is not on the root |
| actual describe | packages/settings/settings/src/index.ts:302–331 | descriptor.schema=form.toJSON; value/base/user are each projectForm'd, metadata is not mixed into these values |
| RPC projection | packages/api/settings-controller/src/index.ts:namespaceView / describe | descriptor.schema is emitted directly as JSON with no extra filtering |
| App graph parser | packages/dsh_client/lib/src/engine_settings_api.dart:132–187 | parses uid/refs and builds SchemaNode |
| App metadata parser | same file:58–80 | unknown meta keys are dropped, but map['extra'] is explicitly preserved |
| App namespace | same file:387–402 | schema is parsed into SchemaNode; do not assume the raw JSON survives |
| lifecycle | vendor/loader/src/index.ts:29–34 | volatile-update notifies the owning instance after the reference commits |

So "arbitrary JS properties can be attached" is not the reason this path was chosen; serialization, form filtering, RPC and the App parser were each read to the end. No real SettingsForms/describe run or Flutter parsing test has been executed; conclusions are limited to this fixed-version source chain.

## 3. Reading requirements on the App side

The App-side implementation lives in `app/lib/state/media_catalog.dart`. The existing SchemaMeta.extra already preserves the catalogue; unknown-meta handling needs no change for this path. The App's (M5) reading must:

1. Take this contract from services.meta.extra, validate v and the basic types, and keep the namespace, Host and connection generation.
2. Read the real service config value.services and intersect by enabled, profile and the service's allowed models list; call the public credentials.describe when needed to decide whether a keyRef is configured. Never treat the existence of the static catalogue as service availability.
3. Render parameter headers with the same grammar as header.js. Reject unsupported explicit parameters; do not rewrite 3:4 into 2:3, and do not default a same-named model to the first service.
4. Use 〈serviceId/modelId〉 to disambiguate models with identical labels; match label and marker together. The catalogue provides the actual model ID; do not guess IDs from display names.
5. Bind requests, later display and defaults to the Host / namespace / service / model identities captured at submission; never re-derive the default target from a new Host after a wait.
6. 0.3.0 opens image, edit and video according to the catalogue and the currently configured services. video=true cannot replace service-credential and model-availability validation; hide executable video choices when no usable video service exists.
7. Optionally read `presets` and `defaults.image*` / `defaults.video*`: on missing fields, type mismatch or unknown catalogue `v`, ignore them and fall back to manual configuration; never block legacy reads. Values supplied by `presets` are still validated against this contract before the App saves a service.

When catalog.v is unknown or fields are corrupt, stop generation-mode selection but keep the ordinary conversation tool path. When the catalogue is missing, the App may say the current Host provides no catalogue; do not guess from an App-bundled legacy model table. If a new location or structure is ever needed, use a new version with an explicit migration; this draft does not treat the old candidate value.catalog as an authoritative fallback.

Old App builds do not need this catalogue to send ordinary conversations; tool results fall back to existing Markdown image display. Dedicated generation modes and exact tool selection still need end-to-end validation against a real Host.

## 4. Why the catalogue is not a const config value

A value.catalog under const+volatile+disabled has a real upgrade counter-example: a client explicitly wrote C1 into raw config, the upgrade package changes the schema to const(C2) with C1!=C2; the old explicit value does not go through the default branch and the const validation fails. disabled only controls the UI and provides no Host write protection.

This candidate has no catalog config field. The catalogue exists only in schema metadata; the ordinary values of services/defaults/limits/budget/credentials never include it. settings describe's value/base/user, the replacement form and user overrides should not carry the catalogue; an upgrade replaces only the installed JSON and schema metadata and never migrates persisted catalogue values. Real settings integration tests should add the regression "an old version wrote ordinary service config → upgrade the catalogue → it still starts" instead of asserting only that a button is disabled.

## 5. Fixed credential slots and rejected designs

### Secrets inside the array do not work

The App's schema_fields.dart:kindOf reads array<object> as objectList. But field_sheets.dart:_ObjectItemPage._draftField:1539–1596 only edits toggle/choice/text/number; every other type, secret included, renders as a disabled row. So the services array carries ordinary config only; do not claim the in-array key button works because a top-level SecretFieldTile exists.

### The mutable credential editor was rejected

An earlier candidate paired a plain keyRef input with a transform that generated a hidden credentialRef, letting the secret read its sibling. On the normal path _AcknowledgedSheet._save waits for service confirmation before closing; SettingsEditSession._checkSecretTarget also compares old/current refs and rejects a stale secret sheet whose target moved.

But if the keyRef write is pending while the user dismisses, the optimistic keyRef and the server-derived credentialRef can temporarily differ; a note saying "wait for the save to finish" does not close the window where a write lands on the old target. This candidate has no such dynamic editor.

### The current four slots

credentials is a plain object group; slot1–slot4 each have a fixed const credentialRef, DSH_MEDIA_SLOT_1_API_KEY and friends. The secret is a leaf node whose target never moves with the services array. A service keyRef is explicit ordinary config pointing at a slot or an existing reference the user knows.

SecretFieldTile (schema_form.dart:404–457) constructs the SettingsEditSession; the controller (engine_settings_state.dart:418–442, 776–815) first verifies source and target, then writes Host credentials through client.setProviderKey / clearProviderKey. It never stores the real key in config.

Simply writing the secret as const('') also has an error-echo problem: errors thrown by the Schemastery const resolver include the got value (657–659). It is instead a transform(any) with strict empty-string validation; non-empty values throw only the fixed Chinese error. Wrapping in intersect does not work either: the App's schemaSections:555 prefers reading intersect as a group. In the current transform, effective any is the leaf; kindOf sees the outer secret role first, so the key-button path is preserved while every non-empty ordinary config write is rejected.

These are the design rationales the fixed sources support; actual button clicks, credential persistence, App reconnection and settings reload are still to be run. The Node tests pass and cover non-empty rejection with no fake key in the error, the fixed refs being immutable, and secret redaction.

Since 0.3.0 `keyRef` may be any configured env-style credential name (e.g. `DSH_MEDIA_ARK_API_KEY`); new App builds can create that credential per provider before writing the service. The four fixed slots remain and old configs need no migration. The Host still resolves only the explicit `keyRef` and never enumerates other plugins' credential channels.

## 6. Key-reuse boundaries

A known CredentialRef can be resolved by credentials.resolve against the Host's actual provider, possibly coming from persisted credentials, the environment or a dotenv fallback. M0 does not blanket-interpret an unset as "absolutely no key".

This does not mean auto-enumerating every identity of llm-pi-ai's currently selected channel. The latter also involves instance, provider, endpoint, auth method and scoped credential records. M0 only allows the user to explicitly enter a known ref; it never snoops another plugin's scoped grant and never silently switches to another "apparently configured" key.

## 7. Catalogue sources and dates

The following official pages were opened and searched on 2026-10-28 (design-doc V labels are not reused):

- https://developers.openai.com/api/reference/resources/images/methods/generate
- https://developers.openai.com/api/docs/guides/image-generation
- https://developers.openai.com/api/docs/models/gpt-image-2.5-sunburst
- https://developers.openai.com/api/docs/models/gpt-image-2.5-flare
- https://ai.google.dev/gemini-api/docs/openai (read in full; the page says Last updated 2026-10-26 UTC with no fixed version, so it is not treated as a permanent protocol guarantee)

Exactly three OpenAI model IDs are listed on that Image API page; the three standard sizes and low/medium/high belong to the verified subset. GPT Image returns base64 and does not accept the old response_format. The page lists more sizes, qualities and capabilities than this M0 data opens. Prices and account entitlements were not verified and the catalogue does not provide them.

The catalogue additionally contains a minimal compatibility entry for gemini-2.5-flash-image: profile=openai-compatible, responseFormats=[b64_json], maxN=1, with all other optional parameter sets empty. The basis is the "Generate an image" request shape on the Gemini page above (model, prompt, n=1, response_format=b64_json, reading data[].b64_json); only shape-compatibility with the existing core is inferred, no real request was sent and account usability is not proven. No video, upload or extra_body was added.

## 8. Acceptance not yet run

| Acceptance item | Current status |
|---|---|
| Real Config / Schemastery / redactSecrets Node tests | 0.3.0 `npm test` 314/314 passed; 0.2.0 rc.4 dependency details in VERIFICATION.md |
| Real Loader→SettingsForms→settings/describe graph→extra | source chain verified, running UNRUN |
| Locating extra after real App SchemaNode decoding | source verified, Flutter UNRUN |
| Four-slot key write/clear and non-empty rejection of ordinary settings | Node tests pass; real UI and Host persistence UNRUN |
| Fixed-slot stale sheet still writing the original fixed target when a service keyRef changes | needs real UI run, UNRUN |
| Catalogue updates never freezing old values into user overrides | source design supports it, integration UNRUN |
| Marked same-name models, Host changes and stale-catalogue response suppression | App (M5) scope, end-to-end UNRUN |
| Real header trigger / plain-wording trigger on two headless runs | passing under local mocks (the model is a fixed script and proves nothing about real models); event records not committed, fixtures not forged |

All test commands explicitly set TZ=Asia/Shanghai.
