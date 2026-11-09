# P2P verification record

> The text below keeps the historical acceptance record for 1.0.3. Changes and verification for the later automatic route selection by default, staged TURN fallback and network details are in [Remote auto-network record](../../docs/testing/remote-auto-network.md).

This round completed real P2P on an Android 35 x86_64 emulator, Relay with direct connection disabled, and a dependency-delta APK comparison on both ABIs. No physical device, cross-public-NAT or real TURN validation was performed; the final shipping artifacts' native license audit is likewise not claimed complete.

## Verification scope

The implementation base is `ef2d69b1` plus `3b2d9918`. The App's "prefer direct (P2P)" setting is off by default; only when enabled do later connections attempt direct. The pure-Dart protocol layer uses WebRTC through a platform interface; the App adapter pins `flutter_webrtc 1.6.3`, whose Android SDK is `io.github.webrtc-sdk:android:150.7871.04`.

Native verification used the standalone probe entry `app/lib/dev/remote_p2p_probe_main.dart`, connecting to a self-hosted upstream Server on this machine (`7e387df`, with WebRTC signaling forwarding added for the test only) and the packaged Host plugin `0.6.0`, running on `dsh web 0.2.1-rc.5` with native `@roamhq/wrtc`. The Server had no STUN/TURN configured, and the emulator reached the host via `10.0.2.2`. The `p2p` in logs is the route actually selected; it does not mean public-internet traversal was covered.

| Check | Actual result |
|---|---|
| `dsh_remote` tests | 191 passed, 4 live tests skipped for unset environment; covers chunking, ICE, routing, timeouts, late-peer cleanup and Relay fallback with fresh connections / fresh Noise |
| `dsh_remote` analyze | no issues |
| App targeted tests | 10 passed: direct preference off by default, settings and backend wiring, connection-path display and license registry entries; targeted analyze clean |
| Android native P2P | Android 35 x86_64; connected in 1,932 ms; client ended on `transport=p2p`, Host logged the authenticated channel `P2P` |
| Android Relay-only | same emulator with direct disabled; connected in 1,173 ms; client ended on `transport=relay`, Host logged the authenticated channel `Relay` |
| TURN | config, filtering and candidate routing have unit tests; no real TURN service or traffic validation |

Both real links ran these checks:

1. Read the session list, returning an empty list (the isolated Host had no sessions).
2. Send a 120 KiB search request and receive Host's expected validation error for the 500-character search limit. The error shows the large request arrived, was reassembled and reached business validation; it does not mean an oversized search succeeded.
3. Receive the 38,328-byte `settings/describe` response. Over P2P this covers DataChannel `RTCH` chunked transport beyond 8 KiB.
4. Complete 20 round trips, still on the corresponding P2P / Relay path at the end.

Nothing in this round substituted the two native links with a simulated network stack. The evidence boundaries for ICE timeouts, new Relay/Noise after negotiation failure, real TURN, physical devices and WAN/NAT still differ: the first two are covered by unit tests, the rest have no live results from this round. Relay-only success must not be written up as a measured native-runtime failure fallback.

## APK dependency delta

The same baseline source snapshot and the same release build config were used to compare artifacts without WebRTC dependencies against artifacts with this round's WebRTC dependencies; both sides used build number `10300400`. This is a dependency A/B measurement, not the release APK with all of this round's features merged, and it excludes the final complete Linux runtime size. The absolute sizes in the table must not be quoted as official installer sizes.

| ABI | baseline / B | with WebRTC / B | delta / B | delta / MiB |
|---|---:|---:|---:|---:|
| arm64-v8a | 29,021,417 | 46,288,191 | 17,266,774 | 16.467 |
| x86_64 | 29,295,716 | 46,562,493 | 17,266,777 | 16.467 |

SHA-256:

```text
aea299f9fda7012f8a5c1f6fe9dbb9b89a08f3e2eca4ab1045fbefd7230b676c  baseline-arm64.apk
bd8513e90836dfef898ed40f62c454c454d958c4737f1ebb909a718529edc248  webrtc-arm64.apk
e98f95f1800dc1b37e2283ec0c24f551f034b6420fc5d01bea2b1d89e7674070  baseline-x64.apk
1f5cc729d5ba679331bcd0d3f0cf7dfbd5a6ae21d538a18bc833f17927c9c745  webrtc-x64.apk
a57d2391f73566511eb004a954a1847638f2c0bfff102c2b23c8b2e20129ed10  p2p-probe-x64.apk
```

The direct-connection switch does not remove the native dependencies already packaged in the APK; keeping it off still pays this size delta.

## Raw records and pre-release boundaries

The local archive for this acceptance keeps `p2p-e2e-final.log`, `p2p-apksize.json`, `p2p-apksize-ab.log` plus the test and analyze logs. These are on-machine records, not distributed via Git; the key results above and the digests below record this round's evidence and contain no credentials from the isolated account.

```text
c2e93b36ec0210d6502500f1baec48642e556a011b25e73710976e90e708bce4  p2p-e2e-final.log
3d33dd1d7b08cc94b2c5d6dec47269f61204078c8156ff050d5e350915cb68af  p2p-apksize.json
```

The P2P record above only organizes completed build/test evidence; no build or emulator operation was re-run. The 2026-10-31 license completion packaged the official `v150.7871.04` tag's full 788,358 B / 30-section license compilation verbatim and surfaces it through the `WebRTC` entry in `LicenseRegistry`; BSD/PATENTS and the flutter_webrtc NOTICE are retained. The official AAR of the same tag was compared against the actual Maven AAR: all ABI native libraries are byte-identical and the only content difference is the downgraded Java class major version. Five targeted license tests pass, covering the full asset load, SHA-256, sections and the pre-existing entries.

Sources, exact digests, verification boundaries and the final APK check commands are in [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md#完整上游通知的随包收录2026-10-31). This closes the gap where the complete upstream notice was not shipped in the package; it does not claim the independent GN dependency-graph audit of the actually linked components is finished. The final release APK's asset digests and license-page access remain part of release-build acceptance and are recorded separately.
