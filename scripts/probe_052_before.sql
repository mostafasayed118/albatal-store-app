-- scripts/probe_052_before.sql — expect 0 rows before 052 is applied
SELECT count(*) AS showcase_products FROM products
WHERE id IN (
  'cccc0001-0001-0001-0001-000000000001',
  'cccc0002-0001-0001-0001-000000000002',
  'cccc0003-0001-0001-0001-000000000003'
);
-- Expected before: showcase_products = 0
