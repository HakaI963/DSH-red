# @ccch1mneyyy/dsh-media

The Host-side media plugin for DSH Go, version `0.3.0`. It generates images, edits images from a single sentence, and produces videos as background jobs; service keys stay in Host credentials and originals are saved into the current workspace. The settings namespace remains `dsh-media`, and media results use the frozen `meta["dsh-go/media"]` v1.

0.3.0 declares compatibility with DSH `0.2.1-rc.4` and `0.2.2-rc.1`, validated with each version's existing runtime locks without re-resolving production dependencies. For the actual validation scope and unverified items see `VERIFICATION.md`. Model availability, moderation, quotas and final charges are decided by the providers. The App ships only the settings and media-display entry points; the Host plugin is still installed separately. This change does not publish to npm, preinstall or auto-enable the plugin, and calls no real paid service.

## Supported scope

| Service / profile | Image & edit | Video | Cancellation |
|---|---|---|---|
| OpenAI / `openai-gpt-image` | GPT Image 2, 2.5 Sunburst / Flare; single-reference edit | none | stopping the wait on a sync request does not mean the vendor stopped billing |
| Gemini OpenAI-compatible / `openai-compatible` | Gemini 2.5 Flash Image, single image, explicit `b64_json` | none | same as above |
| Volcengine Ark / `ark-image`, `ark-video` | Seedream 5.0 Pro; single-reference edit | Seedance 2.5 text-to-video / single first-frame image-to-video | only while queued; confirm via a follow-up query after a real DELETE |
| Alibaba Model Studio / `ali-wan-image`, `ali-video` | Wan 2.7 Image; single-reference edit | Wan 2.7 text-to-video / single first-frame image-to-video | only while PENDING; confirm via a follow-up query after a real cancel request |
| SiliconFlow / `silicon-image`, `silicon-video` | Qwen Image; Qwen Image Edit 2509 single-reference edit | Wan 2.2 T2V / I2V | the current official API offers no cancellation; stopping the local wait may still incur charges |

Exact model IDs, endpoints, parameter whitelists and official references live in `data/models.json`. This version opens only the documented subset and does not represent full provider capability. Seedream Lite stopped new purchases, so the officially listed Pro replacement is used; Lite multi-image fields that Pro does not support are never sent. [Ark deprecation notice](https://docs.volcengine.com/docs/ark/model-deprecation-notice?lang=en)

When no enabled service has configured credentials, no generation tools or system prompt are registered. `edit_image` appears only when an edit-capable model is configured. Native services accept only the HTTPS hosts and paths verified in the catalogue; OpenAI-compatible services take a configurable HTTPS API root and still run public-address and download-safety checks.

## Configuration

Three steps to get started:

1. **Add a service**: pick image or video from a provider preset (Volcengine Ark, Alibaba Model Studio, SiliconFlow, OpenAI, Gemini). The service ID, request protocol, API root, return format and model IDs are filled from the preset automatically — nothing to spell by hand. Create one service each for image and video; image and video services of the same provider can share one credential.
2. **Fill the API key**: new App builds auto-generate a credential name per service (e.g. Ark image and video both use `DSH_MEDIA_ARK_API_KEY`, reused across the same provider), so the key is saved once in the service detail; you can also switch to any configured env-style credential name under "advanced" to reference an existing key. The four legacy fixed slots `DSH_MEDIA_SLOT_1_API_KEY` through `DSH_MEDIA_SLOT_4_API_KEY` still work but are kept only for compatibility; new settings need not be duplicated there.
3. **Enable**: pick the image default service and model and the video default service and model separately, review cost protection, then enable. `generate_image` / `edit_image` use the image defaults, `generate_video` uses the video defaults; when the per-kind defaults resolve to nothing, fall back to the legacy generic `defaults.serviceId` / `defaults.modelId`, then to the first available candidate.

Presets come from `presets[]` in `data/models.json`, read by the App through the service's catalogue metadata; legacy App builds ignore the field and existing configs with legacy generic defaults behave exactly as before.

For example, Ark image and video services (references only, no keys):

```yaml
services:
  - id: ark_image
    enabled: true
    provider: ark
    baseUrl: https://ark.cn-beijing.volces.com
    profile: ark-image
    models: doubao-seedream-5-0-pro-260628
    keyRef: DSH_MEDIA_ARK_API_KEY
  - id: ark_video
    enabled: true
    provider: ark
    baseUrl: https://ark.cn-beijing.volces.com
    profile: ark-video
    models: doubao-seedance-2-5-260628
    keyRef: DSH_MEDIA_ARK_API_KEY
defaults:
  imageServiceId: ark_image
  imageModelId: doubao-seedream-5-0-pro-260628
  videoServiceId: ark_video
  videoModelId: doubao-seedance-2-5-260628
budget:
  dailyCny: '20'
  unknownPriceHoldCny: '20'
limits:
  maxImages: 1
```

Both Bailian profiles use root `https://dashscope.aliyuncs.com` and also accept the Beijing workspace addresses declared by the catalogue. SiliconFlow is `https://api.siliconflow.cn`; OpenAI is `https://api.openai.com/v1`. The Gemini compatibility root is `https://generativelanguage.googleapis.com/v1beta/openai` with `responseFormat: b64_json`. `responseFormat` stays empty for other profiles; the presets already carry these values.

## Usage and recovery

Ordinary chat can ask for "画一张蓝色的猫" (draw a blue cat), "用这张参考图把背景改成夜晚" (use this reference image to change the background to night) or a 5-second video. Generation mode reuses the ordinary user-message parameter header; no new commands or custom session events are added. Video parameters depend on the model; SiliconFlow currently opens only the size mapping, with no guessed seconds or resolution fields. First-frame image-to-video omits `aspect`.

`generate_image` / `edit_image` return the actual file plus v1 metadata when done. `generate_video` immediately returns an `rid` and a background job: real `ctx.jobs` track queued/running/terminal state, the completion notice wakes the Agent, and `get_media_result(job_id)` then fetches the final media card. The plugin never calls `jobs.wait` and never forges session events. v1 has no separate cancelled status; a confirmed cancellation uses `status: failed` with `error.code: cancelled`; an unconfirmed remote cancellation uses `remote_may_continue`.

After a Host restart, the original session can call `resume_media(rid)` to keep querying the saved provider task ID. Recovery creates no new provider task and reserves no new cost; it accepts only the original session, workspace, service endpoint, credential ref and model identity. Completed local indexes can be reused directly. This version is **explicit recovery**: it does not yet rebuild all jobs automatically, and when a POST was accepted but the response lost without a task ID, it cannot be auto-found and creation is never retried.

Image originals are written to `<cwd>/generated/<UTC date>/`; videos are raw MP4 (max 300 MiB). Video width/height, duration and codec are read from the file header and not passed off as full decode validation. A catalogue-verified MP4 codec still does not guarantee hardware decode on every Android device. The plugin's private index and budget ledger live in `<DSH_HOME>/media/dsh-media/`, contain prompts and task-recovery identities, and must not enter public diagnostic bundles.

Reference images are limited to one regular PNG / JPEG / WebP file inside the currently writable workspace, max 10 MiB. Symlinks, named pipes and out-of-workspace paths are rejected. Each approval lists the actual paths and target service; content is read and pinned before approval, and if the file identity changes after approval the submission is refused — never upload the substituted file.

## What cost protection actually means

There are currently no quotes reliable enough to cover every billable input, so **every image, edit and video requires an explicit one-time consent**, and the card shows no fictional estimate. Defaults: ¥20 daily local budget and a ¥20 hold per unknown-price request; the default settings fit only one such hold per day. Dates roll by the Shanghai timezone.

The hold is a local accounting guardrail, **not a hard cap on the provider's actual amount**. The real bill may exceed the hold. Lowering the unknown-price hold admits more requests; it does not change provider prices. The ledger persists the uncertain state before submission; failures, timeouts, cancellations or disconnects after acceptance keep the hold; this plugin never claims refunds. Only requests proven never submitted release the hold. The ledger's internal `basis: estimate` records settle local holds and are not verified provider quotes.

Ark and Bailian may cancel only while queued. Cancel requests can race with state changes; "cancelled" is shown only when a follow-up query explicitly returns cancelled / CANCELED; while running, on query failure, or when the vendor does not support cancellation, the message says the server may continue generating and charging. Paid POSTs are never auto-retried.

## English

`@ccch1mneyyy/dsh-media` is a Host-side DeepSeek Harness plugin. It keeps credentials on the Host, saves original media in the current workspace and emits DSH Go media metadata v1. The settings namespace remains `dsh-media`. Node `^22.19.0 || >=24.0.0` and DSH `0.2.1-rc.4` or `0.2.2-rc.1` peers are required; the DSH Go manifest declares app `1.0.2` or later.

It supports OpenAI / Gemini-compatible images, Ark Seedream / Seedance, Alibaba Wan and SiliconFlow Qwen / Wan. Editing uses one workspace image. Video generation runs as a real background job; `get_media_result` retrieves its media result after the completion notice. `resume_media(rid)` explicitly resumes a saved provider task in its original session without submitting again. Provider cancellation is confirmed only when the API reports it; SiliconFlow cancellation is unavailable.

All currently bundled prices are unknown. Every generation requires explicit one-time approval. The default CNY 20 daily ledger and CNY 20 per-request hold limit local reservations, **not actual provider bills**. Accepted or uncertain submissions retain their hold. Validation uses each supported runtime version’s existing pinned dependency graph; see `VERIFICATION.md` for current evidence. No paid-provider or Android App installation/media-viewer validation is claimed. The package is prepared for publication but this change does not publish or preinstall it.

Version 0.3.0 also publishes provider presets in the plugin catalogue. The App builds a service from a preset, writes any env-style credential name such as `DSH_MEDIA_ARK_API_KEY`, reuses one key for the image and video services of the same provider, and keeps separate image/video defaults. The four fixed slots remain for compatibility only, and a legacy `serviceId`/`modelId` default keeps its exact previous behavior.
