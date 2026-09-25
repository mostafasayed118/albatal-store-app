// scripts/seed_demo_staging.mjs
// Idempotent staging demo seed. Catalog comes from migration 052;
// this script creates USER-LINKED demo data via service_role (bypasses
// RLS like all server scripts) + the same RPCs the app uses, AND uploads
// the showcase hero images 052 deliberately left out ("binaries uploaded
// separately as admin") — without them every demo image 404s and the app
// paints its placeholder. See scripts/demo_seed_images.mjs.
// Safe to rerun: fixed emails, ON CONFLICT/UPSERT, idempotency keys, and
// deterministic image bytes written with upsert:true.
// Usage:
//   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... SUPABASE_ANON_KEY=... node scripts/seed_demo_staging.mjs [--dry-run]
// Safety: refuses project ref alxwvyflasewslinufqe (prod) unless ALLOW_PROD=1.
// That guard covers the image uploads too — they use this same client.
import { createClient } from '@supabase/supabase-js';
import { IMAGE_BUCKET, planHeroUploads, showcaseHeroImages } from './demo_seed_images.mjs';

const DRY = process.argv.includes('--dry-run') || process.env.DRY_RUN === '1';
const URL = process.env.SUPABASE_URL;
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY;
const ANON = process.env.SUPABASE_ANON_KEY;
if (!URL || !SERVICE || !ANON) { console.error('Missing SUPABASE_URL / SERVICE_ROLE / ANON'); process.exit(2); }
if (URL.includes('alxwvyflasewslinufqe') && process.env.ALLOW_PROD !== '1') {
  console.error('Refusing prod ref without ALLOW_PROD=1'); process.exit(3);
}
const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });
const DEMOS = [
  { email: 'demo.standard@albatal.test', password: 'Demo1234!', full_name: 'Demo Standard', tier: 'standard', city: 'Cairo' },
  { email: 'demo.premium@albatal.test', password: 'Demo1234!', full_name: 'Demo Premium', tier: 'premium', city: 'Giza' },
];
const SHOWCASE = ['demo-silk-01', 'demo-cotton-01', 'demo-velvet-01'];

const run = async () => {
  const { data: products, error: productsErr } = await admin.from('products').select('id,slug').in('slug', SHOWCASE);
  if (productsErr) throw new Error(`products lookup: ${productsErr.message}`);
  console.log(`Showcase products found: ${products?.length ?? 0} (${SHOWCASE.join(',')})`);

  // ─── Showcase hero images (the half 052 left to "admin") ─────
  // Only fill objects whose ROW is registered: the catalog mapper resolves
  // images from product_images, so an upload with no row is an orphan nothing
  // reads. Filtering on the registered path also means a 052 path change shows
  // up as a skip here instead of silently writing to the wrong key.
  const showcase = (products ?? []).filter((p) => p?.id);
  const heroImages = showcaseHeroImages(showcase);
  let heroUploads = [];
  if (heroImages.length) {
    const { data: rows, error: rowsError } = await admin
      .from('product_images')
      .select('product_id,storage_path')
      .in('product_id', showcase.map((p) => p.id));
    if (rowsError) throw rowsError;
    const { plan, skipped } = planHeroUploads(heroImages, rows);
    heroUploads = plan;
    for (const img of skipped) {
      console.warn(`No product_images row for ${img.storagePath} — skipping (re-run migration 052?)`);
    }
  }

  if (DRY) {
    for (const img of heroUploads) {
      console.log(`DRY would upload ${img.storagePath} (${img.bytes.length} bytes, ${img.contentType}, upsert=true)`);
    }
    console.log('DRY RUN — no writes');
    return;
  }

  let heroesUploaded = 0;
  for (const img of heroUploads) {
    // Same bucket-prefixed key shape the app produces (StorageService uses
    // `product-images/<id>/<uuid>_<file>`), so both paths resolve identically.
    const { error } = await admin
      .storage.from(IMAGE_BUCKET)
      .upload(img.storagePath, img.bytes, { contentType: img.contentType, upsert: img.upsert });
    if (error) throw new Error(`upload ${img.storagePath}: ${error.message}`);
    heroesUploaded += 1;
    console.log(`Uploaded hero ${img.slug} -> ${img.storagePath} (${img.bytes.length} bytes, ${img.contentType})`);
  }
  if (!heroUploads.length) console.warn('No showcase hero images uploaded');
  const userIds = {};
  for (const d of DEMOS) {
    const { data: created } = await admin.auth.admin.createUser({ email: d.email, password: d.password, email_confirm: true, user_metadata: { full_name: d.full_name } }).catch(() => ({ data: null }));
    let userId = created?.user?.id;
    if (!userId) {
      const { data: users } = await admin.auth.admin.listUsers();
      userId = users?.users?.find((u) => u.email === d.email)?.id;
    }
    if (!userId) throw new Error(`No user id for ${d.email}`);
    userIds[d.email] = userId;
    const { error: profileErr } = await admin.from('profiles').upsert({ id: userId, full_name: d.full_name, phone: '+201000000000' }, { onConflict: 'id' });
    if (profileErr) throw new Error(`profiles.upsert(${d.email}): ${profileErr.message}`);
    // 046 grants admin_set_membership_tier to authenticated ONLY (revoked
    // from PUBLIC), so a service_role client gets permission-denied on the
    // RPC. Write the server-managed column directly instead — service_role
    // bypasses RLS, same as the wishlist/cart writes below. (Fix from #40.)
    if (d.tier === 'premium') {
      const { error: tierErr } = await admin
        .from('profiles')
        .update({ membership_tier: d.tier, updated_at: new Date().toISOString() })
        .eq('id', userId);
      if (tierErr) throw new Error(`membership_tier update (${d.email}): ${tierErr.message}`);
    }
    // Read back the server-managed state so a silent grant/RLS regression
    // can never print success.
    const { data: prof, error: profErr } = await admin
      .from('profiles')
      .select('membership_tier')
      .eq('id', userId)
      .maybeSingle();
    if (profErr) throw new Error(`profiles readback (${d.email}): ${profErr.message}`);
    if (prof?.membership_tier !== d.tier) {
      throw new Error(`tier mismatch for ${d.email}: expected ${d.tier}, got ${prof?.membership_tier}`);
    }
    const { data: existing } = await admin.from('addresses').select('id').eq('user_id', userId).eq('is_default', true).limit(1);
    if (!existing?.length) {
      const { error: addressErr } = await admin.from('addresses').insert({ user_id: userId, recipient: d.full_name, line: '12 Talaat Harb St, Apt 4', city: d.city, country: 'Egypt', is_default: true });
      if (addressErr) throw new Error(`addresses.insert(${d.email}): ${addressErr.message}`);
    }
    console.log(`Seeded user ${d.email} tier=${d.tier} id=${userId}`);
  }
  const anon = createClient(URL, ANON, { auth: { persistSession: false } });
  const { data: variant, error: variantErr } = await admin
    .from('product_variants')
    .select('id, product_id, size, color, products!inner(slug)')
    .eq('products.slug', 'demo-cotton-01')
    .eq('size', '1m')
    .eq('color', 'Gold')
    .gte('stock', 2)
    .limit(1)
    .maybeSingle();
  if (variantErr) throw new Error(`variant lookup: ${variantErr.message}`);
  let standardOrderId = null;
  let standardIdempotent = false;
  let premiumOrderId = null;
  let premiumIdempotent = false;
  if (!variant) {
    console.log('No demo variant — skipping orders');
  } else {
    const std = DEMOS.find((x) => x.tier === 'standard');
     const stdAddress = { recipient: std.full_name, line: '12 Talaat Harb St, Apt 4', city: std.city, country: 'Egypt', phone: '+201001234567' };
    const { error: stdSignInErr } = await anon.auth.signInWithPassword({ email: std.email, password: std.password });
    if (stdSignInErr) throw new Error(`sign-in ${std.email}: ${stdSignInErr.message}`);
    try {
      const { data: stdOrder, error: stdErr } = await anon.rpc('create_checkout_order', {
        p_payment_method: 'cod',
        p_address: stdAddress,
        p_items: [{ product_id: variant.product_id, size: variant.size, color: variant.color, quantity: 2 }],
         p_idempotency_key: 'demo-standard-001',
         p_coupon_code: null,
       });
      if (stdErr) throw stdErr;
      standardOrderId = stdOrder?.order_id ?? null;
      standardIdempotent = stdOrder?.idempotent ?? false;
      console.log(`Standard order order_id=${standardOrderId} idempotent=${standardIdempotent}`);
    } finally {
      await anon.auth.signOut();
    }
    const prem = DEMOS.find((x) => x.tier === 'premium');
     const premAddress = { recipient: prem.full_name, line: '12 Talaat Harb St, Apt 4', city: prem.city, country: 'Egypt', phone: '+201001234567' };
    const { error: premSignInErr } = await anon.auth.signInWithPassword({ email: prem.email, password: prem.password });
    if (premSignInErr) throw new Error(`sign-in ${prem.email}: ${premSignInErr.message}`);
    try {
      const { data: premOrder, error: premErr } = await anon.rpc('create_checkout_order', {
        p_payment_method: 'cod',
        p_address: premAddress,
        p_items: [{ product_id: variant.product_id, size: variant.size, color: variant.color, quantity: 2 }],
         p_idempotency_key: 'demo-premium-001',
         p_coupon_code: null,
       });
      if (premErr) throw premErr;
      premiumOrderId = premOrder?.order_id ?? null;
      premiumIdempotent = premOrder?.idempotent ?? false;
      console.log(`Premium order order_id=${premiumOrderId} idempotent=${premiumIdempotent}`);
      // supabase-js returns { error } instead of throwing — a rerun landing
      // here is expected and safe (order already confirmed).
      const { error: confirmErr } = await anon.rpc('confirm_cod_payment', { p_order_id: premiumOrderId });
      if (confirmErr) console.log(`confirm skipped (rerun-safe): ${confirmErr.message}`);
    } finally {
      await anon.auth.signOut();
    }
  }
  const productIdBySlug = new Map((products ?? []).map((p) => [p.slug, p.id]));
  let wishlistCount = 0;
  for (const d of DEMOS) {
    const uid = userIds[d.email];
    if (!uid) continue;
    for (const slug of SHOWCASE) {
      const pid = productIdBySlug.get(slug);
      if (!pid) continue;
      const { error } = await admin.from('wishlists').upsert({ user_id: uid, product_id: pid }, { onConflict: 'user_id,product_id' });
      if (error) throw error;
      wishlistCount += 1;
    }
  }
  let cartCount = 0;
  if (variant) {
    for (const d of DEMOS) {
      const uid = userIds[d.email];
      if (!uid) continue;
      const { error } = await admin.from('cart_items').upsert({ user_id: uid, variant_id: variant.id, quantity: 1 }, { onConflict: 'user_id,variant_id' });
      if (error) throw error;
      cartCount += 1;
    }
  }
  console.log(`Done. users=2 heroes=${heroesUploaded} standard_order=${standardOrderId} premium_order=${premiumOrderId} wishlist=${wishlistCount} cart=${cartCount}`);
};
run().catch((e) => { console.error(e.message); process.exit(1); });
