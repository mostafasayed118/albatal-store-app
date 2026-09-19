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
-- * The `translate` tables are GENERATED, not hand-written: 75 blocks x 10
--   codepoints is 750 characters of exotic Unicode, and a wrong entry does not
--   merely miss a match — it CORRUPTS the stored value. They are emitted by
--   supabase/tests/gen_phone_digit_ranges.py from Python's `unicodedata` (the
--   Unicode database), which also asserts the structural facts the SQL
--   depends on: every block starts at digit value 0, values map positionally
--   (base + i -> i), and no block appears twice. The TO table is
--   `repeat('0123456789', N)` rather than a second literal, so it cannot fall
--   out of alignment with the FROM table. Re-run with --verify to check the
--   shipped artifacts still agree with the Unicode database.
-- * Column name matches the one 064's header already anticipates.
-- * NOT added to the client's SELECT list. The directory filters on this column
--   but never displays it — `phone` stays the value the admin sees. Returning
--   both would be the same PII twice.
-- Native digits of EVERY script — the same defect, generalised
-- ------------------------------------------------------------
-- The strip is `[^0-9]`, which is ASCII-only. A customer who entered ٠١٠١٢٣٤٥٦٧٨
-- does NOT get a `phone_digits` that keeps the digits differently — Postgres
-- DELETES every one of them, and the column comes out EMPTY. So the row is
-- unreachable by any digit search at all, including an ASCII one typed by an
-- admin who knows nothing about the encoding.
--
-- That is a strictly worse failure than the separator one this migration was
-- written for, and it is why the expression transliterates BEFORE it strips:
-- `translate` maps the digit characters to ASCII, and the strip then has ASCII
-- digits left to keep. This is why the order of the two calls is load-bearing
-- rather than stylistic.
--
-- EVERY Unicode Nd (decimal digit) block is mapped, not only the Arabic ones:
-- Arabic-Indic (U+0660–U+0669), Extended Arabic-Indic (U+06F0–U+06F9),
-- Devanagari (U+0966–U+096F), Thai (U+0E50–U+0E59), fullwidth (U+FF10–U+FF19),
-- the five Mathematical Alphanumeric digit blocks, and every other Nd block in
-- Unicode 16.0.0 — 75 in all. Digit systems are not confined to Arabic script,
-- and a table covering only the ranges the author had heard of would reproduce
-- this exact bug for a customer who typed a number in any of the others. The
-- full list lives in the generated region below; the generator is the source
-- of truth, not this prose.
--
-- `translate(text, text, text)` and `repeat(text, int)` are IMMUTABLE, so the
-- generated column accepts them. Not taken on trust either — the ALTER below
-- is what proves it, and the harness reads the computed values back.
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
      -- strip is `[^0-9]`, i.e. ASCII-only, so native digits are not "not a
      -- digit" in a way it can keep — they are characters it DELETES.
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
