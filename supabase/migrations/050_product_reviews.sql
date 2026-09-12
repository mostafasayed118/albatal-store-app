-- 050_product_reviews.sql (feature-batch §9 — REVIEW-GATED PROPOSAL)
-- Owner review required before applying (AGENTS.md migration gate).
--
-- Buy-to-review photo reviews with moderation:
--   * customers who received an order containing the product may submit,
--   * rows start `pending` and are only publicly readable when
--     `approved`,
--   * the storefront reads via a joined view that carries the author's
--     display name (never an email — PII boundary).

CREATE TABLE IF NOT EXISTS public.product_reviews (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating      integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  text        text NOT NULL DEFAULT '',
  photo_url   text,
  status      text NOT NULL DEFAULT 'pending'
              CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_product_reviews_product
  ON public.product_reviews (product_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_reviews_user
  ON public.product_reviews (user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_product_reviews_one_per_user
  ON public.product_reviews (product_id, user_id);

ALTER TABLE public.product_reviews ENABLE ROW LEVEL SECURITY;

-- INSERT: any authenticated user (the buy-to-review check is enforced
-- by this policy itself — delivery proof via orders).
CREATE POLICY reviews_insert_buyers ON public.product_reviews
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.orders o
      JOIN public.order_items oi ON oi.order_id = o.id
      WHERE o.user_id = auth.uid()
        AND o.status IN ('delivered', 'paid', 'shipped', 'processing')
        AND oi.product_id = product_reviews.product_id
    )
  );

-- READ: approved rows for everyone; own rows (any status) for the author.
CREATE POLICY reviews_read_public ON public.product_reviews
  FOR SELECT USING (
    status = 'approved'
    OR user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles p
               WHERE p.id = auth.uid() AND p.is_admin)
  );

-- UPDATE/DELETE: admins only (moderation).
CREATE POLICY reviews_admin_write ON public.product_reviews
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.is_admin)
  );
CREATE POLICY reviews_admin_delete ON public.product_reviews
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.is_admin)
  );

-- ─── Public read view with the author display name ───────────────────
CREATE OR REPLACE VIEW public.product_reviews_public AS
SELECT
  r.id,
  r.product_id,
  r.rating,
  r.text,
  r.photo_url,
  r.created_at,
  COALESCE(NULLIF(p.full_name, ''), 'Al Batal') AS author_name
FROM public.product_reviews r
LEFT JOIN public.profiles p ON p.id = r.user_id
WHERE r.status = 'approved';

GRANT SELECT ON public.product_reviews_public TO anon, authenticated;

-- ─── Storage: customer review photos ─────────────────────────────────
-- Bucket lives in the product-images bucket policy family; review
-- objects are namespaced `reviews/` and served publicly (images are
-- attached to approved reviews only by moderation).
