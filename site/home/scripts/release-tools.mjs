import { readFile, stat, readdir, realpath } from 'node:fs/promises';
import { resolve, sep, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Script } from 'node:vm';
import utils from '../dist/config-utils.js';

export const projectRoot = fileURLToPath(new URL('../', import.meta.url));
export const { safeUrl } = utils;
const text = value => typeof value === 'string' ? value.trim() : '';
const record = value => value && typeof value === 'object' && !Array.isArray(value);
const pending = value => /to be filled|to be announced|coming soon|please fill/i.test(text(value));

export async function readConfig(root = projectRoot) {
  const source = await readFile(resolve(root, 'dist/site-config.js'), 'utf8');
  // Run the project's configuration with no Node filesystem/network bindings.
  const json = new Script(`${source}\nJSON.stringify(window.DSH_GO_CONFIG)`, { filename: 'site-config.js' })
    .runInNewContext({ window: {} }, { timeout: 1000 });
  if (!json) throw new Error('site-config.js does not define window.DSH_GO_CONFIG.');
  return JSON.parse(json);
}

export async function validateConfig(config, distRoot = resolve(projectRoot, 'dist')) {
  const errors = [], warnings = [];
  const error = (field, message) => errors.push(`${field}：${message}`);
  const warn = (field, message) => warnings.push(`${field}：${message}`);
  if (!record(config)) return { errors: ['The config must be an object.'], warnings };
  const sections = {};
  for (const key of ['author', 'download', 'repository', 'metadata']) {
    if (!record(config[key])) error(key, 'Missing config object; fill it in per the instructions.');
    sections[key] = record(config[key]) ? config[key] : {};
  }
  const { author, download, repository, metadata } = sections;

  function requiredText(value, field) {
    if (!text(value)) error(field, 'No text provided.');
    else if (pending(value)) error(field, 'Still contains to-be-filled/coming-soon placeholder text; replace it with real content.');
  }
  function link(value, field, required = false) {
    if (value === '' || value === undefined || value === null) {
      if (required) error(field, 'No final link provided.');
      return '';
    }
    const url = safeUrl(value);
    if (!url) error(field, 'Must be a full HTTP(S) URL without a username or password.');
    else if (url.startsWith('http:')) warn(field, 'Currently HTTP; prefer HTTPS when going live.');
    return url;
  }
  async function image(value, field) {
    if (value === '' || value === undefined || value === null) return '';
    const url = safeUrl(value, true);
    if (!url) {
      error(field, 'A local image must start with assets/ without dist/, ../ or ?v=; a full HTTP(S) image URL also works.');
      return '';
    }
    if (!url.startsWith('assets/')) {
      link(url, field);
      warn(field, 'Remote images are not verified online; confirm they display on the published page.');
      return url;
    }
    const relative = decodeURIComponent(url);
    const file = resolve(distRoot, relative);
    try {
      const base = await realpath(distRoot);
      const actual = await realpath(file);
      if (!actual.startsWith(base + sep) || !(await stat(actual)).isFile()) throw new Error('not a local asset');
      // Windows can hide case mistakes that would break on a Linux static host.
      let folder = distRoot;
      for (const part of relative.split('/')) {
        if (!(await readdir(folder)).includes(part)) {
          error(field, 'Path case does not match the file on disk; it may fail to load after upload.');
          return '';
        }
        folder = resolve(folder, part);
      }
    } catch {
      error(field, 'The local file is missing, is not a file, or lies outside dist; make sure the image is in the delivery directory.');
      return '';
    }
    return url;
  }

  requiredText(author.id, 'author.id');
  if (['DSH-GO author', 'DSH Go author'].includes(text(author.id))) error('author.id', 'Still the default placeholder ID; enter the app author\'s own ID.');
  await image(author.avatar, 'author.avatar'); // Empty/default brand avatar is allowed.
  if (!text(author.message)) warn('author.message', 'The author bio is empty; if you do not mean to leave it blank, keep the original intro.');
  requiredText(repository.label, 'repository.label');
  link(repository.url, 'repository.url', true);
  for (const field of ['label', 'platform', 'title', 'description']) requiredText(download[field], `download.${field}`);
  const downloadUrl = link(download.url, 'download.url');
  link(download.altUrl, 'download.altUrl'); // Optional second link, e.g. GitHub Releases.
  const qr = await image(download.qrImage, 'download.qrImage');
  if (!downloadUrl && !qr) error('download', 'Provide at least one download method: a valid url or qrImage.');
  // A valid direct URL alone is complete; an absent QR is not a warning.

  requiredText(metadata.title, 'metadata.title');
  requiredText(metadata.description, 'metadata.description');
  const siteUrl = link(metadata.siteUrl, 'metadata.siteUrl');
  if (!siteUrl) {
    if (!text(metadata.siteUrl)) warn('metadata.siteUrl', 'The final page URL is empty, so canonical/og:url are not generated; fill it in once the deploy address is set.');
  } else if (new URL(siteUrl).hash || new URL(siteUrl).search) error('metadata.siteUrl', 'The final page URL must not contain query parameters or a # fragment.');
  const share = await image(metadata.shareImage, 'metadata.shareImage');
  if (!text(metadata.shareImage)) warn('metadata.shareImage', 'No share cover provided; title and description will be generated, but no image tags.');
  if (share && !/\.(png|jpe?g)$/i.test(new URL(share, 'https://local.invalid/').pathname)) error('metadata.shareImage', 'Use a PNG or JPEG file for the share cover.');
  if (share.startsWith('assets/') && !siteUrl) error('metadata.siteUrl', 'A local share cover needs the final page URL to generate a public absolute image URL.');
  if (share && !text(metadata.shareImageAlt)) warn('metadata.shareImageAlt', 'Consider adding an alt-text description for the share image.');

  if (!Array.isArray(config.contributors)) error('contributors', 'Must be an array; use [] when there are no contributors (an empty list is allowed).');
  else for (const [index, person] of config.contributors.entries()) {
    const key = `contributors[${index}]`;
    if (!record(person)) { error(key, 'Each entry must be a contributor object.'); continue; }
    let displayed = Boolean(text(person.name));
    for (const kind of ['github', 'bilibili']) {
      if (person[kind] === undefined) continue;
      const profile = person[kind];
      if (!record(profile)) { error(`${key}.${kind}`, 'Must contain a label and an optional url.'); continue; }
      requiredText(profile.label, `${key}.${kind}.label`);
      displayed ||= Boolean(text(profile.label));
      link(profile.url, `${key}.${kind}.url`); // Missing platform URL means a plain text chip.
    }
    if (!displayed) error(key, 'No displayable name or platform ID; remove the entry to keep the slot blank.');
    if (person.row !== undefined && ![1, 2, 3].includes(person.row)) error(`${key}.row`, 'Only the numbers 1, 2 or 3 are accepted; it may also be omitted.');
  }
  return { errors, warnings };
}

const escapeHtml = value => text(value).replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
export function metadataBlock(metadata) {
  const lines = ['  <!-- DSH-GO metadata:start -->', `  <title>${escapeHtml(metadata.title)}</title>`];
  const meta = (kind, name, value) => lines.push(`  <meta ${kind}="${name}" content="${escapeHtml(value)}">`);
  meta('name', 'description', metadata.description);
  meta('property', 'og:type', 'website');
  meta('property', 'og:site_name', 'DSH Go');
  meta('property', 'og:locale', 'en_US');
  meta('property', 'og:title', metadata.title);
  meta('property', 'og:description', metadata.description);
  const site = safeUrl(metadata.siteUrl);
  const image = safeUrl(metadata.shareImage, true);
  const absoluteImage = image.startsWith('assets/') ? (site ? new URL(image, site).href : '') : image;
  if (site) {
    lines.push(`  <link rel="canonical" href="${escapeHtml(site)}">`);
    meta('property', 'og:url', site);
  }
  if (absoluteImage) {
    meta('property', 'og:image', absoluteImage);
    meta('property', 'og:image:alt', metadata.shareImageAlt);
  }
  meta('name', 'twitter:card', absoluteImage ? 'summary_large_image' : 'summary');
  meta('name', 'twitter:title', metadata.title);
  meta('name', 'twitter:description', metadata.description);
  if (absoluteImage) {
    meta('name', 'twitter:image', absoluteImage);
    meta('name', 'twitter:image:alt', metadata.shareImageAlt);
  }
  lines.push('  <!-- DSH-GO metadata:end -->');
  return lines.join('\n');
}
const metadataRegion = /^  <!-- DSH-GO metadata:start -->[\s\S]*?  <!-- DSH-GO metadata:end -->/m;
export function applyMetadata(html, metadata) {
  if (!metadataRegion.test(html)) throw new Error('index.html is missing the metadata markers; restore the metadata:start / metadata:end block.');
  const newline = html.includes('\r\n') ? '\r\n' : '\n';
  return html.replace(metadataRegion, () => metadataBlock(metadata).replace(/\n/g, newline));
}
export function printReport({ errors, warnings }) {
  for (const message of errors) console.error(`[error] ${message}`);
  for (const message of warnings) console.warn(`[reminder] ${message}`);
  console.log(`Content check: ${errors.length} error(s), ${warnings.length} reminder(s).`);
  if (errors.length) console.log('Not yet ready for a public release. These errors are expected while the handoff template still has placeholders; do not treat a passing syntax check as filled-in content.');
  else console.log('Local config check passed. Review each reminder, then test the download, QR code, external links and the actual share preview; this check is offline and does not decode QR codes.');
}
