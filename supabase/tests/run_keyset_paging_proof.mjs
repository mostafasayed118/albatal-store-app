#!/usr/bin/env node
// ============================================================================
// Keyset-paging + search-filter proof for the admin customer directory.
// ============================================================================
// WHAT THIS PROVES, AND WHY IT NEEDS A REAL PostgREST
// ---------------------------------------------------
// SupabaseAdminRepository.fetchCustomers sends two things that only PostgREST
// can adjudicate, because PostgREST is what parses a query string into SQL:
//
//   1. An `or` tree resuming the walk:
//        created_at.lt.TS,and(created_at.eq.TS,id.lt.ID)
//   2. An `or` tree searching two columns at once:
//        full_name.ilike."%term%",phone_digits.ilike."%digits%"
//      (or `phone.ilike` for a term that is not phone-shaped — migration 065,
//      whose generated column transliterates EVERY Unicode Nd digit block,
//      not only the Arabic ones — see gen_phone_digit_ranges.py)
//
// A Dart test can pin the STRING the client emits (and does), but only a live
// PostgREST can answer whether that string is accepted, whether the quoting
// survives parsing, and whether two `or` parameters are conjoined or one
// clobbers the other. The repo's other supabase/tests/*.mjs probes connect with
// `pg` — straight to Postgres — which bypasses PostgREST entirely and therefore
// cannot answer any of it.
//
// MODES
// -----
//   --mode local    Against the throwaway PostgREST in
//                   supabase/tests/keyset-proof/ (see its docker-compose.yml).
//                   Fixture-backed, including duplicate sort keys, so the
//                   no-duplicate/no-skip claim is actually exercised.
//   --mode staging  Read-only, against the isolated staging project. Walks the
//                   REAL directory and checks the same invariants on real data.
//                   Never writes. Refuses to run against any project other
//                   than the known staging ref.
//
// Run local (the full proof):
//   docker compose -f supabase/tests/keyset-proof/docker-compose.yml up -d --wait
//   node supabase/tests/run_keyset_paging_proof.mjs --mode local
//   docker compose -f supabase/tests/keyset-proof/docker-compose.yml down -v
//
// Run staging (redacted evidence only — no credentials are printed):
//   STAGING_SUPABASE_URL=... STAGING_ANON_KEY=... \
//     node supabase/tests/run_keyset_paging_proof.mjs --mode staging

// ── SAFETY GUARD ────────────────────────────────────────────────────────────
// Staging mode is read-only AND pinned to one project. The previous staging
// project ref is now PRODUCTION, so a URL is never trusted on its own.
const REQUIRED_STAGING_REF = 'zvpjngdgbpnkkqrorkul';
// ────────────────────────────────────────────────────────────────────────────

const LOCAL_BASE = 'http://localhost:3001';

/** PostgREST's own page-size-independent column select for this walk. */
const SELECT_COLUMNS = 'id,full_name,phone,membership_tier,created_at';

/** What the Dart client emits for two descending `.order()` calls (nulls last
 * by default). Kept verbatim so the request matches production. */
const ORDER = 'created_at.desc.nullslast,id.desc.nullslast';

// ── MIRRORS OF THE DART CLIENT ──────────────────────────────────────────────
// These must stay character-for-character equivalent to
// lib/features/admin/data/supabase_admin_repository.dart. If the Dart side
// changes and these do not, this proof silently stops testing the real thing —
// which is why the Dart side also pins the same strings in its own unit tests.

/** LIKE-stage escaping: `\`, `%`, `_` (Postgres' default LIKE escape char). */
function likeEscape(term) {
  return term
    .replaceAll('\\', '\\\\')
    .replaceAll('%', '\\%')
    .replaceAll('_', '\\_');
}

// unicode-digit-translit:generated — do not edit by hand
// 75 non-ASCII Nd blocks, unicodedata 16.0.0; regenerate with
//   python3 supabase/tests/gen_phone_digit_ranges.py --apply
const TRANSLIT_PAIRS = [
['٠', '0'], ['١', '1'], ['٢', '2'], ['٣', '3'], ['٤', '4'], ['٥', '5'], ['٦', '6'], ['٧', '7'], ['٨', '8'], ['٩', '9'], ['۰', '0'], ['۱', '1'], ['۲', '2'], ['۳', '3'], ['۴', '4'], ['۵', '5'], ['۶', '6'], ['۷', '7'], ['۸', '8'], ['۹', '9'], ['߀', '0'], ['߁', '1'], ['߂', '2'], ['߃', '3'], ['߄', '4'], ['߅', '5'], ['߆', '6'], ['߇', '7'], ['߈', '8'], ['߉', '9'], ['०', '0'], ['१', '1'], ['२', '2'], ['३', '3'], ['४', '4'], ['५', '5'], ['६', '6'], ['७', '7'], ['८', '8'], ['९', '9'], ['০', '0'], ['১', '1'], ['২', '2'], ['৩', '3'], ['৪', '4'], ['৫', '5'], ['৬', '6'], ['৭', '7'], ['৮', '8'], ['৯', '9'], ['੦', '0'], ['੧', '1'], ['੨', '2'], ['੩', '3'], ['੪', '4'], ['੫', '5'], ['੬', '6'], ['੭', '7'], ['੮', '8'], ['੯', '9'], ['૦', '0'], ['૧', '1'], ['૨', '2'], ['૩', '3'], ['૪', '4'], ['૫', '5'], ['૬', '6'], ['૭', '7'], ['૮', '8'], ['૯', '9'], ['୦', '0'], ['୧', '1'], ['୨', '2'], ['୩', '3'], ['୪', '4'], ['୫', '5'], ['୬', '6'], ['୭', '7'], ['୮', '8'], ['୯', '9'], ['௦', '0'], ['௧', '1'], ['௨', '2'], ['௩', '3'], ['௪', '4'], ['௫', '5'], ['௬', '6'], ['௭', '7'], ['௮', '8'], ['௯', '9'], ['౦', '0'], ['౧', '1'], ['౨', '2'], ['౩', '3'], ['౪', '4'], ['౫', '5'], ['౬', '6'], ['౭', '7'], ['౮', '8'], ['౯', '9'], ['೦', '0'], ['೧', '1'], ['೨', '2'], ['೩', '3'], ['೪', '4'], ['೫', '5'], ['೬', '6'], ['೭', '7'], ['೮', '8'], ['೯', '9'], ['൦', '0'], ['൧', '1'], ['൨', '2'], ['൩', '3'], ['൪', '4'], ['൫', '5'], ['൬', '6'], ['൭', '7'], ['൮', '8'], ['൯', '9'], ['෦', '0'], ['෧', '1'], ['෨', '2'], ['෩', '3'], ['෪', '4'], ['෫', '5'], ['෬', '6'], ['෭', '7'], ['෮', '8'], ['෯', '9'], ['๐', '0'], ['๑', '1'], ['๒', '2'], ['๓', '3'], ['๔', '4'], ['๕', '5'], ['๖', '6'], ['๗', '7'], ['๘', '8'], ['๙', '9'], ['໐', '0'], ['໑', '1'], ['໒', '2'], ['໓', '3'], ['໔', '4'], ['໕', '5'], ['໖', '6'], ['໗', '7'], ['໘', '8'], ['໙', '9'], ['༠', '0'], ['༡', '1'], ['༢', '2'], ['༣', '3'], ['༤', '4'], ['༥', '5'], ['༦', '6'], ['༧', '7'], ['༨', '8'], ['༩', '9'], ['၀', '0'], ['၁', '1'], ['၂', '2'], ['၃', '3'], ['၄', '4'], ['၅', '5'], ['၆', '6'], ['၇', '7'], ['၈', '8'], ['၉', '9'], ['႐', '0'], ['႑', '1'], ['႒', '2'], ['႓', '3'], ['႔', '4'], ['႕', '5'], ['႖', '6'], ['႗', '7'], ['႘', '8'], ['႙', '9'], ['០', '0'], ['១', '1'], ['២', '2'], ['៣', '3'], ['៤', '4'], ['៥', '5'], ['៦', '6'], ['៧', '7'], ['៨', '8'], ['៩', '9'], ['᠐', '0'], ['᠑', '1'], ['᠒', '2'], ['᠓', '3'], ['᠔', '4'], ['᠕', '5'], ['᠖', '6'], ['᠗', '7'], ['᠘', '8'], ['᠙', '9'], ['᥆', '0'], ['᥇', '1'], ['᥈', '2'], ['᥉', '3'], ['᥊', '4'], ['᥋', '5'], ['᥌', '6'], ['᥍', '7'], ['᥎', '8'], ['᥏', '9'], ['᧐', '0'], ['᧑', '1'], ['᧒', '2'], ['᧓', '3'], ['᧔', '4'], ['᧕', '5'], ['᧖', '6'], ['᧗', '7'], ['᧘', '8'], ['᧙', '9'], ['᪀', '0'], ['᪁', '1'], ['᪂', '2'], ['᪃', '3'], ['᪄', '4'], ['᪅', '5'], ['᪆', '6'], ['᪇', '7'], ['᪈', '8'], ['᪉', '9'], ['᪐', '0'], ['᪑', '1'], ['᪒', '2'], ['᪓', '3'], ['᪔', '4'], ['᪕', '5'], ['᪖', '6'], ['᪗', '7'], ['᪘', '8'], ['᪙', '9'], ['᭐', '0'], ['᭑', '1'], ['᭒', '2'], ['᭓', '3'], ['᭔', '4'], ['᭕', '5'], ['᭖', '6'], ['᭗', '7'], ['᭘', '8'], ['᭙', '9'], ['᮰', '0'], ['᮱', '1'], ['᮲', '2'], ['᮳', '3'], ['᮴', '4'], ['᮵', '5'], ['᮶', '6'], ['᮷', '7'], ['᮸', '8'], ['᮹', '9'], ['᱀', '0'], ['᱁', '1'], ['᱂', '2'], ['᱃', '3'], ['᱄', '4'], ['᱅', '5'], ['᱆', '6'], ['᱇', '7'], ['᱈', '8'], ['᱉', '9'], ['᱐', '0'], ['᱑', '1'], ['᱒', '2'], ['᱓', '3'], ['᱔', '4'], ['᱕', '5'], ['᱖', '6'], ['᱗', '7'], ['᱘', '8'], ['᱙', '9'], ['꘠', '0'], ['꘡', '1'], ['꘢', '2'], ['꘣', '3'], ['꘤', '4'], ['꘥', '5'], ['꘦', '6'], ['꘧', '7'], ['꘨', '8'], ['꘩', '9'], ['꣐', '0'], ['꣑', '1'], ['꣒', '2'], ['꣓', '3'], ['꣔', '4'], ['꣕', '5'], ['꣖', '6'], ['꣗', '7'], ['꣘', '8'], ['꣙', '9'], ['꤀', '0'], ['꤁', '1'], ['꤂', '2'], ['꤃', '3'], ['꤄', '4'], ['꤅', '5'], ['꤆', '6'], ['꤇', '7'], ['꤈', '8'], ['꤉', '9'], ['꧐', '0'], ['꧑', '1'], ['꧒', '2'], ['꧓', '3'], ['꧔', '4'], ['꧕', '5'], ['꧖', '6'], ['꧗', '7'], ['꧘', '8'], ['꧙', '9'], ['꧰', '0'], ['꧱', '1'], ['꧲', '2'], ['꧳', '3'], ['꧴', '4'], ['꧵', '5'], ['꧶', '6'], ['꧷', '7'], ['꧸', '8'], ['꧹', '9'], ['꩐', '0'], ['꩑', '1'], ['꩒', '2'], ['꩓', '3'], ['꩔', '4'], ['꩕', '5'], ['꩖', '6'], ['꩗', '7'], ['꩘', '8'], ['꩙', '9'], ['꯰', '0'], ['꯱', '1'], ['꯲', '2'], ['꯳', '3'], ['꯴', '4'], ['꯵', '5'], ['꯶', '6'], ['꯷', '7'], ['꯸', '8'], ['꯹', '9'], ['０', '0'], ['１', '1'], ['２', '2'], ['３', '3'], ['４', '4'], ['５', '5'], ['６', '6'], ['７', '7'], ['８', '8'], ['９', '9'], ['𐒠', '0'], ['𐒡', '1'], ['𐒢', '2'], ['𐒣', '3'], ['𐒤', '4'], ['𐒥', '5'], ['𐒦', '6'], ['𐒧', '7'], ['𐒨', '8'], ['𐒩', '9'], ['𐴰', '0'], ['𐴱', '1'], ['𐴲', '2'], ['𐴳', '3'], ['𐴴', '4'], ['𐴵', '5'], ['𐴶', '6'], ['𐴷', '7'], ['𐴸', '8'], ['𐴹', '9'], ['𐵀', '0'], ['𐵁', '1'], ['𐵂', '2'], ['𐵃', '3'], ['𐵄', '4'], ['𐵅', '5'], ['𐵆', '6'], ['𐵇', '7'], ['𐵈', '8'], ['𐵉', '9'], ['𑁦', '0'], ['𑁧', '1'], ['𑁨', '2'], ['𑁩', '3'], ['𑁪', '4'], ['𑁫', '5'], ['𑁬', '6'], ['𑁭', '7'], ['𑁮', '8'], ['𑁯', '9'], ['𑃰', '0'], ['𑃱', '1'], ['𑃲', '2'], ['𑃳', '3'], ['𑃴', '4'], ['𑃵', '5'], ['𑃶', '6'], ['𑃷', '7'], ['𑃸', '8'], ['𑃹', '9'], ['𑄶', '0'], ['𑄷', '1'], ['𑄸', '2'], ['𑄹', '3'], ['𑄺', '4'], ['𑄻', '5'], ['𑄼', '6'], ['𑄽', '7'], ['𑄾', '8'], ['𑄿', '9'], ['𑇐', '0'], ['𑇑', '1'], ['𑇒', '2'], ['𑇓', '3'], ['𑇔', '4'], ['𑇕', '5'], ['𑇖', '6'], ['𑇗', '7'], ['𑇘', '8'], ['𑇙', '9'], ['𑋰', '0'], ['𑋱', '1'], ['𑋲', '2'], ['𑋳', '3'], ['𑋴', '4'], ['𑋵', '5'], ['𑋶', '6'], ['𑋷', '7'], ['𑋸', '8'], ['𑋹', '9'], ['𑑐', '0'], ['𑑑', '1'], ['𑑒', '2'], ['𑑓', '3'], ['𑑔', '4'], ['𑑕', '5'], ['𑑖', '6'], ['𑑗', '7'], ['𑑘', '8'], ['𑑙', '9'], ['𑓐', '0'], ['𑓑', '1'], ['𑓒', '2'], ['𑓓', '3'], ['𑓔', '4'], ['𑓕', '5'], ['𑓖', '6'], ['𑓗', '7'], ['𑓘', '8'], ['𑓙', '9'], ['𑙐', '0'], ['𑙑', '1'], ['𑙒', '2'], ['𑙓', '3'], ['𑙔', '4'], ['𑙕', '5'], ['𑙖', '6'], ['𑙗', '7'], ['𑙘', '8'], ['𑙙', '9'], ['𑛀', '0'], ['𑛁', '1'], ['𑛂', '2'], ['𑛃', '3'], ['𑛄', '4'], ['𑛅', '5'], ['𑛆', '6'], ['𑛇', '7'], ['𑛈', '8'], ['𑛉', '9'], ['𑛐', '0'], ['𑛑', '1'], ['𑛒', '2'], ['𑛓', '3'], ['𑛔', '4'], ['𑛕', '5'], ['𑛖', '6'], ['𑛗', '7'], ['𑛘', '8'], ['𑛙', '9'], ['𑛚', '0'], ['𑛛', '1'], ['𑛜', '2'], ['𑛝', '3'], ['𑛞', '4'], ['𑛟', '5'], ['𑛠', '6'], ['𑛡', '7'], ['𑛢', '8'], ['𑛣', '9'], ['𑜰', '0'], ['𑜱', '1'], ['𑜲', '2'], ['𑜳', '3'], ['𑜴', '4'], ['𑜵', '5'], ['𑜶', '6'], ['𑜷', '7'], ['𑜸', '8'], ['𑜹', '9'], ['𑣠', '0'], ['𑣡', '1'], ['𑣢', '2'], ['𑣣', '3'], ['𑣤', '4'], ['𑣥', '5'], ['𑣦', '6'], ['𑣧', '7'], ['𑣨', '8'], ['𑣩', '9'], ['𑥐', '0'], ['𑥑', '1'], ['𑥒', '2'], ['𑥓', '3'], ['𑥔', '4'], ['𑥕', '5'], ['𑥖', '6'], ['𑥗', '7'], ['𑥘', '8'], ['𑥙', '9'], ['𑯰', '0'], ['𑯱', '1'], ['𑯲', '2'], ['𑯳', '3'], ['𑯴', '4'], ['𑯵', '5'], ['𑯶', '6'], ['𑯷', '7'], ['𑯸', '8'], ['𑯹', '9'], ['𑱐', '0'], ['𑱑', '1'], ['𑱒', '2'], ['𑱓', '3'], ['𑱔', '4'], ['𑱕', '5'], ['𑱖', '6'], ['𑱗', '7'], ['𑱘', '8'], ['𑱙', '9'], ['𑵐', '0'], ['𑵑', '1'], ['𑵒', '2'], ['𑵓', '3'], ['𑵔', '4'], ['𑵕', '5'], ['𑵖', '6'], ['𑵗', '7'], ['𑵘', '8'], ['𑵙', '9'], ['𑶠', '0'], ['𑶡', '1'], ['𑶢', '2'], ['𑶣', '3'], ['𑶤', '4'], ['𑶥', '5'], ['𑶦', '6'], ['𑶧', '7'], ['𑶨', '8'], ['𑶩', '9'], ['𑽐', '0'], ['𑽑', '1'], ['𑽒', '2'], ['𑽓', '3'], ['𑽔', '4'], ['𑽕', '5'], ['𑽖', '6'], ['𑽗', '7'], ['𑽘', '8'], ['𑽙', '9'], ['𖄰', '0'], ['𖄱', '1'], ['𖄲', '2'], ['𖄳', '3'], ['𖄴', '4'], ['𖄵', '5'], ['𖄶', '6'], ['𖄷', '7'], ['𖄸', '8'], ['𖄹', '9'], ['𖩠', '0'], ['𖩡', '1'], ['𖩢', '2'], ['𖩣', '3'], ['𖩤', '4'], ['𖩥', '5'], ['𖩦', '6'], ['𖩧', '7'], ['𖩨', '8'], ['𖩩', '9'], ['𖫀', '0'], ['𖫁', '1'], ['𖫂', '2'], ['𖫃', '3'], ['𖫄', '4'], ['𖫅', '5'], ['𖫆', '6'], ['𖫇', '7'], ['𖫈', '8'], ['𖫉', '9'], ['𖭐', '0'], ['𖭑', '1'], ['𖭒', '2'], ['𖭓', '3'], ['𖭔', '4'], ['𖭕', '5'], ['𖭖', '6'], ['𖭗', '7'], ['𖭘', '8'], ['𖭙', '9'], ['𖵰', '0'], ['𖵱', '1'], ['𖵲', '2'], ['𖵳', '3'], ['𖵴', '4'], ['𖵵', '5'], ['𖵶', '6'], ['𖵷', '7'], ['𖵸', '8'], ['𖵹', '9'], ['𜳰', '0'], ['𜳱', '1'], ['𜳲', '2'], ['𜳳', '3'], ['𜳴', '4'], ['𜳵', '5'], ['𜳶', '6'], ['𜳷', '7'], ['𜳸', '8'], ['𜳹', '9'], ['𝟎', '0'], ['𝟏', '1'], ['𝟐', '2'], ['𝟑', '3'], ['𝟒', '4'], ['𝟓', '5'], ['𝟔', '6'], ['𝟕', '7'], ['𝟖', '8'], ['𝟗', '9'], ['𝟘', '0'], ['𝟙', '1'], ['𝟚', '2'], ['𝟛', '3'], ['𝟜', '4'], ['𝟝', '5'], ['𝟞', '6'], ['𝟟', '7'], ['𝟠', '8'], ['𝟡', '9'], ['𝟢', '0'], ['𝟣', '1'], ['𝟤', '2'], ['𝟥', '3'], ['𝟦', '4'], ['𝟧', '5'], ['𝟨', '6'], ['𝟩', '7'], ['𝟪', '8'], ['𝟫', '9'], ['𝟬', '0'], ['𝟭', '1'], ['𝟮', '2'], ['𝟯', '3'], ['𝟰', '4'], ['𝟱', '5'], ['𝟲', '6'], ['𝟳', '7'], ['𝟴', '8'], ['𝟵', '9'], ['𝟶', '0'], ['𝟷', '1'], ['𝟸', '2'], ['𝟹', '3'], ['𝟺', '4'], ['𝟻', '5'], ['𝟼', '6'], ['𝟽', '7'], ['𝟾', '8'], ['𝟿', '9'], ['𞅀', '0'], ['𞅁', '1'], ['𞅂', '2'], ['𞅃', '3'], ['𞅄', '4'], ['𞅅', '5'], ['𞅆', '6'], ['𞅇', '7'], ['𞅈', '8'], ['𞅉', '9'], ['𞋰', '0'], ['𞋱', '1'], ['𞋲', '2'], ['𞋳', '3'], ['𞋴', '4'], ['𞋵', '5'], ['𞋶', '6'], ['𞋷', '7'], ['𞋸', '8'], ['𞋹', '9'], ['𞓰', '0'], ['𞓱', '1'], ['𞓲', '2'], ['𞓳', '3'], ['𞓴', '4'], ['𞓵', '5'], ['𞓶', '6'], ['𞓷', '7'], ['𞓸', '8'], ['𞓹', '9'], ['𞗱', '0'], ['𞗲', '1'], ['𞗳', '2'], ['𞗴', '3'], ['𞗵', '4'], ['𞗶', '5'], ['𞗷', '6'], ['𞗸', '7'], ['𞗹', '8'], ['𞗺', '9'], ['𞥐', '0'], ['𞥑', '1'], ['𞥒', '2'], ['𞥓', '3'], ['𞥔', '4'], ['𞥕', '5'], ['𞥖', '6'], ['𞥗', '7'], ['𞥘', '8'], ['𞥙', '9'], ['🯰', '0'], ['🯱', '1'], ['🯲', '2'], ['🯳', '3'], ['🯴', '4'], ['🯵', '5'], ['🯶', '6'], ['🯷', '7'], ['🯸', '8'], ['🯹', '9'],
];
// unicode-digit-translit:end

/** JS mirror of the Dart `_asciiDigits`: maps every native digit listed in
 * TRANSLIT_PAIRS onto its ASCII value, leaving all else untouched. */
function transliterate(term) {
  const map = new Map(TRANSLIT_PAIRS);
  let out = '';
  for (const ch of term) {
    out += map.get(ch) ?? ch;
  }
  return out;
}

/** `customerSearchPattern` — the `%…%` substring pattern. */
function customerSearchPattern(term) {
  return `%${likeEscape(term)}%`;
}

/**
 * `customerPhoneDigitPattern` — the digit-only pattern for a phone-SHAPED term,
 * or null when the term is not one. Mirrors the Dart `RegExp`s: only `[0-9]`
 * plus the phone separators `+ - . ( ) /` and space, with at least one digit.
 *
 * The term is transliterated FIRST, exactly as the Dart client does — see
 * `_asciiDigits` and the TRANSLIT_PAIRS table below, which is generated from
 * the same Unicode enumeration as the migration's `translate` tables. A mirror
 * that skips this routes native terms down the literal `phone` path and
 * green-checks a filter the real client never builds.
 */
function customerPhoneDigitPattern(term) {
  const ascii = transliterate(term);
  const digits = ascii.replaceAll(/[^0-9]/g, '');
  if (digits.length === 0) return null;
  if (ascii.replaceAll(/[0-9+\-.()/ ]/g, '').length > 0) return null;
  return `%${digits}%`;
}

/** The or-tree quoting: a typed `,` must not split the condition. */
function literalInOrTree(pattern) {
  return `"${pattern.replaceAll('"', '\\"')}"`;
}

/**
 * `customerSearchFilter` — name OR phone, escaped for LIKE and then quoted for
 * the `or` tree so a typed `,` cannot split the condition.
 *
 * The phone half is chosen by TERM SHAPE: a phone-shaped term searches the
 * normalised `phone_digits` column (migration 065), anything else searches
 * `phone` literally. Alternatives, not cumulative — for a digit-only term,
 * `phone_digits` already subsumes `phone`.
 */
function customerSearchFilter(term) {
  const digitPattern = customerPhoneDigitPattern(term);
  const phoneClause = digitPattern === null
    ? `phone.ilike.${literalInOrTree(customerSearchPattern(term))}`
    : `phone_digits.ilike.${literalInOrTree(digitPattern)}`;
  const nameClause = `full_name.ilike.${literalInOrTree(customerSearchPattern(term))}`;
  return `${nameClause},${phoneClause}`;
}

/**
 * The PRE-065 filter shape: always `phone`, always the raw term. Kept so the
 * probe can run it as a negative control and show that the old query genuinely
 * could not reach a separator-laden number.
 */
function legacySearchFilter(term) {
  const quoted = literalInOrTree(customerSearchPattern(term));
  return `full_name.ilike.${quoted},phone.ilike.${quoted}`;
}

/** `customerKeysetFilter` — the rows the previous page did not reach. */
function customerKeysetFilter(createdAt, id) {
  return `created_at.lt.${createdAt},and(created_at.eq.${createdAt},id.lt.${id})`;
}

/**
 * The parentheses `PostgrestFilterBuilder.or` puts around its argument on the
 * wire (`appendSearchParams(key, '($filters)')` in postgrest-dart 2.9.1).
 *
 * Not cosmetic: without them PostgREST does not parse a tree at all — it
 * answers `42703 column profiles.orcreated_at does not exist`. The Dart unit
 * tests pin the filter STRING (correctly, since that is what the repository
 * builds); the wrapping is the client's, so it has to be mirrored here.
 */
function orTree(filters) {
  return `(${filters})`;
}

/**
 * `DateTime.parse(row['created_at']).toUtc().toIso8601String()`.
 *
 * PostgREST returns UTC with a `+00:00` offset; Dart normalises to `Z` and
 * always emits at least milliseconds (microseconds only when non-zero). This
 * reproduces that exactly rather than round-tripping through `new Date()`,
 * which would TRUNCATE to milliseconds and silently change the cursor. The
 * fidelity test below (`cursor timestamps are not lossy`) is what keeps this
 * honest: if the transform ever dropped precision, the `created_at=eq.` probe
 * would match fewer rows than the tie group holds.
 */
function dartIso(serverTs) {
  const m = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d+))?(Z|\+00:00)$/.exec(
    serverTs,
  );
  if (!m) {
    throw new Error(
      `bookmark timestamp is not in the expected UTC shape: ${serverTs}`,
    );
  }
  const [, base, frac = ''] = m;
  const padded = frac.length >= 3 ? frac : (frac + '000').slice(0, 3);
  return `${base}.${padded}Z`;
}

// ── HTTP ────────────────────────────────────────────────────────────────────

let BASE = LOCAL_BASE;
let API_KEY = null;

/**
 * One PostgREST request. `params` values may be arrays, because the walk sends
 * TWO `or` parameters (search, then cursor) and their conjunction is one of the
 * things under test. `URLSearchParams` percent-encodes, as the Dart client's Uri
 * does; PostgREST decodes before parsing the tree either way.
 */
async function rest(path, params = {}, { count = false } = {}) {
  // `path` is written with a leading slash at every call site, but a leading
  // slash makes URL() resolve against the host root and drop BASE's /rest/v1
  // (which is why staging readiness once 404'd). Strip it and anchor BASE.
  const url = new URL(String(path).replace(/^\/+/, ''), BASE + '/');
  for (const [key, value] of Object.entries(params)) {
    for (const single of Array.isArray(value) ? value : [value]) {
      url.searchParams.append(key, single);
    }
  }
  const headers = {};
  if (API_KEY) {
    headers.apikey = API_KEY;
    headers.Authorization = `Bearer ${API_KEY}`;
  }
  if (count) headers.Prefer = 'count=exact';

  const res = await fetch(url, { headers });
  let body = null;
  try {
    body = await res.json();
  } catch {
    // PostgREST error pages are JSON, but a proxy/container error may not be.
  }
  return {
    status: res.status,
    ok: res.ok,
    rows: Array.isArray(body) ? body : null,
    body,
    count: Number(
      (res.headers.get('content-range') ?? '').split('/')[1] ?? NaN,
    ),
  };
}

// ── ASSERTIONS ──────────────────────────────────────────────────────────────

const failures = [];
let checks = 0;

function check(name, condition, detail = '') {
  checks += 1;
  if (condition) {
    console.log(`  ✅ ${name}`);
  } else {
    failures.push(name);
    console.log(`  ❌ ${name}${detail ? `\n       ${detail}` : ''}`);
  }
}

function section(title) {
  console.log(`\n${title}`);
}

function reportAndExit() {
  console.log('\n═══════════════════════════════════════════════════════');
  console.log(`  ${checks - failures.length}/${checks} checks passed`);
  if (failures.length) {
    console.log('  FAILED:');
    for (const name of failures) console.log(`    • ${name}`);
  }
  console.log('═══════════════════════════════════════════════════════');
  process.exit(failures.length ? 1 : 0);
}

// ── THE SUBJECT UNDER TEST ──────────────────────────────────────────────────

/**
 * The separator-laden fixture rows, with the digits each must normalise to.
 * Digit runs are mutually non-overlapping and absent from every other fixture
 * number, so a match can only come from the row named here.
 */
const SEPARATED_PHONES = [
  {
    id: '00000000-0000-0000-0000-000000000301',
    stored: '+966 50 123 4567',
    digits: '966501234567',
  },
  {
    id: '00000000-0000-0000-0000-000000000302',
    stored: '050-123-4567',
    digits: '0501234567',
  },
  {
    id: '00000000-0000-0000-0000-000000000303',
    stored: '(015) 111-2222',
    digits: '0151112222',
  },
];

/**
 * Rows whose STORED number is in a non-ASCII digit system — one per Unicode Nd
 * block, GENERATED by supabase/tests/gen_phone_digit_ranges.py. Before the
 * migration transliterated, the ASCII-only `[^0-9]` strip DELETED every digit
 * instead of keeping it, so `phone_digits` came out EMPTY and the row was
 * unreachable by ANY digit search — including an ASCII one typed by an admin
 * who knows nothing about the encoding.
 *
 * The stored value is <native 0><native 9><two ASCII digits encoding the row
 * index>. The ASCII tail keeps the rows from matching each OTHER: a fixed
 * '0909' everywhere would make one search match all 75 rows and the
 * exact-one-match assertions would be false.
 */
// unicode-digit-blocks:generated — do not edit by hand
const DIGIT_BLOCKS = [
  { id: '00000000-0000-0000-0000-000000000401', base: '0x0660', block: 'Digits U+0660', stored: '٠٩00', digits: '0900' },
  { id: '00000000-0000-0000-0000-000000000402', base: '0x06F0', block: 'Digits U+06F0', stored: '۰۹01', digits: '0901' },
  { id: '00000000-0000-0000-0000-000000000403', base: '0x07C0', block: 'Digits U+07C0', stored: '߀߉02', digits: '0902' },
  { id: '00000000-0000-0000-0000-000000000404', base: '0x0966', block: 'Digits U+0966', stored: '०९03', digits: '0903' },
  { id: '00000000-0000-0000-0000-000000000405', base: '0x09E6', block: 'Digits U+09E6', stored: '০৯04', digits: '0904' },
  { id: '00000000-0000-0000-0000-000000000406', base: '0x0A66', block: 'Digits U+0A66', stored: '੦੯05', digits: '0905' },
  { id: '00000000-0000-0000-0000-000000000407', base: '0x0AE6', block: 'Digits U+0AE6', stored: '૦૯06', digits: '0906' },
  { id: '00000000-0000-0000-0000-000000000408', base: '0x0B66', block: 'Digits U+0B66', stored: '୦୯07', digits: '0907' },
  { id: '00000000-0000-0000-0000-000000000409', base: '0x0BE6', block: 'Digits U+0BE6', stored: '௦௯08', digits: '0908' },
  { id: '00000000-0000-0000-0000-000000000410', base: '0x0C66', block: 'Digits U+0C66', stored: '౦౯09', digits: '0909' },
  { id: '00000000-0000-0000-0000-000000000411', base: '0x0CE6', block: 'Digits U+0CE6', stored: '೦೯10', digits: '0910' },
  { id: '00000000-0000-0000-0000-000000000412', base: '0x0D66', block: 'Digits U+0D66', stored: '൦൯11', digits: '0911' },
  { id: '00000000-0000-0000-0000-000000000413', base: '0x0DE6', block: 'Digits U+0DE6', stored: '෦෯12', digits: '0912' },
  { id: '00000000-0000-0000-0000-000000000414', base: '0x0E50', block: 'Digits U+0E50', stored: '๐๙13', digits: '0913' },
  { id: '00000000-0000-0000-0000-000000000415', base: '0x0ED0', block: 'Digits U+0ED0', stored: '໐໙14', digits: '0914' },
  { id: '00000000-0000-0000-0000-000000000416', base: '0x0F20', block: 'Digits U+0F20', stored: '༠༩15', digits: '0915' },
  { id: '00000000-0000-0000-0000-000000000417', base: '0x1040', block: 'Digits U+1040', stored: '၀၉16', digits: '0916' },
  { id: '00000000-0000-0000-0000-000000000418', base: '0x1090', block: 'Digits U+1090', stored: '႐႙17', digits: '0917' },
  { id: '00000000-0000-0000-0000-000000000419', base: '0x17E0', block: 'Digits U+17E0', stored: '០៩18', digits: '0918' },
  { id: '00000000-0000-0000-0000-000000000420', base: '0x1810', block: 'Digits U+1810', stored: '᠐᠙19', digits: '0919' },
  { id: '00000000-0000-0000-0000-000000000421', base: '0x1946', block: 'Digits U+1946', stored: '᥆᥏20', digits: '0920' },
  { id: '00000000-0000-0000-0000-000000000422', base: '0x19D0', block: 'Digits U+19D0', stored: '᧐᧙21', digits: '0921' },
  { id: '00000000-0000-0000-0000-000000000423', base: '0x1A80', block: 'Digits U+1A80', stored: '᪀᪉22', digits: '0922' },
  { id: '00000000-0000-0000-0000-000000000424', base: '0x1A90', block: 'Digits U+1A90', stored: '᪐᪙23', digits: '0923' },
  { id: '00000000-0000-0000-0000-000000000425', base: '0x1B50', block: 'Digits U+1B50', stored: '᭐᭙24', digits: '0924' },
  { id: '00000000-0000-0000-0000-000000000426', base: '0x1BB0', block: 'Digits U+1BB0', stored: '᮰᮹25', digits: '0925' },
  { id: '00000000-0000-0000-0000-000000000427', base: '0x1C40', block: 'Digits U+1C40', stored: '᱀᱉26', digits: '0926' },
  { id: '00000000-0000-0000-0000-000000000428', base: '0x1C50', block: 'Digits U+1C50', stored: '᱐᱙27', digits: '0927' },
  { id: '00000000-0000-0000-0000-000000000429', base: '0xA620', block: 'Digits U+A620', stored: '꘠꘩28', digits: '0928' },
  { id: '00000000-0000-0000-0000-000000000430', base: '0xA8D0', block: 'Digits U+A8D0', stored: '꣐꣙29', digits: '0929' },
  { id: '00000000-0000-0000-0000-000000000431', base: '0xA900', block: 'Digits U+A900', stored: '꤀꤉30', digits: '0930' },
  { id: '00000000-0000-0000-0000-000000000432', base: '0xA9D0', block: 'Digits U+A9D0', stored: '꧐꧙31', digits: '0931' },
  { id: '00000000-0000-0000-0000-000000000433', base: '0xA9F0', block: 'Digits U+A9F0', stored: '꧰꧹32', digits: '0932' },
  { id: '00000000-0000-0000-0000-000000000434', base: '0xAA50', block: 'Digits U+AA50', stored: '꩐꩙33', digits: '0933' },
  { id: '00000000-0000-0000-0000-000000000435', base: '0xABF0', block: 'Digits U+ABF0', stored: '꯰꯹34', digits: '0934' },
  { id: '00000000-0000-0000-0000-000000000436', base: '0xFF10', block: 'Digits U+FF10', stored: '０９35', digits: '0935' },
  { id: '00000000-0000-0000-0000-000000000437', base: '0x104A0', block: 'Digits U+104A0', stored: '𐒠𐒩36', digits: '0936' },
  { id: '00000000-0000-0000-0000-000000000438', base: '0x10D30', block: 'Digits U+10D30', stored: '𐴰𐴹37', digits: '0937' },
  { id: '00000000-0000-0000-0000-000000000439', base: '0x10D40', block: 'Digits U+10D40', stored: '𐵀𐵉38', digits: '0938' },
  { id: '00000000-0000-0000-0000-000000000440', base: '0x11066', block: 'Digits U+11066', stored: '𑁦𑁯39', digits: '0939' },
  { id: '00000000-0000-0000-0000-000000000441', base: '0x110F0', block: 'Digits U+110F0', stored: '𑃰𑃹40', digits: '0940' },
  { id: '00000000-0000-0000-0000-000000000442', base: '0x11136', block: 'Digits U+11136', stored: '𑄶𑄿41', digits: '0941' },
  { id: '00000000-0000-0000-0000-000000000443', base: '0x111D0', block: 'Digits U+111D0', stored: '𑇐𑇙42', digits: '0942' },
  { id: '00000000-0000-0000-0000-000000000444', base: '0x112F0', block: 'Digits U+112F0', stored: '𑋰𑋹43', digits: '0943' },
  { id: '00000000-0000-0000-0000-000000000445', base: '0x11450', block: 'Digits U+11450', stored: '𑑐𑑙44', digits: '0944' },
  { id: '00000000-0000-0000-0000-000000000446', base: '0x114D0', block: 'Digits U+114D0', stored: '𑓐𑓙45', digits: '0945' },
  { id: '00000000-0000-0000-0000-000000000447', base: '0x11650', block: 'Digits U+11650', stored: '𑙐𑙙46', digits: '0946' },
  { id: '00000000-0000-0000-0000-000000000448', base: '0x116C0', block: 'Digits U+116C0', stored: '𑛀𑛉47', digits: '0947' },
  { id: '00000000-0000-0000-0000-000000000449', base: '0x116D0', block: 'Digits U+116D0', stored: '𑛐𑛙48', digits: '0948' },
  { id: '00000000-0000-0000-0000-000000000450', base: '0x116DA', block: 'Digits U+116DA', stored: '𑛚𑛣49', digits: '0949' },
  { id: '00000000-0000-0000-0000-000000000451', base: '0x11730', block: 'Digits U+11730', stored: '𑜰𑜹50', digits: '0950' },
  { id: '00000000-0000-0000-0000-000000000452', base: '0x118E0', block: 'Digits U+118E0', stored: '𑣠𑣩51', digits: '0951' },
  { id: '00000000-0000-0000-0000-000000000453', base: '0x11950', block: 'Digits U+11950', stored: '𑥐𑥙52', digits: '0952' },
  { id: '00000000-0000-0000-0000-000000000454', base: '0x11BF0', block: 'Digits U+11BF0', stored: '𑯰𑯹53', digits: '0953' },
  { id: '00000000-0000-0000-0000-000000000455', base: '0x11C50', block: 'Digits U+11C50', stored: '𑱐𑱙54', digits: '0954' },
  { id: '00000000-0000-0000-0000-000000000456', base: '0x11D50', block: 'Digits U+11D50', stored: '𑵐𑵙55', digits: '0955' },
  { id: '00000000-0000-0000-0000-000000000457', base: '0x11DA0', block: 'Digits U+11DA0', stored: '𑶠𑶩56', digits: '0956' },
  { id: '00000000-0000-0000-0000-000000000458', base: '0x11F50', block: 'Digits U+11F50', stored: '𑽐𑽙57', digits: '0957' },
  { id: '00000000-0000-0000-0000-000000000459', base: '0x16130', block: 'Digits U+16130', stored: '𖄰𖄹58', digits: '0958' },
  { id: '00000000-0000-0000-0000-000000000460', base: '0x16A60', block: 'Digits U+16A60', stored: '𖩠𖩩59', digits: '0959' },
  { id: '00000000-0000-0000-0000-000000000461', base: '0x16AC0', block: 'Digits U+16AC0', stored: '𖫀𖫉60', digits: '0960' },
  { id: '00000000-0000-0000-0000-000000000462', base: '0x16B50', block: 'Digits U+16B50', stored: '𖭐𖭙61', digits: '0961' },
  { id: '00000000-0000-0000-0000-000000000463', base: '0x16D70', block: 'Digits U+16D70', stored: '𖵰𖵹62', digits: '0962' },
  { id: '00000000-0000-0000-0000-000000000464', base: '0x1CCF0', block: 'Digits U+1CCF0', stored: '𜳰𜳹63', digits: '0963' },
  { id: '00000000-0000-0000-0000-000000000465', base: '0x1D7CE', block: 'Digits U+1D7CE', stored: '𝟎𝟗64', digits: '0964' },
  { id: '00000000-0000-0000-0000-000000000466', base: '0x1D7D8', block: 'Digits U+1D7D8', stored: '𝟘𝟡65', digits: '0965' },
  { id: '00000000-0000-0000-0000-000000000467', base: '0x1D7E2', block: 'Digits U+1D7E2', stored: '𝟢𝟫66', digits: '0966' },
  { id: '00000000-0000-0000-0000-000000000468', base: '0x1D7EC', block: 'Digits U+1D7EC', stored: '𝟬𝟵67', digits: '0967' },
  { id: '00000000-0000-0000-0000-000000000469', base: '0x1D7F6', block: 'Digits U+1D7F6', stored: '𝟶𝟿68', digits: '0968' },
  { id: '00000000-0000-0000-0000-000000000470', base: '0x1E140', block: 'Digits U+1E140', stored: '𞅀𞅉69', digits: '0969' },
  { id: '00000000-0000-0000-0000-000000000471', base: '0x1E2F0', block: 'Digits U+1E2F0', stored: '𞋰𞋹70', digits: '0970' },
  { id: '00000000-0000-0000-0000-000000000472', base: '0x1E4F0', block: 'Digits U+1E4F0', stored: '𞓰𞓹71', digits: '0971' },
  { id: '00000000-0000-0000-0000-000000000473', base: '0x1E5F1', block: 'Digits U+1E5F1', stored: '𞗱𞗺72', digits: '0972' },
  { id: '00000000-0000-0000-0000-000000000474', base: '0x1E950', block: 'Digits U+1E950', stored: '𞥐𞥙73', digits: '0973' },
  { id: '00000000-0000-0000-0000-000000000475', base: '0x1FBF0', block: 'Digits U+1FBF0', stored: '🯰🯹74', digits: '0974' }
];
// unicode-digit-blocks:end

/**
 * Phone normalisation (migration 065).
 *
 * Three claims, and the middle one is what makes the others worth anything:
 *   1. Postgres really does compute `phone_digits` from `phone` — read back
 *      from the server, never recomputed in JS, or this would only be testing
 *      the probe's own arithmetic.
 *   2. The pre-065 filter shape cannot reach a separator-laden row. Without
 *      this, a passing (3) could just mean the fixture was matchable all along.
 *   3. The new filter does reach it — by its digits, and by a term the admin
 *      typed with the separators still in it.
 */
async function phoneNormalisationChecks() {
  for (const { id, stored, digits } of SEPARATED_PHONES) {
    const row = await rest('/profiles', {
      select: 'phone,phone_digits',
      id: `eq.${id}`,
    });
    const computed =
      row.ok && row.rows.length === 1 ? row.rows[0].phone_digits : null;
    check(
      `Postgres computes phone_digits for "${stored}" → ${digits}`,
      computed === digits,
      `server said ${JSON.stringify(computed)} (HTTP ${row.status})`,
    );

    // NEGATIVE CONTROL — the old query. Keyed on THIS row rather than on a
    // global zero: a digit run may legitimately appear inside another fixture
    // number, and a count assertion would then fail for the wrong reason.
    const legacy = await searchForFilter(legacySearchFilter(digits));
    check(
      `pre-065 filter cannot reach "${stored}" by its digits`,
      legacy.ok && !legacy.rows.some((r) => r.id === id),
      `the old query already matched it — the fixture does not exercise the ` +
        `defect and this proof would be hollow`,
    );
    console.log(
      `  ℹ️  pre-065 filter for ${digits} matched ` +
        `${legacy.rows?.length ?? '?'} row(s), none of them the target`,
    );

    const normalised = await searchFor(digits);
    check(
      `digit-only search "${digits}" reaches "${stored}" and nothing else`,
      normalised.ok &&
        normalised.rows.length === 1 &&
        normalised.rows[0].id === id,
      `HTTP ${normalised.status}, matched ${normalised.rows?.length ?? 0}`,
    );
  }

  // Normalising only the column would leave the admin's OWN punctuation
  // unhandled, so the term is normalised too. Same target row as entry 1.
  const typedWithSeparators = await searchFor('+966 50 123 4567');
  check(
    'a term typed WITH separators normalises to the same digits',
    typedWithSeparators.ok &&
      typedWithSeparators.rows.length === 1 &&
      typedWithSeparators.rows[0].id === SEPARATED_PHONES[0].id,
    `HTTP ${typedWithSeparators.status}, matched ` +
      `${typedWithSeparators.rows?.length ?? 0}`,
  );

  // The digit branch must not match everything — otherwise the checks above
  // would pass for a query that simply returns the whole directory.
  const absent = await searchFor('77777777777');
  check(
    'a digit run present in no stored number matches nothing',
    absent.ok && absent.rows.length === 0,
    `unexpectedly matched ${absent.rows?.length ?? '?'} row(s)`,
  );

  // ── Native digits of every script ─────────────────────────────────────────
  // One row per Unicode Nd block, each checked from BOTH directions: an admin
  // typing ASCII digits finds a native-stored number, and an admin typing
  // native digits finds the same row. Neither works without transliteration on
  // the side being typed.
  for (const { id, block, stored, digits } of DIGIT_BLOCKS) {
    const row = await rest('/profiles', {
      select: 'phone,phone_digits',
      id: `eq.${id}`,
    });
    const computed =
      row.ok && row.rows.length === 1 ? row.rows[0].phone_digits : null;
    check(
      `Postgres transliterates ${block} "${stored}" → ${digits}`,
      computed === digits,
      `server said ${JSON.stringify(computed)} — an empty value here is the ` +
        `pre-transliteration bug, where the strip deleted the digits outright`,
    );

    // An ASCII-digit term must reach the native-stored row. This is the half
    // that made the row invisible to EVERYONE, not just to admins typing that
    // script.
    const byAscii = await searchFor(digits);
    check(
      `an ASCII digit term reaches the ${block} row`,
      byAscii.ok && byAscii.rows.length === 1 && byAscii.rows[0].id === id,
      `HTTP ${byAscii.status}, matched ${byAscii.rows?.length ?? 0}`,
    );

    // And a term typed in the SAME native digits must reach it too — the
    // direction the shape gate would otherwise reject as "not digit-shaped".
    const byNative = await searchFor(stored);
    check(
      `a term typed in ${block} digits reaches its own row`,
      byNative.ok &&
        byNative.rows.length === 1 &&
        byNative.rows[0].id === id,
      `HTTP ${byNative.status}, matched ${byNative.rows?.length ?? 0} — if 0, ` +
        `the term was not transliterated or the shape gate rejected it`,
    );
  }

  // NEGATIVE CONTROL for the SHAPE GATE. 'Layla1' is not phone-shaped, so it
  // must stay a literal search. No name contains it, while Layla's stored phone
  // '01098765432' does contain a '1': if the gate were loosened to "contains a
  // digit", the term would reduce to '%1%', match her here, and in production
  // match roughly the whole directory.
  const mixed = await searchFor('Layla1');
  check(
    'a mixed alphanumeric term is not reinterpreted as a digit search',
    mixed.ok && mixed.rows.length === 0,
    `matched ${mixed.rows?.length ?? '?'} row(s) — the shape gate leaked ` +
      `digits out of a literal term`,
  );
}

/**
 * Walks the directory exactly as the Dart repository does: ask for one row past
 * the page, read `hasMore` off the data, bookmark the last row actually
 * returned, resume with the cursor tree. Returns the ids in walk order.
 */
async function walk({ pageSize, search = null, degradeCursor = false }) {
  const ids = [];
  let cursor = null;

  for (let page = 0; ; page += 1) {
    if (page > 200) throw new Error('walk did not terminate');

    const params = {
      select: SELECT_COLUMNS,
      order: ORDER,
      limit: String(pageSize + 1),
    };
    if (search !== null) params.or = [orTree(customerSearchFilter(search))];
    if (cursor) {
      // `degradeCursor` is the negative control: the same walk with the
      // tie-breaking `id` clause removed, i.e. the naive
      // `created_at < last_seen` cursor. It must behave DIFFERENTLY, or this
      // fixture does not actually exercise duplicate sort keys.
      const filter = degradeCursor
        ? `created_at.lt.${cursor.createdAt}`
        : customerKeysetFilter(cursor.createdAt, cursor.id);
      params.or = [...(params.or ?? []), orTree(filter)];
    }

    const res = await rest('/profiles', params);
    if (!res.ok) {
      throw new Error(
        `cursor request rejected by PostgREST: HTTP ${res.status} ` +
          `${JSON.stringify(res.body)}`,
      );
    }

    const rows = (res.rows ?? []).filter(
      (row) => typeof row.id === 'string' && row.id.length > 0,
    );
    const hasMore = rows.length > pageSize;
    const pageRows = hasMore ? rows.slice(0, pageSize) : rows;
    ids.push(...pageRows.map((row) => row.id));

    if (!hasMore) break;
    const last = pageRows[pageRows.length - 1];
    cursor = { createdAt: dartIso(last.created_at), id: last.id };
  }

  return ids;
}

/** Every id the filter matches, in one over-sized read — the walk's oracle. */
async function readAllIds(search = null) {
  const params = { select: SELECT_COLUMNS, order: ORDER, limit: '5000' };
  if (search !== null) params.or = [orTree(customerSearchFilter(search))];
  const res = await rest('/profiles', params);
  if (!res.ok) {
    throw new Error(`baseline read rejected: HTTP ${res.status}`);
  }
  return res.rows.map((row) => row.id);
}

function duplicates(ids) {
  const seen = new Set();
  const dupes = new Set();
  for (const id of ids) {
    if (seen.has(id)) dupes.add(id);
    seen.add(id);
  }
  return [...dupes];
}

// ── THE PROOF ───────────────────────────────────────────────────────────────

async function main() {
  const argv = process.argv.slice(2);
  const mode = argv.includes('--mode')
    ? argv[argv.indexOf('--mode') + 1]
    : 'local';
  const pageSizeArg = argv.indexOf('--page-size');
  const requestedPageSize =
    pageSizeArg >= 0 ? Number(argv[pageSizeArg + 1]) : null;

  if (mode === 'local') {
    BASE = LOCAL_BASE;
  } else if (mode === 'staging') {
    const url = process.env.STAGING_SUPABASE_URL ?? '';
    API_KEY = process.env.STAGING_ANON_KEY ?? '';
    if (!url) {
      console.error('ABORT: STAGING_SUPABASE_URL is not set.');
      process.exit(1);
    }
    if (!url.includes(REQUIRED_STAGING_REF)) {
      console.error(
        `ABORT: URL does not reference the isolated staging project ` +
          `${REQUIRED_STAGING_REF}. Refusing to run.`,
      );
      process.exit(1);
    }
    if (!API_KEY) {
      console.error('ABORT: STAGING_ANON_KEY is not set.');
      process.exit(1);
    }
    BASE = url.replace(/\/+$/, '') + '/rest/v1';
  } else {
    console.error(`ABORT: unknown --mode ${mode}`);
    process.exit(1);
  }

  console.log('═══════════════════════════════════════════════════════');
  console.log(`  KEYSET PAGING PROOF — mode: ${mode}`);
  // Host only: the staging ingest URL is not a secret, but keys never print.
  console.log(`  target: ${new URL(BASE).host}`);
  console.log('═══════════════════════════════════════════════════════');

  section('Readiness');
  const ready = await rest('/profiles', { select: 'id', limit: '1' });
  check(
    'PostgREST answers a trivial read',
    ready.ok,
    `HTTP ${ready.status} ${JSON.stringify(ready.body)}`,
  );
  if (!ready.ok) {
    console.error('\nCannot continue: PostgREST is not answering.');
    process.exit(1);
  }

  const baseline = await readAllIds();
  // Derived from the generated block count rather than hand-updated, so the
  // generator adding a row cannot leave this assertion stale.
  const baselineRows = 120 + 4 + 3 + DIGIT_BLOCKS.length;
  if (mode === 'local') {
    check(
      `fixture is loaded (${baselineRows} rows: 120 walk + 4 search + 3 normalisation + ${DIGIT_BLOCKS.length} native-digit)`,
      baseline.length === baselineRows,
      `saw ${baseline.length}`,
    );
  }
  console.log(`  ℹ️  directory holds ${baseline.length} rows`);

  if (mode === 'staging' && baseline.length === 0) {
    // Anonymous staging reads see zero rows under RLS (fail-closed, correct).
    // The cursor/search acceptance checks above already passed; every section
    // below needs visible rows, so exiting here instead of aborting on
    // baseline[0]. For a non-vacuous walk, run with an authenticated admin JWT.
    console.log(
      '  ℹ️  no visible rows — skipping row-content sections',
    );
    reportAndExit();
  }

  section('Page walking — the `or` cursor tree must be accepted and exact');
  // Production page size (DEFAULT_CUSTOMERS_PAGE_SIZE = 50), so the boundaries
  // fall inside the fixture's 10-row tie groups.
  const productionWalk = await walk({ pageSize: 50 });
  check(
    'page size 50: cursor tree accepted and walk is complete',
    productionWalk.length === baseline.length,
    `walked ${productionWalk.length}, baseline ${baseline.length}`,
  );
  check(
    'page size 50: no row appears on two pages',
    duplicates(productionWalk).length === 0,
    `duplicated: ${duplicates(productionWalk).join(', ')}`,
  );
  check(
    'page size 50: no row is skipped (walk === baseline, in order)',
    JSON.stringify(productionWalk) === JSON.stringify(baseline),
  );

  // A small page size makes ties straddle boundaries far more often, which is
  // where a missing tie-breaker shows itself.
  const smallWalk = await walk({ pageSize: 7 });
  check(
    'page size 7: no row appears on two pages',
    duplicates(smallWalk).length === 0,
    `duplicated: ${duplicates(smallWalk).join(', ')}`,
  );
  check(
    'page size 7: no row is skipped (walk === baseline, in order)',
    JSON.stringify(smallWalk) === JSON.stringify(baseline),
  );

  section('Bookmark fidelity — the cursor timestamp must not be lossy');
  // If dartIso() (or Dart's own formatting) truncated microseconds, this `eq`
  // would match fewer rows than actually sit at that instant, and the walk
  // would skip the rest. The fixture puts 10 rows at each instant, so a lossy
  // bookmark shows up immediately as a smaller count.
  const bookmarkSource = await createdAtOf(baseline[0]);
  const tieGroup = await rest('/profiles', {
    select: 'id',
    created_at: `eq.${dartIso(bookmarkSource)}`,
  });
  check(
    'a bookmark instant matches its whole tie group (10 rows), not a subset',
    tieGroup.ok && tieGroup.rows?.length === 10,
    `HTTP ${tieGroup.status}, matched ${tieGroup.rows?.length ?? 0} ` +
      `(server said ${bookmarkSource}, client sends ${dartIso(bookmarkSource)})`,
  );

  section('Negative control — the tie-breaker must be doing real work');
  // With 10 rows per instant and a page size of 7, the first page can only
  // return 7 of them. The naive `created_at < TS` cursor then skips the
  // remaining 3 outright — they are neither returned nor reachable again. This
  // is deterministic, not a race, and it is the exact defect the tie-breaker
  // exists to prevent.
  const degraded = await walk({ pageSize: 7, degradeCursor: true });
  check(
    'dropping the tie-breaker visibly loses or repeats rows on real Postgres',
    JSON.stringify(degraded) !== JSON.stringify(baseline),
    'the degraded walk matched the baseline, so the fixture does not ' +
      'exercise duplicate sort keys and this proof would be hollow',
  );
  console.log(
    `  ℹ️  degraded walk returned ${degraded.length} of ${baseline.length} rows ` +
      `(${baseline.length - degraded.length} lost)`,
  );

  section('Search — name OR phone, with or-tree structure escaped');
  const layla = await searchFor('Layla');
  check(
    'search by NAME matches (full_name branch of the or tree)',
    layla.ok && layla.rows.length === 1,
    `HTTP ${layla.status}, matched ${layla.rows?.length ?? 0}`,
  );

  const byPhone = await searchFor('98765432');
  check(
    'search by PHONE matches — the same term reaches the phone column',
    byPhone.ok && byPhone.rows.length === 1,
    `HTTP ${byPhone.status}, matched ${byPhone.rows?.length ?? 0}`,
  );

  // Each of these terms contains a character PostgREST treats as STRUCTURE
  // inside an `or` tree. Matching the intended single row is the proof that the
  // client's quoting was honoured rather than the comma splitting the tree.
  for (const [term, note] of [
    ['Ali, Omar', 'comma'],
    ['Sara (Home)', 'parentheses'],
    ['Quote "Q"', 'embedded quote'],
  ]) {
    const res = await searchFor(term);
    check(
      `search containing a ${note} is accepted and matches literally`,
      res.ok && res.rows.length === 1,
      `HTTP ${res.status}, matched ${res.rows?.length ?? 0} ` +
        `${res.ok ? '' : JSON.stringify(res.body)}`,
    );
  }

  // NEGATIVE CONTROL. Same term, same escaping, but WITHOUT the quoting — the
  // pre-fix shape. This must NOT behave like the quoted form; if it did, the
  // quoting would be decorative and the tests above would prove nothing.
  const unquoted = await rest('/profiles', {
    select: 'id',
    or: orTree('full_name.ilike.%Ali, Omar%,phone.ilike.%Ali, Omar%'),
  });
  check(
    'negative control: the UNQUOTED comma form does not resolve to the same row',
    !(unquoted.ok && unquoted.rows?.length === 1),
    `unquoted form unexpectedly matched one row (HTTP ${unquoted.status})`,
  );
  console.log(
    `  ℹ️  unquoted comma form → HTTP ${unquoted.status}` +
      (unquoted.body?.message ? ` (${unquoted.body.message})` : ''),
  );

  section('Phone normalisation — a digit term must reach a separated number');
  await phoneNormalisationChecks();

  section('Search + paging together — two `or` params must conjoin');
  // 'Customer' matches the 120 walk rows. If the second `or` replaced the
  // first, this set would grow to 124; if the search were dropped mid-walk, the
  // walk would restart and duplicate rows.
  const searchBaseline = await readAllIds('Customer');
  const searchWalk = await walk({ pageSize: 7, search: 'Customer' });
  check(
    'a filtered walk returns exactly the filtered set (both trees applied)',
    JSON.stringify(searchWalk) === JSON.stringify(searchBaseline),
    `walked ${searchWalk.length}, filtered baseline ${searchBaseline.length}`,
  );
  check(
    'the search tree actually narrowed the results',
    searchBaseline.length < baseline.length,
    `filtered ${searchBaseline.length} of ${baseline.length}`,
  );
  check(
    'no duplicate rows across filtered pages',
    duplicates(searchWalk).length === 0,
    `duplicated: ${duplicates(searchWalk).join(', ')}`,
  );

  if (mode === 'local' && requestedPageSize !== null) {
    const custom = await walk({ pageSize: requestedPageSize });
    check(
      `page size ${requestedPageSize}: no duplicates and no skips`,
      duplicates(custom).length === 0 &&
        JSON.stringify(custom) === JSON.stringify(baseline),
      `walked ${custom.length}, baseline ${baseline.length}`,
    );
  }

  reportAndExit();
}

/** The single search request shape the repository sends. */
async function searchFor(term) {
  return searchForFilter(customerSearchFilter(term));
}

/** Same request, with the filter string supplied rather than derived. */
async function searchForFilter(filter) {
  return rest('/profiles', {
    select: SELECT_COLUMNS,
    order: ORDER,
    limit: '100',
    or: orTree(filter),
  });
}

/** Reads the `created_at` of [id] (used to build a bookmark for the fidelity check). */
async function createdAtOf(id) {
  const res = await rest('/profiles', { select: 'created_at', id: `eq.${id}` });
  if (!res.ok || res.rows.length !== 1) {
    throw new Error(`could not read created_at for ${id}`);
  }
  return res.rows[0].created_at;
}

main().catch((err) => {
  console.error(`\nABORTED: ${err.message}`);
  process.exit(1);
});
