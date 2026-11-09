# Third-Party Notices

This file lists in one place the third-party code and assets that dsh-go has copied or adapted into its source, together with the fonts, native libraries and Linux runtime components distributed with the App. The `Portions derived from …` line in source file headers points here.

- The in-App "Settings › Open-source licenses" page distributes the same notices with the APK (`app/lib/ui/common/third_party_licenses.dart`; fonts in `app/lib/ui/settings/font_licenses.dart`).
- Dart / Flutter dependencies should be checked against `app/pubspec.lock` (and the local packages' lockfiles) for both direct and transitive dependencies; Flutter collects licenses from each package's root `LICENSE` and shows them on the licenses page. They are not repeated here, package by package, but before a release you must still verify the license assets of the actual APK — a dependency declaration is not proof of inclusion.
- The full license texts are in the "Full License Texts" section at the end.
- This project's own license is in `LICENSE` (AGPL-3.0); the brand mark and mascot artwork are neither third-party nor covered by the AGPL grant — see `ASSETS.md`.

## 1. Code copied or adapted into the source

### Phase (used with the author's permission)

| Item | Details |
|---|---|
| Project | Phase, https://github.com/CikeSeven/phase (based on commit `c209f6f`) |
| Copyright holder | Copyright (c) 2026 CikeSeven |
| License | Used with the author's permission |
| Use | Phone control: accessibility screen reading and actions, the control overlay, and the privileged virtual display of "Do Not Disturb" mode |

The upstream path prefix is `android/app/src/main/kotlin/app/xiangyue/phase/`; the prefix in this repository is `app/android/app/src/main/kotlin/dev/nolyf/dsh_red/phone/`.

| File in this repo | Upstream source |
|---|---|
| `a11y/Actuator.kt` | `accessibility/AccessibilityDriver.kt`, `vision/VisualDriver.kt` |
| `a11y/ControlOverlay.kt` | `accessibility/TaskOverlay.kt` |
| `a11y/MainScreenDriver.kt` | `accessibility/AccessibilityDriver.kt` |
| `a11y/PhoneA11yService.kt` | `accessibility/PhaseAccessibilityService.kt` |
| `a11y/ScreenShooter.kt` | `vision/VisualDriver.kt` |
| `background/PrivilegedDisplayCore.kt` | `shizuku/ShizukuDeviceService.kt`, `DisplayTextConnection.kt`, `DisplayTextInput.kt` |
| `background/PrivilegedDisplayEntry.kt` | `shizuku/ShizukuDeviceService.kt` |
| `background/PrivilegedProtocol.kt` | Set of failure reason codes |
| `background/ShizukuStarter.kt` | `shizuku/ShizukuConnection.kt` |
| `app/android/app/src/main/res/xml/phone_accessibility_service.xml` | `accessibility_service.xml` |

Original notice text:

```text
Portions of the phone control feature are derived from Phase
(https://github.com/CikeSeven/phase), Copyright (c) 2026 CikeSeven,
used with the author's permission.
```

### go.dshtui.com home page (delivered by the author for this project)

| Item | Details |
|---|---|
| Work | DSH Go showcase website: HTML, CSS, JavaScript, content-check and publishing scripts, eight feature showcase images |
| Author | ClayGao233 / Caiyunshi Shaobing (https://github.com/ClayGao233 , https://space.bilibili.com/28879571) |
| License | Delivered by the author for use on go.dshtui.com; the delivery came with no license statement and is not covered by this repository's AGPL-3.0 grant |
| Use | The home page of `https://go.dshtui.com/` |

Location in this repository: `site/home/`. Changes made on top of the delivered version: the product name unified as "DSH Go"; author, download, repository, contributors and share metadata filled in (`dist/site-config.js`); page CSP, a download QR code, a second download link and the Star count added (`dist/index.html`, `dist/author-ui.js`, end of `dist/refinements.css`); line endings unified. Working files that were never published (author notes, backup scripts, unused images) were not included. The feature showcase images were made from DSH Go UI screenshots and contain DSH Go's brand graphics and the whale-girl imagery (see `ASSETS.md`). The author's "web development" credit is kept in the page footer.

### PiPilot (MIT)

| Item | Details |
|---|---|
| Project | PiPilot, https://github.com/CikeSeven/pi_pilot |
| Copyright holder | Copyright (c) 2026 CikeSeven |
| License | MIT |
| Use | Structure and partial implementation of the chat UI, common components, drawer shell and theming |

All under `app/lib/ui/`:

- `chat/`: `chat_header.dart`, `chat_list.dart`, `chat_screen.dart`, `composer.dart`, `model_sheet.dart`
- `chat/render/`: `ansi_text.dart`, `code_block.dart`, `diff_view.dart`, `markdown_body.dart`
- `chat/widgets/`: `approval_card.dart`, `assistant_message.dart`, `question_card.dart`, `thinking_pill.dart`, `tool_row.dart`, `user_bubble.dart`
- `common/`: `app_sheet.dart`, `glass_pill.dart`, `overscroll_forwarder.dart`, `sheet_navigator.dart`, `status_dot.dart`, `streaming_cursor.dart`, `tool_glyph.dart`, `typing_indicator.dart`
- `settings/`: `diagnostics_page.dart`, `settings_widgets.dart`
- `shell/`: `drawer_drag.dart`, `home_shell.dart`, `sessions_drawer.dart`
- `theme/`: `accent.dart`, `app_theme.dart`, `backdrop.dart`, `highlight_theme.dart`, `motion.dart`, `palette.dart`, `semantic_colors.dart`, `shapes.dart`, `squircle.dart`, `typography.dart`

### DeepSeek Harness (MIT)

| Item | Details |
|---|---|
| Project | DeepSeek Harness, https://github.com/deepseek-ai/deepseek-harness |
| Copyright holder | Copyright (c) 2026 DeepSeek |
| License | MIT |
| Use | Several algorithms and graphics ported from the official client; the structure and behavior of some components were modeled on its web client |

| File in this repo | Upstream source | Use |
|---|---|---|
| `app/lib/ui/chat/secret_mask.dart` | `@deepseek-ai/dsh-client-ui-secret-mask` | Credential format, linear matching and masking; the eye icon |
| `app/lib/ui/chat/widgets/artifact_card.dart` | `@deepseek-ai/dsh-client-ui-deliverables` (`PresentedFileCard`, `Deliverables`) | Deliverable file cards |
| `app/lib/state/session_search.dart` | `@deepseek-ai/dsh-client-ui-workspace` (`deriveSearchResults`) | Conversation search-result merging |
| `app/lib/ui/features/schedule_editor/cron.dart` | `@deepseek-ai/dsh-client-ui-schedule` (`task-cron.js`) | Cron parsing and human-readable (Chinese) descriptions for scheduled tasks |
| `app/lib/ui/engine_settings/namespace_copy.dart` | The official settings pages (`dsh-client-ui-settings-*`, `dsh-client-ui-chat`, `dsh-client-ui-conversation`, etc.) and the Chinese UI copy in the READMEs of those packages | Chinese UI copy for engine settings |
| `app/lib/ui/common/think_glyph.dart` | `@deepseek-ai/dsh-web-frontend` (`IconThinkOutline`) | Thinking icon outline |
| `packages/dsh_client/lib/src/binary_response.dart` | `@deepseek-ai/dsh-client-connection` (`parseBinaryResponse`) | Binary result decoding |
| `packages/dsh_client/lib/src/deliverables.dart` | `@deepseek-ai/dsh-client-ui-deliverables` (`isPresentedData`, `isPresentedFile`, `presentedForClosing`) | Deliverable validation and per-turn selection |
| `runtime/patches/route-guard.diff` | `dsh-host-webserver` | Patch applied to DSH at runtime build time |

In addition, the structure and behavior of some App components were modeled on DeepSeek Harness's web client (MIT), including message actions, mentions, the input dock, turn progress, artifacts, the workspace, the terminal and scheduled tasks, among others; these are not listed file by file.

### DS Bot (Apache-2.0, modified)

| Item | Details |
|---|---|
| Project | DS Bot, https://github.com/Fei2411/DeepSeek-Bot (based on commit `1bebe82`) |
| Copyright holder | Copyright 2026 Fei2411 and the DS Bot contributors |
| License | Apache License 2.0 |
| Use | Normalization, validation, limits, summaries, selection rules and chart ticks for interactive replies (dsh-ui); the color scheme and default colors of the DS Bot client |

All files below have been modified; starting from the second line of each file, a `Modified: …` note describes the changes:

| File in this repo | Upstream source |
|---|---|
| `app/lib/ui/chat/dsh_ui/dsh_ui_model.dart` | `ds-bot/src/shared/views.js` (`normalizeView`, validation and limits, `viewSummary`) |
| `app/lib/ui/chat/dsh_ui/dsh_ui_reply.dart` | `ds-bot/src/shared/views.js` (`validateOptions`) |
| `app/lib/ui/chat/dsh_ui/dsh_ui_chart.dart` | `ds-bot/src/client/widget-chart.js` (`niceTicks`, numeric axis, tooltip) |
| `app/test/chat/dsh_ui/dsh_ui_model_test.dart` | Test cases from `ds-bot/test/views.test.js` |
| `packages/dsh_client/lib/src/dsbot_api.dart` | `src/client/inks.js` (color table), `src/client/characters.js` (`fnv1a`, `defaultColor`) |
| `app/android/.../runtime/GuestSetup.kt` | `ds-bot/src/host/tools.js`, `prompt.js` (`show_view` instructions and prompting rules) |
| `app/lib/ui/bots/bot_mention.dart` | `ds-bot/src/shared/mentions.js` (mention rules such as "everyone" and address resolution) |

The original DS Bot NOTICE is reproduced at the end of this file.

### ds-harness-remote (MIT)

| Item | Details |
|---|---|
| Project | ds-harness-remote, https://github.com/liguobao/ds-harness-remote |
| Copyright holder | Copyright (c) 2026 DSH Remote contributors |
| License | MIT (full text also kept in `packages/dsh_remote/LICENSE-ds-harness-remote`) |
| Use | Remote connectivity: protocol, framing, validation, secure channel, direct connection (WebRTC) and connection logic |
| Upstream version | `7e387df` (Host plugin 0.6.0); the workspace-upload protocol references `479b94341c0d0de63846f21d0fcca26997d158d1` (Host plugin 0.6.2) |

All paths are relative to `packages/dsh_remote/`:

| File in this repo | Upstream source |
|---|---|
| `lib/src/server/server_api.dart` | `apps/android/src/services/api.ts` (`RemoteServerApi`, incl. `turnCredentials`), `docs/protocol.md`, `docs/plugin-integration.md` |
| `lib/src/account/remote_account.dart` | `apps/android/src/services/server-session-manager.ts`, `device-directory.ts`, `connection.ts` (incl. opening a pure Relay connection after a direct connection fails), `packages/plugin/src/cli.ts` |
| `lib/src/carrier/tunnel_carrier.dart` | `packages/client-core/src/remote-gateway.ts`; the whitelist comes from `packages/plugin/src/harness-remote-bridge.ts`, `terminal-policy.ts`; the workspace-upload protocol and filename validation reference `docs/protocol.md`, `packages/plugin/src/workspace-upload.ts`, `rpc-router.ts` (`479b943`); rewritten in Dart, respecting the protocol's absolute limits, with concrete path/version restrictions taken from the host's replies |
| `lib/src/crypto/noise_ik.dart` | `packages/crypto/src/noise.ts`, `packages/crypto/src/index.ts` (session wrapper); the Noise IK state machine is this project's own implementation, with the upstream author's consent |
| `lib/src/channel/secure_channel.dart` | `packages/plugin/src/client-secure-transport.ts`, `packages/plugin/src/server-connection.ts` |
| `lib/src/channel/rpc_client.dart` | `packages/client-core/src/index.ts` (`RemoteClientCore`) |
| `lib/src/protocol/control.dart` | `packages/protocol/src/index.ts` (envelope, validation, limits, negotiation, Relay data frame) |
| `lib/src/protocol/messages.dart` | `packages/protocol/src/index.ts` (`RemoteMessage`, `SecureMessageCodec`, RPC payloads) |
| `lib/src/transport/relay_transport.dart` | `packages/webrtc/src/index.ts` (`RelayTransport`, incl. attaching the Relay data socket); sending `transport.selected` after attach, direct-connection capability negotiation and signaling send/receive come from `packages/webrtc/src/adaptive-transport.ts` |
| `lib/src/transport/webrtc_transport.dart` | `packages/webrtc/src/adaptive-transport.ts` (`negotiate`, `tryWebRtc`, ICE server acquisition and timeouts), `packages/webrtc/src/rtc-data-channel.ts` (initiator, remote candidate cache, path-selection retries) |
| `lib/src/transport/rtc_chunking.dart` | `packages/webrtc/src/rtc-chunking.ts` (`RTCH` chunking, byte-for-byte identical wire format) |
| `lib/src/transport/peer_connection.dart` | `packages/webrtc/src/rtc-data-channel.ts` (`inspectSelectedPath`, LAN detection), `packages/webrtc/src/rtc-adapter.ts` (address ranges, `stunOnlyIceServers`, DataChannel names) |
| `lib/src/util/bytes.dart` | `packages/protocol/src/wire-json.ts` (rejecting duplicate fields), `packages/protocol/src/index.ts` (canonical Base64URL) |
| `test/fixtures/noise-ik.json` | `fixtures/crypto/v1/noise-ik.json` (copied verbatim) |
| `test/fixtures/protocol-v1/` | `fixtures/protocol/v1` (copied verbatim) |
| `tool/e2e/patch-webrtc.mjs` | No code copied: during E2E it rewrites the upstream `apps/server/src/gateway.ts` to open WebRTC negotiation and signaling forwarding, matching the managed Server's behavior |

### DSHA (MIT)

| Item | Details |
|---|---|
| Project | DSHA, https://github.com/DSH-APP/DSHA |
| Copyright holder | Copyright (c) 2026 qiannianhuanxiang |
| License | MIT |
| Use | The `app_process` entry point of the privileged process for "Do Not Disturb" mode |
| File | `app/android/app/src/main/kotlin/dev/nolyf/dsh_red/phone/background/PrivilegedDisplayEntry.kt` |

### discourse_docker (MIT)

| Item | Details |
|---|---|
| Project | discourse_docker, https://github.com/discourse/discourse_docker |
| Copyright holder | Copyright (c) 2018 Civilized Discourse Construction Kit, Inc. |
| License | MIT |
| Use | Container configuration for the community forum, rewritten from the official `samples/standalone.yml` |
| File | `infra/forum/containers/app.yml`, `infra/forum/containers/app.reverse-proxy.yml` |

## 2. Assets

### Phosphor Icons (MIT)

| Item | Details |
|---|---|
| Project | Phosphor Icons 2.1.1, https://phosphoricons.com (`@phosphor-icons/core`) |
| Copyright holder | Copyright (c) 2023 Phosphor Icons |
| License | MIT |
| Use | Glyphs for the UI icon font; a few icons were completed to match its grid and outlines |

- `app/tool/icons/phosphor/`: icon source files and LICENSE
- `app/assets/fonts/DshIcons.ttf`, `app/lib/ui/theme/dsh_glyphs.dart`: generated by `app/tool/make_icon_font.py`
- `app/android/.../phone/a11y/ControlOverlay.kt`: the collapse key's path taken from `arrows-in-simple`

### Material Icons (Apache-2.0)

| Item | Details |
|---|---|
| Project | Material Icons, https://github.com/google/material-design-icons |
| Copyright holder | Google |
| License | Apache License 2.0 |
| Use | Icons for desktop shortcuts and quick-settings tiles; scaled and centered for the adaptive-icon canvas |

All under `app/android/app/src/main/res/drawable/`: `ic_shortcut_chat_glyph.xml` (`chat_bubble_outline_rounded`), `ic_shortcut_new_chat_glyph.xml` (`add_comment_outlined`), `ic_shortcut_voice_glyph.xml` (`mic_none_rounded`), `ic_tile_new_chat.xml` (`add_comment_outlined`).

### discourse-emojis (MIT)

| Item | Details |
|---|---|
| Project | discourse-emojis, https://github.com/discourse/discourse-emojis |
| Copyright holder | Discourse (gemspec author: Joffrey Jaffeux) |
| License | MIT (see its `discourse-emojis.gemspec`) |
| Use | Forum emoji names and alias table; data only, no images |
| File | `app/lib/forum/emoji_data.g.dart`, generated by `infra/forum/tools/gen_emoji_table.py` from `dist/emojis.json`, `dist/aliases.json` |

### JetBrains Mono (SIL OFL 1.1)

| Item | Details |
|---|---|
| Project | JetBrains Mono, https://github.com/JetBrains/JetBrainsMono |
| Copyright holder | Copyright 2020 The JetBrains Mono Project Authors |
| License | SIL Open Font License 1.1, full text in `app/assets/fonts/OFL.txt` |
| Use | The code font, distributed with the App and also injected into the web build |
| File | `app/assets/fonts/JetBrainsMono-*.ttf` |

## 3. Native libraries distributed with the App

The libraries below are packaged into the APK as Gradle dependencies; none was copied into the source.

| Library | Version | License | Copyright holder | Use |
|---|---|---|---|---|
| Shizuku-API (`dev.rikka.shizuku:api`, `provider`) | 13.1.5 | MIT | Copyright (c) 2021 RikkaW | "Do Not Disturb" mode obtains shell privileges via Shizuku |
| libadb-android | 3.1.1 | Apache-2.0 (dual-licensed GPL-3.0-or-later and Apache-2.0; used under Apache-2.0) | Copyright 2021 Muntashir Al-Islam | Wireless debugging pairing, ADB protocol and mDNS |
| spake2-android (a dependency of libadb-android) | 2.2.1 | LGPL-3.0 | Copyright 2021 Muntashir Al-Islam | SPAKE2 for wireless debugging pairing |
| Conscrypt (`org.conscrypt:conscrypt-android`) | 2.8.0 | Apache-2.0 | Copyright 2016 The Android Open Source Project | TLS for libadb; original NOTICE text at the end |
| Bouncy Castle (`bcprov`, `bcpkix-jdk15to18`) | 1.81 | Bouncy Castle Licence (MIT terms) | Copyright (c) 2000-2023 The Legion of the Bouncy Castle Inc. | Self-signed ADB client certificates |
| XZ for Java (`org.tukaani:xz`) | 1.10 | 0BSD | Copyright (C) The XZ for Java authors and contributors | Decompressing `.tar.xz` runtime packages |
| AndroidX WebKit | 1.15.0 | Apache-2.0 | The Android Open Source Project | Dark mode for the web plugin |
| flutter_webrtc (pub package, incl. Android plugin code) | 1.6.3 | MIT; its NOTICE also covers react-native-webrtc (MIT, Copyright (c) 2015 Howard Yang) and `SimulcastVideoEncoderFactoryWrapper.kt` (Apache-2.0, Copyright 2017, Lyo Kato; Copyright 2017-2021, Shiguredo Inc.); original texts at the end | Copyright (c) 2018 Hubei Jiezhiyun Technology Co., Ltd. | DataChannels for DSH Remote direct connections (P2P / TURN); only data channels are used — no microphone, camera or audio session |
| WebRTC Android SDK (`io.github.webrtc-sdk:android`, libwebrtc m150) | 150.7871.04 | BSD-3-Clause, plus Google's patent grant (PATENTS) | Copyright (c) 2011, The WebRTC project authors | flutter_webrtc's native WebRTC (`libjingle_peerconnection_so.so`, one per ABI) |
| AudioSwitch (`com.github.davidliu:audioswitch`, a fork of twilio/audioswitch) | `039a35aefab7747c557242fa216c9ea11743b604` | Apache-2.0 | Copyright 2020 Twilio, inc. | flutter_webrtc's audio-routing dependency; DSH Go never creates audio tracks, so it is never activated |
| mobile_scanner (pub package, incl. Android plugin code) | 7.5.0 | BSD-3-Clause | Copyright (c) 2022, Julian Steenbakker | Camera scanning and album image recognition for Remote's "pair with your PC by QR code" |
| ML Kit Barcode Scanning (`com.google.mlkit:barcode-scanning`, model bundled with the APK) | 17.3.0 | [ML Kit Terms of Service](https://developers.google.com/ml-kit/terms) (a Google binary distributed free of charge, not open source) | Google LLC | QR-code recognition for mobile_scanner, running on-device without Google Play services |
| CameraX (`androidx.camera:*`, a dependency of mobile_scanner) | per mobile_scanner 7.5.0 | Apache-2.0 | The Android Open Source Project | Camera preview while scanning |

### WebRTC 150.7871.04 verification record (2026-10-30)

Both AARs actually consumed from the Gradle cache and their `classes.jar` were checked: neither includes a LICENSE, NOTICE or PATENTS file. The AAR digests are listed below to distinguish the Maven/JitPack artifacts actually consumed from other same-named downloads:

```text
1872dda4e3bf7d6ea6f7c6e11861332081c57081a1e62fc82fab72415c69c84c  android-150.7871.04.aar  (49,068,339 B)
c8240221daa9a96d4ea01a4dc6f6f6b10b4903d2a71f9b57f838bdfeb6c3fcbc  audioswitch-039a35aefab7747c557242fa216c9ea11743b604.aar  (95,318 B)
```

| Source | Confirmed | What cannot be inferred from this |
|---|---|---|
| The `LICENSE`, `NOTICE` and `android/build.gradle` of the `flutter_webrtc 1.6.3` pub package | MIT copyright and the original NOTICE text; the Android dependencies pinned to the two versions in the table above. The NOTICE full text and MIT copyright lines are appended at the end | Flutter auto-collecting the package-root LICENSE does not guarantee the extra NOTICE or native static-dependency notices were automatically included |
| [LICENSE.txt of the pinned AudioSwitch commit](https://github.com/davidliu/audioswitch/blob/039a35aefab7747c557242fa216c9ea11743b604/LICENSE.txt) | Apache-2.0 with `Copyright 2020 Twilio, inc.`; consistent with the copyright and license already registered by the App | The AAR itself ships no license text, so the distribution must provide it |
| [License compilation for Android SDK v150.7871.04](https://github.com/webrtc-sdk/android/blob/1d6a68a74162d3f218f9681d49c6b5eef8f02800/Licenses/WEBRTC.md) | The release tag points to `1d6a68a74162d3f218f9681d49c6b5eef8f02800`; the file blob is `f371735b3a706ff1401bce870f096efc9bbb5f51`, with 30 license sections including WebRTC, Abseil, BoringSSL, etc. | The file is not tied to the actual AAR's build commit, GN arguments or per-ABI target dependency lists; one cannot directly conclude that the 30 sections exactly cover all components actually linked into this AAR |
| [LICENSE](https://github.com/webrtc-sdk/webrtc/blob/a802fa9849e0dae7f54c7d3deb05820a674b2f46/LICENSE) and [PATENTS](https://github.com/webrtc-sdk/webrtc/blob/a802fa9849e0dae7f54c7d3deb05820a674b2f46/PATENTS) of the m150 source | At verification time `m150_release` was pinned to `a802fa9849e0dae7f54c7d3deb05820a674b2f46`; the top-level BSD and Google patent texts are checkable, full texts at the end | This source snapshot has not been proven to be the build commit of the AAR above; the top-level BSD and patent texts also do not substitute for the licenses of statically linked third parties |

The upstream [v150.7871.04 release process](https://github.com/webrtc-sdk/android/blob/1d6a68a74162d3f218f9681d49c6b5eef8f02800/.github/workflows/fetch-webrtc-artifacts.yml) takes the AAR from build archives; the [release assets](https://github.com/webrtc-sdk/android/releases/expanded_assets/v150.7871.04) are three AARs and two repository source archives, with no per-build license manifest attached. Maven releases additionally modify the Java class version per [downloadAar.sh](https://github.com/webrtc-sdk/android/blob/1d6a68a74162d3f218f9681d49c6b5eef8f02800/downloadAar.sh); the GitHub AAR digest must not be conflated with the Maven AAR digest.

### Full upstream notice bundled with the package (2026-10-31)

The App now saves the **complete `Licenses/WEBRTC.md` from the same release tag** verbatim as `app/assets/licenses/webrtc-150.7871.04.md`, packaged via `pubspec.yaml`; the open-source licenses page in Settings shows all 30 sections under the `WebRTC` entry, and continues to show the top-level BSD and PATENTS texts. No sections were trimmed based on feature usage. This change completes the bundling of the upstream release notice; it does not mean every statically linked component was individually audited.

The source is pinned to `webrtc-sdk/android@1d6a68a74162d3f218f9681d49c6b5eef8f02800` (`v150.7871.04`): that tag's `gradle.properties` explicitly sets `VERSION_NAME=150.7871.04`; the `downloadAar.sh` above downloads `libwebrtc.aar` from that same tag's release assets and then modifies the Java class version. On 2026-10-31 this asset was actually downloaded and compared with the Maven AAR in the Gradle cache described above: the ZIP entry lists match, and all entries except `classes.jar` are identical; the JAR entry lists also match, with the only content difference being 433 classes whose major version changed from 65 to 61, all other bytes identical. This ties the actually consumed binary to the official release tag that carries the notice, without passing off the moving `m150_release` branch as the exact build source.

```text
f15e6bf94c1cbb9d6defaa95f04d1ae16b84e897f584032781091022d8366e30  official v150.7871.04/libwebrtc.aar (49,068,339 B)
d1f9382c6878ac024155fd6d44a5977329108bb8b0a01cea40e4a2f1d7de252e  webrtc-150.7871.04.md (788,358 B)
f371735b3a706ff1401bce870f096efc9bbb5f51  Git blob SHA-1 of the same notice
```

The native libraries of the official and Maven AARs have identical SHA-256 digests:

| ABI | `libjingle_peerconnection_so.so` SHA-256 |
|---|---|
| arm64-v8a | `2b561520298d9fec3e216baf58a53fbddf4a46dfd247880cbc3821875ed20200` |
| x86_64 | `b87bbb6d6c81c50f04538cd809575de633a789cc3555af2c5eb6ec414b148908` |
| armeabi-v7a | `5415e7a02ce83e983329575e7c2e46b8ced6c75baea3c41aa52b5699ccb54eda` |
| x86 | `9a532ef72dcda8b4b9874d4f578dbd3a5eb18bce01f9f91bee883bc0962dce3c` |

**Scope of verification:** this time the release-side license compilation was kept in full; Chromium was not rebuilt, the GN dependency graph of that build was not obtained, and the 30 sections were not proven to map one-to-one onto the binary's actual components. The limitation noted in the table above — the lack of a per-component build manifest — still holds; it is a separate matter from "the full upstream notice was not bundled with the package", which this change resolves. Any future WebRTC upgrade must re-verify the release tag, the binaries and the notice; this version's compilation and digests must not be reused.

Targeted tests verify that `LicenseRegistry` can load the full asset, checking the original digest, the 30 sections, the existing BSD/PATENTS and other license entries. After a release build, the following check must also be run against every final APK (replace the path with the actual file to be distributed); on success it prints the license digest and the WebRTC ABIs the APK contains:

```bash
python3 - path/to/final.apk <<'PY_APK'
import hashlib, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as apk:
    name = 'assets/flutter_assets/assets/licenses/webrtc-150.7871.04.md'
    data = apk.read(name)
    digest = hashlib.sha256(data).hexdigest()
    assert len(data) == 788358
    assert digest == 'd1f9382c6878ac024155fd6d44a5977329108bb8b0a01cea40e4a2f1d7de252e'
    libraries = [n for n in apk.namelist() if n.endswith('/libjingle_peerconnection_so.so')]
    assert libraries, 'No packaged WebRTC native library found'
    print(sys.argv[1], digest, libraries)
PY_APK
```

The final App's open-source licenses page should also be able to open the `WebRTC` entry and show the `zlib` section at the end of the compilation. The command and targeted tests above do not mean the final release APK was run; build and UI check results should be recorded separately in the actual release verification records. Disabling P2P by default does not remove these packaged dependencies or waive the notice-bundling requirement.


## 4. Linux runtime components

The Linux runtime embedded in the APK is built by `runtime/build-runtime.sh`; the components below come from upstream binaries or packages and each retains its own license. The build trims files and modifies proot's DT_NEEDED and libtalloc's DT_SONAME for the APK's naming rules; the specific changes are recorded in the build report. The native components' license texts live under `assets/runtime/licenses/` in the APK, and the Ubuntu packages' copyright files are kept in the runtime's `/usr/share/doc/`.

| Component | Version | Source | License |
|---|---|---|---|
| proot | 5.1.107.98 | Termux (source: https://github.com/termux/proot) | GPL-2.0 (`licenses/proot-COPYING.txt`) |
| libtalloc | 2.5.0 | Termux | LGPL-3.0-or-later (`licenses/libtalloc-notice.txt`) |
| libandroid-shmem | 0.7 | Termux | BSD-3-Clause (`licenses/libandroid-shmem-copyright.txt`) |
| Ubuntu Base and packages (tzdata, ca-certificates, git and dependencies) | 24.04.5 | Canonical / Ubuntu | Per-package, see `/usr/share/doc/` |
| Node.js | 24.22.1 | https://nodejs.org | MIT plus the licenses of its bundled components |
| CPython | 3.12.15 | astral-sh/python-build-standalone | PSF-2.0 plus the licenses of its bundled components |
| pnpm | 11.28.5 | npm | MIT |
| DeepSeek Harness main package (`@deepseek-ai/dsh`) | 0.2.1-rc.4 | npm | MIT; the patch set applied at build time is determined by `runtime/patches/pins.json` |

Corresponding sources for the GPL / LGPL components: the binaries of proot, libtalloc and libandroid-shmem come from Termux's official apt repository (https://packages.termux.dev/apt/termux-main ), and `runtime/build-runtime.sh` pins the SHA-256 of each .deb. The sources are at https://github.com/termux/proot (tag `v5.1.107.98`, downloaded and hash-checked at build time), https://www.samba.org/ftp/talloc/ (2.5.0) and https://github.com/termux/libandroid-shmem (0.7); Termux's build recipes are at https://github.com/termux/termux-packages . This project's only modifications to these three binaries are the DT_NEEDED / DT_SONAME renames described above.

### npm transitive dependencies and release verification

The main package's MIT license does not cover all transitive dependencies. The current default `runtime/locks/dsh-0.2.1-rc.4/package-lock.json` also pins the following components, which need separate verification:

| Component | Pinned version | License declared by the package | Release boundary |
|---|---|---|---|
| `@deepseek-ai/libreoffice-kit` and the corresponding platform components | 0.1.5 | MPL-2.0 | Keep the LICENSE/NOTICE of the components actually distributed; do not classify the whole `@deepseek-ai/*` scope as MIT |
| `@img/sharp-libvips-linux-arm64`, `@img/sharp-libvips-linux-x64` | 1.3.4 | LGPL-3.0-or-later | Based on the actual install result for the target ABI, verify libvips and its bundled components' licenses and corresponding sources |
| Other direct and transitive npm dependencies | See the pinned locks of DSH and pnpm | Each package's own license | The lock includes optional platform packages; not every entry can be assumed to be packaged in every APK — the actual rootfs file list is the reference |

`runtime/lib/rtbuild.py` keeps the Node distribution's `LICENSE` as `/opt/node/LICENSE` and keeps Ubuntu's `/usr/share/doc/*/copyright`; npm license files are not part of the regular development-metadata trimming. The final archive must still be checked for usable license files and symlink targets, especially where an npm package ships no license text. Preserving license texts and providing the corresponding source required by components such as GPL/LGPL are different checks; for each concrete release, record the version, build recipe, modifications and available corresponding source — a project homepage or a single statement is not a substitute.

### Unicode Character Database 15.0.0 (Unicode Data License)

Pet ZIP filename deduplication uses NFC and full casefold data tables generated from CPython 3.12 / Unicode 15.0.0; the generator is `app/tool/generate_pet_validation_data.py` and the table is `app/lib/pets/pet_unicode_data.g.dart`. No CPython implementation code was copied.

Copyright © 1991-2026 Unicode, Inc.

Data version source: https://www.unicode.org/Public/15.0.0/ucd/ReadMe.txt (original data notice © 2022 Unicode®, Inc.). The full current Unicode license text was taken from https://www.unicode.org/license.txt , retrieved 2026-11-07; this is the current V3 notice and is not passed off as the license version in effect at the 2022 release. The full license text is stored verbatim as `app/tool/unicode-15.0-LICENSE.txt`, packaged byte-identically as `app/assets/licenses/unicode-15.0.txt`, and shown by the existing LicenseRegistry page.

The `image` 4.12.0 pub dependency added in C710 is MIT-licensed; its original license is provided by Flutter's dependency-license collection with the package. The Codex Pet conversion is implemented independently from the published format; a source license is not treated as authorization to redistribute third-party atlases.

## 5. Format compatibility and acknowledgements (no code copied)

- **Clawd on Desk** (https://github.com/rullerzhou-afk/clawd-on-desk, AGPL-3.0): the desktop pet's theme-pack format, state names, priorities and duration defaults are compatible with it, and pet packs work on both sides. This project did not copy its code.
- **Streamdown** (https://github.com/vercel/streamdown): the way `app/lib/ui/chat/render/stream_repair.dart` repairs the tail of streamed Markdown was modeled on its `remend`.
- **DS Bot**: the dsh-ui component names match DS Bot's.
- **Open-Meteo** (https://open-meteo.com, data CC BY 4.0): the example plugin `examples/plugins/dsh-go-example-weather` uses its weather data, with the source noted on the card.

## Full License Texts

### MIT License

Applies to the following copyright notices:

```text
Copyright (c) 2026 CikeSeven                                   (PiPilot)
Copyright (c) 2026 DeepSeek                                    (DeepSeek Harness)
Copyright (c) 2026 DSH Remote contributors                     (ds-harness-remote)
Copyright (c) 2026 qiannianhuanxiang                           (DSHA)
Copyright (c) 2018 Civilized Discourse Construction Kit, Inc.  (discourse_docker)
Copyright (c) 2023 Phosphor Icons                              (Phosphor Icons)
Copyright (c) 2021 RikkaW                                      (Shizuku-API)
Copyright (c) 2018 Hubei Jiezhiyun Technology Co., Ltd.        (flutter_webrtc)
Copyright (c) 2015 Howard Yang                                 (react-native-webrtc)
```

The upstream discourse-emojis ships no LICENSE file or copyright line; it is used under the MIT license declared in its gemspec.

```text
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Apache License 2.0

Applies to DS Bot, Material Icons, libadb-android, Conscrypt, AndroidX WebKit.

```text
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS
```

### NOTICE: DS Bot (commit `1bebe82`, verbatim)

```text
DS Bot
Copyright 2026 Fei2411 and the DS Bot contributors

This product is licensed under the Apache License, Version 2.0 (see LICENSE).

==============================================================================
Third-party code in this repository
==============================================================================

DeepSeek Harness (https://github.com/deepseek-ai/deepseek-harness)
MIT License, Copyright (c) 2026 DeepSeek

  - ds-bot/dev/desktop-linux/launch.mts follows the steps of
    apps/desktop/scripts/dev.ts in DeepSeek Harness and reuses a few of its
    lines (the release record and the Electron launch arguments). It is a
    developer script for screenshots on Linux and is not in the npm package.
  - app/src/host.mjs and app/src/profile.mjs follow
    apps/desktop-host/src/index.ts: the profile boot and the ready, fatal and
    shutdown messages.
  - app/src/host-process.mjs follows apps/desktop/src/host-process.ts: the
    Host in Electron's Node mode and the shutdown escalation.
  - app/src/main.mjs follows apps/desktop/src/main.ts for the Windows window
    options (the caption-button overlay, its colors and the native theme). app/src/preload.cjs adapts
    apps/desktop/src/preload-windows.ts, apps/desktop/src/preload-platform.ts
    and apps/desktop/src/preload-theme.ts: the caption-band marks, the
    fullscreen mark, the caption-color measure and the theme sync.
  - app/src/bot-browser.mjs adapts apps/desktop/src/browser-guests.ts, and
    the browser part of app/src/preload.cjs follows
    apps/desktop/src/preload-browser.ts: the webview leases, the attachment
    checks and fixed guest preferences, the session policy and the new-window
    requests.
  - app/engine/cordis.patch.yml follows the bundle patch of
    @deepseek-ai/dsh-web-app (packages/bundle/web-app/cordis.patch.yml): the
    transport and host-service rows and the agent-plane rows it turns off.
    app/engine/preset-standard.patch.yml copies its standard preset
    (presets/standard.patch.yml), including the plan-mode prompt text,
    without the goal rows.
  - .agents/skills/record-browser-gif/ comes from the skill of the same name
    in DeepSeek Harness (.agents/skills/record-browser-gif/): SKILL.md is
    adapted and translated for this repository; scripts/encode_gif.py and
    scripts/test_encode_gif.py are copied unchanged.

  Full license text:

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.

No other third-party code is copied into this repository. At run time the
plugin uses the @deepseek-ai/* packages of the DeepSeek Harness install it
runs in; they are not bundled. esbuild is a build tool only. The desktop app
in app/ installs the pinned @deepseek-ai/* packages, Electron and pnpm from
npm; they keep their own licenses. The build of its window (app/ui) bundles,
from npm, React and React DOM (MIT, Copyright (c) Meta Platforms, Inc. and
affiliates), and react-markdown and remark-gfm with the packages they use
(MIT, most of them Copyright (c) Titus Wormer; @ungap/structured-clone is ISC,
Copyright (c) Andrea Giammarchi). Vite is a build tool only.

==============================================================================
Projects that gave us ideas (no code copied)
==============================================================================

We thank these projects for the designs they published. DS Bot learned from
their ideas; it does not contain their code.

  - AgentMemoryRepo (https://github.com/AgentMemoryRepo/agentmemoryrepo), MIT:
    the Markdown format of Bot memory (one entry per line with [key: value]
    metadata, a MEMORY.md index that links topic files).
  - OpenAI Codex (https://github.com/openai/codex), Apache-2.0:
    keeping the user's messages next to the summary in a checkpoint, and
    message anchors for searching earlier chat.
  - OpenMausBot (https://github.com/milind-soni/OpenMausBot), Apache-2.0:
    group chat rounds and @mention relays between Bots.
  - Hermes Agent (https://github.com/NousResearch/hermes-agent) and
    Hermes Bot Mode (https://github.com/NousResearch/Hermes-Bot-Mode), MIT:
    one Session per member per group chat, and the list of earlier user
    messages that the plugin, not the model, writes into the handoff.
  - OpenCode (https://github.com/sst/opencode), MIT;
    goose (https://github.com/block/goose), Apache-2.0;
    pi (https://github.com/badlogic/pi-mono), MIT;
    Gemini CLI (https://github.com/google-gemini/gemini-cli), Apache-2.0:
    when to condense a long conversation, and what a handoff note holds.
  - obelisk (https://github.com/tommy0103/obelisk), AGPL-3.0:
    searching a Bot's own chat with a SQLite FTS5 index ranked by BM25.
  - DeepSeek Harness Voice Input plugin
    (packages/experimental/client-ui-voice-input), MIT: the voice chat
    records with the same steps (record, resample to 16 kHz mono, PCM16 WAV)
    before it calls the plugin's speech service.
```

### NOTICE: Conscrypt 2.8.0 (verbatim)

```text
Copyright 2016 The Android Open Source Project

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

-----------------------------------------------------------------------
This product contains a modified portion of `Netty`, a configurable network
stack in Java, which can be obtained at:

  * LICENSE:
    * licenses/LICENSE.netty.txt (Apache License 2.0)
  * HOMEPAGE:
    * http://netty.io/

This product contains a modified portion of `Apache Harmony`, modular Java runtime,
which can be obtained at:

  * LICENSE:
    * licenses/LICENSE.harmony.txt (Apache License 2.0)
  * HOMEPAGE:
    * https://harmony.apache.org/
```

### Bouncy Castle Licence

```text
Copyright (c) 2000-2023 The Legion of the Bouncy Castle Inc. (https://www.bouncycastle.org)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software
and associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
```

### BSD Zero Clause License (XZ for Java)

```text
Copyright (C) The XZ for Java authors and contributors

Permission to use, copy, modify, and/or distribute this
software for any purpose with or without fee is hereby granted.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL
THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
```

### NOTICE: flutter_webrtc 1.6.3 (verbatim from the pub package)

```text
###################################################################################

The following modifications follow Apache License 2.0 from shiguredo.

SimulcastVideoEncoderFactoryWrapper.kt

Apache License 2.0

Copyright 2017, Lyo Kato <lyo.kato at gmail.com> (Original Author)
Copyright 2017-2021, Shiguredo Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

#####################################################################################

react-native-webrtc
https://github.com/react-native-webrtc/react-native-webrtc

The MIT License (MIT)

Copyright (c) 2015 Howard Yang

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

#####################################################################################
```

### WebRTC BSD and Google patent grant

Sources and version boundaries are in the WebRTC verification record above; the texts below correspond to the top-level licenses registered by the App.

```text
Copyright (c) 2011, The WebRTC project authors. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

  * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

  * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

  * Neither the name of Google nor the names of its contributors may
    be used to endorse or promote products derived from this software
    without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Additional IP Rights Grant (Patents)

"This implementation" means the copyrightable works distributed by
Google as part of the WebRTC code package.

Google hereby grants to you a perpetual, worldwide, non-exclusive,
no-charge, irrevocable (except as stated in this section) patent
license to make, have made, use, offer to sell, sell, import,
transfer, and otherwise run, modify and propagate the contents of this
implementation of the WebRTC code package, where such license applies
only to those patent claims, both currently owned by Google and
acquired in the future, licensable by Google that are necessarily
infringed by this implementation of the WebRTC code package. This
grant does not include claims that would be infringed only as a
consequence of further modification of this implementation. If you or
your agent or exclusive licensee institute or order or agree to the
institution of patent litigation against any entity (including a
cross-claim or counterclaim in a lawsuit) alleging that this
implementation of the WebRTC code package or any code incorporated
within this implementation of the WebRTC code package constitutes
direct or contributory patent infringement, or inducement of patent
infringement, then any patent rights granted to you under this License
for this implementation of the WebRTC code package shall terminate as
of the date such litigation is filed.
```

### Other licenses

- SIL Open Font License 1.1: `app/assets/fonts/OFL.txt`
- GNU LGPL-3.0 (spake2-android, libtalloc): https://www.gnu.org/licenses/lgpl-3.0.txt ; it builds on GNU GPL-3.0, and both full texts are bundled together in the App's license page under the spake2-android entry: https://www.gnu.org/licenses/gpl-3.0.txt
- GNU GPL-2.0 (proot): shipped with the APK at `assets/runtime/licenses/proot-COPYING.txt`

## Google ML Kit Text Recognition (Chinese)

Google ML Kit Text Recognition (Chinese)
com.google.mlkit:text-recognition-chinese:16.0.1

This bundled Google SDK is subject to the Google ML Kit terms:
https://developers.google.com/ml-kit/terms
Android SDK data disclosure:
https://developers.google.com/ml-kit/android-data-disclosure

Recognition runs on-device. Screenshots and recognized text are not sent to
Google by this SDK. The SDK collects usage statistics such as device model,
app version and processing time. Phone control may send screenshots and
recognized text to the user's configured model.

Local recognition is enabled by default. While off, recognition requests do not
trigger SDK loading or initialization. Turning it off prevents new recognition,
but does not uninstall
the SDK or promise to clear or stop sending previously accumulated SDK statistics.
The dsh-go anonymous usage statistics switch does not control this SDK.
The Apache 2.0 license for documentation sample code is not the license for
this SDK binary. This notice does not replace Google's SDK terms.
