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
//        full_name.ilike."%term%",phone.ilike."%term%"
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
 * `customerSearchFilter` — name OR phone, escaped for LIKE and then quoted for
 * the `or` tree so a typed `,` cannot split the condition.
 */
function customerSearchFilter(term) {
  const pattern = customerSearchPattern(term);
  const quoted = `"${pattern.replaceAll('"', '\\"')}"`;
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
      'fixture is loaded (124 rows: 120 walk + 4 search)',
      baseline.length === 124,
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
  return rest('/profiles', {
    select: SELECT_COLUMNS,
    order: ORDER,
    limit: '100',
    or: orTree(customerSearchFilter(term)),
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
