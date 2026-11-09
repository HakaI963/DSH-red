# dsh-Go Contract Gates
Sources of truth: `runtime/bridge/dsh-go-bridge/` (HTTP routes), the public API of `packages/dsh_client`, the capability state in `app/lib/state`, `runtime/patches/pins.json`, `app/lib/l10n/parts/*.arb`, `sdk/plugin-kit`, CONTRIBUTING.md. This file only defines check order and stores no dated constants; a contract change without a compatibility strategy/migration/verification blocks by default.

## Gate 1 | Bridge HTTP contract
`/dsh-go/v1/*` routes: paths, methods, authentication (request rejections such as `connection.requestRejection`), status codes, JSON shapes and version fields, error codes (e.g. `unavailable`).
Blocks: one side changing a route/shape/error code without the other side synced; no version migration; tests not covering the rejection, disconnected, and host-refusal paths.

## Gate 2 | Client public API
Public exports of `packages/dsh_client` (carrier, mux, SessionDeletionApi, etc.): signature/semantics changes need compatibility or migration; new capabilities must have corresponding tests; do not bypass the carrier with a new direct HTTP client just because the app side wants one.

## Gate 3 | Capability state is three-valued
Host capabilities such as session deletion must distinguish unknown / supported / unsupported: not connected, or mux not ready, means unknown and must not be flattened into a bool; UI copy maps the states exhaustively; "unsupported" is shown only when the host explicitly says so; re-probing must work once the mux is ready.

## Gate 4 | Runtime patches and pins
Patches in `runtime/patches/` stay in sync with `pins.json`; patches still apply after an engine version change; writes, locks, tombstones, and derived-state cleanup introduced by patches are covered by node tests.

## Gate 5 | l10n and docs sync
`app/lib/l10n/parts/*.arb` stays in sync with `.en.arb` and `l10n_merge.py --check` passes; `docs/guide/` stays in sync with the app's built-in skills (`guide_sync.py --check`); README/CONTRIBUTING/SECURITY stay in sync between their Chinese and English versions.

## Gate 6 | Plugin SDK consumption surface
`sdk/plugin-kit` public API, skill inputs, and generated artifacts stay in sync (`sync-skill.mjs --check`); when a type-check dependency is missing, a skip must not be reported as a pass.

## Proof obligations when a gate modifies itself
When the implementation and its protecting gate change together, you must list the old gate's result against a bad implementation and the exact set the new gate widened/narrowed, prove with an independent oracle that no backdoor was opened, and prove the CI/aggregation chain actually executed; the script existing or CI being green is not enough.
