BEGIN;

INSERT INTO storage.buckets (id, name, public)
VALUES ('instapay-proofs', 'instapay-proofs', false)
ON CONFLICT (id) DO UPDATE SET public = false;

UPDATE storage.buckets
   SET public = false
 WHERE id IN ('instapay-proofs', 'review-images');

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'storage'
      AND table_name = 'buckets'
      AND column_name = 'file_size_limit'
  ) OR NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'storage'
      AND table_name = 'buckets'
      AND column_name = 'allowed_mime_types'
  ) THEN
    RAISE EXCEPTION 'Supabase Storage bucket hardening columns are unavailable';
  END IF;
END;
$$;

UPDATE storage.buckets
   SET file_size_limit = 5 * 1024 * 1024,
       allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']::TEXT[]
 WHERE id IN ('instapay-proofs', 'review-images');

CREATE OR REPLACE FUNCTION public.set_payment_provider_order_id_claim(
  p_payment_id UUID,
  p_paymob_order_id TEXT,
  p_claim_token UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_payment RECORD;
BEGIN
  IF p_payment_id IS NULL OR p_claim_token IS NULL
     OR COALESCE(btrim(p_paymob_order_id), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_input');
  END IF;

  SELECT id, user_id, method, status, paymob_order_id,
         paymob_initiation_claim_token, paymob_initiation_phase
    INTO v_payment
    FROM public.payments
   WHERE id = p_payment_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_found');
  END IF;
  IF v_payment.method <> 'paymob_card' OR v_payment.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending');
  END IF;
  IF v_payment.paymob_order_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'already_set');
  END IF;
  IF v_payment.paymob_initiation_phase <> 'provider_submitted'
     OR v_payment.paymob_initiation_claim_token IS DISTINCT FROM p_claim_token THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_claim');
  END IF;

  UPDATE public.payments
     SET paymob_order_id = btrim(p_paymob_order_id),
         paymob_initiation_phase = 'provider_persisted',
         updated_at = now()
   WHERE id = p_payment_id
     AND status = 'pending'
     AND paymob_order_id IS NULL
     AND paymob_initiation_phase = 'provider_submitted'
     AND paymob_initiation_claim_token = p_claim_token;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_race');
  END IF;
  RETURN jsonb_build_object('ok', true, 'code', 'updated');
END;
$$;

REVOKE ALL ON FUNCTION public.set_payment_provider_order_id_claim(UUID, TEXT, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_payment_provider_order_id_claim(UUID, TEXT, UUID) TO service_role;
REVOKE ALL ON FUNCTION public.set_payment_provider_order_id(UUID, TEXT) FROM PUBLIC, anon, authenticated, service_role;

UPDATE public.payments
   SET method = 'cash_on_delivery', updated_at = now()
 WHERE method = 'cod'
   AND status = 'pending';

WITH ranked AS (
  SELECT p.id,
         row_number() OVER (
           PARTITION BY p.order_id,
             CASE
               WHEN p.method IN ('cod', 'cash_on_delivery') THEN 'cash_on_delivery'
               ELSE p.method
             END
           ORDER BY
             (EXISTS (
                SELECT 1
                FROM public.instapay_proofs ip
                WHERE ip.payment_id = p.id
                  AND ip.outcome IS NULL
             )) DESC,
             (p.paymob_order_id IS NOT NULL) DESC,
             p.created_at ASC,
             p.id ASC
         ) AS rn
    FROM public.payments p
   WHERE p.status = 'pending'
     AND p.method IN ('cod', 'cash_on_delivery', 'instapay')
)
UPDATE public.payments p
   SET status = 'cancelled', updated_at = now()
  FROM ranked r
 WHERE p.id = r.id
   AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_one_pending_instapay_per_order
  ON public.payments(order_id)
  WHERE method = 'instapay' AND status = 'pending';
CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_one_pending_cod_per_order
  ON public.payments(order_id)
  WHERE method IN ('cod', 'cash_on_delivery') AND status = 'pending';

CREATE OR REPLACE FUNCTION public.set_pending_order_payment_method(
  p_order_id UUID,
  p_method TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_owner UUID;
  v_status TEXT;
  v_method TEXT;
  v_payment_method TEXT;
  v_previous_method TEXT;
  v_current_expires_at TIMESTAMPTZ;
  v_inserted INTEGER := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  IF p_method IS NULL OR p_method NOT IN ('cod', 'card', 'paymob_card', 'instapay') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_method');
  END IF;
  v_method := CASE WHEN p_method = 'card' THEN 'paymob_card' ELSE p_method END;
  v_payment_method := CASE
    WHEN v_method = 'cod' THEN 'cash_on_delivery'
    ELSE v_method
  END;

  SELECT user_id, status::TEXT, payment_method, expires_at
    INTO v_owner, v_status, v_previous_method, v_current_expires_at
    FROM public.orders
   WHERE id = p_order_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;
  IF v_owner IS DISTINCT FROM v_user_id THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_owner');
  END IF;
  IF v_status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_pending');
  END IF;
  IF v_current_expires_at IS NOT NULL
     AND v_current_expires_at <= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_expired');
  END IF;

  PERFORM 1
    FROM public.payments
   WHERE order_id = p_order_id
     AND status = 'pending'
   FOR UPDATE;

  IF v_method IS DISTINCT FROM 'paymob_card'
     AND EXISTS (
       SELECT 1
       FROM public.payments
       WHERE order_id = p_order_id
         AND status = 'pending'
         AND (
           paymob_order_id IS NOT NULL
           OR paymob_initiation_phase IN ('provider_submitted', 'provider_persisted')
         )
     ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_in_progress');
  END IF;

  UPDATE public.orders
     SET payment_method = v_method,
          expires_at = CASE
             WHEN v_previous_method IS DISTINCT FROM v_method
               OR v_current_expires_at IS NULL THEN
              CASE WHEN v_method = 'instapay'
                   THEN now() + interval '24 hours'
                   ELSE now() + interval '15 minutes' END
            ELSE v_current_expires_at
          END,
         updated_at = now()
   WHERE id = p_order_id;

  UPDATE public.payments
     SET status = 'cancelled', updated_at = now()
   WHERE order_id = p_order_id
     AND user_id = v_user_id
     AND status = 'pending'
     AND CASE
       WHEN method IN ('cod', 'cash_on_delivery') THEN 'cod'
       WHEN method = 'paymob_card' THEN 'paymob_card'
       WHEN method = 'instapay' THEN 'instapay'
       ELSE method
     END <> v_method
     AND NOT (
       method = 'paymob_card'
       AND (
         paymob_order_id IS NOT NULL
         OR paymob_initiation_phase IN ('provider_submitted', 'provider_persisted')
       )
     );

  IF v_method = 'cod' THEN
    INSERT INTO public.payments (order_id, user_id, method, amount, status)
    SELECT p_order_id, v_user_id, v_payment_method, total, 'pending'
      FROM public.orders
     WHERE id = p_order_id
       AND NOT EXISTS (
         SELECT 1 FROM public.payments
          WHERE order_id = p_order_id
            AND status = 'pending'
            AND method IN ('cod', 'cash_on_delivery')
       );
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
  ELSIF v_method = 'instapay' THEN
    INSERT INTO public.payments (order_id, user_id, method, amount, status)
    SELECT p_order_id, v_user_id, 'instapay', total, 'pending'
      FROM public.orders
     WHERE id = p_order_id
       AND NOT EXISTS (
         SELECT 1 FROM public.payments
          WHERE order_id = p_order_id
            AND status = 'pending'
            AND method = 'instapay'
       );
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
  ELSIF v_method = 'paymob_card' THEN
    INSERT INTO public.payments (order_id, user_id, method, amount, status)
    SELECT p_order_id, v_user_id, 'paymob_card', total, 'pending'
      FROM public.orders
     WHERE id = p_order_id
       AND NOT EXISTS (
         SELECT 1 FROM public.payments
          WHERE order_id = p_order_id
            AND status = 'pending'
            AND method = 'paymob_card'
       );
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'method_updated',
    'order_id', p_order_id,
    'payment_method', v_method,
    'payment_row_ensured', v_inserted > 0
  );
END;
$$;

REVOKE ALL ON FUNCTION public.set_pending_order_payment_method(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_pending_order_payment_method(UUID, TEXT) TO authenticated;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.instapay_proofs
    WHERE (reference IS NOT NULL AND char_length(reference) > 64)
       OR (note IS NOT NULL AND char_length(note) > 2000)
  ) THEN
    RAISE EXCEPTION 'instapay_proofs contains oversized reference or note values';
  END IF;
END;
$$;

ALTER TABLE public.instapay_proofs
  DROP CONSTRAINT IF EXISTS instapay_proofs_reference_length_check;
ALTER TABLE public.instapay_proofs
  ADD CONSTRAINT instapay_proofs_reference_length_check
  CHECK (reference IS NULL OR char_length(reference) <= 64);
ALTER TABLE public.instapay_proofs
  DROP CONSTRAINT IF EXISTS instapay_proofs_note_length_check;
ALTER TABLE public.instapay_proofs
  ADD CONSTRAINT instapay_proofs_note_length_check
  CHECK (note IS NULL OR char_length(note) <= 2000);

WITH ranked AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY payment_id
           ORDER BY created_at DESC, id DESC
         ) AS rn
    FROM public.instapay_proofs
   WHERE outcome IS NULL
)
UPDATE public.instapay_proofs p
   SET outcome = 'rejected',
       reviewed_at = now(),
       note = COALESCE(p.note, 'Superseded duplicate proof')
  FROM ranked r
 WHERE p.id = r.id
   AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS uq_instapay_proofs_one_pending_per_payment
  ON public.instapay_proofs(payment_id)
  WHERE outcome IS NULL;

DROP POLICY IF EXISTS "instapay_proofs_insert_own" ON public.instapay_proofs;
CREATE POLICY "instapay_proofs_insert_own"
  ON public.instapay_proofs FOR INSERT
  WITH CHECK (
    outcome IS NULL
    AND reviewed_by IS NULL
    AND reviewed_at IS NULL
    AND (storage.foldername(storage_path))[1] = auth.uid()::TEXT
    AND (storage.foldername(storage_path))[2] = payment_id::TEXT
    AND EXISTS (
      SELECT 1
      FROM public.payments p
      JOIN public.orders o ON o.id = p.order_id
      WHERE p.id = payment_id
        AND p.user_id = auth.uid()
        AND p.status = 'pending'
        AND p.method = 'instapay'
        AND o.status = 'pending'
        AND (o.expires_at IS NULL OR o.expires_at > now())
    )
    AND EXISTS (
      SELECT 1
      FROM storage.objects o
      WHERE o.bucket_id = 'instapay-proofs'
        AND o.name = storage_path
        AND (storage.foldername(o.name))[1] = auth.uid()::TEXT
        AND (storage.foldername(o.name))[2] = payment_id::TEXT
        AND o.metadata->>'mimetype' IN ('image/jpeg', 'image/png', 'image/webp')
         AND COALESCE(o.metadata->>'size', o.metadata->>'contentLength') ~ '^[0-9]+$'
         AND (COALESCE(o.metadata->>'size', o.metadata->>'contentLength'))::BIGINT <= 5 * 1024 * 1024
    )
  );

CREATE OR REPLACE FUNCTION public.review_instapay_proof(
  p_proof_id UUID,
  p_approve BOOLEAN,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin UUID := auth.uid();
  v_is_admin BOOLEAN;
  v_payment RECORD;
  v_order_id UUID;
  v_method TEXT;
  v_payment_status TEXT;
  v_order_status TEXT;
BEGIN
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;
  SELECT is_admin INTO v_is_admin FROM public.profiles WHERE id = v_admin;
  IF v_is_admin IS DISTINCT FROM TRUE THEN
    RETURN jsonb_build_object('ok', false, 'code', 'admin_required');
  END IF;

  SELECT payment_id, outcome INTO v_payment
    FROM public.instapay_proofs
   WHERE id = p_proof_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_not_found');
  END IF;
  IF v_payment.outcome IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_already_reviewed');
  END IF;

  SELECT p.order_id, p.method, p.status, o.status::TEXT
    INTO v_order_id, v_method, v_payment_status, v_order_status
    FROM public.payments p
    JOIN public.orders o ON o.id = p.order_id
   WHERE p.id = v_payment.payment_id
   FOR UPDATE OF p, o;
  IF NOT FOUND OR v_method IS DISTINCT FROM 'instapay'
     OR v_payment_status IS DISTINCT FROM 'pending'
     OR v_order_status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending_instapay');
  END IF;

  IF p_approve THEN
    UPDATE public.payments
       SET status = 'success',
           transaction_id = 'instapay_' || p_proof_id::TEXT,
           updated_at = now()
     WHERE id = v_payment.payment_id AND status = 'pending';
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending');
    END IF;
  UPDATE public.orders
       SET status = 'paid', updated_at = now()
     WHERE id = v_order_id AND status = 'pending';
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'code', 'order_not_pending');
    END IF;
    UPDATE public.instapay_proofs
       SET outcome = 'approved', reviewed_by = v_admin,
           reviewed_at = now(), note = p_note
     WHERE id = p_proof_id;
  ELSE
    UPDATE public.payments
       SET status = 'failed', updated_at = now()
     WHERE id = v_payment.payment_id AND status = 'pending';
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending');
    END IF;
    UPDATE public.instapay_proofs
       SET outcome = 'rejected', reviewed_by = v_admin,
           reviewed_at = now(), note = p_note
     WHERE id = p_proof_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
    'payment_id', v_payment.payment_id,
    'order_id', v_order_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.review_instapay_proof(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_instapay_proof(UUID, BOOLEAN, TEXT) TO authenticated;

GRANT EXECUTE ON FUNCTION public.expire_stale_instapay_payments() TO service_role;

CREATE OR REPLACE FUNCTION public.rate_limit_take(
  p_bucket TEXT,
  p_limit INTEGER,
  p_window_seconds INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_window BIGINT := extract(epoch FROM now())::BIGINT / greatest(p_window_seconds, 1);
  v_bucket TEXT;
  v_allowed BOOLEAN;
BEGIN
  IF p_bucket IS NULL OR length(p_bucket) > 200
     OR p_bucket !~ '^(acct|init|proof|cb|validate_coupon):[A-Za-z0-9:._-]+$'
     OR p_limit IS NULL OR p_limit < 1 OR p_limit > 1000
     OR p_window_seconds IS NULL OR p_window_seconds < 1
     OR p_window_seconds > 86400 THEN
    RETURN false;
  END IF;

  v_bucket := CASE
    WHEN auth.uid() IS NOT NULL THEN split_part(p_bucket, ':', 1) || ':' || auth.uid()::TEXT
    ELSE p_bucket
  END;

  INSERT INTO public.rate_limits (bucket, window_id, count)
  VALUES (v_bucket, v_window, 1)
  ON CONFLICT (bucket, window_id)
  DO UPDATE SET count = public.rate_limits.count + 1
  WHERE public.rate_limits.count < p_limit;
  v_allowed := found;

  IF random() < 0.01 THEN
    DELETE FROM public.rate_limits
     WHERE window_id < extract(epoch FROM now())::BIGINT - 172800;
  END IF;
  RETURN v_allowed;
END;
$$;

REVOKE ALL ON FUNCTION public.rate_limit_take(TEXT, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rate_limit_take(TEXT, INTEGER, INTEGER) TO authenticated, service_role;

COMMIT;

