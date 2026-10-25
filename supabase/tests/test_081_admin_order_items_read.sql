-- ═══════════════════════════════════════════════════════════
-- Proof: migration 081 — admin SELECT on order_items
-- Run AFTER applying 081, as the table owner (postgres) so
-- pg_policies is fully visible.
-- Static/read-only. Every check RAISEs 'FAIL …' on violation;
-- silence = pass. No live psql run was performed in this session.
-- ═══════════════════════════════════════════════════════════

-- 1. RLS stays enabled on order_items.
DO $$
BEGIN
  IF NOT (SELECT relrowsecurity FROM pg_class
           WHERE oid = 'public.order_items'::regclass) THEN
    RAISE EXCEPTION 'FAIL 081: order_items RLS not enabled';
  END IF;
END $$;

-- 2. The owner policy is retained (081 is additive).
DO $$
DECLARE p_count INT;
BEGIN
  SELECT COUNT(*) INTO p_count
    FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename = 'order_items'
     AND policyname = 'order_items_select_own'
     AND cmd = 'SELECT';
  IF p_count <> 1 THEN
    RAISE EXCEPTION 'FAIL 081: order_items_select_own missing or not SELECT';
  END IF;
END $$;

-- 3. The admin policy exists, is SELECT-only, targets authenticated,
--    and derives the admin flag from the caller (auth.uid + is_admin).
DO $$
DECLARE p_count INT; p_cmd TEXT; p_roles TEXT; p_qual TEXT;
BEGIN
  SELECT COUNT(*), MIN(cmd), MIN(roles::text), MIN(qual)
    INTO p_count, p_cmd, p_roles, p_qual
    FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename = 'order_items'
     AND policyname = 'order_items_select_admin';

  IF p_count <> 1 THEN
    RAISE EXCEPTION 'FAIL 081: order_items_select_admin missing (found %)', p_count;
  END IF;
  IF p_cmd <> 'SELECT' THEN
    RAISE EXCEPTION 'FAIL 081: admin policy cmd=% (expected SELECT)', p_cmd;
  END IF;
  IF p_roles <> '{authenticated}' THEN
    RAISE EXCEPTION 'FAIL 081: admin policy roles=% (expected {authenticated})', p_roles;
  END IF;
  IF p_qual IS NULL OR p_qual NOT ILIKE '%is_admin%' THEN
    RAISE EXCEPTION 'FAIL 081: admin policy qual does not mention is_admin: %', p_qual;
  END IF;
  IF p_qual NOT ILIKE '%auth.uid()%' THEN
    RAISE EXCEPTION 'FAIL 081: admin policy qual does not bind auth.uid(): %', p_qual;
  END IF;
END $$;
