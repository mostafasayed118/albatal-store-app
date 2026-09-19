// scripts/demo_seed_images_check.mjs
//
// Offline verification for scripts/demo_seed_images.mjs — needs no
// credentials and no network. This exists because seed_demo_staging.mjs
// imports @supabase/supabase-js, so the image logic cannot be exercised by
// running the seed, and the Flutter suite cannot reach Node code at all.
//
//   node scripts/demo_seed_images_check.mjs
//
// Also prints the generated sizes, and decodes nothing: structural validity is
// covered by any PNG parser, while pixel correctness was verified once with
// Skia (dart:ui instantiateImageCodec) at 1280x1280 — see STATE.md part 26.
import assert from 'node:assert/strict';
import {
  SHOWCASE_PRODUCTS,
  generateHeroPng,
  planHeroUploads,
  showcaseHeroImages,
} from './demo_seed_images.mjs';

const images = showcaseHeroImages(SHOWCASE_PRODUCTS);

// 1. one image per showcase product, at the exact path 052 registered
assert.equal(images.length, 3, 'one image per showcase product');
assert.deepEqual(
  images.map((i) => i.storagePath),
  SHOWCASE_PRODUCTS.map((p) => `product-images/${p.id}/hero.jpg`),
  'paths follow the 052 convention',
);

// 2. every upload carries real bytes and an honest content type
for (const img of images) {
  assert.equal(img.contentType, 'image/png', 'declared content type');
  assert.equal(img.upsert, true, 'idempotent re-runs');
  assert.ok(img.bytes.length > 10_000, 'bytes are a real image');
  assert.deepEqual(
    [...img.bytes.subarray(0, 8)],
    [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
    'PNG signature',
  );
}

const rows = images.map((i) => ({ product_id: i.productId, storage_path: i.storagePath }));

// 3. registered rows -> all three planned
let r = planHeroUploads(images, rows);
assert.equal(r.plan.length, 3, 'all three planned when rows exist');
assert.equal(r.skipped.length, 0, 'nothing skipped when rows exist');

// 4. 052 not applied -> upload nothing rather than write orphan objects
r = planHeroUploads(images, []);
assert.equal(r.plan.length, 0, 'nothing planned without rows');
assert.equal(r.skipped.length, 3, 'all three reported as skipped');

// 5. a drifted path is skipped, never uploaded to the wrong key
const drifted = rows.map((x, i) =>
  i === 0 ? { ...x, storage_path: x.storage_path.replace('/hero.jpg', '/cover.jpg') } : x,
);
r = planHeroUploads(images, drifted);
assert.equal(r.plan.length, 2, 'drift skips exactly the drifted one');
assert.equal(r.skipped.length, 1, 'drifted one is reported');
assert.equal(r.skipped[0].productId, SHOWCASE_PRODUCTS[0].id, 'the drifted product is the skipped one');

// 6. deterministic, and palettes actually differ per product
const silkA = generateHeroPng('demo-silk-01', { size: 64 });
const silkB = generateHeroPng('demo-silk-01', { size: 64 });
assert.ok(silkA.equals(silkB), 'same slug -> byte-identical');
const cotton = generateHeroPng('demo-cotton-01', { size: 64 });
assert.ok(!silkA.equals(cotton), 'different products -> different images');

console.log(`demo_seed_images: all checks passed (${images.length} images, ${rows.length} registered paths)`);
