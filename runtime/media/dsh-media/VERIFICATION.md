# Media verification and reproduction

## 0.3.0 compatibility integration — 2026-11-07

This section is based on an isolated worktree from the latest main baseline 3a91fab9 and does not reuse the 320-test pass conclusion of the older worktree. It keeps main's existing owner teardown, staging cleanup and storage error-classification fixes plus their tests; no production runtime locks, patches or media execution code were changed.

- DSH 0.2.2-rc.1: full Node suite 325 passed, 4 DSH_PREFIX-gated cases skipped; the owner lifecycle also ran against rc.1's real service, 4/4 passed (no skips). Headless image and video both passed with 27/38 events respectively.
- DSH 0.2.1-rc.4: full Node suite 325 passed, 4 DSH_PREFIX cases specific to rc.1 skipped; headless image and video both passed with 27/38 events respectively.
- Each version's test prefix is derived from its own existing runtime lock, adding only the mock-server and image-size at exact SRI; compatibility.test compares every non-root record of the original lock line by line and verifies the real host compatibility evaluator's positive/negative version gates.
- Headless waits for the actual video job to settle before fetching results; rc.1 keeps the explicit native executor on / PTC executor off, and only rc.4 uses the old tools.mode config.
- Linux arm64 / Android PRoot, Node v24.22.1, local HTTP/LLM mocks; no real paid vendor, App installation, media viewer or market publication validation.

Reproduce: prepare.mjs defaults to 0.2.2-rc.1; add --dsh-version 0.2.1-rc.4 for the older one. Run a separate npm ci --ignore-scripts per version, switching the source tree's node_modules test link serially. Do not omit the current platform's native loader/system optional bindings. The real owner-lifecycle cases additionally set DSH_PREFIX to the rc.1 prefix before running; skips must never be reported as passes.

## History: 0.2.0 verification and reproduction

Environment: Linux, Node v24.21.0, DSH npm `0.2.1-rc.4`, `TZ=Asia/Shanghai`. All 628 non-root records of the existing rc.4 runtime lock were preserved, adding only `dsh-llm-mock-server@0.2.1-rc.4` and `image-size@2.0.2` at exact integrity; jobs from other versions were not mixed in.

## Reproduce

Run from the repository root; `/absolute/media-deps` and `/absolute/media-evidence` must be fresh directories. Install steps run no npm lifecycle scripts; if the real workspace already has node_modules, do not overwrite it — verify its provenance first.

```sh
node runtime/media/dsh-media/test/headless-v2/prepare.mjs --dsh-version 0.2.1-rc.4 --out /absolute/media-deps
npm ci --ignore-scripts --prefix /absolute/media-deps
ln -s /absolute/media-deps/node_modules runtime/media/dsh-media/node_modules
TZ=Asia/Shanghai node --test runtime/media/dsh-media/test/*.test.js
TZ=Asia/Shanghai node runtime/media/dsh-media/test/headless-v2/run.mjs --out /absolute/media-evidence
```

On shared dev machines run tests / headless serially and give each workspace its own TMPDIR. The prepare generator writes only into its own directory, never re-resolving or modifying runtime locks; its test-inputs.json records the baseline hashes and retained record counts.

## What was executed and where evidence stops

- Full Node suite: **306 / 306 passed**, including the existing M0, budget ledger, HTTP / file-safety regressions and the new provider / jobs wiring cases.
- Local real HTTP: image and edit for OpenAI, Ark, Bailian and SiliconFlow; text-to- and image-to-video for three of them, real DELETE / POST cancellation, non-cancellable while running, failures, submission timeout, query timeout. A socket drop after POST acceptance submits exactly once and stays submission_unknown. Downloads keep the original bytes and carry no service keys.
- Security boundaries: exact reference-file approval, post-approval identity substitution rejected, FIFO rejected, JSON-escape-inflated metadata rejected before POST, budget across requests, calling video under the image default service, recovery in the original session. A real child process ran `process.exit(77)` after publishing the MP4 but before writing the index; a new process then continued the publication under the new filename with the old file retained and zero vendor POSTs.
- Real unmodified rc.4 public CLI: one actual Session each for image and video through the production admission / approval / ledger path; the mock seam only replaces the HTTP target, never generate, and never skips cost approval. Video used real jobs.start, a completion producer state and tool-jobs notifications, then really executed get_media_result with matching rid/job from initial to terminal state.

Headless output includes identity.json (Node, CLI, source and test-lock hashes), summary.json, per-case wire-audit.json, raw Session events, physical V4 JSONL and verified.json. Verification checks continuous seq, object-by-object equality of raw vs persisted events, clean exit, no fake credential echo, and output matching fixture bytes. Logs keep the private test workspace absolute paths, are not rewritten into phone paths, and are not copied as an App live fixture.

A single headless rc.4 run does not auto-wait for ordinary jobs. The test makes the second local mock LLM response finish the current turn only after the download completes, ensuring the real notification reaches a still-alive Host; jobs.wait / job_output(wait:true), which would mark awaited and suppress notifications, is never called. This verifies the real Host wiring, not that any one-shot headless process would wait out a video on its own.

The video fixture is a locally synthesized 32×24 blue 1-second H.264 MP4 with no third-party material; generation commands:

```sh
ffmpeg -f lavfi -i color=c=blue:s=32x24:r=1:d=1 -c:v libx264 -pix_fmt yuv420p -movflags +faststart synthetic.mp4
base64 -w0 synthetic.mp4 > runtime/media/dsh-media/test/fixtures/video.base64
```

## Unverified / deliberate limits

No real paid service was called; API fields come from the official references listed in data/models.json and prove neither account entitlements nor actual image quality. No Android / PRoot / App media full-chain, real-model language understanding, real settings form write + reload, or cross-Host deployment was executed. The old test/headless M0 verification material is historical only; the current entry point is headless-v2.

Prices are currently unknown; per-request approval and local holds cannot guarantee provider bills stay under ¥20, and no refund is inferred. A Host restart requires the original session to explicitly call resume_media; tasks are not rebuilt automatically, and uncertain submissions without a task ID cannot be auto-recovered. Recovery uses a new naming to avoid overwriting half-published leftovers, and crash-era old files and .pending directories are not auto-deleted. MP4 gets format and actual header-metadata validation only, with no decode guarantee on every device. Ark/Bailian confirm queue-stage cancellation only; SiliconFlow cancellation is unavailable.

npm pack completed with local content inspection and unpacked import. Before the 2026-10-31 publication and again after switching to the alternate organization, the full suite passed 306/306 under the exact rc.4 dependency set. The old 0.2.0 package's staging download matched byte for byte; the new token's direct publish returned 409 because the staged version was taken, and it proceeded as the normal update to `@ccch1mneyyy/dsh-media@0.2.1`. The final tarball's 19 files match the source, 48,019 bytes; versus the 306-pass package only the package.json version field differs and runtime code is unchanged. The historical headless run's JS sources, CLI, Node and test-lock identities all match and it was not re-run.

The previous token's direct-publish limit was finally made explicit as `E_STAGE_REQUIRED` — manual approval is not required for all npm publishes. The latest token's 0.2.1 submission returned HTTP 202; from 2026-10-30 19:55:51 UTC on, anonymous exact-version queries and public tarball downloads both returned 200, and the 48,019-byte download matches the local SHA256 and registry SHA512 exactly, confirming the published version is downloadable. Device installation, the Android/PRoot media full chain and real paid generation remain unverified; see PUBLISH.md and the market acceptance record.

## Public package install and profile combination (0.2.1)

A fresh private consumer installed the exact `@ccch1mneyyy/dsh-media@0.2.1` from the public registry using an isolated empty npmrc, with `--ignore-scripts --legacy-peer-deps`, pulling 6 ordinary dependencies. All 10 Host peers were checked at exact versions and then reused the existing rc.4 dependency set; the install lock's tarball URLs and SHA512 equal the published artifacts.

Three exports were imported through real bare specifiers: `. / ./config / ./package.json`; the installed package's `cordis.patch.yml` points to the new official scope with the entry ID still `dsh-media`. The unmodified rc.4 CLI ran `--dump-config` in an isolated `DSH_HOME` and successfully composed `dsh-media` using the installed package's original patch. This verifies actual npm install, export loading and profile patch composition; it does not claim actual mounted activation, App installation or new media-generation verification.

The real market npm scan with 24 checks and builds of all 5 packages passed; Pages and both Worker files are live at HTTP 200, Worker reports `X-Market-Stale:false`, the official format 1 parser and the actual Worker validator both pass, and the live media entry is official / 0.2.1 with SRI matching npm. The standalone check of the `/p/%40ccch1mneyyy%2Fdsh-media` share page returned 200 with the Chinese title, 0.2.1 and the correct `dshgo://` deep link. In-App entry: Settings → Plugins → Plugin market → Official; when uninstalled, Settings → Image & video also offers an install button for the current host. This confirms the live discovery path and existing UI wiring; no real click-to-install was performed on a phone.
