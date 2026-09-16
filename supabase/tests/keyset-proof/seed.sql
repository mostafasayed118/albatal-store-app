-- ============================================================================
-- Fixture for the keyset-paging / search-filter proof.
-- ============================================================================
-- Mirrors ONLY what the query under test depends on: the column set and types
-- of public.profiles, and the fact that `created_at` is NOT unique.
--
-- Deliberate omissions, each because it would test the wrong thing:
--   * The `references auth.users(id)` FK is dropped — there is no auth schema
--     in this container, and referential integrity is not what is in question.
--   * RLS is left OFF. This harness isolates PostgREST's query parsing and
--     Postgres' row ordering; row-level access is covered by
--     run_rls_adversarial.mjs against the real policies.
-- ============================================================================

-- PostgREST's canonical role pair: a login role that inherits a nologin role.
create role authenticator noinherit login password 'authpass';
create role web_anon nologin;
grant web_anon to authenticator;

create table public.profiles (
  id uuid primary key,
  full_name text not null default '',
  phone text,
  membership_tier text not null default 'standard'
    check (membership_tier in ('standard', 'premium')),
  created_at timestamptz not null default now()
);

grant usage on schema public to web_anon;
grant select on public.profiles to web_anon;

-- ---------------------------------------------------------------------------
-- The walk fixture: 120 rows sharing only 12 distinct instants (10 rows each).
--
-- Duplicate sort keys are the POINT. `ORDER BY created_at DESC` alone is stable
-- within one query but not across queries, so 10 rows sharing an instant are
-- exactly the arrangement that lets a row land on two consecutive pages or on
-- neither — the defect keyset paging exists to remove. A fixture of unique
-- timestamps would pass even with the `id` tie-breaker deleted, i.e. it would
-- prove nothing.
--
-- 12 instants x 10 rows spans the production page size (50) three times, so the
-- page boundaries fall *inside* tie groups rather than between them.
-- ---------------------------------------------------------------------------
insert into public.profiles (id, full_name, phone, membership_tier, created_at)
select
  ('00000000-0000-0000-0000-' || lpad(g::text, 12, '0'))::uuid,
  'Customer ' || lpad(g::text, 3, '0'),
  '0100' || lpad(g::text, 6, '0'),
  case when g % 4 = 0 then 'premium' else 'standard' end,
  timestamptz '2026-09-16 10:00:00+00' - ((g - 1) / 10) * interval '1 hour'
from generate_series(1, 120) as g;

-- ---------------------------------------------------------------------------
-- Search fixture. These names contain the characters that are STRUCTURAL in an
-- `or` tree (`,` `(` `)` and `"`), so a search for them only matches literally
-- if the client escaped them. Each gets a distinct, older instant so it does
-- not collide with the tie groups above.
-- ---------------------------------------------------------------------------
insert into public.profiles (id, full_name, phone, membership_tier, created_at) values
  ('00000000-0000-0000-0000-000000000201', 'Ali, Omar',        '01555555555', 'standard', timestamptz '2026-09-16 09:00:00+00'),
  ('00000000-0000-0000-0000-000000000202', 'Sara (Home)',      '01555555556', 'premium',  timestamptz '2026-09-16 08:00:00+00'),
  ('00000000-0000-0000-0000-000000000203', 'Quote "Q" Test',   '01555555557', 'standard', timestamptz '2026-09-16 07:00:00+00'),
  -- Phone-search fixture: the number is NOT derivable from the name, so a match
  -- on it can only have come from the phone column.
  ('00000000-0000-0000-0000-000000000204', 'Layla Hassan',     '01098765432', 'premium',  timestamptz '2026-09-16 06:00:00+00');
