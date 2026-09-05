-- ═══════════════════════════════════════════════════════════
-- Test: migration 034 — audit trail locked
-- Run AFTER `supabase db reset` against the local database.
-- Every check RAISEs 'FAIL: …' on violation; silence = pass.
-- ═══════════════════════════════════════════════════════════

-- 1. RLS is enabled on state_transitions.
DO $$
BEGIN
  IF NOT (SELECT relrowsecurity FROM pg_class
           WHERE oid = 'public.state_transitions'::regclass) THEN
    RAISE EXCEPTION 'FAIL: state_transitions RLS not enabled';
  END IF;
END $$;

-- 2. Exactly one policy exists and it is the admin SELECT policy.
DO $$
DECLARE p_count INT; p_cmd TEXT; p_roles TEXT;
BEGIN
  SELECT COUNT(*), MIN(cmd), MIN(roles::text) INTO p_count, p_cmd, p_roles
    FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'state_transitions';
  IF p_count <> 1 OR p_cmd <> 'SELECT' OR p_roles <> '{authenticated}' THEN
    RAISE EXCEPTION 'FAIL: unexpected policies on state_transitions (% rows, cmd=%, roles=%)',
      p_count, p_cmd, p_roles;
  END IF;
END $$;

-- 3. Seed one row as owner, then verify anon reads NOTHING (no grant =>
--    permission denied; if a grant existed, RLS would filter to 0 rows).
INSERT INTO public.state_transitions (entity_type, entity_id, new_status)
VALUES ('order', '00000000-0000-0000-0000-000000000001', 'seeded');

BEGIN;
SET LOCAL ROLE anon;
DO $$
DECLARE n INT;
BEGIN
  BEGIN
    SELECT COUNT(*) INTO n FROM public.state_transitions;
    IF n <> 0 THEN
      RAISE EXCEPTION 'FAIL: anon read % rows from state_transitions', n;
    END IF;
  EXCEPTION
    WHEN insufficient_privilege THEN NULL;  -- SQLSTATE 42501: no grant => also locked
  END;
END $$;
ROLLBACK;

-- 4. Anon INSERT is rejected (no grant + no policy => 42501).
BEGIN;
SET LOCAL ROLE anon;
DO $$
BEGIN
  BEGIN
    INSERT INTO public.state_transitions (entity_type, entity_id, new_status)
    VALUES ('order', '00000000-0000-0000-0000-000000000002', 'forged');
    RAISE EXCEPTION 'FAIL: anon inserted into state_transitions';
  EXCEPTION
    WHEN insufficient_privilege THEN NULL;  -- SQLSTATE 42501: expected
  END;
END $$;
ROLLBACK;

-- 5. Internal write path still works: audit_transition() runs as its
--    owner (SECURITY DEFINER), unaffected by the EXECUTE revokes and by
--    RLS (table owner bypasses RLS). Probe row is cleaned up afterwards.
DO $$
DECLARE n INT;
BEGIN
  PERFORM public.audit_transition(
    'order', '00000000-0000-0000-0000-000000000003',
    NULL, 'internal-ok', 'system', 'test: owner path');
  SELECT COUNT(*) INTO n FROM public.state_transitions
   WHERE entity_id = '00000000-0000-0000-0000-000000000003'
     AND new_status = 'internal-ok';
  IF n <> 1 THEN
    RAISE EXCEPTION 'FAIL: audit_transition owner path inserted % rows', n;
  END IF;
  DELETE FROM public.state_transitions
   WHERE entity_id = '00000000-0000-0000-0000-000000000003'
     AND new_status = 'internal-ok';
END $$;

-- 6. audit_transition is not executable by anon or authenticated.
DO $$
BEGIN
  IF has_function_privilege('anon',
       'public.audit_transition(text,uuid,text,text,text,text,jsonb)',
       'EXECUTE') THEN
    RAISE EXCEPTION 'FAIL: anon can execute audit_transition';
  END IF;
  IF has_function_privilege('authenticated',
       'public.audit_transition(text,uuid,text,text,text,text,jsonb)',
       'EXECUTE') THEN
    RAISE EXCEPTION 'FAIL: authenticated can execute audit_transition';
  END IF;
END $$;
