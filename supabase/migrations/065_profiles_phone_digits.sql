-- ============================================================================
-- 065_profiles_phone_digits.sql — REVIEW-GATED PROPOSAL
-- ============================================================================
-- Owner review required before applying (AGENTS.md migration gate).
-- Provenance: owner-requested follow-up on branch feat/admin-customer-tier.
-- Closes the residual recorded in 064's "Interaction with phone normalisation"
-- section, in STATE.md, and in the PR description.
--
-- Problem
-- -------
-- `profiles.phone` is raw TEXT captured from auth metadata
-- (003_auth_profiles_and_hardening.sql reads
-- `NEW.raw_user_meta_data->>'phone'`), so it stores whatever the customer
-- typed: '+966 50 123 4567', '050-123-4567', '(010) 987-6543'. Nothing in this
-- repo normalises it — there is no write-time trigger and no client-side
-- reformat.
--
-- The admin directory's search matches that column literally:
--     phone.ilike.'%<term>%'
-- (see `customerSearchFilter` in
-- lib/features/admin/data/supabase_admin_repository.dart). So an admin who
-- types a bare digit run — which is how a phone number is normally read back
-- and searched — matches NOTHING whenever the stored value carries separators.
-- The search looks broken while being technically correct, and the admin has no
-- way to tell the difference between "no such customer" and "the customer's
-- number has spaces in it".
--
-- Fix
-- ---
-- A STORED generated column holding the digits of `phone`, giving the query a
-- punctuation-free column to match a digit-only term against.
--
-- Generated rather than trigger-maintained because Postgres then owns the
-- invariant: `phone_digits` cannot drift from `phone`, no write path has to
-- remember to maintain it, and clients cannot write it at all (a generated
-- column rejects INSERT/UPDATE, so this cannot be used to smuggle a value past
-- RLS).
--
-- Design notes
-- ------------
-- * Expression: COALESCE(phone, '') first, then strip every non-digit.
--   COALESCE is load-bearing, not defensive: without it a NULL `phone` makes
--   the generated value NULL, and a NULL is not "no digits" — it is a
--   comparison that can never be true. With it, a row that has no phone yields
--   '' and simply never matches a digit term, which is the correct outcome.
-- * `regexp_replace(text, text, text, text)` and `translate(text, text, text)`
--   are both IMMUTABLE in PostgreSQL 15, which STORED requires. Not taken on
--   trust: the probe in supabase/tests/keyset-proof/ applies this exact
--   statement against a live PostgreSQL 15.19 instance (postgres:15-alpine,
--   matching this project's pinned major_version) and then READS THE COMPUTED
--   VALUES BACK, so a non-immutable expression would fail at the ALTER and a
--   wrong expression would fail the read-back rather than reach production.
-- * The two `translate` tables are 20 characters each, positionally aligned,
--   and contain no duplicates (duplicates would silently make the first
--   mapping win).
-- * Column name matches the one 064's header already anticipates.
-- * NOT added to the client's SELECT list. The directory filters on this column
--   but never displays it — `phone` stays the value the admin sees. Returning
--   both would be the same PII twice.
-- Arabic-Indic digits — a SECOND defect this same expression has to fix
-- --------------------------------------------------------------------
-- The strip is `[^0-9]`, which is ASCII-only. An Arabic-locale customer who
-- entered ٠١٠١٢٣٤٥٦٧٨ does NOT get a `phone_digits` that keeps the digits
-- differently — Postgres DELETES every one of them, and the column comes out
-- EMPTY. So the row is unreachable by any digit search at all, including an
-- ASCII one typed by an admin who knows nothing about the encoding.
--
-- That is a strictly worse failure than the separator one this migration was
-- written for, and it is why the expression transliterates BEFORE it strips:
-- `translate` maps the digit characters to ASCII, and the strip then has ASCII
-- digits left to keep. This is why the order of the two calls is load-bearing
-- rather than stylistic.
--
-- Both Arabic digit ranges are mapped, not just the one the app's own locale
-- uses:
--   * Arabic-Indic           U+0660–U+0669   ٠١٢٣٤٥٦٧٨٩   (Egypt, Saudi)
--   * Extended Arabic-Indic  U+06F0–U+06F9   ۰۱۲۳۴۵۶۷۸۹   (Persian, Urdu)
-- Arabic script is shared across languages, so a customer is as likely to have
-- typed one as the other, and partial normalisation would reproduce this exact
-- bug for the half left out. Both are `translate` tables, so the cost is
-- characters in a literal, not a second code path.
--
-- `translate(text, text, text)` is IMMUTABLE, so the generated column accepts
-- it. Not taken on trust either — the ALTER below is what proves it, and the
-- harness reads the computed values back.
--
-- ORDERING COUPLING — read before deploying the matching client build
-- ------------------------------------------------------------------
-- The client build on this branch emits `phone_digits.ilike.'%…%'` for a
-- phone-shaped search term. PostgREST answers an unknown column with
-- `42703`/HTTP 400, i.e. THE WHOLE DIRECTORY REQUEST FAILS, not just the phone
-- branch of the search. So this migration must be applied BEFORE that client
-- build ships. Pairing already exists in this branch (the tier control calls
-- `admin_set_membership_tier` from 046), so the deploy order is: migrations
-- 063–065, then the app.
--
-- Cost
-- ----
-- ADD COLUMN … STORED rewrites `profiles` and holds ACCESS EXCLUSIVE for the
-- duration. At today's row counts that is a blink; on a large table this would
-- need an out-of-band build instead of a plain statement in a migration.
--
-- ⚠️ `IF NOT EXISTS` does NOT cover the expression
-- ------------------------------------------------
-- `ADD COLUMN IF NOT EXISTS` makes the STATEMENT idempotent, not the column
-- DEFINITION. If this migration has already been applied anywhere with an
-- earlier revision of the expression, re-running it is a silent no-op and the
-- column keeps the OLD expression — with no error, and the only visible
-- symptom being searches that quietly miss rows. This is exactly how the
-- Arabic-Indic transliteration below could fail to take effect on a database
-- where a pre-transliteration 065 was already applied. Check first:
--     select pg_get_expr(d.adbin, d.adrelid)
--       from pg_attrdef d join pg_attribute a
--         on a.attrelid = d.adrelid and a.attnum = d.adnum
--      where d.adrelid = 'public.profiles'::regclass
--        and a.attname = 'phone_digits';
-- If it does not mention `translate`, drop and re-add the column (see Rollback,
-- then apply 065 again). Verified NOT yet applied anywhere, so today the plain
-- statement is correct as written.
--
-- Rollback
-- --------
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS phone_digits;
-- (Dropping the column drops idx_profiles_phone_digits_trgm with it.)
-- Rollback restores the pre-065 behaviour: a digit-only search again matches
-- nothing when the stored number has separators. No other data changes either
-- way — `phone` is never modified by this migration.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- The digits of `phone`, with every separator removed. Read-only, server-owned.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone_digits TEXT
  GENERATED ALWAYS AS (
    regexp_replace(
      -- TRANSLITERATE FIRST, then strip. The order is the whole point: the
      -- strip is `[^0-9]`, i.e. ASCII-only, so Arabic-Indic digits are not
      -- "not a digit" in a way it can keep — they are characters it DELETES.
      translate(
        COALESCE(phone, ''),
        '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
        '01234567890123456789'
      ),
      '[^0-9]', '', 'g'
    )
  )
  STORED;

-- Digit-only searches match this column with a LEADING wildcard, exactly as
-- 064's indexes serve the name search, so it needs the same trigram treatment.
-- Without it, every phone-shaped search is a sequential scan — and digits are
-- the *common* case, which would make 064's benefit the rarer half.
--
-- Measured at 20 127 rows (the planner check in supabase/tests/keyset-proof/),
-- searching for a run that matches 100 of them:
--   without this index   Seq Scan, 20 027 rows removed by filter, 288 buffers
--   with this index      Bitmap Index Scan, 106 buffers
-- Buffers rather than wall-clock are the scale-relevant number: 12.5 ms →
-- 2.8 ms is not the point, 288 pages → 106 is.
CREATE INDEX IF NOT EXISTS idx_profiles_phone_digits_trgm
  ON public.profiles USING gin (phone_digits gin_trgm_ops);
