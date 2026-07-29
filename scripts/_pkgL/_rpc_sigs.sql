SELECT p.proname AS fn,
       pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS result
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'create_checkout_order','confirm_cod_payment','process_paymob_callback',
    'create_order','checkout','cancel_order','cancel_expired_orders'
  )
ORDER BY p.proname;
