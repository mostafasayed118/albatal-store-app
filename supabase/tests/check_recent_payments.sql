-- Check recent payments
SELECT id, order_id, status, method, amount, paymob_order_id, created_at, updated_at
FROM payments
ORDER BY created_at DESC
LIMIT 5;
