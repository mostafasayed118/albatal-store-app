-- ============================================================================
-- PROPOSAL ONLY — HUMAN REVIEW REQUIRED — DO NOT AUTO-APPLY
-- ============================================================================
-- File:   proposals/061_admin_profiles_read.sql
-- Status: NOT APPLIED. Lives under docs/audit/2026-09-15/proposals/ deliberately:
--         AGENTS.md forbids editing supabase/ migrations without human review,
--         and the reviewer must run `supabase db push` themselves.
--
-- Problem (finding AUD-008)
-- -------------------------
-- public.profiles grants SELECT only for the caller's own row
-- (002_rls_policies.sql: "profiles_select_own" USING auth.uid() = id).
-- The admin customer directory (SupabaseAdminRepository.fetchCustomers,
-- lib/features/admin/data/supabase_admin_repository.dart) reads
-- profiles(id, full_name, phone, membership_tier), so an admin sees ONLY
-- their own profile row and the directory silently under-reports.
-- Repository comments already reference this proposal path; the file did
-- not exist, so the gap had no reviewable artifact.
--
-- Security analysis
-- -----------------
-- * No data is leaked today: RLS restricts MORE than intended.
-- * The fix must widen SELECT to admins only, never to all authenticated
--   users: `email`/`phone` are PII.
-- * is_admin is read from the caller's own row. The existing
--   profiles_update_own_safe policy (029) prevents a user from setting
--   is_admin = true themselves, so trusting is_admin here is sound.
-- * profiles.phone is the contact column the directory renders; profiles
--   has no email column (auth.users holds it, PostgREST does not expose it).
-- * To avoid recursive RLS evaluation (a policy on profiles that itself
--   selects from profiles), the admin check is wrapped in a SECURITY
--   DEFINER helper, matching the pattern already used by 017 (get_order_details).
--
-- Review checklist before applying
-- --------------------------------
-- [ ] Choose ONE remediation route (they are alternatives, not complements):
--     (a) this SELECT policy on profiles, or
--     (b) migrate the live-only `admin_list_customers` SECURITY DEFINER
--         function (discovered by the 2026-09-14 live-DB check: it exists in
--         production with NO migration file) and have fetchCustomers call it.
--     Route (b) is closer to the live system and avoids widening table-level
--     SELECT; route (a) is the smaller change. Decide before applying.
-- [ ] Confirm the helper name does not already exist.
-- [ ] Confirm no other policy on profiles grants broader SELECT.
-- [ ] Run `supabase db lint` / local policy tests.
-- [ ] Apply on staging first; verify the admin directory lists other customers.
-- [ ] Verify a non-admin still sees exactly one row (own profile only).
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
