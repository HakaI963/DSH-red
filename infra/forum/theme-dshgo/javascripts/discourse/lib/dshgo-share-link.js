// Parsing and decoding of dsh-go share links (no Discourse dependency; standalone-testable).
//
// The format matches the App (app/lib/share_code/share_link.dart, share_codec.dart,
// spec in docs/design/share-codes.md):
//
//   dshgo://share/<kind>?p=<code>              kind = plugin | profile
//   dshgo://share/profile?gist=<id>&c=<sum>    large configs that do not fit a link
//   <landing page>#p=<code>                    web form, kind lives inside the code
//   <landing page>#gist=<id>&c=<sum>
//
//   code = base64url(deflate-raw(json)) + "." + base64url(sha256(json)[0..6])
//
// If the share-code format changes, this file is the only thing to change.

const KINDS = ["plugin", "profile"];
const CODE_RE = /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]{8}$/;
const GIST_RE = /^[0-9a-f]{20,40}$/;
const SUM_RE = /^[A-Za-z0-9_-]{8}$/;
const APP_RE = /^dshgo:\/\/share\/([^?#]*)(?:\?([^#]*))?/i;
const MAX_CODE_CHARS = 1024 * 1024;
const MAX_BODY_BYTES = 1024 * 1024;

// Regex that finds dshgo://share/… in plain text (for global matching).
export const APP_LINK_TEXT_RE = /dshgo:\/\/share\/[A-Za-z0-9_.\-\/?=&%]+/gi;

function landingKey(url) {
  try {
    const u = new URL(url);
    return `${u.host.toLowerCase()}${u.pathname.replace(/\/(index\.html)?$/, "")}`;
  } catch {
    return null;
  }
}

function fromParams(params, kind) {
  const code = params.get("p");
  if (code && code.length <= MAX_CODE_CHARS && CODE_RE.test(code)) {
    return { kind, code, gistId: null, gistSum: null };
  }
  const gist = params.get("gist");
  const sum = params.get("c");
  if (gist && sum && GIST_RE.test(gist) && SUM_RE.test(sum)) {
    return { kind: "profile", code: null, gistId: gist, gistSum: sum };
  }
  return null;
}

/**
 * Parses one link; returns null when it is not a share link.
 * Returns { kind, code, gistId, gistSum }; kind is null for the web form (known only after decoding).
 */
export function parseShareLink(href, landingUrls = []) {
  if (typeof href !== "string") {
    return null;
  }
  const value = href.trim();

  const app = APP_RE.exec(value);
  if (app) {
    const segment = (app[1].split("/")[0] || "").toLowerCase();
    if (!KINDS.includes(segment)) {
      return null;
    }
    return fromParams(new URLSearchParams(app[2] || ""), segment);
  }

  if (!/^https?:\/\//i.test(value)) {
    return null;
  }
  const hashAt = value.indexOf("#");
  if (hashAt < 0) {
    return null;
  }
  const key = landingKey(value.slice(0, hashAt));
  const known = landingUrls.map(landingKey).filter(Boolean);
  if (!key || !known.includes(key)) {
    return null;
  }
  return fromParams(new URLSearchParams(value.slice(hashAt + 1)), null);
}

/** The link that opens in the App (same as ShareLink.appLink). Returns null when kind is unknown. */
export function appLinkFor(link) {
  if (link.gistId) {
    return `dshgo://share/profile?gist=${link.gistId}&c=${link.gistSum}`;
  }
  if (!link.kind || !KINDS.includes(link.kind)) {
    return null;
  }
  return `dshgo://share/${link.kind}?p=${link.code}`;
}

function base64UrlToBytes(text) {
  const b64 = text.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64 + "===".slice((b64.length + 3) % 4);
  const raw = atob(padded);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) {
    out[i] = raw.charCodeAt(i);
  }
  return out;
}

function bytesToBase64Url(bytes) {
  let raw = "";
  for (const b of bytes) {
    raw += String.fromCharCode(b);
  }
  return btoa(raw).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function inflateRaw(bytes) {
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("deflate-raw"));
  const reader = stream.getReader();
  const chunks = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) {
      break;
    }
    total += value.length;
    if (total > MAX_BODY_BYTES) {
      await reader.cancel();
      throw new Error("body too large");
    }
    chunks.push(value);
  }
  const body = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.length;
  }
  return body;
}

/** Decodes and validates the code, returning the JSON object; throws when corrupted. */
export async function decodeShareCode(code) {
  if (!CODE_RE.test(code || "") || code.length > MAX_CODE_CHARS) {
    throw new Error("malformed");
  }
  if (typeof DecompressionStream === "undefined") {
    throw new Error("unsupported browser");
  }
  const dot = code.indexOf(".");
  const body = await inflateRaw(base64UrlToBytes(code.slice(0, dot)));
  // The checksum is only available in secure contexts (https); skip validation when SubtleCrypto is missing, the result is display-only
  if (globalThis.crypto?.subtle) {
    const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", body));
    if (bytesToBase64Url(digest.slice(0, 6)) !== code.slice(dot + 1)) {
      throw new Error("checksum mismatch");
    }
  }
  return JSON.parse(new TextDecoder().decode(body));
}

function text(value, max) {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }
  return trimmed.length > max ? `${trimmed.slice(0, max - 1)}…` : trimmed;
}

function count(value) {
  return Array.isArray(value) ? value.length : 0;
}

/**
 * Decoded JSON → the content the card shows.
 * { kind, title, author, version, summary, counts: { plugins, skills, presets } }
 */
export function describePayload(json) {
  if (!json || typeof json !== "object" || typeof json.v !== "number" || json.v < 1) {
    throw new Error("not a share body");
  }
  if (json.kind === "plugin") {
    const plugin = json.plugin || {};
    const name = text(plugin.name, 80);
    if (!name) {
      throw new Error("plugin without name");
    }
    return {
      kind: "plugin",
      title: text(plugin.title, 60) || name,
      author: text(plugin.author, 40),
      version: text(plugin.version, 40),
      summary: text(plugin.summary, 140),
      counts: null,
    };
  }
  if (json.kind === "profile") {
    return {
      kind: "profile",
      title: text(json.name, 40),
      author: null,
      version: null,
      summary: null,
      counts: { plugins: count(json.plugins), skills: count(json.skills), presets: count(json.presets) },
    };
  }
  throw new Error("unknown kind");
}
