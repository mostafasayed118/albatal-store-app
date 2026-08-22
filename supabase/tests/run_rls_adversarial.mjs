import { Client } from 'pg';
import { readFileSync } from 'fs';

let sql = readFileSync('supabase/tests/test_rls_adversarial_cli.sql', 'utf8');

const client = new Client({
  connectionString: 'postgresql://postgres.alxwvyflasewslinufqe:MZ1avH7HTec2yGht@aws-0-eu-west-1.pooler.supabase.com:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

try {
  await client.connect();
  console.log('Connected to Supabase database.\n');
  console.log('Running adversarial RLS tests...\n');

  // Split into 3 queries: DDL+seed, test logic, results
  const phase3Idx = sql.indexOf('-- PHASE 3');
  const resultsIdx = sql.indexOf('-- RESULTS');
  const seedPart = sql.substring(0, phase3Idx);
  const testPart = sql.substring(phase3Idx, resultsIdx);
  const resultsPart = sql.substring(resultsIdx);

  // DDL + Seed
  await client.query(seedPart);
  console.log('✅ DDL + Seed completed');

  // Test logic
  await client.query(testPart);
  console.log('✅ Test logic completed');

  // Results: run each SELECT separately
  console.log('\n═══════════════════════════════════════════════════════');
  console.log('  RLS TEST RESULTS');
  console.log('═══════════════════════════════════════════════════════\n');

  const allResults = await client.query(
    `SELECT test_id, description, expected, actual, status
     FROM _rls_results
     ORDER BY test_id`
  );
  console.table(allResults.rows);

  const summary = await client.query(
    `SELECT
       COUNT(*) FILTER (WHERE status = 'PASS') AS passed,
       COUNT(*) FILTER (WHERE status = 'FAIL') AS failed,
       COUNT(*) AS total,
       CASE
         WHEN COUNT(*) FILTER (WHERE status = 'FAIL') = 0
         THEN 'ALL PASS — RLS VERIFIED'
         ELSE 'FAILURES DETECTED — RLS NOT VERIFIED'
       END AS verdict
     FROM _rls_results`
  );
  console.log('═══════════════════════════════════════════════════════');
  console.table(summary.rows);

  const failures = await client.query(
    `SELECT test_id, description, expected, actual
     FROM _rls_results
     WHERE status = 'FAIL'
     ORDER BY test_id`
  );
  if (failures.rows.length > 0) {
    console.log('═══════════════════════════════════════════════════════');
    console.log('  FAILURES');
    console.log('═══════════════════════════════════════════════════════\n');
    console.table(failures.rows);
  } else {
    console.log('\nNo failures — all tests passed!');
  }

} catch (err) {
  console.error('❌ Error:', err.message);
} finally {
  try { await client.query('ROLLBACK;'); } catch(e) {}
  await client.end();
}
