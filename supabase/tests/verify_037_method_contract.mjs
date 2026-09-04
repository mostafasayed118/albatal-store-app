// Migration 037 contract verifier — static source checks.
// Run: node supabase/tests/verify_037_method_contract.mjs
// Exit 0 when all checks pass, 1 otherwise.
import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', 'migrations');
const file37 = join(root, '037_pending_order_payment_method.sql');
const file38 = join(root, '038_fix_037_grants.sql');
const file39 = join(root, '039_method_update_ensures_cod_row.sql');

let pass = 0;
let fail = 0;
const check = (name, cond) => {
  if (cond) { pass++; console.log(`  PASS ${name}`); }
  else { fail++; console.log(`  FAIL ${name}`); }
};

console.log('037 method-update contract:');
check('migration file exists', existsSync(file37));
check('038 grant-fix migration exists', existsSync(file38));
const src = existsSync(file37) ? readFileSync(file37, 'utf8') : '';
const src38 = existsSync(file38) ? readFileSync(file38, 'utf8') : '';

check('defines set_pending_order_payment_method(UUID, TEXT)',
  /CREATE OR REPLACE FUNCTION set_pending_order_payment_method\(\s*p_order_id UUID,\s*p_method\s+TEXT\s*\)/i.test(src));
check('SECURITY DEFINER', /SECURITY DEFINER/i.test(src));
check('locked search_path (public, pg_temp)',
  /SET\s+search_path\s*=\s*public\s*,\s*pg_temp/i.test(src));
check('revokes from PUBLIC/anon (038-corrected matrix)',
  /REVOKE ALL ON FUNCTION set_pending_order_payment_method\(UUID, TEXT\)[\s\S]*FROM PUBLIC,\s*anon/i.test(src38));
check('grants EXECUTE to authenticated (client calls it)',
  /GRANT EXECUTE ON FUNCTION set_pending_order_payment_method\(UUID, TEXT\)[\s\S]*TO authenticated/i.test(src38));
check('039 payment-row migration exists', existsSync(file39));
const src39 = existsSync(file39) ? readFileSync(file39, 'utf8') : '';
check('039 inserts pending cash_on_delivery row on cod switch',
  /INSERT INTO payments \(order_id, user_id, method, amount, status\)[\s\S]*'cash_on_delivery', total, 'pending'/i.test(src39));
check('039 insert guarded by NOT EXISTS (idempotent)',
  /AND NOT EXISTS \([\s\S]*status = 'pending'[\s\S]*method ILIKE '%cash%' OR method ILIKE '%cod%'/i.test(src39));
check('039 re-asserts client grant matrix',
  /GRANT EXECUTE ON FUNCTION set_pending_order_payment_method\(UUID, TEXT\)[\s\S]*TO authenticated/i.test(src39));
check('method allowlist cod+card',
  /p_method NOT IN \('cod',\s*'card'\)/i.test(src));
check('invalid_method code', /'invalid_method'/.test(src));
check('pending-only guard', /order_not_pending/.test(src));
check('owner check via auth.uid', /auth\.uid\(\)/.test(src));
check('not_owner code', /'not_owner'/.test(src));
check('authentication_required code', /'authentication_required'/.test(src));
check('order_not_found code', /'order_not_found'/.test(src));
check('returns JSONB ok/code envelope', /RETURNS JSONB[\s\S]*jsonb_build_object\(\s*'ok', true/i.test(src));
check('updates payment_method + updated_at',
  /UPDATE orders[\s\S]*SET payment_method = p_method,[\s\S]*updated_at = now\(\)/i.test(src));

console.log(`${pass}/${pass + fail} checks passed.`);
if (fail > 0) { console.log('037 method-update contract: FAIL'); process.exit(1); }
console.log('037 method-update contract: OK');
