-- ═══════════════════════════════════════════════════════════
-- Proof: migration 082 — admin_list_instapay_proofs()
-- Run AFTER applying 082, as the table owner (postgres) so ACLs and
-- pg_proc metadata are fully visible.
-- Static/read-only. Every check RAISEs 'FAIL …' on violation;
-- silence = pass. No live psql run was performed in this session.
-- ═══════════════════════════════════════════════════════════

-- 1. Function exists.
DO $$
BEGIN
  IF to_regprocedure('public.admin_list_instapay_proofs()') IS NULL THEN
    RAISE EXCEPTION 'FAIL 082: public.admin_list_instapay_proofs() missing';
  END IF;
END $$;

-- 2. SECURITY DEFINER, LANGUAGE sql, STABLE.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_proc p
      JOIN pg_language l ON l.oid = p.prolang
     WHERE p.oid = to_regprocedure('public.admin_list_instapay_proofs()')
       AND p.prosecdef
       AND p.provolatile = 's'
       AND l.lanname = 'sql'
  ) THEN
    RAISE EXCEPTION 'FAIL 082: function is not SECURITY DEFINER STABLE LANGUAGE sql';
  END IF;
END $$;

-- 3. search_path pinned exactly.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_proc p
     WHERE p.oid = to_regprocedure('public.admin_list_instapay_proofs()')
       AND p.proconfig IS NOT NULL
       AND 'search_path=public, pg_temp' = ANY (p.proconfig)
  ) THEN
    RAISE EXCEPTION 'FAIL 082: search_path not pinned to public, pg_temp';
  END IF;
END $$;

-- 4. Return contract pinned: names, order and types.
DO $$
DECLARE v_shape TEXT;
BEGIN
  SELECT string_agg(a.col, ',' ORDER BY a.ord) INTO v_shape
    FROM (
      SELECT ord,
             p.proargnames[ord] || ':' ||
             format_type(p.proallargtypes[ord], NULL) AS col
        FROM pg_proc p,
             generate_subscripts(p.proallargtypes, 1) AS ord
       WHERE p.oid = to_regprocedure('public.admin_list_instapay_proofs()')
         AND p.proargmodes[ord] IN ('o', 't')
    ) a;

  IF v_shape IS DISTINCT FROM
     'proof_id:uuid,payment_id:uuid,order_id:uuid,order_total:integer,' ||
     'customer_name:text,reference:text,storage_path:text,' ||
     'created_at:timestamp with time zone'
  THEN
    RAISE EXCEPTION 'FAIL 082: unexpected return shape %', v_shape;
  END IF;
END $$;

-- 5. anon cannot execute; authenticated can (also proves PUBLIC is
--    revoked, since anon would inherit a PUBLIC grant).
DO $$
BEGIN
  IF has_function_privilege('anon',
       'public.admin_list_instapay_proofs()', 'EXECUTE') THEN
    RAISE EXCEPTION 'FAIL 082: anon can execute admin_list_instapay_proofs';
  END IF;
  IF NOT has_function_privilege('authenticated',
       'public.admin_list_instapay_proofs()', 'EXECUTE') THEN
    RAISE EXCEPTION 'FAIL 082: authenticated cannot execute admin_list_instapay_proofs';
  END IF;
END $$;

-- 6. Fail-closed body: caller gate + queue filters + cap.
DO $$
DECLARE v_src TEXT;
BEGIN
  SELECT prosrc INTO v_src
    FROM pg_proc
   WHERE oid = to_regprocedure('public.admin_list_instapay_proofs()');

  IF v_src NOT ILIKE '%auth.uid() IS NOT NULL%'
     OR v_src NOT ILIKE '%is_admin = true%'
     OR v_src NOT ILIKE '%ip.outcome IS NULL%'
     OR v_src NOT ILIKE '%p.status = ''pending''%'
     OR v_src NOT ILIKE '%LIMIT 100%' THEN
    RAISE EXCEPTION 'FAIL 082: body guard, pending filter or LIMIT 100 drift';
  END IF;
END $$;
