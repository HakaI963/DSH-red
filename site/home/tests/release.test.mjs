import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readFile, copyFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve, dirname, basename } from 'node:path';
import { spawnSync } from 'node:child_process';
import { projectRoot, readConfig, validateConfig, metadataBlock, applyMetadata, safeUrl } from '../scripts/release-tools.mjs';

const original = await readConfig();
const dist = resolve(projectRoot, 'dist');
/** The handoff template's placeholders (the live config is filled in). */
function template() {
  const config = structuredClone(original);
  config.author = { ...config.author, avatar: 'assets/dsh-go.svg', id: 'DSH Go author' };
  config.download = { ...config.download, description: 'The public beta has started; download details are coming soon.', qrImage: '', url: '', altUrl: '' };
  config.repository = { label: 'github / repository coming soon', url: '' };
  config.metadata = { ...config.metadata, siteUrl: '', shareImage: '' };
  config.contributors = [];
  return config;
}
function filled() {
  const config = template();
  config.author.id = 'Test author';
  config.repository = { label: 'github / test repository', url: 'https://example.com/repository' };
  config.download.description = 'Download the Android package';
  config.download.url = 'https://example.com/app.apk';
  config.metadata.siteUrl = 'https://example.com/dsh/';
  return config;
}

test('the handoff template blocks a public release and names the unfilled fields', async () => {
  const report = await validateConfig(template(), dist);
  for (const field of ['author.id', 'repository.url', 'repository.label', 'download']) assert(report.errors.some(item => item.startsWith(field)));
});
test('the current config is ready for release and the QR code file exists', async () => {
  const report = await validateConfig(original, dist);
  assert.deepEqual(report.errors, []);
  assert.equal(original.download.qrImage, 'assets/author/download-qr-v2.png');
});
test('a direct download URL, the brand avatar and empty contributors are all valid; no QR code required', async () => {
  const report = await validateConfig(filled(), dist);
  assert.deepEqual(report.errors, []);
  assert(!report.warnings.some(item => /qrImage|author.avatar|contributors/.test(item)));
});
test('a QR code alone also works, but the checker never pretends to verify what it encodes', async () => {
  const config = filled();
  config.download.url = '';
  config.download.qrImage = 'assets/dsh-go.svg'; // Test file existence only, never a real download QR.
  assert.deepEqual((await validateConfig(config, dist)).errors, []);
});
test('the second download link is optional, but must be a valid URL when provided', async () => {
  const config = filled();
  config.download.altUrl = 'https://github.com/example/app/releases/latest';
  assert.deepEqual((await validateConfig(config, dist)).errors, []);
  config.download.altUrl = 'javascript:alert(1)';
  assert((await validateConfig(config, dist)).errors.some(item => item.startsWith('download.altUrl')));
});
test('with a valid direct download URL, a filled-in but broken QR code path still needs fixing or clearing', async () => {
  const config = filled();
  config.download.qrImage = 'dist/assets/qr.png';
  assert((await validateConfig(config, dist)).errors.some(item => item.startsWith('download.qrImage')));
});
test('missing local images and case mistakes are both reported', async () => {
  for (const path of ['assets/author/missing.png', 'assets/DSH-GO.svg']) {
    const config = filled();
    config.author.avatar = path;
    assert((await validateConfig(config, dist)).errors.some(item => item.startsWith('author.avatar')));
  }
});
test('the page and the checker share URL rules, rejecting scripts, credentials and encoded path escapes', () => {
  for (const url of ['javascript:alert(1)', 'https://user:pass@example.com', 'assets/../private.png', 'assets/%2e%2e/private.png', 'assets/%252e%252e/private.png', 'assets/avatar.png?v=2', 'dist/assets/avatar.png']) assert.equal(safeUrl(url, true), '');
  assert.equal(safeUrl('assets/avatar-v2.png', true), 'assets/avatar-v2.png');
  assert.equal(safeUrl('https://example.com/avatar.png?v=2', true), 'https://example.com/avatar.png?v=2');
});
test('all four contributor shapes and link-less platform IDs are valid; an illegal row number is reported', async () => {
  const config = filled();
  config.contributors = [{ name: 'Name', row: 1 }, { github: { label: 'ID', url: '' } }, { bilibili: { label: 'Nickname', url: 'https://example.com/profile' } }, { github: { label: 'ID', url: 'https://example.com' }, bilibili: { label: 'Nickname', url: '' } }];
  assert.deepEqual((await validateConfig(config, dist)).errors, []);
  config.contributors[0].row = 4;
  assert((await validateConfig(config, dist)).errors.some(item => item.includes('.row')));
});
test('a malformed config produces readable errors without crashing', async () => {
  assert((await validateConfig(null, dist)).errors.length);
  const config = filled();
  config.author = [];
  config.contributors = {};
  assert((await validateConfig(config, dist)).errors.some(item => item.startsWith('contributors')));
});
test('a local share cover must exist and resolve to a PNG/JPEG under the final domain', async t => {
  const root = await fixture(t);
  const config = filled();
  config.metadata.shareImage = 'assets/author/share.png';
  await writeFile(resolve(root, 'dist/assets/author/share.png'), 'fixture');
  assert.deepEqual((await validateConfig(config, resolve(root, 'dist'))).errors, []);
  assert(metadataBlock(config.metadata).includes('https://example.com/dsh/assets/author/share.png'));
  config.metadata.siteUrl = '';
  assert((await validateConfig(config, resolve(root, 'dist'))).errors.some(item => item.startsWith('metadata.siteUrl')));
});
test('static share tags are generated with escaped content; removing the cover leaves no stale image tags', () => {
  const metadata = { ...filled().metadata, title: '<script> & "Title" $&', shareImage: 'https://example.com/share.jpg' };
  const block = metadataBlock(metadata);
  assert(block.includes('&lt;script&gt; &amp; &quot;Title&quot; $&'));
  assert(block.includes('summary_large_image'));
  assert(!block.includes('<script>'));
  const html = `<!doctype html>\n<head>\n${block}\n</head><body>body unchanged</body>`;
  const updated = applyMetadata(html, { ...metadata, shareImage: '' });
  assert(!updated.includes('og:image'));
  assert(!updated.includes('twitter:image'));
  assert(updated.endsWith('<body>body unchanged</body>'));
  assert.equal(applyMetadata(updated, { ...metadata, shareImage: '' }), updated);
});
test('the delivered home page metadata matches the default config; the Star bubble links to the repository', async () => {
  const html = await readFile(resolve(dist, 'index.html'), 'utf8');
  assert.equal(applyMetadata(html, original.metadata), html);
  assert(html.includes('<a class="star-callout" aria-disabled="true">'));
  assert(html.includes('<span class="callout-count" id="star-count" hidden></span>'));
});

async function fixture(t) {
  const root = await mkdtemp(resolve(tmpdir(), 'dsh-go-release-test-'));
  t.after(async () => {
    // Verify the generated absolute target before recursive test-directory cleanup.
    if (dirname(root) !== resolve(tmpdir()) || !basename(root).startsWith('dsh-go-release-test-')) throw new Error('Unsafe test cleanup path');
    await rm(root, { recursive: true, force: true });
  });
  await mkdir(resolve(root, 'dist/assets/author'), { recursive: true });
  await mkdir(resolve(root, 'scripts'));
  for (const name of ['release-tools.mjs', 'check-content.mjs', 'prepare-publish.mjs']) await copyFile(resolve(projectRoot, 'scripts', name), resolve(root, 'scripts', name));
  for (const name of ['config-utils.js', 'index.html']) await copyFile(resolve(dist, name), resolve(root, 'dist', name));
  await copyFile(resolve(dist, 'assets/dsh-go.svg'), resolve(root, 'dist/assets/dsh-go.svg'));
  return root;
}
async function saveConfig(root, config) {
  await writeFile(resolve(root, 'dist/site-config.js'), `window.DSH_GO_CONFIG = ${JSON.stringify(config)};`);
}
test('CLI: missing content exits 1 and publish preparation does not rewrite the page', async t => {
  const root = await fixture(t);
  await saveConfig(root, template());
  const before = await readFile(resolve(root, 'dist/index.html'));
  for (const script of ['check-content.mjs', 'prepare-publish.mjs']) {
    const result = spawnSync(process.execPath, [resolve(root, 'scripts', script)], { encoding: 'utf8' });
    assert.equal(result.status, 1);
    assert(result.stderr.includes('author.id'));
  }
  assert.deepEqual(await readFile(resolve(root, 'dist/index.html')), before);
});
test('CLI: a complete config passes, reminds to sync metadata, and publishing generates static HTML repeatably', async t => {
  const root = await fixture(t);
  const config = filled();
  config.metadata.title = 'Share title provided by the author';
  await saveConfig(root, config);
  const check = spawnSync(process.execPath, [resolve(root, 'scripts/check-content.mjs')], { encoding: 'utf8' });
  assert.equal(check.status, 0);
  assert(check.stderr.includes('not in sync'));
  const command = () => spawnSync(process.execPath, [resolve(root, 'scripts/prepare-publish.mjs')], { encoding: 'utf8' });
  assert.equal(command().status, 0);
  const html = await readFile(resolve(root, 'dist/index.html'), 'utf8');
  assert(html.includes('<title>Share title provided by the author</title>'));
  assert(html.includes('<link rel="canonical" href="https://example.com/dsh/">'));
  assert.equal(command().status, 0);
  assert.equal(await readFile(resolve(root, 'dist/index.html'), 'utf8'), html);
});
test('CLI: a config syntax error is diagnosable', async t => {
  const root = await fixture(t);
  await writeFile(resolve(root, 'dist/site-config.js'), 'window.DSH_GO_CONFIG = {');
  const result = spawnSync(process.execPath, [resolve(root, 'scripts/check-content.mjs')], { encoding: 'utf8' });
  assert.equal(result.status, 1);
  assert(result.stderr.includes('cannot check config'));
});
