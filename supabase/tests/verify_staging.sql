-- Quick verification queries for staging
-- Run via: supabase db query --linked -f supabase/tests/verify_staging.sql

-- 1. confirm_cod_payment grants
SELECT 'confirm_cod_payment' AS rpc,
  has_function_privilege('anon', 'confirm_cod_payment(uuid)', 'EXECUTE') AS anon_exec,
  has_function_privilege('authenticated', 'confirm_cod_payment(uuid)', 'EXECUTE') AS auth_exec;

-- 2. process_paymob_callback grants
SELECT 'process_paymob_callback' AS rpc,
  has_function_privilege('anon', 'process_paymob_callback(text,text,integer,text,boolean)', 'EXECUTE') AS anon_exec,
  has_function_privilege('authenticated', 'process_paymob_callback(text,text,integer,text,boolean)', 'EXECUTE') AS auth_exec,
  has_function_privilege('service_role', 'process_paymob_callback(text,text,integer,text,boolean)', 'EXECUTE') AS svc_exec;

-- 3. payments_insert_own policy check
SELECT 'payments_insert_own' AS policy,
  COUNT(*) AS exists_count
FROM pg_policies
WHERE tablename = 'payments'
  AND policyname = 'payments_insert_own';

-- 4. confirm_cod_payment function exists
SELECT 'confirm_cod_payment' AS function_name,
  COUNT(*) AS exists_count
FROM pg_proc
WHERE proname = 'confirm_cod_payment';
