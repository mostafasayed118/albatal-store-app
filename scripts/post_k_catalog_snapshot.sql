-- Consolidated read-only post-K catalog snapshot (one JSON result set).
SELECT json_build_object(
  'check1_ledger', (
    SELECT json_build_object('migration_count', count(*), 'high_water', max(version))
    FROM supabase_migrations.schema_migrations
  ),
  'check1_versions', (
    SELECT json_agg(version ORDER BY version) FROM supabase_migrations.schema_migrations
  ),
  'check2_payments_insert_policies', (
    SELECT COALESCE(json_agg(policyname), '[]'::json)
    FROM pg_policies
    WHERE schemaname='public' AND tablename='payments'
      AND policyname IN ('payments_insert_own','payments_insert_authenticated_own')
  ),
  'check3_anon_public_write_grants', (
    SELECT count(*)
    FROM information_schema.table_privileges
    WHERE table_schema='public' AND grantee IN ('anon','public')
      AND table_name IN ('profiles','addresses','wishlists','cart_items','orders',
        'order_items','payments','notifications','analytics_events','error_logs')
      AND privilege_type IN ('INSERT','UPDATE','DELETE')
  ),
  'check4_rpc_grants', (
    SELECT json_agg(json_build_object(
      'proname', p.proname,
      'anon', has_function_privilege('anon', p.oid, 'EXECUTE'),
      'auth', has_function_privilege('authenticated', p.oid, 'EXECUTE'),
      'svc', has_function_privilege('service_role', p.oid, 'EXECUTE')
    ) ORDER BY p.proname)
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname IN (
      'confirm_cod_payment','process_paymob_callback','create_checkout_order',
      'update_order_status','calculate_shipping_fee','expire_pending_order',
      'decrement_stock','increment_stock','set_payment_provider_order_id')
  ),
  'check5_rls_flags', (
    SELECT json_agg(json_build_object('relname', c.relname, 'rls', c.relrowsecurity) ORDER BY c.relname)
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname IN ('profiles','addresses','wishlists',
      'cart_items','orders','order_items','payments','notifications',
      'analytics_events','error_logs')
  )
) AS snapshot;
