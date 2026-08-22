import { readFileSync, writeFileSync } from 'fs';

let sql = readFileSync('supabase/tests/test_rls_adversarial.sql', 'utf8');

// Strip psql meta-commands
sql = sql.replace(/^\\set\s+.+$/gm, '');
sql = sql.replace(/^\\echo\s+.+$/gm, '');

// Fix 'desc' reserved word
sql = sql.replace(/TEXT, desc TEXT,/g, 'TEXT, "desc" TEXT,');
sql = sql.replace(/VALUES \(test_id, desc,/, 'VALUES (test_id, "desc",');

// Fix helper functions to use SET ROLE
sql = sql.replace(/CREATE OR REPLACE FUNCTION _anon\(\)[\s\S]*?END; \$\$;?/, (match) => {
  return `CREATE OR REPLACE FUNCTION _anon() RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  SET ROLE anon;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claim.role', 'anon', true);
END; $$;`;
});

sql = sql.replace(/CREATE OR REPLACE FUNCTION _as\(p_uid TEXT\)[\s\S]*?END; \$\$;?/, (match) => {
  return `CREATE OR REPLACE FUNCTION _as(p_uid TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  SET ROLE authenticated;
  PERFORM set_config('request.jwt.claim.sub', p_uid, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
END; $$;`;
});

sql = sql.replace(/CREATE OR REPLACE FUNCTION _service\(\)[\s\S]*?END; \$\$;?/, (match) => {
  return `CREATE OR REPLACE FUNCTION _service() RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  SET ROLE service_role;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
END; $$;`;
});

// Make exception handlers more robust: catch both check_violation AND insufficient_privilege
sql = sql.replace(/EXCEPTION WHEN check_violation THEN/g, 'EXCEPTION WHEN check_violation OR insufficient_privilege THEN');

// Find key markers
const ddlEndIdx = sql.indexOf('PERFORM _service();');
const section1Marker = '-- SECTION 1: ANONYMOUS USER';
const section1Idx = sql.indexOf(section1Marker);
const summaryMarker = '-- SUMMARY';
const summaryIdx = sql.indexOf(summaryMarker);

// DDL
let ddl = sql.substring(0, ddlEndIdx).trimEnd();
ddl = ddl.replace('CREATE TEMP TABLE _rls_results (', 'CREATE TABLE IF NOT EXISTS _rls_results (');
const rlsCreateIdx = ddl.indexOf('CREATE TABLE IF NOT EXISTS _rls_results');
const rlsCreateEnd = ddl.indexOf(');', rlsCreateIdx);
if (rlsCreateEnd > 0) {
  ddl = ddl.substring(0, rlsCreateEnd + 2) + '\nALTER TABLE _rls_results DISABLE ROW LEVEL SECURITY;' + ddl.substring(rlsCreateEnd + 2);
}

// Seed data
const firstInsertAfterPerf = sql.indexOf('INSERT INTO auth.users', ddlEndIdx);
const seedData = sql.substring(firstInsertAfterPerf, section1Idx).trimEnd();

// Split seed
const authInsertRegex = /INSERT INTO auth\.users[\s\S]*?ON CONFLICT \(id\) DO NOTHING;\n*/g;
const authInserts = [];
let match;
while ((match = authInsertRegex.exec(seedData)) !== null) {
  authInserts.push(match[0].trimEnd());
}
const authInsertBlock = authInserts.join('\n\n');
let otherSeed = seedData;
for (const ai of authInserts) {
  otherSeed = otherSeed.replace(ai, '');
}
otherSeed = otherSeed.replace(/^\s*-- SEED DISPOSABLE[^\n]*\n/gm, '').trim();

// Test logic
const testStartIdx = sql.indexOf('PERFORM _anon();');
const testLogic = sql.substring(testStartIdx, summaryIdx).trimEnd();

// Wrap test logic with labeled dollar-quoting
let tagCounter = 0;
let currentTag = '';
const wrappedTest = testLogic.replace(/(DO \$\$|END \$\$\s*;)/g, (match) => {
  if (match.startsWith('DO')) {
    tagCounter++;
    currentTag = `tag${tagCounter}`;
    return `DO $${currentTag}$`;
  } else {
    return `END $${currentTag}$;`;
  }
});

// Results
const tail = sql.substring(summaryIdx).trim();
const resultsClean = tail.replace(/^\\echo\s+.+$/gm, '').trim().split('\n').map(line => line.trim().startsWith('PERFORM ') ? `DO $$ BEGIN ${line.trim()} END $$;` : line).join('\n');

const drops = [
  'DROP FUNCTION IF EXISTS _r(text,text,text,text);',
  'DROP FUNCTION IF EXISTS _anon();',
  'DROP FUNCTION IF EXISTS _as(text);',
  'DROP FUNCTION IF EXISTS _service();',
  'DROP TABLE IF EXISTS _rls_results;',
].join('\n');

const output = `-- ============================================================
-- Al Batal Elite -- Adversarial RLS (Node.js pg runner version)
-- ============================================================

BEGIN;

-- DDL
${drops}

${ddl}

-- PHASE 1: Seed auth.users (as postgres)
${authInsertBlock}

-- PHASE 2: Seed remaining data (service_role for RLS bypass)
DO $seed$ DECLARE
BEGIN
  PERFORM _service();
  ${otherSeed.replace(/\n/g, '\n  ')}
END $seed$;

-- PHASE 3: Test logic
DO $outer$ DECLARE
BEGIN
${wrappedTest}
END $outer$;

-- RESULTS
${resultsClean}

DROP TABLE IF EXISTS _rls_results;
ROLLBACK;
`;

writeFileSync('supabase/tests/test_rls_adversarial_cli.sql', output);
console.log(`Written: ${output.length} chars, ${output.split('\n').length} lines`);
