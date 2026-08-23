-- Aggregate only, no PII: has paymob-initiate ever created a payment on staging?
SELECT method, count(*) AS n,
  count(*) FILTER (WHERE paymob_order_id IS NOT NULL) AS with_provider_order
FROM public.payments
GROUP BY method
ORDER BY method;
