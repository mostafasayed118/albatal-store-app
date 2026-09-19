// scripts/demo_seed_images.mjs
//
// Hero images for the demo showcase catalog — the missing half of migration 052.
//
// WHY THIS EXISTS: 052 registers the `product_images` ROWS and says the binaries
// are "uploaded separately as admin", but nothing in the repo ever did that, so
// every showcase image 404s and the app paints its placeholder. A verified
// read-only probe of staging found no object at any of the three registered
// paths (STATE.md part 24). This module supplies them so any environment can be
// seeded from the repo alone — no binary fixtures, no new dependency, no
// network at generation time.
//
// FORMAT: PNG, because it is the only raster format a dependency-free Node
// runtime can emit (hand-rolled CRC32 + `node:zlib` deflate). The registered
// path still ends in `.jpg`, and that is deliberate: the path lives in
// `product_images.storage_path`, so renaming it means a DB write, and 052's own
// idempotency guard only stays a no-op while those exact strings exist
// (repoint them and a re-run inserts a second, object-less row). Uploading PNG
// bytes to the existing path keeps this change purely additive — zero DB writes
// — and the object is served as `image/png` regardless of the suffix, because
// the upload declares its real content type. Nothing in the app keys off the
// extension beyond `StorageService`'s renderable allowlist, which includes
// `.jpg` (the content is what every decoder sniffs).
//
// These are generated woven swatches, not photographs: they look intentional
// and match the brand palette, and they exist so the catalog renders. Replace
// them with real photography through the admin image manager when it is
// available — that flow repoints `storage_path` on its own.
//
// Offline use (no credentials, no network):
//   node scripts/demo_seed_images.mjs --out /tmp/demo-heroes

import { deflateSync } from 'node:zlib';

/** Bucket that holds product imagery (migrations 005 / 032). */
export const IMAGE_BUCKET = 'product-images';

/** File name 052 registered for every showcase hero (`…/<productId>/hero.jpg`). */
export const HERO_FILE_NAME = 'hero.jpg';

/** True content type of the bytes this module emits. */
export const HERO_CONTENT_TYPE = 'image/png';

/** 1280px so the widest render the app asks for (1080 zoom) never upscales. */
export const HERO_SIZE = 1280;

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i += 1) {
    c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function pngChunk(type, data) {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length, 0);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body), 0);
  return Buffer.concat([length, body, crc]);
}

/**
 * Encode 8-bit truecolour (RGB) pixel data as a PNG.
 *
 * One `IDAT` chunk, filter type 0 (None) on every scanline — the simplest thing
 * that is unambiguously valid; the size win from per-row filters is not worth
 * the extra code for three seed images.
 *
 * @param {number} width
 * @param {number} height
 * @param {Buffer} rgb `width * height * 3` bytes, row-major.
 * @returns {Buffer}
 */
export function encodePng(width, height, rgb) {
  const stride = width * 3;
  if (rgb.length !== stride * height) {
    throw new Error(`rgb length ${rgb.length} != ${stride * height} for ${width}x${height}`);
  }
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y += 1) {
    raw[y * (stride + 1)] = 0; // filter: None
    rgb.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // colour type: truecolour
  ihdr[10] = 0; // compression: deflate
  ihdr[11] = 0; // filter method
  ihdr[12] = 0; // interlace: none
  return Buffer.concat([
    PNG_SIGNATURE,
    pngChunk('IHDR', ihdr),
    pngChunk('IDAT', deflateSync(raw, { level: 9 })),
    pngChunk('IEND', Buffer.alloc(0)),
  ]);
}

// Brand-derived palettes (DESIGN.md): emerald `#064E3B`, gold `#D97706`,
// burgundy from the product's own colour language. `light` is the weft thread,
// `sheen` the highlight swept across the weave.
const EMERALD = { base: [0x06, 0x4e, 0x3b], light: [0x0b, 0x6b, 0x51], sheen: [0x95, 0xd3, 0xba] };
const GOLD = { base: [0xd9, 0x77, 0x06], light: [0xfe, 0x93, 0x2c], sheen: [0xff, 0xdc, 0x9a] };
const BURGUNDY = { base: [0x5c, 0x14, 0x20], light: [0x8a, 0x1f, 0x2e], sheen: [0xba, 0x1a, 0x1a] };

const PALETTES = {
  'demo-silk-01': EMERALD,
  'demo-cotton-01': GOLD,
  'demo-velvet-01': BURGUNDY,
};

// Fixed UUIDs + slugs mirroring migration 052. Used by the offline CLI and as
// the fallback palette key; the seed script prefers the live product rows.
export const SHOWCASE_PRODUCTS = [
  { id: 'cccc0001-0001-0001-0001-000000000001', slug: 'demo-silk-01' },
  { id: 'cccc0002-0001-0001-0001-000000000002', slug: 'demo-cotton-01' },
  { id: 'cccc0003-0001-0001-0001-000000000003', slug: 'demo-velvet-01' },
];

/** Storage path 052 registered for a product's hero image. */
export function showcaseHeroPath(productId) {
  if (!productId) throw new Error('productId required');
  return `${IMAGE_BUCKET}/${productId}/${HERO_FILE_NAME}`;
}

/**
 * Render the woven swatch for one product as RGB bytes.
 *
 * Deterministic: same slug and size in, byte-identical pixels out, so re-running
 * the seed overwrites with the same object rather than churning storage.
 *
 * @param {string} slug
 * @param {number} size
 * @returns {Buffer}
 */
export function generateHeroRgb(slug, size = HERO_SIZE) {
  const palette = PALETTES[slug] ?? EMERALD;
  const out = Buffer.alloc(size * size * 3);
  const period = 24; // twill band pitch
  const mid = (size - 1) / 2;
  const maxDist = Math.hypot(mid, mid);
  for (let y = 0; y < size; y += 1) {
    for (let x = 0; x < size; x += 1) {
      // Diagonal twill banding (2:1 warp float)…
      const band = (x + 2 * y) % (period * 2) < period ? 1 : 0;
      // …with the fine warp/weft threads on top of it.
      const micro = (x % 6 < 3 ? 1 : 0.88) * (y % 6 < 3 ? 1 : 0.92);
      const dist = Math.hypot(x - mid, y - mid);
      const vignette = 1 - 0.22 * (dist / maxDist) ** 2;
      const glint = Math.max(0, Math.sin(((x - y) / size) * Math.PI * 3)) * 0.18;
      const shade = micro * vignette;
      const offset = (y * size + x) * 3;
      for (let c = 0; c < 3; c += 1) {
        const thread = band ? palette.light[c] : palette.base[c];
        const lit = thread * shade * (1 - glint) + palette.sheen[c] * glint;
        out[offset + c] = Math.max(0, Math.min(255, Math.round(lit)));
      }
    }
  }
  return out;
}

/** PNG bytes for one product's hero image. */
export function generateHeroPng(slug, options = {}) {
  const size = options.size ?? HERO_SIZE;
  return encodePng(size, size, generateHeroRgb(slug, size));
}

/**
 * The exact uploads the seed performs: one per product, keyed by the registered
 * `storage_path` (which already carries the bucket prefix — see the note in
 * `StorageService.uploadProductImage`, which does the same on purpose).
 *
 * @param {Array<{id: string, slug: string}>} products
 * @param {{size?: number}} [options]
 * @returns {Array<{productId: string, slug: string, storagePath: string, bytes: Buffer, contentType: string, upsert: boolean}>}
 */
export function showcaseHeroImages(products, options = {}) {
  return (products ?? [])
    .filter((p) => p && p.id)
    .map((p) => ({
      productId: p.id,
      slug: p.slug ?? null,
      storagePath: showcaseHeroPath(p.id),
      bytes: generateHeroPng(p.slug, options),
      contentType: HERO_CONTENT_TYPE,
      upsert: true,
    }));
}

/**
 * Decide which hero images to upload.
 *
 * Only objects whose `product_images` ROW is registered are eligible: the
 * catalog mapper resolves images from that table, so an upload with no row is
 * an orphan nothing reads — and a path change in 052 should surface as a skip
 * here rather than a silent write to the wrong key.
 *
 * Split out from the seed script (which imports `@supabase/supabase-js` and so
 * cannot run without credentials) precisely so this decision is testable
 * offline.
 *
 * @param {Array<{productId: string, storagePath: string}>} images
 * @param {Array<{product_id: string, storage_path: string}>} registeredRows
 * @returns {{plan: Array<object>, skipped: Array<object>}}
 */
export function planHeroUploads(images, registeredRows) {
  const registered = new Set(
    (registeredRows ?? []).map((r) => `${r.product_id}|${r.storage_path}`),
  );
  const plan = [];
  const skipped = [];
  for (const img of images ?? []) {
    if (registered.has(`${img.productId}|${img.storagePath}`)) plan.push(img);
    else skipped.push(img);
  }
  return { plan, skipped };
}

// ─── Offline CLI ────────────────────────────────────────────
// Generates the bytes and reports them. No credentials, no network — this is
// how the generator is verified and how a reviewer can eyeball the output.
function readFlag(name, fallback) {
  const idx = process.argv.indexOf(name);
  return idx >= 0 && process.argv[idx + 1] ? process.argv[idx + 1] : fallback;
}

const invokedDirectly =
  process.argv[1] && process.argv[1].endsWith('demo_seed_images.mjs');

if (invokedDirectly) {
  const outDir = readFlag('--out', null);
  const size = Number(readFlag('--size', HERO_SIZE));
  const images = showcaseHeroImages(SHOWCASE_PRODUCTS, { size });
  console.log(`size=${size}px images=${images.length}`);
  for (const img of images) {
    console.log(
      `${img.slug.padEnd(16)} ${img.storagePath}  ${img.bytes.length} bytes  ${img.contentType}`,
    );
    if (outDir) {
      const { mkdirSync, writeFileSync } = await import('node:fs');
      mkdirSync(outDir, { recursive: true });
      const file = `${outDir}/${img.slug}.png`;
      writeFileSync(file, img.bytes);
      console.log(`  wrote ${file}`);
    }
  }
}
