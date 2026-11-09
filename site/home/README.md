# go.dshtui.com home page

The showcase site at `https://go.dshtui.com/`. The page was made by community developer **ClayGao233 / 采云师烧饼** ([GitHub](https://github.com/ClayGao233), [Bilibili](https://space.bilibili.com/28879571)) and handed over by its author for go.dshtui.com; the handoff came without a license statement, so this part is not covered by this repository's AGPL-3.0 license — see [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md). The "Web development" credit in the footer stays.

Pure HTML, CSS and JavaScript: no third-party dependencies, and nothing is loaded from other sites.

## How it goes live

`services/share-worker/scripts/build-site.mjs` copies `dist/` into the root of the Worker's static assets `public/`; `/` returns `index.html` (visiting `/index.html` directly is a 404), and the page's relative paths (`/app.js`, `/assets/…`) are served at their own paths, all without going through the Worker. The security headers for each file are written into the generated `public/_headers`. Deploy as usual: `CF_TOKEN_FILE=… services/share-worker/scripts/provision.sh deploy`. For routing, security headers and caching see [share-links.md](../../docs/design/share-links.md) §2.

- **CSP**: declared in the `<meta>` tag of `dist/index.html`; the Worker build extracts it as a response header (plus `frame-ancestors 'none'`). Scripts may only be same-site files — no inline scripts or event attributes; stylesheets may only be same-site files, while inline `style` attributes are allowed (the intro animation uses CSS variables like `style="--order:…"`); images may only come from this site; `connect-src` is this site only (the Star count). So the avatar and QR code must live in `dist/assets/author/` — external links won't work.
- **Star count**: the page asks this site's own `GET /api/github/stars` (`services/share-worker/src/github.ts`); the Worker queries GitHub and caches for 10 minutes, so visitors' browsers never talk to GitHub. When no number is available the bubble still shows, just without a count. The Worker always queries `ccch1mneyyy/dsh-go`.
- **Search engines**: the home page and its files may be indexed (`robots.txt` only allows these; every other page stays `noindex`).
- **Caching**: HTML is `no-cache`, everything else one hour. To change an image, change its file name (e.g. `download-qr-v3.png`) instead of overwriting the same name.

## Editing content

1. Everything fillable lives in `dist/site-config.js`: author avatar / ID / bio, download entries (QR code, download page, GitHub Releases), platform notes, repository, contributors, share metadata.
2. After changing `metadata`, run `npm run prepare:publish` to write the title, description, canonical and Open Graph tags into `dist/index.html`.
3. Run `npm run check` (syntax), `npm run check:content` (required fields, links, local images) and `npm test` (release-tool regression tests), then run `npm test` in `services/share-worker`.

All of these commands use only Node, stay offline and need no `npm install`. `npm run dev` previews locally at http://127.0.0.1:4173/ (without the Star count).

The download QR code `dist/assets/author/download-qr-v2.png` encodes the same content as `download.url`, with error-correction level M, 10 pixels per module and a 4-module margin (`qrencode -t PNG -l M -s 10 -m 4` or an equivalent tool). Whenever `download.url` changes, regenerate it and verify by scanning.

The share cover `dist/assets/author/share.png` is a copy of `docs/assets/social-preview.png`.

## Still to be confirmed by the author

The currently filled-in content is provisional: author ID `ccch1mneyyy`, the brand icon as the avatar, and the repository's social preview image as the share cover. After confirming or replacing them, re-run the checks above.
