-- ============================================================================
-- Planner check for migration 064 (pg_trgm search indexes).
-- ============================================================================
-- Proves the claim the migration makes: that the directory's leading-wildcard
-- search stops being a sequential scan. "The index exists" is not that claim —
-- an index the planner cannot use for the predicate, or will not choose, leaves
-- the scan in place.
--
-- RUN ORDER MATTERS. This script bulk-loads 20 000 rows. Run the HTTP probe
-- (run_keyset_paging_proof.mjs --mode local) FIRST — its keyset walk visits
-- every row, so at 20k rows and a page size of 7 it would take thousands of
-- requests. `docker compose ... down -v` then `up -d --wait` resets the
-- fixture if you need to run the probe again.
--
-- Run:
--   docker exec -i keyset-proof-db-1 \
--     psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
--     < supabase/tests/keyset-proof/search_index_plan.sql
-- ON_ERROR_STOP=1 is what makes the assertions below fail the command.
--
-- WHY A BULK LOAD AT ALL: on the probe's 124-row fixture the planner picks a
-- sequential scan whatever indexes exist, and it is right to — a 2-page table
-- is cheaper to scan. Asserting index usage there would be asserting a fiction.
-- The indexes have to be measured at a size where the choice is real.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Bulk fixture. Distinct uuid prefix from the probe's rows, so the two fixtures
-- do not collide; ON CONFLICT makes re-running this script idempotent.
-- ---------------------------------------------------------------------------
insert into public.profiles (id, full_name, phone, membership_tier, created_at)
select
  ('00000000-0000-0000-0001-' || lpad(g::text, 12, '0'))::uuid,
  'Bulk Customer ' || lpad(g::text, 6, '0'),
  '0100' || lpad(g::text, 6, '0'),
  'standard',
  timestamptz '2026-09-01 00:00:00+00' - (g * interval '1 second')
from generate_series(1, 20000) as g
on conflict (id) do nothing;

-- ANALYZE is not optional: without fresh statistics the planner is guessing and
-- the result says nothing about the index.
analyze public.profiles;

\echo ''
\echo '=== row count ==='
select count(*) as profiles from public.profiles;

-- ---------------------------------------------------------------------------
-- Assertion 1: a name search is served by the trigram index, not a seq scan.
-- ---------------------------------------------------------------------------
do $$
declare
  plan json;
begin
  execute $q$explain (format json)
    select id from public.profiles where full_name ilike '%layla%'$q$ into plan;

  if position('idx_profiles_full_name_trgm' in plan::text) = 0 then
    raise exception
      'name search did not use idx_profiles_full_name_trgm — migration 064 is not doing its job. Plan: %',
      plan::text;
  end if;

  raise notice 'name search uses idx_profiles_full_name_trgm';
end $$;

-- ---------------------------------------------------------------------------
-- Assertion 2: likewise for the phone column.
-- ---------------------------------------------------------------------------
do $$
declare
  plan json;
begin
  execute $q$explain (format json)
    select id from public.profiles where phone ilike '%98765432%'$q$ into plan;

  if position('idx_profiles_phone_trgm' in plan::text) = 0 then
    raise exception
      'phone search did not use idx_profiles_phone_trgm. Plan: %',
      plan::text;
  end if;

  raise notice 'phone search uses idx_profiles_phone_trgm';
end $$;

-- ---------------------------------------------------------------------------
-- Recorded, NOT asserted: the documented limit of the technique.
--
-- A trigram index needs at least 3 extractable characters. A 1-2 character
-- pattern yields none, so no index can help and the scan returns — which is why
-- the directory's debounce still matters even with 064 applied. Printed rather
-- than asserted because falling back is correct behaviour here, not a failure.
-- ---------------------------------------------------------------------------
\echo ''
\echo '=== informational: a 2-character pattern cannot use a trigram index ==='
explain (costs off)
  select id from public.profiles where full_name ilike '%la%';

\echo ''
\echo '=== informational: the name-search plan in full ==='
explain (analyze, buffers)
  select id from public.profiles where full_name ilike '%layla%';
