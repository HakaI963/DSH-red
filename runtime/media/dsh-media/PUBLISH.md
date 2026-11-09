# Publication preparation and runbook

> 0.3.0 pending release: after publishing to npm publicly and verifying the tarball, set `version` in `market/plugins/@ccch1mneyyy__dsh-media.json` to `0.3.0` and rebuild the index per `market/VERIFICATION.md`; do not point the market at 0.3.0 before the npm release.

The current version `@ccch1mneyyy/dsh-media@0.2.1` was published officially to npm on 2026-10-31 (Asia/Singapore) with a granular token holding direct-publish rights. After the HTTP 202 acceptance, anonymous exact-version queries and public tarball downloads both returned 200 at 2026-10-30 19:55:51 UTC, and the registry SHA512 plus local SHA256 double checks passed. No manual staging approval was needed. The package name uses the user-authorized alternate organization; the settings namespace / bundle entry ID stays `dsh-media`, existing Apps support the `/dsh-media` package name, and no new App build is required.

The published package is 48,019 bytes with 19 regular files, SHA256 `9829f5106dec8cb354c203c74cc0510656f0f94538c36abf0fb80226388d13c9`. Compared file by file against the version that passed 306/306, only the package.json version changed from 0.2.0 to 0.2.1; runtime code is identical. The explicit files list excludes tests, credentials, private logs and dev dependencies.

## This release's constraints and version choice

- The previous GAT showed Bypass 2FA and coarse package/write metadata but in practice had staging-only rights. The first publish attempt returned E404; after staging created the package, the same token explicitly returned `E_STAGE_REQUIRED` on direct publish. The earlier 404 must not be read as "the organization lacks rights" or "2FA being off is the only cause".
- `0.2.0` was uploaded and verified through the official staging flow, stage ID `87e228cd-1e3b-4014-8410-f49ab24581af`; the staged tarball hashes identically to the local one. It was never formally published and does not enter the installable market.
- The latest token passed the direct-publish permission check, but publishing `0.2.0` directly returned 409: staged versions cannot be overwritten. So `0.2.1` was used for a normal direct publish with no functional code changes; no further duplicate staging was created and no user approval of the old version was requested.
- Automated direct publishing requires `Read and write (publish and stage)` on Packages and scopes with Bypass 2FA enabled; `Read and write (stage only)` does not suffice. Official staged approval separately requires manual 2FA, and that requirement cannot be generalized to all GAT direct publishes.

The public tarball was cross-checked against registry SHA512 and local SHA256. The real market scan, 24 checks and 5-package build passed, and Pages is deployed; at 2026-10-30 19:58:47 UTC both Worker files returned 200 with X-Market-Stale:false, the official format and the Worker validator pass, the live entry is official / 0.2.1 with SRI matching npm. The standalone plugin share page returned HTTP 200 with the Chinese title, version and App deep link correct. The market lists published versions only, never npm staging placeholders.

## Local verification and token publish

From the repository root, prepare dependencies per VERIFICATION.md, run the full test suite and headless; then:

```sh
cd runtime/media/dsh-media
npm pack --dry-run --json
npm pack --pack-destination /absolute/private/release-dir
```

After reviewing the tarball content and SHA256, the owner may choose, on their own machine, a short-lived granular token scoped to this organization/package and satisfying the publishing 2FA policy. Never put the real token into command text or the repository. The following are the routine steps for future versions; this `0.2.1` was submitted through this normal direct-publish path. Before publishing a new version, first confirm the version is not taken by a published or staged record:

```sh
umask 077
media_npmrc=$(mktemp)
trap 'rm -f "$media_npmrc"; unset NPM_TOKEN' EXIT
printf '%s\n' '//registry.npmjs.org/:_authToken=${NPM_TOKEN}' > "$media_npmrc"
read -rsp 'npm token: ' NPM_TOKEN
export NPM_TOKEN
NPM_CONFIG_USERCONFIG="$media_npmrc" npm whoami
NPM_CONFIG_USERCONFIG="$media_npmrc" npm publish /absolute/private/release-dir/ccch1mneyyy-dsh-media-0.2.1.tgz --access public
```

Complete authentication per the organization's 2FA / granular token policy; never assume org policies can be bypassed. For the env-var-referenced `.npmrc` usage see the [npm token docs](https://docs.npmjs.com/private-modules/ci-server-config/). Publishing from an ordinary local token does not claim CI provenance.

## Legacy 0.2.0 staging record (not a precondition of this release)

```sh
npm stage view 87e228cd-1e3b-4014-8410-f49ab24581af --json
npm stage download 87e228cd-1e3b-4014-8410-f49ab24581af
npm stage approve 87e228cd-1e3b-4014-8410-f49ab24581af --auth-type=web
```

Approval can also be done in the npm web UI under the Staged Packages tab for `@ccch1mneyyy/dsh-media@0.2.0`. Officially, maintainers must complete account 2FA at final approval; a Bypass-2FA GAT cannot substitute it. First-publish staging may generate an npm-managed `0.0.0-stage`, which contains none of the pending release's content and is not an installable version of this plugin. See [official staged publishing](https://docs.npmjs.com/staged-publishing/).

## Optional GitHub Actions provenance template (not enabled)

This package has no public-source `repository.url` or provenance workflow configured, so **it must not be claimed to satisfy public provenance requirements**. Before enabling, decide the public plugin source location, fill `repository.url` in package.json with the exact case of that public repository; keep the full verification inputs and re-run the tests. npm provenance requires public sources and a supported hosted runner; OIDC trusted publishing bindings must also be configured on the npm side. See [provenance](https://docs.npmjs.com/generating-provenance-statements/) and [trusted publishing](https://docs.npmjs.com/trusted-publishers/).

Below is a template that keeps this repository's paths, to be copied into `.github/workflows/` only once the owner decides on a publishing scheme. Use a protected environment, explicit dispatch, and pin action tags to exact owner-reviewed commits. If the plugin is later extracted into its own repository, move both existing runtime lock versions and the header golden first, then adjust the paths. The template below verifies `0.2.2-rc.1` by default; before a compatibility release, prepare a second dependency set with `--dsh-version 0.2.1-rc.4` and run the same checks.

```yaml
name: Publish media with provenance
on:
  workflow_dispatch:
permissions:
  contents: read
jobs:
  publish:
    runs-on: ubuntu-latest
    environment: npm-release
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: '24.x'
          registry-url: https://registry.npmjs.org
          package-manager-cache: false
      - name: Install exact test graph
        run: |
          node runtime/media/dsh-media/test/headless-v2/prepare.mjs --out "$RUNNER_TEMP/media-deps"
          npm ci --ignore-scripts --prefix "$RUNNER_TEMP/media-deps"
          ln -s "$RUNNER_TEMP/media-deps/node_modules" runtime/media/dsh-media/node_modules
      - name: Verify
        env:
          TZ: Asia/Shanghai
        run: |
          node --test runtime/media/dsh-media/test/*.test.js
          node runtime/media/dsh-media/test/headless-v2/run.mjs --out "$RUNNER_TEMP/media-evidence"
      - name: Check and publish
        working-directory: runtime/media/dsh-media
        run: |
          npm pack --dry-run --json
          npm publish --provenance --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

This template uses npm's official token + provenance mode. Once an OIDC trusted publisher is configured and verified, the token can be dropped per the official instructions; merely deleting the env var does not prove it is configured. Provenance attests origin and build, not that the code is risk-free. The template deliberately omits automatic tag / release triggers, and this branch has no executable publish workflow.
