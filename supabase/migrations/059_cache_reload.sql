-- 059_cache_reload.sql (2026-09-13): post-migration PostgREST schema
-- cache reload. The migrations 053-058 ran through the management API,
-- which does not NOTIFY the pgrst channel; without this the REST layer
-- keeps serving the pre-migration schema (app_config 404 etc.).
NOTIFY pgrst, 'reload schema';
