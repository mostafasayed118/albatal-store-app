-- ============================================================
-- Migration 040: relax user-ownership FKs for account deletion
-- (UX-043, decision B: retain transactional records, unlink the
-- user so the personal footprint is erased).
--
--   orders.user_id    NOT NULL, FK RESTRICT  → NULLABLE, FK ON DELETE SET NULL
--   payments.user_id  NOT NULL, FK CASCADE   → NULLABLE, FK ON DELETE SET NULL
--
-- After this migration, deleting an auth user cascades through
-- profiles and wipes addresses / wishlists / cart_items, while
-- order + payment rows survive with user_id = NULL (their
-- fulfillment/financial content is self-contained snapshots).
--
-- RLS impact: client SELECT policies filter by auth.uid() =
-- user_id, so orphaned retention rows are never visible through
-- the app. The edge function (delete-account) performs the delete
-- with the service role; no new client RLS path is introduced.
--
-- Forward-only, idempotent. Human review required before
-- `supabase db push`.
-- ============================================================

DO $$
BEGIN
  -- ─── orders: NOT NULL RESTRICT → NULLABLE SET NULL ─────────
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'orders_user_id_fkey' AND conrelid = 'public.orders'::regclass
  ) THEN
    ALTER TABLE public.orders DROP CONSTRAINT orders_user_id_fkey;
  END IF;

  ALTER TABLE public.orders ALTER COLUMN user_id DROP NOT NULL;

  ALTER TABLE public.orders
    ADD CONSTRAINT orders_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

  -- ─── payments: NOT NULL CASCADE → NULLABLE SET NULL ────────
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'payments_user_id_fkey' AND conrelid = 'public.payments'::regclass
  ) THEN
    ALTER TABLE public.payments DROP CONSTRAINT payments_user_id_fkey;
  END IF;

  ALTER TABLE public.payments ALTER COLUMN user_id DROP NOT NULL;

  ALTER TABLE public.payments
    ADD CONSTRAINT payments_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
END $$;
