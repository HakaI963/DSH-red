# AGENTS.md

dsh-Go is the Android phone app for DeepSeek Harness: a Flutter native UI + a pure Dart client + a patched DSH engine runtime (running `dsh web` inside PRoot). Before making changes, read [CONTRIBUTING.md](CONTRIBUTING.md) (the contribution and verification contract) and [docs/architecture.md](docs/architecture.md).

## Repository layout

```
app/                         Flutter App: native UI, Riverpod state, l10n, phone control
app/lib/l10n/parts/          Chinese/English ARB inputs for UI strings
packages/dsh_client/         Pure Dart client: HTTP/SSE, mux, session and deletion APIs
packages/dsh_remote/         Remote transport: WebRTC / LAN / TURN / relay
runtime/                     Patched DSH engine runtime
runtime/bridge/dsh-go-bridge/  HTTP bridge between App ↔ engine (/dsh-go/v1/*, incl. session-deletion routes)
runtime/patches/             Engine patches and their pins.json (patches pinned to versions)
sdk/plugin-kit/              Plugin SDK
tooling/                     APK build and build-number scripts
docs/                        Architecture, releases, roadmap, user guides
```

## Commands

Choose verification according to the scope of your change, and record the commands actually executed and their results in the PR/report. See [CONTRIBUTING.md](CONTRIBUTING.md) for full details.

```bash
(cd app && flutter pub get && flutter analyze && flutter test)   # Flutter app
(cd packages/dsh_client && dart pub get && dart analyze && dart test)
(cd packages/dsh_remote && dart pub get && dart analyze && dart test)
(cd sdk/plugin-kit && npm install && npm test)
node --test runtime/tests/*.test.mjs                               # engine bridge/patch tests
python3 app/tool/l10n_merge.py --check                             # UI-string generation check
python3 app/tool/guide_sync.py --check                             # user guide sync check
tooling/build-apk.sh --build-name <x.y.z>                          # build APK
```

CI (`.github/workflows/ci.yml`) runs the common checks plus the parts affected by a change on PRs, and the full set on `main`; look for `CI OK` in the results. It does not touch real devices or real accounts, so green does not mean the app works on a phone.

## Hard rules

### No external PRs (highest priority)

- This repository **does not currently accept any external Pull Requests** (code, docs, configuration or templates alike).
- **Never merge any external PR**: do not bring external commits into `main` via `gh pr merge`, the GitHub API, web-UI merging, rebase or cherry-pick.
- **Never create a PR on the user's behalf**, unless the user explicitly asks in the current conversation.
- When you receive an external PR: close it and reply "External PRs are not accepted at this time; please open an issue instead to share suggestions." The entry gate (`.github/workflows/pr-gate.yml`) auto-closes external PRs; handle them manually under the same policy and never "merge first, ask later".
- Do not automatically package an implementation into a PR just because some issue happens to have one.

### Source, generated artifacts and runtime patches

- Never hand-edit generated artifacts: `app/build/`, `.dart_tool/`, generated l10n outputs, etc.; edit the inputs, then run the corresponding generator.
- UI strings: edit `app/lib/l10n/parts/*.arb`, keep the Chinese and English in sync, then run `python3 app/tool/l10n_merge.py`; do not hand-edit generated results.
- User guides: edit `docs/guide/`, then run `python3 app/tool/guide_sync.py`.
- Engine patches live in `runtime/patches/`: keep patch files in sync with `pins.json`; do not hand-edit artifacts currently overwritten by a patch.
- Plugin teaching skills: edit `sdk/plugin-kit/skill/` or the corresponding SDK inputs, then run `node sdk/plugin-kit/scripts/sync-skill.mjs`.

### Behavior and contracts

- When changing the client, bridge or plugin protocols, check the callers on the other end and backward compatibility at the same time.
- For dangerous operations (deleting sessions, permissions, credentials), rely on the host/engine's actual responses; do not substitute local inference. Failures must have stable error codes; never swallow errors silently.
- Keep UI strings in sync in both Chinese and English (`app/lib/l10n/parts/*.arb` and the matching `.en.arb`).
- Keep bilingual docs in sync: README, CONTRIBUTING, SECURITY and docs/guide all have Chinese and English versions that must match.

### Credentials and privacy

- Never log, echo or persist full API keys, tokens, cookies or login state.
- Manually review diagnostic bundles and logs before sending them out; automatic redaction is not a guarantee.

### Git safety

- Before starting work, check the working tree, branch and upstream state, and run `git fetch origin main`; by default create an isolated work branch from the latest `origin/main` instead of stacking new tasks onto stale branches. When there are already uncommitted changes, never auto reset, stash or overwrite them just to sync.
- After work is committed and merged, clean up the temporary worktrees and branches created for it; before cleanup, confirm the commits are merged into the target and nothing is unsaved or unpushed. Do not force-delete worktrees containing modifications, and do not delete branches belonging to other tasks.
- After merging and cleanup, fetch the latest `main`, sync inside a clean primary worktree using fast-forward only, and report the final commit and anything left uncleaned; if the primary worktree has unrelated changes, keep and explain them — never lose work just to manufacture "clean".
- Stage only explicit paths; never use `git add .` / `git add -A`.
- Do not commit, push, tag or publish unless asked.
- Do not force push `main` or rewrite shared history unless the user explicitly asks in the current conversation; after a rewrite, rebuild the affected branches and PRs.

### Real-device verification

- Flutter widget tests require a Flutter engine for the matching architecture; when only the desktop (x86_64) engine is available and the device is arm64, explicitly state "not run" and why.
- Changes touching phone control, PRoot, direct start or update installation must be verified on a real device; desktop results are not a substitute.

## Code review principles

When reviewing a PR or change, center on **not introducing new bugs, making the minimum necessary change, and keeping the code simple**:

1. **Prevent regressions**: prioritize checking for new bugs, races, resource leaks, performance degradation and compatibility issues, especially how shared layers (`packages/dsh_client`, the bridge, runtime patches) affect existing host connection behavior.
2. **Avoid over-design**: flag duplicate implementations, unnecessary abstractions, redundant wrappers and excessive defensive programming; report only when a simpler equivalent exists, and do not misjudge necessary security checks and error handling.
3. **Strictly control scope**: changes should stay around the goal and its linked issue — no drive-by refactors, reformatting, dependency upgrades or unrelated feature edits; necessary tests and doc sync are exempt.
4. **Ensure real value**: watch for dead code, duplicated logic, pointless splitting and tests without meaningful assertions; do not judge contribution by lines of code or commit counts, and do not speculate about contributors' motives.
5. **Reviews must be evidence-based**: report only substantive problems introduced by the change at hand, with the exact location, trigger conditions and real impact, and prefer a minimal fix suggestion.

## Skills and workflows

- Internal PRs: follow `.agents/skills/pr` (workflow, templates, verification records).
- Code review: follow `.agents/skills/review` (evidence first; report only substantive problems introduced by the change).
- Bug reports: `.agents/skills/bug`; security audits: `.agents/skills/vuln-check`; broad audits: `.agents/skills/audit`.

## Editing this file

`CLAUDE.md` is a symlink to `AGENTS.md`; edit the real file. Keep every rule self-contained and link to the authoritative document for details.
