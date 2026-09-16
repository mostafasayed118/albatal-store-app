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
//      (or `phone.ilike` for a term that is not phone-shaped — migration 065)
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

/** `customerSearchPattern` — the `%…%` substring pattern. */
function customerSearchPattern(term) {
  return `%${likeEscape(term)}%`;
}

/**
 * `customerPhoneDigitPattern` — the digit-only pattern for a phone-SHAPED term,
 * or null when the term is not one. Mirrors the Dart `RegExp`s: only `[0-9]`
 * plus the phone separators `+ - . ( ) /` and space, with at least one digit.
 */
function customerPhoneDigitPattern(term) {
  const digits = term.replaceAll(/[^0-9]/g, '');
  if (digits.length === 0) return null;
  if (term.replaceAll(/[0-9+\-.()/ ]/g, '').length > 0) return null;
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
  const url = new URL(path, BASE);
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
  if (mode === 'local') {
    check(
      'fixture is loaded (127 rows: 120 walk + 4 search + 3 normalisation)',
      baseline.length === 127,
      `saw ${baseline.length}`,
    );
  }
  console.log(`  ℹ️  directory holds ${baseline.length} rows`);

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

  console.log('\n═══════════════════════════════════════════════════════');
  console.log(`  ${checks - failures.length}/${checks} checks passed`);
  if (failures.length) {
    console.log('  FAILED:');
    for (const name of failures) console.log(`    • ${name}`);
  }
  console.log('═══════════════════════════════════════════════════════');
  process.exit(failures.length ? 1 : 0);
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
