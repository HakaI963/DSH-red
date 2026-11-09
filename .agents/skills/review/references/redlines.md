# dsh-Go Repository Redlines
The sources of truth are the full text of AGENTS.md and CONTRIBUTING.md on the current target branch; this table is not exhaustive. Severities belong to this skill's policy; the repository text only defines obligations.

## 1. Separate source from generated artifacts | ❌
Only change true sources; never hand-edit generated artifacts: `app/build/`, `.dart_tool/`, l10n generation output, guide sync output. After changing `app/lib/l10n/parts/*.arb`, run `python3 app/tool/l10n_merge.py`; after changing `docs/guide/`, run `python3 app/tool/guide_sync.py`; after changing plugin skill inputs, run `node sdk/plugin-kit/scripts/sync-skill.mjs`. Generated artifacts inconsistent with their inputs block.

## 2. Engine patches and pins stay in sync | ❌
Patch files in `runtime/patches/` must stay in sync with `pins.json`; never hand-edit vendor artifacts that patches overwrite; patches must still apply when the engine version is upgraded. Check pins, patch contents, and the runtime startup path.

## 3. The bridge protocol has exactly one source of truth | ❌
Request/response shapes and error codes (e.g. `unavailable`) of `/dsh-go/v1/*` routes are defined by `runtime/bridge/dsh-go-bridge/`; the app side (`packages/dsh_client`, `app/lib/state`) only consumes them and must not create parallel definitions. Changing one side requires syncing the other side and the tests.

## 4. Dangerous operations trust the host's answer | ❌
Operations like deleting sessions, permissions, or credentials: capability/failure is determined by what the host/engine actually answers, never faked by local inference; failures return stable error codes and are never silently swallowed. Unknown capability must not be treated as "unsupported".

## 5. Single state owner | ⚠️/❌
Riverpod provider autoDispose lifecycles, mux generations, and connection-object ownership stay clear; async callbacks never resurrect disposed state; when switching hosts/connections, old objects must retire.

## 6. Bilingual copy stays in sync | ⚠️
`app/lib/l10n/parts/*.arb` stays in sync with `.en.arb`; README, CONTRIBUTING, SECURITY, and docs/guide stay in sync between their Chinese and English versions; semantically equivalent rather than word-for-word translation.

## 7. Credentials and privacy | ❌
Never log/echo/persist full API keys, tokens, cookies, or login states; manually inspect diagnostic bundles and logs before sending them out; automatic redaction is not a guarantee.

## 8. Git safety | ❌
Only stage explicit paths; never use `git add .`/`-A`; never stash to hide someone else's changes; no force push to main and no rewriting shared history unless the user explicitly asks; after a rewrite, affected branches and PRs must be rebuilt; never commit/push/tag/release unless asked.

## 9. Build and real-device contract | ⚠️/❌
APK builds go through `tooling/build-apk.sh`; Flutter widget tests need the engine for the matching architecture; phone control/PRoot/direct boot/update-install changes require real-device verification — desktop results are not a substitute. Claiming to have run a command that does not exist blocks.

## 10. Scope discipline | ⚠️/❌
One topic per PR; no smuggling in unrelated formatting, dependency upgrades, upstream sync trees, or local config; spillover that cannot be reliably reviewed/rolled back counts as ❌, while a small amount of independently removable churn counts as ⚠️.
