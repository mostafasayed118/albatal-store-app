-- ─────────────────────────────────────────────────────────────
-- 046: MEMBERSHIP TIER — real customer data behind the Premium badge
--
-- profiles.membership_tier joins the customer-facing schema. The tier is
-- SERVER-MANAGED: customers can never set it themselves (RLS WITH CHECK),
-- only admins can change it (SECURITY DEFINER RPC), mirroring how 003
-- protects is_admin.
--
-- Value contract (enforced by profiles_membership_tier_check):
--   'standard' (default) | 'premium'
--
-- Write paths after this migration:
--   - INSERT (self, new profile):  forced to is_admin=false AND
--     membership_tier='standard' — this also closes a pre-existing
--     escalation gap: 002's profiles_insert_own allowed a customer to
--     INSERT their own row with is_admin=true before any trigger-created
--     row existed (003 hardened UPDATE but never INSERT).
--   - UPDATE (self): is_admin and membership_tier must equal the current
--     row's values — name/phone/avatar stay editable, privileges do not.
--   - admin_set_membership_tier(UUID, TEXT): the only tier write path,
--     admin-gated via assert_admin() (033), revokes from PUBLIC/anon and
--     grants to authenticated like every admin RPC.
-- ─────────────────────────────────────────────────────────────

BEGIN;

-- 1. Column + value guard.
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS membership_tier TEXT NOT NULL DEFAULT 'standard';

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_membership_tier_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_membership_tier_check
  CHECK (membership_tier IN ('standard', 'premium'));

-- 2. INSERT hardening: a self-created profile must start unprivileged.
DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_own_safe" ON profiles;
CREATE POLICY "profiles_insert_own_safe"
  ON profiles FOR INSERT
  WITH CHECK (
    auth.uid() = id
    AND is_admin = false
    AND membership_tier = 'standard'
  );

-- 3. UPDATE hardening: tier and admin flag are server-managed; the two
-- subqueries compare NEW values against the existing row (same pattern
-- as 003's is_admin guard, extended to the tier).
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
DROP POLICY IF EXISTS "profiles_update_own_safe" ON profiles;
CREATE POLICY "profiles_update_own_safe"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND is_admin = (SELECT is_admin FROM profiles WHERE id = auth.uid())
    AND membership_tier = (SELECT membership_tier FROM profiles WHERE id = auth.uid())
  );

-- 4. The admin write path.
CREATE OR REPLACE FUNCTION admin_set_membership_tier(
  p_profile_id UUID,
  p_tier TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM assert_admin();

  IF p_tier NOT IN ('standard', 'premium') THEN
    RAISE EXCEPTION 'invalid_tier' USING ERRCODE = '22023';
  END IF;

  UPDATE profiles
     SET membership_tier = p_tier,
         updated_at = now()
   WHERE id = p_profile_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0002';
  END IF;
END $$;

REVOKE EXECUTE ON FUNCTION admin_set_membership_tier(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION admin_set_membership_tier(UUID, TEXT) TO authenticated;

COMMIT;
