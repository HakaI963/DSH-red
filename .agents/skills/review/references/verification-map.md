# dsh-Go Verification Map
First read the "Common checks" section of the current CONTRIBUTING.md, the tooling scripts, and .github/workflows; this table only guides selection — when it drifts, the repository source of truth wins and the drift is recorded in the report.

## No fabrication
Record only commands actually run, exit codes, SHAs, and key output; never write "should pass" as "passed". When a device/dependency/engine is missing, write "not run" and the reason.

## Minimal common gates
Select by change surface; pure-docs/pure-workflow changes are triaged per the contributing guide — do not mechanically run everything.

## Change surface → verification category
| Change surface | Check at least |
|---|---|
| app/lib UI/state/Riverpod | `(cd app && flutter analyze)` + focused `flutter test test/<related>` |
| App UI copy ARB | `python3 app/tool/l10n_merge.py --check` |
| packages/dsh_client protocol/API | `(cd packages/dsh_client && dart analyze && dart test)` |
| packages/dsh_remote transport | `(cd packages/dsh_remote && dart analyze && dart test)` |
| runtime/bridge routes and deletion logic | `node --test runtime/tests/*.test.mjs` |
| runtime/patches | pins sync check, patches still apply, corresponding node tests |
| sdk/plugin-kit | `(cd sdk/plugin-kit && npm test)` + `node sdk/plugin-kit/scripts/sync-skill.mjs --check` |
| docs/guide user guide | `python3 app/tool/guide_sync.py --check` |
| tooling/ build scripts | `tooling/build-apk.sh` (when the environment allows) or static review |
| .github/workflows, pr-intake | permissions, fork trust, fail-open, path filters, action versions |
| Maintainer skills .agents/skills/ | frontmatter, relative references, script self-tests |

Look up concrete script names from the current package manifests/contributing guide; do not guess from this table.

## Selection algorithm
In order: list the diff's behaviors/owners/public contracts/user-visible surfaces → for each, find the nearest existing regression → check the CI/aggregated invocation or state the local supplementary evidence → start minimal and focused, then widen to aggregated runs based on failures/risk → for real-device/platform-sensitive changes add a real drill (desktop green is not enough) → report split into static proofs / automated regressions / manual drills / not executed.

## Untrusted-fork execution gate
If external PRs are ever accepted again: any command at head could execute contributor-modified scripts or build config. Default to static; require explicit user permission, an isolated worktree/container, no repository secrets/production credentials, minimal read-only credentials only, and capped network/CPU/memory/disk/time.

## Anti-false-green checks
### Bad baseline
A regression must fail against the unfixed implementation; prefer a reverse patch in an isolated tree or minimal fault injection to break the protected invariant; never corrupt a shared tree or roll back with a destructive reset.

### Independent oracle
The oracle must not compute the expected value with the same helper as the implementation, copy the implementation, or compare against the same source; it must not be trivially true or merely check that a symbol string exists; never substitute localized copy, random content, or loose substrings for structural assertions; event/exports/features allowlists compare directly against the official/target full set; field allowlists compare directly against the real response.

### Real paths
Import the real source or a clean build artifact as the scripts intend, going through the real registration/invocation/disposal paths; mocks only replace uncontrollable external boundaries; reads/writes use isolated temp directories, and env/listeners are restored.

### CI mounting
A script existing proves no protection: the workflow/package script must actually reference it, path filters must not skip it by mistake, it must fail-closed on upstream failed/cancelled/empty output, and the latest head checks must be non-empty and match the current SHA.

## Report record template
| Command/check | Type | SHA | Result | Notes |
|---|---|---|---|---|
| `...` | static / regression / manual | `...` | exit / pass / fail / blocked | failure attribution, environment, invariants covered |

Report statically established blocking mechanisms directly; do not hide behind "suggest running the tests"; tests are for proving impact/fixes.
