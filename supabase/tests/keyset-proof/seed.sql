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
-- Search indexes: MIRROR OF MIGRATION 064 (064_profiles_search_trgm_index.sql).
--
-- Duplicated here on purpose so the planner check in search_index_plan.sql runs
-- against the schema shape the migration actually proposes. If 064 changes,
-- change this in the same commit or the check silently stops testing it.
--
-- Created after the walk fixture and before the bulk load in
-- search_index_plan.sql, which is where they matter: on 129 rows the planner
-- will choose a sequential scan whatever indexes exist, and rightly so.
-- ---------------------------------------------------------------------------
create extension if not exists pg_trgm;

create index if not exists idx_profiles_full_name_trgm
  on public.profiles using gin (full_name gin_trgm_ops);

-- NOTE: there is deliberately NO index on `phone` here. An earlier revision of
-- 064 created one and it was dropped as vestigial — a phone-shaped term is
-- routed to `phone_digits`, so `phone` is only reached by a term that is not
-- phone-shaped. Kept in step with 064 rather than reintroduced by habit.

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

-- ---------------------------------------------------------------------------
-- Phone-normalisation fixture (migration 065).
--
-- Every stored value here carries separators, which is the whole point: a
-- digit-only search can only reach these rows through `phone_digits`, so if the
-- normalised column or the matching clause is broken they are unreachable and
-- the probe fails. Three different separator styles because the expression
-- strips a character CLASS, and a fixture using only spaces would not notice if
-- it had been written as `replace(phone, ' ', '')`.
--
-- Distinct older instants, so they do not collide with the tie groups above.
-- ---------------------------------------------------------------------------
insert into public.profiles (id, full_name, phone, membership_tier, created_at) values
  ('00000000-0000-0000-0000-000000000301', 'Nour Separated', '+966 50 123 4567', 'standard', timestamptz '2026-09-16 05:00:00+00'),
  ('00000000-0000-0000-0000-000000000302', 'Hana Dashes',    '050-123-4567',     'premium',  timestamptz '2026-09-16 04:00:00+00'),
  ('00000000-0000-0000-0000-000000000303', 'Rania Parens',   '(015) 111-2222',   'standard', timestamptz '2026-09-16 03:00:00+00');

-- ---------------------------------------------------------------------------
-- Native-digit fixture: one row per Unicode Nd block, GENERATED.
--
-- Every digit system, not just Arabic: a customer may have typed a number in
-- Devanagari, Thai, fullwidth, or any other Nd script, and the pre-065 strip
-- deleted all of them alike. The stored value is <native 0><native 9><two ASCII
-- digits encoding the row index> — the ASCII tail is what keeps rows from
-- matching each OTHER (a fixed '0909' everywhere would make one search match
-- all 75 rows and the exact-one-match assertions would be false). The names are
-- ASCII on purpose, so a match can only have come from the phone column.
-- Distinct older instants, so they do not collide with the tie groups above.
-- ---------------------------------------------------------------------------
-- unicode-digit-rows:generated — do not edit by hand
insert into public.profiles (id, full_name, phone, membership_tier, created_at) values
  ('00000000-0000-0000-0000-000000000401', 'Digits 00', '٠٩00', 'standard', timestamptz '2026-09-15 23:00:00+00' - 0 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000402', 'Digits 01', '۰۹01', 'standard', timestamptz '2026-09-15 23:00:00+00' - 1 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000403', 'Digits 02', '߀߉02', 'standard', timestamptz '2026-09-15 23:00:00+00' - 2 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000404', 'Digits 03', '०९03', 'standard', timestamptz '2026-09-15 23:00:00+00' - 3 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000405', 'Digits 04', '০৯04', 'standard', timestamptz '2026-09-15 23:00:00+00' - 4 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000406', 'Digits 05', '੦੯05', 'standard', timestamptz '2026-09-15 23:00:00+00' - 5 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000407', 'Digits 06', '૦૯06', 'standard', timestamptz '2026-09-15 23:00:00+00' - 6 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000408', 'Digits 07', '୦୯07', 'standard', timestamptz '2026-09-15 23:00:00+00' - 7 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000409', 'Digits 08', '௦௯08', 'standard', timestamptz '2026-09-15 23:00:00+00' - 8 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000410', 'Digits 09', '౦౯09', 'standard', timestamptz '2026-09-15 23:00:00+00' - 9 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000411', 'Digits 10', '೦೯10', 'standard', timestamptz '2026-09-15 23:00:00+00' - 10 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000412', 'Digits 11', '൦൯11', 'standard', timestamptz '2026-09-15 23:00:00+00' - 11 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000413', 'Digits 12', '෦෯12', 'standard', timestamptz '2026-09-15 23:00:00+00' - 12 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000414', 'Digits 13', '๐๙13', 'standard', timestamptz '2026-09-15 23:00:00+00' - 13 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000415', 'Digits 14', '໐໙14', 'standard', timestamptz '2026-09-15 23:00:00+00' - 14 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000416', 'Digits 15', '༠༩15', 'standard', timestamptz '2026-09-15 23:00:00+00' - 15 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000417', 'Digits 16', '၀၉16', 'standard', timestamptz '2026-09-15 23:00:00+00' - 16 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000418', 'Digits 17', '႐႙17', 'standard', timestamptz '2026-09-15 23:00:00+00' - 17 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000419', 'Digits 18', '០៩18', 'standard', timestamptz '2026-09-15 23:00:00+00' - 18 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000420', 'Digits 19', '᠐᠙19', 'standard', timestamptz '2026-09-15 23:00:00+00' - 19 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000421', 'Digits 20', '᥆᥏20', 'standard', timestamptz '2026-09-15 23:00:00+00' - 20 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000422', 'Digits 21', '᧐᧙21', 'standard', timestamptz '2026-09-15 23:00:00+00' - 21 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000423', 'Digits 22', '᪀᪉22', 'standard', timestamptz '2026-09-15 23:00:00+00' - 22 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000424', 'Digits 23', '᪐᪙23', 'standard', timestamptz '2026-09-15 23:00:00+00' - 23 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000425', 'Digits 24', '᭐᭙24', 'standard', timestamptz '2026-09-15 23:00:00+00' - 24 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000426', 'Digits 25', '᮰᮹25', 'standard', timestamptz '2026-09-15 23:00:00+00' - 25 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000427', 'Digits 26', '᱀᱉26', 'standard', timestamptz '2026-09-15 23:00:00+00' - 26 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000428', 'Digits 27', '᱐᱙27', 'standard', timestamptz '2026-09-15 23:00:00+00' - 27 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000429', 'Digits 28', '꘠꘩28', 'standard', timestamptz '2026-09-15 23:00:00+00' - 28 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000430', 'Digits 29', '꣐꣙29', 'standard', timestamptz '2026-09-15 23:00:00+00' - 29 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000431', 'Digits 30', '꤀꤉30', 'standard', timestamptz '2026-09-15 23:00:00+00' - 30 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000432', 'Digits 31', '꧐꧙31', 'standard', timestamptz '2026-09-15 23:00:00+00' - 31 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000433', 'Digits 32', '꧰꧹32', 'standard', timestamptz '2026-09-15 23:00:00+00' - 32 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000434', 'Digits 33', '꩐꩙33', 'standard', timestamptz '2026-09-15 23:00:00+00' - 33 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000435', 'Digits 34', '꯰꯹34', 'standard', timestamptz '2026-09-15 23:00:00+00' - 34 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000436', 'Digits 35', '０９35', 'standard', timestamptz '2026-09-15 23:00:00+00' - 35 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000437', 'Digits 36', '𐒠𐒩36', 'standard', timestamptz '2026-09-15 23:00:00+00' - 36 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000438', 'Digits 37', '𐴰𐴹37', 'standard', timestamptz '2026-09-15 23:00:00+00' - 37 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000439', 'Digits 38', '𐵀𐵉38', 'standard', timestamptz '2026-09-15 23:00:00+00' - 38 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000440', 'Digits 39', '𑁦𑁯39', 'standard', timestamptz '2026-09-15 23:00:00+00' - 39 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000441', 'Digits 40', '𑃰𑃹40', 'standard', timestamptz '2026-09-15 23:00:00+00' - 40 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000442', 'Digits 41', '𑄶𑄿41', 'standard', timestamptz '2026-09-15 23:00:00+00' - 41 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000443', 'Digits 42', '𑇐𑇙42', 'standard', timestamptz '2026-09-15 23:00:00+00' - 42 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000444', 'Digits 43', '𑋰𑋹43', 'standard', timestamptz '2026-09-15 23:00:00+00' - 43 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000445', 'Digits 44', '𑑐𑑙44', 'standard', timestamptz '2026-09-15 23:00:00+00' - 44 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000446', 'Digits 45', '𑓐𑓙45', 'standard', timestamptz '2026-09-15 23:00:00+00' - 45 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000447', 'Digits 46', '𑙐𑙙46', 'standard', timestamptz '2026-09-15 23:00:00+00' - 46 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000448', 'Digits 47', '𑛀𑛉47', 'standard', timestamptz '2026-09-15 23:00:00+00' - 47 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000449', 'Digits 48', '𑛐𑛙48', 'standard', timestamptz '2026-09-15 23:00:00+00' - 48 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000450', 'Digits 49', '𑛚𑛣49', 'standard', timestamptz '2026-09-15 23:00:00+00' - 49 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000451', 'Digits 50', '𑜰𑜹50', 'standard', timestamptz '2026-09-15 23:00:00+00' - 50 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000452', 'Digits 51', '𑣠𑣩51', 'standard', timestamptz '2026-09-15 23:00:00+00' - 51 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000453', 'Digits 52', '𑥐𑥙52', 'standard', timestamptz '2026-09-15 23:00:00+00' - 52 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000454', 'Digits 53', '𑯰𑯹53', 'standard', timestamptz '2026-09-15 23:00:00+00' - 53 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000455', 'Digits 54', '𑱐𑱙54', 'standard', timestamptz '2026-09-15 23:00:00+00' - 54 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000456', 'Digits 55', '𑵐𑵙55', 'standard', timestamptz '2026-09-15 23:00:00+00' - 55 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000457', 'Digits 56', '𑶠𑶩56', 'standard', timestamptz '2026-09-15 23:00:00+00' - 56 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000458', 'Digits 57', '𑽐𑽙57', 'standard', timestamptz '2026-09-15 23:00:00+00' - 57 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000459', 'Digits 58', '𖄰𖄹58', 'standard', timestamptz '2026-09-15 23:00:00+00' - 58 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000460', 'Digits 59', '𖩠𖩩59', 'standard', timestamptz '2026-09-15 23:00:00+00' - 59 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000461', 'Digits 60', '𖫀𖫉60', 'standard', timestamptz '2026-09-15 23:00:00+00' - 60 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000462', 'Digits 61', '𖭐𖭙61', 'standard', timestamptz '2026-09-15 23:00:00+00' - 61 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000463', 'Digits 62', '𖵰𖵹62', 'standard', timestamptz '2026-09-15 23:00:00+00' - 62 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000464', 'Digits 63', '𜳰𜳹63', 'standard', timestamptz '2026-09-15 23:00:00+00' - 63 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000465', 'Digits 64', '𝟎𝟗64', 'standard', timestamptz '2026-09-15 23:00:00+00' - 64 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000466', 'Digits 65', '𝟘𝟡65', 'standard', timestamptz '2026-09-15 23:00:00+00' - 65 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000467', 'Digits 66', '𝟢𝟫66', 'standard', timestamptz '2026-09-15 23:00:00+00' - 66 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000468', 'Digits 67', '𝟬𝟵67', 'standard', timestamptz '2026-09-15 23:00:00+00' - 67 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000469', 'Digits 68', '𝟶𝟿68', 'standard', timestamptz '2026-09-15 23:00:00+00' - 68 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000470', 'Digits 69', '𞅀𞅉69', 'standard', timestamptz '2026-09-15 23:00:00+00' - 69 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000471', 'Digits 70', '𞋰𞋹70', 'standard', timestamptz '2026-09-15 23:00:00+00' - 70 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000472', 'Digits 71', '𞓰𞓹71', 'standard', timestamptz '2026-09-15 23:00:00+00' - 71 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000473', 'Digits 72', '𞗱𞗺72', 'standard', timestamptz '2026-09-15 23:00:00+00' - 72 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000474', 'Digits 73', '𞥐𞥙73', 'standard', timestamptz '2026-09-15 23:00:00+00' - 73 * interval '1 minute'),
  ('00000000-0000-0000-0000-000000000475', 'Digits 74', '🯰🯹74', 'standard', timestamptz '2026-09-15 23:00:00+00' - 74 * interval '1 minute');
-- unicode-digit-rows:end

-- ---------------------------------------------------------------------------
-- Phone normalisation: MIRROR OF MIGRATION 065
-- (065_profiles_phone_digits.sql).
--
-- The ALTER runs here, at the END of the fixture and after rows exist, rather
-- than inside the CREATE TABLE above — that is the production path, where the
-- column is added to a table that already holds rows and Postgres has to
-- backfill every one. Adding it to the DDL would skip that entirely.
--
-- The translate tables inside the marked region below are GENERATED by
-- supabase/tests/gen_phone_digit_ranges.py (the same region 065 carries), so
-- the mirror cannot drift from the migration by a mistyped codepoint. If 065
-- changes, re-run the generator with --apply in the same commit or the probe
-- silently stops testing the real expression.
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists phone_digits text
  generated always as (
    regexp_replace(
-- unicode-digit-tables:generated — do not edit by hand
      -- 75 non-ASCII Nd blocks, unicodedata 16.0.0; regenerate with
      --   python3 supabase/tests/gen_phone_digit_ranges.py --apply
      translate(
        COALESCE(phone, ''),
        '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹߀߁߂߃߄߅߆߇߈߉०१२३४५६७८९০১২৩৪৫৬৭৮৯੦੧੨੩੪੫੬੭੮੯૦૧૨૩૪૫૬૭૮૯୦୧୨୩୪୫୬୭୮୯௦௧௨௩௪௫௬௭௮௯౦౧౨౩౪౫౬౭౮౯೦೧೨೩೪೫೬೭೮೯൦൧൨൩൪൫൬൭൮൯෦෧෨෩෪෫෬෭෮෯๐๑๒๓๔๕๖๗๘๙໐໑໒໓໔໕໖໗໘໙༠༡༢༣༤༥༦༧༨༩၀၁၂၃၄၅၆၇၈၉႐႑႒႓႔႕႖႗႘႙០១២៣៤៥៦៧៨៩᠐᠑᠒᠓᠔᠕᠖᠗᠘᠙᥆᥇᥈᥉᥊᥋᥌᥍᥎᥏᧐᧑᧒᧓᧔᧕᧖᧗᧘᧙᪀᪁᪂᪃᪄᪅᪆᪇᪈᪉᪐᪑᪒᪓᪔᪕᪖᪗᪘᪙᭐᭑᭒᭓᭔᭕᭖᭗᭘᭙᮰᮱᮲᮳᮴᮵᮶᮷᮸᮹᱀᱁᱂᱃᱄᱅᱆᱇᱈᱉᱐᱑᱒᱓᱔᱕᱖᱗᱘᱙꘠꘡꘢꘣꘤꘥꘦꘧꘨꘩꣐꣑꣒꣓꣔꣕꣖꣗꣘꣙꤀꤁꤂꤃꤄꤅꤆꤇꤈꤉꧐꧑꧒꧓꧔꧕꧖꧗꧘꧙꧰꧱꧲꧳꧴꧵꧶꧷꧸꧹꩐꩑꩒꩓꩔꩕꩖꩗꩘꩙꯰꯱꯲꯳꯴꯵꯶꯷꯸꯹０１２３４５６７８９𐒠𐒡𐒢𐒣𐒤𐒥𐒦𐒧𐒨𐒩𐴰𐴱𐴲𐴳𐴴𐴵𐴶𐴷𐴸𐴹𐵀𐵁𐵂𐵃𐵄𐵅𐵆𐵇𐵈𐵉𑁦𑁧𑁨𑁩𑁪𑁫𑁬𑁭𑁮𑁯𑃰𑃱𑃲𑃳𑃴𑃵𑃶𑃷𑃸𑃹𑄶𑄷𑄸𑄹𑄺𑄻𑄼𑄽𑄾𑄿𑇐𑇑𑇒𑇓𑇔𑇕𑇖𑇗𑇘𑇙𑋰𑋱𑋲𑋳𑋴𑋵𑋶𑋷𑋸𑋹𑑐𑑑𑑒𑑓𑑔𑑕𑑖𑑗𑑘𑑙𑓐𑓑𑓒𑓓𑓔𑓕𑓖𑓗𑓘𑓙𑙐𑙑𑙒𑙓𑙔𑙕𑙖𑙗𑙘𑙙𑛀𑛁𑛂𑛃𑛄𑛅𑛆𑛇𑛈𑛉𑛐𑛑𑛒𑛓𑛔𑛕𑛖𑛗𑛘𑛙𑛚𑛛𑛜𑛝𑛞𑛟𑛠𑛡𑛢𑛣𑜰𑜱𑜲𑜳𑜴𑜵𑜶𑜷𑜸𑜹𑣠𑣡𑣢𑣣𑣤𑣥𑣦𑣧𑣨𑣩𑥐𑥑𑥒𑥓𑥔𑥕𑥖𑥗𑥘𑥙𑯰𑯱𑯲𑯳𑯴𑯵𑯶𑯷𑯸𑯹𑱐𑱑𑱒𑱓𑱔𑱕𑱖𑱗𑱘𑱙𑵐𑵑𑵒𑵓𑵔𑵕𑵖𑵗𑵘𑵙𑶠𑶡𑶢𑶣𑶤𑶥𑶦𑶧𑶨𑶩𑽐𑽑𑽒𑽓𑽔𑽕𑽖𑽗𑽘𑽙𖄰𖄱𖄲𖄳𖄴𖄵𖄶𖄷𖄸𖄹𖩠𖩡𖩢𖩣𖩤𖩥𖩦𖩧𖩨𖩩𖫀𖫁𖫂𖫃𖫄𖫅𖫆𖫇𖫈𖫉𖭐𖭑𖭒𖭓𖭔𖭕𖭖𖭗𖭘𖭙𖵰𖵱𖵲𖵳𖵴𖵵𖵶𖵷𖵸𖵹𜳰𜳱𜳲𜳳𜳴𜳵𜳶𜳷𜳸𜳹𝟎𝟏𝟐𝟑𝟒𝟓𝟔𝟕𝟖𝟗𝟘𝟙𝟚𝟛𝟜𝟝𝟞𝟟𝟠𝟡𝟢𝟣𝟤𝟥𝟦𝟧𝟨𝟩𝟪𝟫𝟬𝟭𝟮𝟯𝟰𝟱𝟲𝟳𝟴𝟵𝟶𝟷𝟸𝟹𝟺𝟻𝟼𝟽𝟾𝟿𞅀𞅁𞅂𞅃𞅄𞅅𞅆𞅇𞅈𞅉𞋰𞋱𞋲𞋳𞋴𞋵𞋶𞋷𞋸𞋹𞓰𞓱𞓲𞓳𞓴𞓵𞓶𞓷𞓸𞓹𞗱𞗲𞗳𞗴𞗵𞗶𞗷𞗸𞗹𞗺𞥐𞥑𞥒𞥓𞥔𞥕𞥖𞥗𞥘𞥙🯰🯱🯲🯳🯴🯵🯶🯷🯸🯹',
        repeat('0123456789', 75)
      ),
-- unicode-digit-tables:end
      '[^0-9]', '', 'g'
    )
  )
  stored;

create index if not exists idx_profiles_phone_digits_trgm
  on public.profiles using gin (phone_digits gin_trgm_ops);
