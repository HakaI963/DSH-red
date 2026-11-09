# M0 headless · rc4 run notes

Two real local-mock sessions (one parameter header, one plain Chinese message) once passed in the environment below; for the overall verification scope and uncovered items see ../../VERIFICATION.md. The test plugin plugin.mjs is loaded only inside headless and is never installed into a production profile.

Before re-running: run.mjs pins the SHA-256 of ten production files. Since the recording, src/header.js, src/config.js and package.json have changed (parameter header aligned to the finalized spec, etc.), so the pins no longer match and the runner refuses to start. Review those changes and update the pins first; record new results under the new identity. The two existing records correspond to the pre-change files.

## Reproducible environment

DSH comes from an isolated npm test prefix. run.mjs requires the prefix root's package-lock.json to have SHA-256 8f1f2d0363e8c481ef1d163be1f263ba8089b378f9a2f99dd02707ce571fb68c (EXPECTED_TEST_LOCK). That lock is based on runtime/locks/dsh-0.2.1-rc.4/package-lock.json, keeps all 628 non-root records, and adds only image-size 2.0.2 and @deepseek-ai/dsh-llm-mock-server 0.2.1-rc.4 (direct dependencies in dependencies.json). The test prefix does not apply runtime/patches, so conclusions concern the original npm rc4, not the patched mobile rootfs.

Missing inputs: this test lock and its package.json are not committed. Without them the run.mjs lock check will not pass; when rebuilding, derive from the baseline lock per the rules above, replace EXPECTED_TEST_LOCK with the new lock's SHA, and record results under the new identity.

Create a fresh isolated prefix, place package.json and package-lock.json at the prefix root, then npm ci --ignore-scripts --no-audit --no-fund (add --offline if cached). Never use npm install to re-resolve and silently allow transitive upgrades. Point the product directory's node_modules at this prefix/node_modules; create the symlink only when the target does not exist and never overwrite an existing dependency tree. Do not create a separate node_modules under test/headless.

From runtime/media/dsh-media run:

    TZ=Asia/Shanghai node --test test/*.test.js
    TZ=Asia/Shanghai node test/headless/run.mjs --out /absolute/new-private-result

out must be an absolute path that does not yet exist, with an existing parent. The runner refuses to overwrite; expected Node is 22.x above 22.19 or 24+, and the test actually used v24.22.1. Key engine files, the exact lock, the ten production files and parent/child module instances are all verified. If the engine is patched, do not delete pins to pass — review the actual post-image and define a new identity for that tree.

## Paths actually executed

The public CLI dsh headless --patch <file> --json <task>, each case with its own home/workspace. credentials-local is restored with this run's fixed fake credential; the official llm-deepseek-api-key connects only to the local official mock. The script pins tool_call_success→success; these are not real model decisions. Production Config still uses an HTTPS placeholder; only the test plugin's in-process generate seam routes to this run's fixed loopback image endpoint. The service address and transport never come from model parameters or user settings.

The first session uses the formatter to generate the header; the second, plain Chinese, must give parseGenerationMessage=null. Both recordings predate the parameter-header grammar's finalization and prove the real session execution chain under the then-candidate grammar; the finalized grammar is validated by test/header.test.js against the shared golden, and headless has not been re-recorded under it.

Session post-commit events are JSON-serialized verbatim one by one, with seq continuous from 0. Flushing uses a queued checkpoint so it does not check ahead inside another observer's synchronous flush; it guarantees at least the requested prefix has been captured. runtime-context user/message entries are kept, but only source.kind=user counts as real user input. All events after the physical V4 log header equal the capture object by object.

The normal success path must show exit 0, an observed close, turn/end completed, one user input/tool call/successful media result, the correct request body, original bytes/dimensions, Host index and Session agreement, and no fake credential in events/stdout/stderr/index. Any failed assertion means failure: no success summary is written.

## Artifacts and what they mean

- stdout.projection.jsonl is only the CLI display projection, never an App raw fixture.
- capture/session-events.jsonl holds the full logical events; capture-receipt and loaded-modules record identity.
- durable-session.v4.jsonl is a verbatim copy of the physical file, aligned with all logical events.
- wire-audit records request bodies and mock behavior only, never auth headers.
- verified/summary appears only after this case's / both cases' assertions pass; failure/cleanup/process keep the real failure and shutdown facts.
- Actual originals stay in the private workspace; absolute paths inside the fixture are not rewritten, and consuming tests must supply their own file provider mapping.
- live_image.jsonl and live_image_plain.jsonl are the raw logical logs of the two Sessions and must not be concatenated; no hand-written media events.

The two primary records each contain 23 events, 2 local LLM requests and 1 local image request. They prove only the real DSH scheduling/tool/storage chain; real model understanding, vendor costs/entitlements, production network, and the App and mobile runtime are not proven by them.

## Failure handling and process cleanup

At the 90-second limit send TERM first, then KILL after 5 seconds; if no close arrives within 10 seconds after stopping, fail and record the PID and kill diagnostics, shut the mock network down, and do not proceed to the next case. A kill return code is never treated as process exit. Every successfully run child was observed closing and its mock was shut down.

The early nine pure-JS fault models remain models only. OS-level fault injections — synchronous spawn exceptions, async error/close, missing pipe, kill failure, repeated errors, exit without stdio closing, close timeout — were not all run and are outside the current PASS coverage.
