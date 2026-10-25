-- ============================================================
-- Migration 082: admin list pending InstaPay proofs
-- ============================================================
-- Verified gap: instapay_proofs already has an admin SELECT policy
-- (041_instapay_payment_method.sql:147-161), but payments is
-- owner-only (006_payments_table.sql:30-32), so the admin UI cannot
-- join proof -> payment -> order -> customer. review_instapay_proof
-- can act on a proof the admin already knows, but nothing lists the
-- pending review queue.
--
-- admin_list_instapay_proofs() returns the queue:
--   unreviewed proofs on pending payments, oldest first, max 100.
--
-- Fail closed: auth.uid() must be present AND profiles.is_admin must
-- be true; otherwise the WHERE guard returns zero rows (no exception,
-- so an unauthorized caller cannot probe the queue).
--
-- SECURITY DEFINER with a pinned search_path so the join can read
-- payments, orders and profiles regardless of the caller's RLS.
--
-- Owner review required before apply (AGENTS.md migration gate).
-- Idempotent: CREATE OR REPLACE.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.admin_list_instapay_proofs()
RETURNS TABLE (
  proof_id      uuid,
  payment_id    uuid,
  order_id      uuid,
  order_total   integer,
  customer_name text,
  reference     text,
  storage_path  text,
  created_at    timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    ip.id           AS proof_id,
    ip.payment_id   AS payment_id,
    p.order_id      AS order_id,
    o.total         AS order_total,
    pr.full_name    AS customer_name,
    ip.reference    AS reference,
    ip.storage_path AS storage_path,
    ip.created_at   AS created_at
  FROM public.instapay_proofs ip
  JOIN public.payments p  ON p.id = ip.payment_id
  JOIN public.orders   o  ON o.id = p.order_id
  JOIN public.profiles pr ON pr.id = p.user_id
  WHERE auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
        FROM public.profiles adm
       WHERE adm.id = auth.uid()
         AND adm.is_admin = true
    )
    AND ip.outcome IS NULL
    AND p.status = 'pending'
  ORDER BY ip.created_at ASC
  LIMIT 100;
$$;

REVOKE ALL ON FUNCTION public.admin_list_instapay_proofs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_instapay_proofs() TO authenticated;

COMMIT;
