-- ============================================================
-- DROP EVERYTHING — Fresh Start
--
-- ⚠️  DESTRUCTIVE: Drops ALL app tables, functions, types,
-- policies, and indexes. Use ONLY on a dev/staging database
-- where you want to start from scratch.
--
-- After running this, run run_all_migrations.sql
-- ============================================================

-- Drop in dependency order (children before parents)
DROP TRIGGER IF EXISTS set_profiles_updated_at ON profiles;
DROP TRIGGER IF EXISTS set_products_updated_at ON products;
DROP TRIGGER IF EXISTS set_addresses_updated_at ON addresses;
DROP TRIGGER IF EXISTS set_cart_items_updated_at ON cart_items;
DROP TRIGGER IF EXISTS set_orders_updated_at ON orders;
DROP TRIGGER IF EXISTS set_payments_updated_at ON payments;
DROP TRIGGER IF EXISTS set_shipping_config_updated_at ON shipping_config;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

DROP FUNCTION IF EXISTS update_updated_at();
DROP FUNCTION IF EXISTS handle_new_user();
DROP FUNCTION IF EXISTS decrement_stock(UUID, TEXT, TEXT, INTEGER);
DROP FUNCTION IF EXISTS increment_stock(UUID, TEXT, TEXT, INTEGER);
DROP FUNCTION IF EXISTS calculate_shipping_fee(TEXT, INTEGER);
DROP FUNCTION IF EXISTS update_order_status(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS get_order_details(UUID);
DROP FUNCTION IF EXISTS get_low_stock_products(INTEGER);
DROP FUNCTION IF EXISTS create_checkout_order(JSONB, JSONB, JSONB, TEXT);

DROP TABLE IF EXISTS error_logs CASCADE;
DROP TABLE IF EXISTS analytics_events CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS shipping_config CASCADE;
DROP TABLE IF EXISTS shipping_zones CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS cart_items CASCADE;
DROP TABLE IF EXISTS wishlists CASCADE;
DROP TABLE IF EXISTS addresses CASCADE;
DROP TABLE IF EXISTS product_images CASCADE;
DROP TABLE IF EXISTS product_variants CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

DROP TYPE IF EXISTS order_status CASCADE;

-- Storage buckets/policies are managed by the Supabase Storage API.
-- Clean them manually via Dashboard → Storage if needed.
-- (Direct DELETE from storage.* tables is blocked by Supabase.)

SELECT '✅ All app objects dropped. Ready for fresh migration.
   Storage buckets: clean manually via Dashboard → Storage if needed.' AS result;
