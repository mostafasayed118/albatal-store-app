BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'product_reviews_text_length_check'
      AND conrelid = 'public.product_reviews'::regclass
  ) THEN
    ALTER TABLE public.product_reviews
      ADD CONSTRAINT product_reviews_text_length_check
      CHECK (char_length(text) <= 2000);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'product_reviews_photo_path_length_check'
      AND conrelid = 'public.product_reviews'::regclass
  ) THEN
    ALTER TABLE public.product_reviews
      ADD CONSTRAINT product_reviews_photo_path_length_check
      CHECK (photo_url IS NULL OR char_length(photo_url) <= 512);
  END IF;
END;
$$;

DROP POLICY IF EXISTS reviews_insert_buyers ON public.product_reviews;

INSERT INTO storage.buckets (id, name, public)
VALUES ('review-images', 'review-images', false)
ON CONFLICT (id) DO UPDATE SET public = false;

DROP POLICY IF EXISTS "review images owner read" ON storage.objects;
CREATE POLICY "review images owner read"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'review-images'
    AND (
      (storage.foldername(name))[1] = auth.uid()::TEXT
      OR EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.is_admin = true
      )
      OR EXISTS (
        SELECT 1 FROM public.product_reviews r
        WHERE r.photo_url = name AND r.status = 'approved'
      )
    )
  );

DROP POLICY IF EXISTS "review images owner write" ON storage.objects;
CREATE POLICY "review images owner write"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'review-images'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
    AND metadata->>'mimetype' IN ('image/jpeg', 'image/png', 'image/webp')
    AND COALESCE(metadata->>'size', metadata->>'contentLength') ~ '^[0-9]+$'
    AND (COALESCE(metadata->>'size', metadata->>'contentLength'))::BIGINT
        <= 5 * 1024 * 1024
  );

DROP POLICY IF EXISTS "review images owner delete" ON storage.objects;
CREATE POLICY "review images owner delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'review-images'
    AND (
      (storage.foldername(name))[1] = auth.uid()::TEXT
      OR EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.is_admin = true
      )
    )
  );

CREATE OR REPLACE FUNCTION public.submit_product_review(
  p_product_id UUID,
  p_rating INTEGER,
  p_text TEXT,
  p_photo_path TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_photo_path TEXT;
  v_review public.product_reviews;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 THEN
    RAISE EXCEPTION 'Invalid rating' USING ERRCODE = '22023';
  END IF;
  IF p_text IS NULL OR btrim(p_text) = '' OR char_length(p_text) > 2000 THEN
    RAISE EXCEPTION 'Invalid review text' USING ERRCODE = '22023';
  END IF;
  IF p_photo_path IS NOT NULL THEN
    v_photo_path := btrim(p_photo_path);
    IF v_photo_path = ''
       OR v_photo_path !~ ('^' || v_user_id::TEXT || '/' || p_product_id::TEXT || '/') THEN
      RAISE EXCEPTION 'Invalid review photo path' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM storage.objects o
      WHERE o.bucket_id = 'review-images'
        AND o.name = v_photo_path
        AND (storage.foldername(o.name))[1] = v_user_id::TEXT
        AND (storage.foldername(o.name))[2] = p_product_id::TEXT
        AND o.metadata->>'mimetype' IN ('image/jpeg', 'image/png', 'image/webp')
        AND COALESCE(o.metadata->>'size', o.metadata->>'contentLength') ~ '^[0-9]+$'
        AND (COALESCE(o.metadata->>'size', o.metadata->>'contentLength'))::BIGINT
            <= 5 * 1024 * 1024
    ) THEN
      RAISE EXCEPTION 'Review photo not found' USING ERRCODE = '22023';
    END IF;
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.order_items oi ON oi.order_id = o.id
    WHERE o.user_id = v_user_id
      AND o.status IN ('delivered', 'paid', 'shipped', 'processing')
      AND oi.product_id = p_product_id
  ) THEN
    RAISE EXCEPTION 'Purchase required' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.product_reviews (
    product_id, user_id, rating, text, photo_url, status
  )
  VALUES (
    p_product_id, v_user_id, p_rating, btrim(p_text), v_photo_path, 'pending'
  )
  RETURNING * INTO v_review;

  RETURN to_jsonb(v_review) || jsonb_build_object(
    'author_name', COALESCE(
      (SELECT NULLIF(p.full_name, '') FROM public.profiles p WHERE p.id = v_user_id),
      'Al Batal'
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_product_review(UUID, INTEGER, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_product_review(UUID, INTEGER, TEXT, TEXT) TO authenticated;

COMMIT;
