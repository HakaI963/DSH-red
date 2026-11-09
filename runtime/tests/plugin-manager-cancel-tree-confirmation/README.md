# Cancel confirmation for the plugin manager's own package process groups

This test group targets the service/POSIX path; it runs the real rc4 `runCli()`, the production HTTP RPC and real local processes. The package manager is a hand-written controlled fixture: no pnpm is run, nothing is downloaded, no external registry is touched, and the `.invalid` addresses are only parameter and classification inputs. These tests are not proof for Android/PRoot or a full ABI runtime build.

## Preparation and commands

At the repository root, prepare a patched DSH 0.2.1-rc.4 prefix the same way `runtime/build-runtime.sh` does in `install_dsh` and its patching step:

1. Copy `runtime/locks/dsh-0.2.1-rc.4/package.json` and `package-lock.json` into a fresh empty directory (the prefix) and run `npm ci --ignore-scripts --no-audit --no-fund` there. build-runtime.sh additionally passes `--cpu`, `--os=linux` and `--libc=glibc` to pick the target ABI; on a Linux host, just use the host platform for these tests.
2. `python3 -I runtime/lib/rtbuild.py patch-dsh --prefix /absolute/own/prefix --dsh-version 0.2.1-rc.4`. It applies the whole patch chain from `runtime/patches/` in filename order and verifies each file's before/after SHA-256 against `runtime/patches/pins.json`. The patches touching `dsh-plugin-manager` are `install-log-redaction.diff`, `plugin-manager-active-run-guard.diff` and this test's `plugin-manager-cancel-tree-confirmation.diff`.

Never accept a mid-chain patched file by editing pins or skipping validation. Re-running step 2 on a fully patched prefix is idempotent.

```sh
DSH_PREFIX=/absolute/own/prefix node --test --test-isolation=none --test-reporter=tap runtime/tests/plugin-manager-cancel-tree.test.mjs
python runtime/tests/plugin-manager-cancel-tree-confirmation/run.py --prefix /absolute/own/prefix --out /absolute/own/results --port 39311
```

`--cases` selects any subset from the table below. The runner needs Linux `/proc` and `prctl(PR_SET_CHILD_SUBREAPER)`. The port given to `--port` must be free (default 39311); other tests on the same machine must not occupy it concurrently. Never point the test home at a user's real config.

## Golden scenarios

| Name | What must be observed |
| --- | --- |
| cooperative | group gone, both APIs cancelled, both files restored, record and lock removed |
| term-resistant | parent exited, same-group descendants resist TERM; cancelled is returned only after a confirmed KILL and the group being gone, with no gated late writes |
| stop-unconfirmed | parent and child resist TERM and KILL is blocked only for that group; cancel is an RPC error, install failed, current-state files and the run record are kept |
| nonzero | PM exit17; stop confirmed, restore, no record leak |
| success-remove | both the ordinary disabled install and the production remove are applied, neither operation leaks a record |
| outer-not-bundle | primary exits normally while a background descendant is still alive; the outer not-bundle failure must stop the group before restoring and releasing |
| success-background | ordinary success keeps the existing background behavior, does not kill normal background descendants, and releases the record after the cancel window closes |
| late-cancel | the real runPnpm already returned and the test only delays the outer continuation; cancel still stops the background group it holds, then restores and releases |
| stop-unconfirmed-emit | on stop failure an install-log emit exception is additionally injected; the private stop fact still makes cancel an error and keeps files unrestored |
| compat-primary-unconfirmed | the incompatible manifest appears only after the primary install and descendants cannot be stopped; no internal restore is entered and no repair starts |
| compat-repair-success | repair is genuinely entered, both files already hold their original values at startup, the new independent group takes over the record, and the outcome is a failed incompatible install |
| compat-repair-cancel | repair's own group accepts the cancel; after descendants are confirmed stopped both APIs return cancelled, restore and release happen |
| compat-repair-unconfirmed | repair's parent and child are still alive, cancel errors and the install is failed; no second restore and no deletion of the successor repair record |
| compat-repair-timeout | repair's continuous heartbeat output still trips the original absolute timeout; after the group is confirmed stopped: install failed, restore and release |
| registry-retry | two controlled adds; before the second starts, both files are restored and the first group is gone; the second succeeds as applied |

## Evidence boundaries

The first two unconfirmed failures explicitly block KILL for the own group; they cannot support claims about naturally occurring D-state, permission faults, or a real OS dropping signals. EPERM/EIO/ESRCH differences are covered by unit injection in the production helpers. late-cancel adds a wait gate at the return point of runPnpm in the real service instance; the emit scenario injects the exception only into the stop-failure log. All these test gates live in the observer/launcher and are never written into product code.

Every process cleanup first verifies PID/startTicks/PGID and only acts on identities recorded by this run; the child reaper only waitpids specified own orphans — never waitpid(-1) — and never steals the exit status of the Host's Popen. A Z state still means the group exists: disappearance may only be asserted after actual reaping. Under `--out`, each run's `evidence/` holds the HTTP envelopes, before/after files, real loaded-module SHAs, signal injections and cleanup; raw Host logs containing the login token stay only in each case's `private/` directory and are never copied into `evidence/`.

Timings in the test report are this run's observations, not an end-to-end SLA. The product guard reuses the existing 5-second wait value per stage; scheduling, file IO, error emission and other final processing gained no uniform deadline from this fix. Normal-success background groups, descendants that left the process group, system-level PID/PGID reuse races, and the different CLI/Windows semantics are not claimed as comprehensively solved by this change.
