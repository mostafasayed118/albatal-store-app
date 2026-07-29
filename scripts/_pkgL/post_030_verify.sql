-- post_030_verify.sql — consolidated single-JSON verification after migration 030.
-- Run via: supabase db query --linked --file <this> -o json
SELECT json_build_object(
  'high_water', (
    SELECT max(version) FROM supabase_migrations.schema_migrations
  ),
  'unsafe_policy_count', (
    SELECT count(*) FROM pg_policies
    WHERE schemaname='public' AND tablename='profiles'
      AND policyname='profiles_update_own'
  ),
  'safe_policy', (
    SELECT json_agg(json_build_object(
      'policyname', policyname,
      'with_check_not_null', (with_check IS NOT NULL)
    ))
    FROM pg_policies
    WHERE schemaname='public' AND tablename='profiles'
      AND policyname='profiles_update_own_safe'
  ),
  'null_withcheck_update_policies', (
    SELECT count(*) FROM pg_policies
    WHERE schemaname='public' AND tablename='profiles'
      AND cmd='UPDATE' AND with_check IS NULL
  ),
  'payments_insert_policies', (
    SELECT count(*) FROM pg_policies
    WHERE schemaname='public' AND tablename='payments'
      AND policyname IN ('payments_insert_own','payments_insert_authenticated_own')
  ),
  'anon_public_write_grants', (
    SELECT count(*) FROM information_schema.table_privileges
    WHERE table_schema='public' AND grantee IN ('anon','public')
      AND table_name IN ('profiles','addresses','wishlists','cart_items',
        'orders','order_items','payments','notifications','analytics_events','error_logs')
      AND privilege_type IN ('INSERT','UPDATE','DELETE')
  ),
  'rls_enabled_tables', (
    SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relrowsecurity=true
      AND c.relname IN ('profiles','addresses','wishlists','cart_items',
        'orders','order_items','payments','notifications','analytics_events','error_logs')
  ),
  'rpc_grants', (
    SELECT json_agg(json_build_object(
      'proname', p.proname,
      'anon', has_function_privilege('anon', p.oid, 'EXECUTE'),
      'authenticated', has_function_privilege('authenticated', p.oid, 'EXECUTE'),
      'service_role', has_function_privilege('service_role', p.oid, 'EXECUTE')
    ) ORDER BY p.proname)
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname IN (
      'confirm_cod_payment','process_paymob_callback',
      'decrement_stock','increment_stock','expire_pending_order',
      'set_payment_provider_order_id')
  )
) AS post_030_verification;
