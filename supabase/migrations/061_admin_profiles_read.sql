-- ============================================================================
-- 061_admin_profiles_read.sql — AUD-008 remediation (route a)
-- ============================================================================
-- Provenance: docs/audit/2026-09-15/proposals/061_admin_profiles_read.sql
-- (owner-reviewed 2026-09-15; route (a) chosen over route (b) because the
-- client never calls admin_list_customers — SupabaseAdminRepository
-- .fetchCustomers reads profiles(id, full_name, phone, membership_tier)
-- directly, so the table-level SELECT policy is the change that makes the
-- live admin Customers screen list other users).
--
-- Problem
-- -------
-- public.profiles grants SELECT only for the caller's own row
-- (002_rls_policies.sql "profiles_select_own" USING auth.uid() = id), so an
-- admin sees ONLY their own profile row and the customer directory silently
-- under-reports.
--
-- Security analysis
-- -----------------
-- * The fix widens SELECT to ADMINS only, never to all authenticated users:
--   phone is PII (profiles has no email column; auth.users holds it).
-- * is_admin is read from the caller's own row; profiles_update_own_safe
--   (029) prevents self-escalation, so trusting is_admin here is sound.
-- * The admin check is wrapped in a SECURITY DEFINER helper to avoid
--   recursive RLS evaluation, matching the 017 (get_order_details) pattern.
-- * Additive: the own-row policy stays; non-admins still see exactly one row.
-- ============================================================================

-- 1. SECURITY DEFINER admin check (avoids recursive RLS evaluation).
create or replace function public.is_current_user_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (select p.is_admin from public.profiles p where p.id = auth.uid()),
    false
  );
$$;

revoke all on function public.is_current_user_admin() from public;
grant execute on function public.is_current_user_admin() to authenticated;

-- 2. Admin-only SELECT policy on profiles (additive: the own-row policy stays).
drop policy if exists "profiles_select_admin" on public.profiles;
create policy "profiles_select_admin"
  on public.profiles
  for select
  to authenticated
  using ( public.is_current_user_admin() );

-- ============================================================================
-- Rollback
-- ============================================================================
-- drop policy if exists "profiles_select_admin" on public.profiles;
-- drop function if exists public.is_current_user_admin();
-- (Rollback restores the pre-061 behaviour: directory limited to own row.)
-- ============================================================================
